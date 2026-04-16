#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

STATE_ENV_FILE="${ROTATION_ENV_FILE:-${BACKEND_DIR}/runtime/rotation.env}"
KEEP="${ROTATION_KEEP:-3}"
TARGET="${ROTATION_TARGET:-all}"
ROTATION_VERSION="${ROTATION_VERSION:-v$(date -u +%Y%m%d%H%M%S)}"

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

log() {
  printf '[%s] [rotation] %s\n' "$(timestamp)" "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "missing required command: $1"
    exit 1
  fi
}

ensure_positive_int() {
  local value="$1"
  local name="$2"
  if [[ ! "$value" =~ ^[1-9][0-9]*$ ]]; then
    log "$name must be a positive integer, got: $value"
    exit 1
  fi
}

load_env_if_exists() {
  local file="$1"
  if [[ -f "$file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$file"
    set +a
  fi
}

generate_secret() {
  openssl rand -hex 32
}

pair_index() {
  local version="$1"
  local versions_name="$2"
  local len
  local current
  local i

  len="$(eval "printf '%s' \"\${#${versions_name}[@]}\"")"
  for ((i = 0; i < len; i++)); do
    current="$(eval "printf '%s' \"\${${versions_name}[${i}]}\"")"
    if [[ "$current" == "$version" ]]; then
      printf '%s' "$i"
      return 0
    fi
  done

  return 1
}

append_pair_if_missing() {
  local version="$1"
  local value="$2"
  local versions_name="$3"
  local values_name="$4"

  [[ -z "$version" || -z "$value" ]] && return 0

  if pair_index "$version" "$versions_name" >/dev/null 2>&1; then
    return 0
  fi

  eval "${versions_name}+=(\"\$version\")"
  eval "${values_name}+=(\"\$value\")"
}

prepend_pair() {
  local version="$1"
  local value="$2"
  local versions_name="$3"
  local values_name="$4"
  local new_versions=("$version")
  local new_values=("$value")
  local len
  local current_version
  local current_value
  local i

  len="$(eval "printf '%s' \"\${#${versions_name}[@]}\"")"
  for ((i = 0; i < len; i++)); do
    current_version="$(eval "printf '%s' \"\${${versions_name}[${i}]}\"")"
    current_value="$(eval "printf '%s' \"\${${values_name}[${i}]}\"")"
    if [[ "$current_version" == "$version" ]]; then
      continue
    fi
    new_versions+=("$current_version")
    new_values+=("$current_value")
  done

  eval "${versions_name}=()"
  eval "${values_name}=()"
  for i in "${!new_versions[@]}"; do
    eval "${versions_name}+=(\"\${new_versions[$i]}\")"
    eval "${values_name}+=(\"\${new_values[$i]}\")"
  done
}

load_pairs() {
  local raw_pairs="$1"
  local current_version="$2"
  local current_value="$3"
  local versions_name="$4"
  local values_name="$5"

  eval "${versions_name}=()"
  eval "${values_name}=()"

  append_pair_if_missing "$current_version" "$current_value" "$versions_name" "$values_name"

  if [[ -z "$raw_pairs" ]]; then
    return 0
  fi

  local pair version value
  local -a parsed_pairs=()
  IFS=',' read -r -a parsed_pairs <<< "$raw_pairs"
  for pair in "${parsed_pairs[@]}"; do
    [[ -z "${pair// }" ]] && continue
    version="${pair%%:*}"
    value="${pair#*:}"
    append_pair_if_missing "$version" "$value" "$versions_name" "$values_name"
  done
}

truncate_pairs() {
  local limit="$1"
  local versions_name="$2"
  local values_name="$3"
  local len
  local truncated_versions=()
  local truncated_values=()
  local i

  len="$(eval "printf '%s' \"\${#${versions_name}[@]}\"")"
  if (( len <= limit )); then
    return 0
  fi

  for ((i = 0; i < limit; i++)); do
    truncated_versions+=("$(eval "printf '%s' \"\${${versions_name}[${i}]}\"")")
    truncated_values+=("$(eval "printf '%s' \"\${${values_name}[${i}]}\"")")
  done

  eval "${versions_name}=()"
  eval "${values_name}=()"
  for i in "${!truncated_versions[@]}"; do
    eval "${versions_name}+=(\"\${truncated_versions[$i]}\")"
    eval "${values_name}+=(\"\${truncated_values[$i]}\")"
  done
}

join_pairs() {
  local versions_name="$1"
  local values_name="$2"
  local joined=""
  local len
  local current_version
  local current_value
  local i

  len="$(eval "printf '%s' \"\${#${versions_name}[@]}\"")"
  for ((i = 0; i < len; i++)); do
    current_version="$(eval "printf '%s' \"\${${versions_name}[${i}]}\"")"
    current_value="$(eval "printf '%s' \"\${${values_name}[${i}]}\"")"
    if [[ -n "$joined" ]]; then
      joined+=","
    fi
    joined+="${current_version}:${current_value}"
  done

  printf '%s' "$joined"
}

_TMP_FILE=""

cleanup_on_exit() {
  if [[ -n "$_TMP_FILE" && -f "$_TMP_FILE" ]]; then
    rm -f "$_TMP_FILE"
    log "removed incomplete tmp file on exit"
  fi
}

