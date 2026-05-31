#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="${OPENSHELL_DEMO_RUNTIME:-$ROOT_DIR/.demo-runtime}"
AUDIT_LOG="$RUNTIME_DIR/audit.log"
STATE_FILE="$RUNTIME_DIR/policy-state"
SANDBOX_NAME="${OPENSHELL_SANDBOX_NAME:-copilot-demo}"
DEMO_REPO="${DEMO_REPO:-alig80/OpenShell-demo}"

ensure_runtime() {
  mkdir -p "$RUNTIME_DIR"
  touch "$AUDIT_LOG"
  if [[ ! -f "$STATE_FILE" ]]; then
    printf 'readonly\n' > "$STATE_FILE"
  fi
}

timestamp() {
  date '+%H:%M:%S'
}

current_policy_state() {
  ensure_runtime
  tr -d '[:space:]' < "$STATE_FILE"
}

set_policy_state() {
  ensure_runtime
  case "${1:-}" in
    readonly|writeable)
      printf '%s\n' "$1" > "$STATE_FILE"
      ;;
    *)
      printf 'unknown policy state: %s\n' "${1:-}" >&2
      return 2
      ;;
  esac
}

policy_name_for_state() {
  case "${1:-$(current_policy_state)}" in
    readonly) printf 'copilot-readonly' ;;
    writeable) printf 'copilot-writeable' ;;
    *) printf 'unknown' ;;
  esac
}

policy_file_for_state() {
  case "${1:-$(current_policy_state)}" in
    readonly) printf '%s/policies/copilot-readonly.yaml' "$ROOT_DIR" ;;
    writeable) printf '%s/policies/copilot-writeable.yaml' "$ROOT_DIR" ;;
    *) return 2 ;;
  esac
}

log_decision() {
  ensure_runtime
  local decision="$1"
  local method="$2"
  local host="$3"
  local target="$4"
  local rule="$5"
  local reason="${6:-}"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(timestamp)" "$decision" "$method" "$host" "$target" "$rule" "$reason" >> "$AUDIT_LOG"
}

log_reload() {
  ensure_runtime
  local from_policy="$1"
  local to_policy="$2"
  printf '%s\tRELOAD\tpolicy\t%s\t%s\tpolicy-reload\t0 restarts\n' \
    "$(timestamp)" "$SANDBOX_NAME" "$from_policy -> $to_policy" >> "$AUDIT_LOG"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}
