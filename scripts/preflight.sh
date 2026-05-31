#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/demo-lib.sh
source "$SCRIPT_DIR/demo-lib.sh"

MODE="scripted"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/preflight.sh [--mode scripted|live]
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

pass() {
  printf 'PASS %s\n' "$1"
}

warn() {
  printf 'WARN %s\n' "$1"
}

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

ensure_runtime

[[ -f "$ROOT_DIR/policies/copilot-readonly.yaml" ]] || fail "missing read-only policy"
[[ -f "$ROOT_DIR/policies/copilot-writeable.yaml" ]] || fail "missing writeable policy"
[[ -f "$ROOT_DIR/seed/issues.json" ]] || fail "missing seed issues"
[[ -f "$ROOT_DIR/fallback/demo.cast" ]] || fail "missing fallback/demo.cast"

for script in "$ROOT_DIR"/scripts/*.sh; do
  bash -n "$script" || fail "bash syntax failed for ${script#$ROOT_DIR/}"
done
pass "shell scripts parse"

grep -q '^version: 1$' "$ROOT_DIR/policies/copilot-readonly.yaml" || fail "read-only policy missing version: 1"
grep -q '^network_policies:' "$ROOT_DIR/policies/copilot-readonly.yaml" || fail "read-only policy missing network_policies"
grep -q 'method: PATCH' "$ROOT_DIR/policies/copilot-writeable.yaml" || fail "writeable policy missing PATCH allow"
pass "policy files include expected OpenShell schema fields"

if command_exists tmux; then
  pass "tmux available"
else
  warn "tmux not found; stage.sh will print manual pane commands"
fi

case "$MODE" in
  scripted)
    pass "scripted demo assets are ready"
    ;;
  live)
    command_exists openshell || fail "openshell CLI not found"
    openshell --version || fail "openshell --version failed"
    command_exists gh || fail "gh CLI not found"
    gh auth status || fail "gh is not authenticated"
    [[ -n "${GITHUB_TOKEN:-}" ]] || warn "GITHUB_TOKEN is not set; provider creation may need an existing configured token"
    if command_exists copilot; then
      pass "copilot CLI available"
    elif gh copilot --help >/dev/null 2>&1; then
      pass "gh copilot available"
    elif command_exists codex; then
      pass "codex CLI available"
    else
      warn "no copilot/codex agent command found; live sandbox can still run another agent binary"
    fi
    pass "live prerequisites checked"
    ;;
  *)
    fail "unknown mode: $MODE"
    ;;
esac
