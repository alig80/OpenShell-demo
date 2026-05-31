#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/demo-lib.sh
source "$SCRIPT_DIR/demo-lib.sh"

REPO="$DEMO_REPO"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/seed-repo.sh [--repo owner/name]

Creates the three demo issues from seed/issues.json using gh.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
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

command_exists gh || die "gh CLI not found"
gh auth status >/dev/null || die "gh is not authenticated"

if command_exists jq; then
  while IFS=$'\t' read -r title body; do
    printf 'Creating issue: %s\n' "$title"
    gh issue create --repo "$REPO" --title "$title" --body "$body" >/dev/null
  done < <(jq -r '.issues[] | [.title, .body] | @tsv' "$ROOT_DIR/seed/issues.json")
elif command_exists node; then
  node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1], 'utf8')); for (const i of data.issues) console.log(JSON.stringify([i.title, i.body]));" "$ROOT_DIR/seed/issues.json" |
    while IFS= read -r row; do
      title="$(node -e "const row=JSON.parse(process.argv[1]); process.stdout.write(row[0]);" "$row")"
      body="$(node -e "const row=JSON.parse(process.argv[1]); process.stdout.write(row[1]);" "$row")"
      printf 'Creating issue: %s\n' "$title"
      gh issue create --repo "$REPO" --title "$title" --body "$body" >/dev/null
    done
else
  die "jq or node is required to read seed/issues.json"
fi

printf 'Seeded demo issues in %s\n' "$REPO"
