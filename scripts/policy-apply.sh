#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/demo-lib.sh
source "$SCRIPT_DIR/demo-lib.sh"

MODE="scripted"
TARGET_STATE="writeable"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/policy-apply.sh [readonly|writeable] [--mode scripted|live]

Examples:
  ./scripts/policy-apply.sh writeable
  ./scripts/policy-apply.sh readonly
  ./scripts/policy-apply.sh writeable --mode live
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    readonly|writeable)
      TARGET_STATE="$1"
      shift
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

ensure_runtime
FROM_STATE="$(current_policy_state)"
FROM_POLICY="$(policy_name_for_state "$FROM_STATE")"
TO_POLICY="$(policy_name_for_state "$TARGET_STATE")"
POLICY_FILE="$(policy_file_for_state "$TARGET_STATE")"

case "$MODE" in
  scripted)
    set_policy_state "$TARGET_STATE"
    log_reload "$FROM_POLICY" "$TO_POLICY"
    printf 'Applied scripted policy state: %s -> %s (0 restarts)\n' "$FROM_POLICY" "$TO_POLICY"
    ;;
  live)
    command_exists openshell || die "openshell CLI not found"
    openshell policy set "$SANDBOX_NAME" --policy "$POLICY_FILE" --wait
    set_policy_state "$TARGET_STATE"
    log_reload "$FROM_POLICY" "$TO_POLICY"
    printf 'Applied live OpenShell policy: %s -> %s\n' "$FROM_POLICY" "$TO_POLICY"
    ;;
  *)
    die "unknown mode: $MODE"
    ;;
esac