trap cleanup_on_exit EXIT

should_rotate_jwt() {
  [[ "$TARGET" == "all" || "$TARGET" == "jwt" ]]
}

should_rotate_rtk() {
  [[ "$TARGET" == "all" || "$TARGET" == "rtk" ]]
}

main() {
  require_cmd openssl
  ensure_positive_int "$KEEP" "ROTATION_KEEP"
  case "$TARGET" in
    all|jwt|rtk) ;;
    *)
      log "ROTATION_TARGET must be one of: all, jwt, rtk"
      exit 1
      ;;
  esac

  mkdir -p "$(dirname "$STATE_ENV_FILE")"
  load_env_if_exists "$STATE_ENV_FILE"

  local jwt_current_version="${JWT_CUR_KEY_VERSION:-}"
  local jwt_current_value="${JWT_KEY:-}"
  local jwt_pairs_raw="${JWT_KEYS:-}"
  local rtk_current_version="${AUTH_RTK_PEPPER_VERSION:-}"
  local rtk_current_value="${AUTH_RTK_PEPPER:-}"
  local rtk_pairs_raw="${AUTH_RTK_PEPPERS:-}"

  local jwt_versions=()
  local jwt_values=()
  local rtk_versions=()
  local rtk_values=()

  load_pairs "$jwt_pairs_raw" "$jwt_current_version" "$jwt_current_value" jwt_versions jwt_values
  load_pairs "$rtk_pairs_raw" "$rtk_current_version" "$rtk_current_value" rtk_versions rtk_values

  if [[ ( -z "$jwt_current_version" || -z "$jwt_current_value" ) && ${#jwt_versions[@]} -gt 0 ]]; then
    jwt_current_version="${jwt_versions[0]}"
    jwt_current_value="${jwt_values[0]}"
  fi
  if [[ ( -z "$rtk_current_version" || -z "$rtk_current_value" ) && ${#rtk_versions[@]} -gt 0 ]]; then
    rtk_current_version="${rtk_versions[0]}"
    rtk_current_value="${rtk_values[0]}"
  fi

  local jwt_bootstrapped=false
  local rtk_bootstrapped=false

  # Bootstrap any missing rotation state directly in runtime/rotation.env so
  # the base env files do not need to carry rotation secrets.
  if [[ -z "$jwt_current_version" || -z "$jwt_current_value" ]]; then
    jwt_current_version="$ROTATION_VERSION"
    jwt_current_value="$(generate_secret)"
    prepend_pair "$jwt_current_version" "$jwt_current_value" jwt_versions jwt_values
    jwt_bootstrapped=true
    log "initialized JWT key at ${jwt_current_version}"
  fi

  if [[ -z "$rtk_current_version" || -z "$rtk_current_value" ]]; then
    rtk_current_version="$ROTATION_VERSION"
    rtk_current_value="$(generate_secret)"
    prepend_pair "$rtk_current_version" "$rtk_current_value" rtk_versions rtk_values
    rtk_bootstrapped=true
    log "initialized RTK pepper at ${rtk_current_version}"
  fi

  if should_rotate_jwt && [[ "$jwt_bootstrapped" != "true" ]]; then
    jwt_current_version="$ROTATION_VERSION"
    jwt_current_value="$(generate_secret)"
    prepend_pair "$jwt_current_version" "$jwt_current_value" jwt_versions jwt_values
    log "rotated JWT key to ${jwt_current_version}"
  fi

  if should_rotate_rtk && [[ "$rtk_bootstrapped" != "true" ]]; then
    rtk_current_version="$ROTATION_VERSION"
    rtk_current_value="$(generate_secret)"
    prepend_pair "$rtk_current_version" "$rtk_current_value" rtk_versions rtk_values
    log "rotated RTK pepper to ${rtk_current_version}"
  fi

  truncate_pairs "$KEEP" jwt_versions jwt_values
  truncate_pairs "$KEEP" rtk_versions rtk_values

  local jwt_pairs
  local rtk_pairs
  jwt_pairs="$(join_pairs jwt_versions jwt_values)"
  rtk_pairs="$(join_pairs rtk_versions rtk_values)"

  local tmp_file
  tmp_file="$(mktemp "${STATE_ENV_FILE}.XXXXXX")"
  _TMP_FILE="$tmp_file"
  chmod 600 "$tmp_file"

  cat >"$tmp_file" <<EOF
# Generated by backend/scripts/rotation.sh on $(timestamp)
# This file is the single source of truth for rotation-managed secrets.

JWT_CUR_KEY_VERSION=${jwt_current_version}
JWT_KEY=${jwt_current_value}
JWT_KEYS=${jwt_pairs}

AUTH_RTK_PEPPER_VERSION=${rtk_current_version}
AUTH_RTK_PEPPER=${rtk_current_value}
AUTH_RTK_PEPPERS=${rtk_pairs}
EOF

  mv "$tmp_file" "$STATE_ENV_FILE"

  log "wrote rotation state to ${STATE_ENV_FILE}"
  log "retained JWT versions: ${#jwt_versions[@]}"
  log "retained RTK pepper versions: ${#rtk_versions[@]}"
}

main "$@"
