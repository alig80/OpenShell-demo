#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/demo-lib.sh
source "$SCRIPT_DIR/demo-lib.sh"

MODE="scripted"
ACT=""
INTERACTIVE="false"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/agent-run.sh --interactive [--mode scripted]
  ./scripts/agent-run.sh --act list|push [--mode scripted]
  ./scripts/agent-run.sh --mode live

Scripted commands inside --interactive:
  list      List and summarize the open issues.
  push      Try to close issue #3 and push the fix.
  state     Show the active policy state.
  help      Show this help.
  quit      Exit.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --act)
      ACT="${2:-}"
      shift 2
      ;;
    --interactive)
      INTERACTIVE="true"
      shift
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

print_agent_header() {
  clear 2>/dev/null || true
  cat <<'HEADER'
[ AGENT ]
Copilot-style agent actor

Commands:
  list  - list and summarize open issues
  push  - close issue #3 and push the fix
  state - show active policy
  quit

HEADER
}

act_list() {
  printf 'User: List and summarize the open issues.\n\n'
  sleep 0.2
  printf 'Agent: Calling GitHub issues API...\n'
  log_decision "ALLOW" "GET" "api.github.com" "/repos/$DEMO_REPO/issues" "github-api-readonly" "read-only GitHub issue listing"
  sleep 0.4
  log_decision "ALLOW" "GET" "api.github.com" "/repos/$DEMO_REPO/issues/3/comments" "github-api-readonly" "read-only GitHub issue comments"
  sleep 0.2
  cat <<'TEXT'

Agent: I found 3 open issues.

  #1 Cache warmup script should handle empty repositories
     Small reliability fix for first-run repositories.

  #2 Document sandbox policy reload command
     The runbook needs the exact hot-reload command.

  #3 Fix README typo in agent setup section
     Tiny doc change, safe to fix once write policy is approved.

TEXT
}

act_push_readonly() {
  printf 'User: Close issue #3 and push a fix to main.\n\n'
  sleep 0.2
  printf 'Agent: I can draft the change. I am attempting the GitHub update now...\n'
  sleep 0.4
  log_decision "DENY" "PATCH" "api.github.com" "/repos/$DEMO_REPO/issues/3" "github-api-readonly" "PATCH is not permitted by the current read-only policy"
  sleep 0.2
  cat <<'TEXT'

Agent: I can't close issue #3 or push to main.

OpenShell denied the outbound PATCH before it reached GitHub:
  PATCH /repos/alig80/OpenShell-demo/issues/3

This is a policy decision, not an agent-code change or token failure.

TEXT
}

act_push_writeable() {
  printf 'User: Close issue #3 and push a fix to main.\n\n'
  sleep 0.2
  printf 'Agent: Retrying the same workflow under the updated policy...\n'
  sleep 0.4
  log_decision "ALLOW" "PATCH" "api.github.com" "/repos/$DEMO_REPO/issues/3" "github-api-demo-write" "narrow issue update allowed"
  sleep 0.4
  log_decision "ALLOW" "POST" "api.github.com" "/repos/$DEMO_REPO/git/refs" "github-api-demo-write" "demo ref creation allowed"
  sleep 0.3
  log_decision "ALLOW" "POST" "github.com" "/alig80/OpenShell-demo.git/git-receive-pack" "github-git-demo-write" "git push allowed for demo repository"
  sleep 0.2
  cat <<'TEXT'

Agent: Done.

  - Fixed the README typo.
  - Closed issue #3.
  - Pushed the fix branch.

Same agent. Same prompt. The policy changed, not the code.

TEXT
}

run_scripted_act() {
  local act="$1"
  local state
  state="$(current_policy_state)"
  case "$act" in
    list)
      act_list
      ;;
    push)
      if [[ "$state" == "writeable" ]]; then
        act_push_writeable
      else
        act_push_readonly
      fi
      ;;
    *)
      die "unknown act: $act"
      ;;
  esac
}

run_interactive() {
  print_agent_header
  while true; do
    printf 'agent[%s]> ' "$(policy_name_for_state)"
    IFS= read -r command || break
    case "$command" in
      list|push)
        printf '\n'
        run_scripted_act "$command"
        ;;
      state)
        printf 'active policy: %s\n' "$(policy_name_for_state)"
        ;;
      help)
        usage
        ;;
      quit|exit)
        break
        ;;
      '')
        ;;
      *)
        printf 'unknown command: %s\n' "$command"
        ;;
    esac
    printf '\n'
  done
}

run_live() {
  cat <<'TEXT'
Live mode is intentionally a thin handoff.

Use the current OpenShell workflow from the runbook:

  openshell provider create --name build-demo-github --type github --from-existing
  openshell sandbox create --name copilot-demo --keep --provider build-demo-github -- codex
  openshell policy set copilot-demo --policy policies/copilot-readonly.yaml --wait

Then drive the real agent in that sandbox and watch `openshell term` or
`openshell logs copilot-demo --tail --source sandbox` in the decisions pane.

For the Build stage slot, prefer scripted mode unless live mode has passed
dress rehearsal twice on the exact machine and network.
TEXT
}

ensure_runtime

case "$MODE" in
  scripted)
    if [[ "$INTERACTIVE" == "true" ]]; then
      run_interactive
    elif [[ -n "$ACT" ]]; then
      run_scripted_act "$ACT"
    else
      usage
      exit 2
    fi
    ;;
  live)
    run_live
    ;;
  *)
    die "unknown mode: $MODE"
    ;;
esac
