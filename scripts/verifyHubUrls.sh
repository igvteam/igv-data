#!/usr/bin/env bash
# Verifies that every URL in the "hubs" array of the json files in genomes/json
# exists.  Exits non-zero if any URL does not resolve.
#
# Usage: verifyHubUrls.sh [directory]
#
# Defaults to genomes/json relative to the repository root.  Each URL is checked
# with a HEAD request, falling back to a one-byte ranged GET for servers that
# reject HEAD.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIR="${1:-$ROOT/genomes/json}"

if [ ! -d "$DIR" ]; then
    echo "ERROR: no such directory: $DIR" >&2
    exit 1
fi

urls="$(mktemp)"
trap 'rm -f "$urls"' EXIT

# Emit "<file><tab><url>" for every entry of every "hubs" array.
python3 - "$DIR" > "$urls" <<'PY'
import glob, json, os, sys

for path in sorted(glob.glob(os.path.join(sys.argv[1], "*.json"))):
    name = os.path.basename(path)
    try:
        with open(path) as fp:
            doc = json.load(fp)
    except (OSError, ValueError) as e:
        print("%s\tINVALID_JSON: %s" % (name, e), file=sys.stderr)
        continue
    for entry in (doc if isinstance(doc, list) else [doc]):
        if not isinstance(entry, dict):
            continue
        for url in entry.get("hubs") or []:
            print("%s\t%s" % (name, url))
PY

total=0
failed=0

while IFS=$'\t' read -r file url; do
    total=$((total + 1))
    code="$(curl -s -o /dev/null -L --max-time 30 -w '%{http_code}' -I "$url")"
    if [ "$code" != "200" ]; then
        # Retry with a ranged GET -- some servers do not answer HEAD.
        code="$(curl -s -o /dev/null -L --max-time 30 -r 0-0 -w '%{http_code}' "$url")"
    fi
    case "$code" in
        200|206)
            ;;
        *)
            echo "FAIL $code  $file  $url"
            failed=$((failed + 1))
            ;;
    esac
done < "$urls"

echo "Checked $total url(s), $failed failure(s)"
[ "$failed" -eq 0 ]
