#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/demo-lib.sh
source "$SCRIPT_DIR/demo-lib.sh"

MODE="scripted"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/reset.sh [--mode scripted|live]

Scripted reset clears the local decision stream and returns policy to readonly.
Live reset also tries to delete the named OpenShell sandbox.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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
: > "$AUDIT_LOG"
set_policy_state readonly
printf 'Reset scripted runtime: %s\n' "$RUNTIME_DIR"

if [[ "$MODE" == "live" ]]; then
  command_exists openshell || die "openshell CLI not found"
  openshell sandbox delete "$SANDBOX_NAME" || true
  printf 'Requested live sandbox cleanup: %s\n' "$SANDBOX_NAME"
elif [[ "$MODE" != "scripted" ]]; then
  die "unknown mode: $MODE"
fi
