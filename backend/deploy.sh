#!/usr/bin/env bash
# deploy.sh — Docker Compose deployment for CoLiz backend.
#
# Usage:
#   ./deploy.sh                         # interactive: prompts for environment
#   ./deploy.sh prod                    # defaults to "up"
#   ./deploy.sh prod up                 # build images and start all services
#   ./deploy.sh prod down               # stop and remove all containers
#   ./deploy.sh prod down api worker    # stop specific services
#   ./deploy.sh prod restart            # restart all services
#   ./deploy.sh prod restart api worker # restart specific services
#   ./deploy.sh prod rotate             # rotate secrets and restart api+worker
#   ./deploy.sh prod logs <svc>         # follow logs for a service
#   ./deploy.sh prod status             # show container status
#   ./deploy.sh prod build              # build images only
#
# Prerequisites: docker (with Compose v2 plugin)
#
# Automated rotation via cron (adjust path as needed):
#   0 3 * * 1   /path/to/backend/deploy.sh prod rotate >> /path/to/backend/runtime/logs/rotate-cron.log 2>&1

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

# ── 1. select environment ─────────────────────────────────────────────────────

if [[ "${1:-}" == "prod" || "${1:-}" == "dev" ]]; then
  ENV="$1"
  shift
else
  printf '\n  CoLiz Backend Deployment\n'
  printf '  ════════════════════════\n'
  PS3='  Select environment: '
  select ENV in prod dev; do
    [[ -n "$ENV" ]] && break
    echo '  Please enter 1 (prod) or 2 (dev).'
  done
fi

ENV_FILE="${ENV}.env"

if [[ ! -f "$ENV_FILE" ]]; then
  printf '\n  [error] %s not found.\n' "$ENV_FILE"
  printf '  Create it with the required variables listed at the top of deploy.sh.\n\n'
  exit 1
fi

printf '\n  env=%-5s  file=%s\n\n' "$ENV" "$ENV_FILE"

# ── 2. helpers ────────────────────────────────────────────────────────────────

log() { printf '  %s\n' "$*"; }

# Auto-detect compose backend: prefer Docker Compose plugin, fall back to Podman.
if docker compose version >/dev/null 2>&1; then
  DC="docker compose"
elif podman compose version >/dev/null 2>&1; then
  DC="podman compose"
else
  printf '\n  [error] no compose backend found.\n'
  printf '  Install Docker Engine + Compose plugin, or: dnf install podman-compose\n\n'
  exit 1
fi

# ── 3. commands ───────────────────────────────────────────────────────────────

do_build() {
  log "building images..."
  $DC build
  log "build complete"
}

do_up() {
  log "creating required directories..."
  mkdir -p storage/data/mysql storage/data/redis storage/avatars runtime
  log "building images..."
  $DC build
  log "running initial rotation..."
  $DC --profile rotation run --rm -T rotation bash scripts/rotation.sh
  log "starting services..."
  $DC up -d
  printf '\n'
  do_status
}

do_down() {
  local services=("$@")
  if [[ ${#services[@]} -eq 0 ]]; then
    log "stopping all services..."
    $DC down
  else
    log "stopping: ${services[*]}"
    $DC stop "${services[@]}"
    $DC rm -f "${services[@]}"
  fi
}

do_restart() {
  local services=("$@")
  if [[ ${#services[@]} -eq 0 ]]; then
    log "restarting all services..."
    $DC restart
  else
    log "restarting: ${services[*]}"
    $DC restart "${services[@]}"
  fi
}

do_rotate() {
  log "rotating secrets..."
  $DC --profile rotation run --rm -T rotation bash scripts/rotation.sh
  log "restarting api and worker to load new secrets..."
  $DC restart api worker
  log "rotation complete"
}

do_status() {
  $DC ps
}

do_logs() {
  local name="${1:-}"
  if [[ -z "$name" ]]; then
    log "usage: ./deploy.sh $ENV logs <service>"
    log "services: api worker dlq_cleaner mysql redis"
    exit 1
  fi
  $DC logs -f "$name"
}

# ── 4. dispatch ───────────────────────────────────────────────────────────────

case "${1:-up}" in
  up)      do_up ;;
  down)    do_down "${@:2}" ;;
  restart) do_restart "${@:2}" ;;
  rotate)  do_rotate ;;
  status)  do_status ;;
  logs)    do_logs "${2:-}" ;;
  build)   do_build ;;
  *)
    printf '  unknown command: %s\n' "${1:-}"
    printf '  usage: %s [env] [up|down|restart|rotate|logs|status|build]\n' "$0"
    exit 1
    ;;
esac
