#!/usr/bin/env bash
set -euo pipefail

OLD='https://raw.githubusercontent.com/igvteam/igv-data/refs/heads/main'

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <replacement_string>" >&2
  exit 1
fi

NEW="$1"
REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

echo "Replacing:"
echo "  FROM: $OLD"
echo "  TO:   $NEW"
echo ""

matches=$(grep -rl --include='*' "$OLD" "$REPO_ROOT" 2>/dev/null || true)

if [[ -z "$matches" ]]; then
  echo "No matches found."
  exit 0
fi

echo "Files to update:"
echo "$matches"
echo ""

read -r -p "Proceed? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

while IFS= read -r file; do
  sed -i '' "s|${OLD}|${NEW}|g" "$file"
  echo "Updated: $file"
done <<< "$matches"

echo ""
echo "Done."
