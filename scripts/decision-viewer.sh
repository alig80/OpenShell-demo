#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/demo-lib.sh
source "$SCRIPT_DIR/demo-lib.sh"

ensure_runtime

clear 2>/dev/null || true
cat <<'HEADER'
[ OPENSHELL ]
Live policy decisions

HEADER

printf 'waiting for decisions in %s\n\n' "${AUDIT_LOG#$ROOT_DIR/}"

tail -n +1 -F "$AUDIT_LOG" 2>/dev/null | awk -F '\t' '
BEGIN {
  green = "\033[32m";
  red = "\033[31m";
  blue = "\033[34m";
  yellow = "\033[33m";
  bold = "\033[1m";
  reset = "\033[0m";
}
{
  time = $1;
  decision = $2;
  method = $3;
  host = $4;
  target = $5;
  rule = $6;
  reason = $7;

  color = reset;
  if (decision == "ALLOW") color = green;
  if (decision == "DENY") color = red bold;
  if (decision == "ROUTE") color = blue;
  if (decision == "RELOAD") color = yellow bold;

  if (decision == "RELOAD") {
    printf "%s  %s%-7s%s policy: %s  %s\n", time, color, decision, reset, target, reason;
    fflush();
    next;
  }

  label = decision;
  printf "%s  %s%-7s%s %-5s %-14s %-46s rule: %s", time, color, label, reset, method, host, target, rule;
  if (reason != "") {
    printf "  %s", reason;
  }
  printf "\n";
  fflush();
}
'
