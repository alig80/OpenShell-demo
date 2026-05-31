#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/demo-lib.sh
source "$SCRIPT_DIR/demo-lib.sh"

clear 2>/dev/null || true
cat <<'HEADER'
[ POLICY ]
Act 4 command:

  ./scripts/policy-apply.sh writeable

Current read-only policy excerpt:

HEADER

sed -n '/network_policies:/,$p' "$ROOT_DIR/policies/copilot-readonly.yaml" | sed -n '1,54p'

cat <<'FOOTER'

Press Enter to open a shell in this pane.
FOOTER

IFS= read -r _ || true
exec "${SHELL:-/bin/bash}"
