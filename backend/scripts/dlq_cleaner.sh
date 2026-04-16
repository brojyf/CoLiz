#!/usr/bin/env bash
# backend/scripts/dlq_cleaner.sh

# Execute once, for cron
# backend/scripts/dlq_cleaner.sh --once

# Stop running process
# backend/scripts/dlq_cleaner.sh --stop

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load local development env if present. This keeps the script aligned with backend/dev.sh.
if [[ -f "${BACKEND_DIR}/dev.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${BACKEND_DIR}/dev.env"
  set +a
fi

MODE="loop"
if [[ "${1:-}" == "--once" ]]; then
  MODE="once"
elif [[ "${1:-}" == "--stop" ]]; then
  MODE="stop"
fi

INTERVAL_SECONDS="${DLQ_CLEANER_INTERVAL_SECONDS:-3600}"
RETENTION_DAYS="${DLQ_CLEANER_RETENTION_DAYS:-30}"
BATCH_SIZE="${DLQ_CLEANER_BATCH_SIZE:-1000}"
STATUSES_CSV="${DLQ_CLEANER_STATUSES:-sent,dead}"
DRY_RUN="${DLQ_CLEANER_DRY_RUN:-0}"
LOCK_FILE="${DLQ_CLEANER_LOCK_FILE:-/tmp/coliz-email-dlq-cleaner.lock}"
PID_FILE="${DLQ_CLEANER_PID_FILE:-/tmp/coliz-email-dlq-cleaner.pid}"

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

log() {
  printf '[%s] [dlq_cleaner] %s\n' "$(timestamp)" "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "missing required command: $1"
    exit 1
  fi
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

build_status_predicate() {
  local raw_csv="$1"
  local status
  local predicate=""

  IFS=',' read -r -a statuses <<< "$raw_csv"
  for status in "${statuses[@]}"; do
    status="$(trim "$status")"
    [[ -z "$status" ]] && continue
    if [[ ! "$status" =~ ^[A-Za-z_]+$ ]]; then
      log "invalid DLQ status value: $status"
      exit 1
    fi
    if [[ -n "$predicate" ]]; then
      predicate+=", "
    fi
    predicate+="'$status'"
  done

  if [[ -z "$predicate" ]]; then
    log "DLQ_CLEANER_STATUSES is empty after parsing"
    exit 1
  fi

  printf '%s' "$predicate"
}

mysql_exec() {
  local sql="$1"

  if [[ -n "${MYSQL_CLI:-}" ]]; then
    eval "${MYSQL_CLI}" -N -B -e "\"${sql}\""
    return
  fi

  if [[ -n "${MYSQL_DATABASE:-}" && -n "${MYSQL_USER:-}" ]]; then
    local db_host="${MYSQL_HOST:-localhost}"
    local db_port="${MYSQL_PORT:-3306}"

    if [[ -n "${MYSQL_PASSWORD:-}" ]]; then
      MYSQL_PWD="${MYSQL_PASSWORD}" mysql \
        --host="$db_host" \
        --port="$db_port" \
        --user="${MYSQL_USER}" \
        --database="${MYSQL_DATABASE}" \
        --batch \
        --skip-column-names \
        -e "$sql"
    else
      mysql \
        --host="$db_host" \
        --port="$db_port" \
        --user="${MYSQL_USER}" \
        --database="${MYSQL_DATABASE}" \
        --batch \
        --skip-column-names \
        -e "$sql"
    fi
    return
  fi

  if [[ -n "${MYSQL_DSN:-}" ]]; then
    local dsn_no_params="${MYSQL_DSN%%\?*}"
    local creds="${dsn_no_params%%@tcp(*}"
    local host_port_and_db="${dsn_no_params#*@tcp(}"
    local host_port="${host_port_and_db%%)/*}"
    local db_name="${host_port_and_db#*)/}"
    local db_host="${host_port%%:*}"
    local db_port="${host_port##*:}"
    local db_user="${creds%%:*}"
    local db_pass="${creds#*:}"

    if [[ -z "$db_host" || -z "$db_port" || -z "$db_name" || -z "$db_user" ]]; then
      log "failed to parse MYSQL_DSN; set MYSQL_CLI explicitly if your DSN format differs"
      exit 1
    fi

    MYSQL_PWD="$db_pass" mysql \
      --host="$db_host" \
      --port="$db_port" \
      --user="$db_user" \
      --database="$db_name" \
      --batch \
      --skip-column-names \
      -e "$sql"
    return
  fi

  log "missing database config; set MYSQL_DATABASE/MYSQL_USER[/MYSQL_PASSWORD], MYSQL_DSN, or MYSQL_CLI"
  exit 1
}

stop_daemon() {
  if [[ ! -f "$PID_FILE" ]]; then
    log "no PID file found at ${PID_FILE}; is the cleaner running?"
    exit 1
  fi
  local pid
  pid="$(cat "$PID_FILE")"
  if ! kill -0 "$pid" 2>/dev/null; then
    log "process ${pid} is not running; removing stale PID file"
    rm -f "$PID_FILE"
    exit 0
  fi
  log "sending SIGTERM to process ${pid}"
  kill -TERM "$pid"
  local waited=0
  while kill -0 "$pid" 2>/dev/null && (( waited < 30 )); do
    sleep 1
    (( waited++ ))
  done
  if kill -0 "$pid" 2>/dev/null; then
    log "process did not stop within 30s; sending SIGKILL"
    kill -9 "$pid"
  else
    log "process ${pid} stopped"
  fi
}

cleanup_once() {
  local statuses_sql
  local count_sql
  local delete_sql
  local candidates
  local deleted

  statuses_sql="$(build_status_predicate "$STATUSES_CSV")"

  count_sql="
    SELECT COUNT(*)
    FROM email_dlq
    WHERE status IN (${statuses_sql})
      AND created_at < (NOW() - INTERVAL ${RETENTION_DAYS} DAY);
  "
  candidates="$(mysql_exec "$count_sql" | tail -n 1 | tr -d '[:space:]')"
  candidates="${candidates:-0}"

  if [[ "$candidates" == "0" ]]; then
    log "no expired rows to clean"
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log "dry run: ${candidates} expired rows would be deleted"
    return 0
  fi

  delete_sql="
    DELETE FROM email_dlq
    WHERE status IN (${statuses_sql})
      AND created_at < (NOW() - INTERVAL ${RETENTION_DAYS} DAY)
    ORDER BY created_at
    LIMIT ${BATCH_SIZE};

    SELECT ROW_COUNT();
  "
  deleted="$(mysql_exec "$delete_sql" | tail -n 1 | tr -d '[:space:]')"
  deleted="${deleted:-0}"

  log "deleted ${deleted} expired rows (retention=${RETENTION_DAYS}d statuses=${STATUSES_CSV} batch=${BATCH_SIZE} remaining_candidates_before_run=${candidates})"
}

main() {
  require_cmd mysql
  require_cmd flock

  if [[ "$MODE" == "stop" ]]; then
    stop_daemon
    return 0
  fi

  exec 9>"${LOCK_FILE}"
  if ! flock -n 9; then
    log "another cleaner instance is already running"
    exit 0
  fi

  log "starting mode=${MODE} retention=${RETENTION_DAYS}d interval=${INTERVAL_SECONDS}s statuses=${STATUSES_CSV} batch=${BATCH_SIZE} dry_run=${DRY_RUN}"

  if [[ "$MODE" == "once" ]]; then
    cleanup_once
    return 0
  fi

  # loop mode: write PID file and register cleanup/stop traps
  echo $$ > "$PID_FILE"
  trap 'rm -f "$PID_FILE"; log "stopped"' EXIT

  local _stop=0
  trap '_stop=1' SIGTERM SIGINT

  while true; do
    cleanup_once
    (( _stop )) && break
    # interruptible sleep: background sleep + wait so SIGTERM wakes us immediately
    sleep "${INTERVAL_SECONDS}" &
    wait $! || true
    (( _stop )) && break
  done
}

main "$@"
