#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/demo-lib.sh
source "$SCRIPT_DIR/demo-lib.sh"

MODE="scripted"
SESSION="${OPENSHELL_DEMO_SESSION:-openshell-demo}"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/stage.sh [--mode scripted|live]

Starts a three-pane tmux layout:
  left/top     agent
  right        decisions
  left/bottom  policy commands
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

if ! command_exists tmux; then
  cat <<TEXT
tmux is not installed. Run the panes manually:

  ./scripts/agent-run.sh --mode $MODE --interactive
  ./scripts/decision-viewer.sh
  ./scripts/policy-pane.sh
TEXT
  exit 0
fi

tmux has-session -t "$SESSION" 2>/dev/null && tmux kill-session -t "$SESSION"

tmux new-session -d -s "$SESSION" -c "$ROOT_DIR" "./scripts/agent-run.sh --mode $MODE --interactive"
tmux split-window -h -p 38 -t "$SESSION:0" -c "$ROOT_DIR" "./scripts/decision-viewer.sh"
tmux select-pane -t "$SESSION:0.0"
tmux split-window -v -p 34 -t "$SESSION:0.0" -c "$ROOT_DIR" "./scripts/policy-pane.sh"
tmux select-pane -t "$SESSION:0.0"
tmux set-option -t "$SESSION" status on >/dev/null
tmux rename-window -t "$SESSION:0" "OpenShell Build Demo"
tmux attach-session -t "$SESSION"
