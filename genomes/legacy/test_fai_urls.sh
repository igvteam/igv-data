#!/usr/bin/env bash
#
# Test all ".fai" URLs referenced in genomes.json for existence.
# A URL is considered OK if a GET request returns HTTP 200.
# The User-Agent is set to "IGV" for every request.
#
# Usage: ./test_fai_urls.sh [path/to/genomes.json]

set -u

JSON_FILE="${1:-genomes.json}"

if [[ ! -f "$JSON_FILE" ]]; then
  echo "Error: file not found: $JSON_FILE" >&2
  exit 1
fi

# Extract unique .fai URLs from the JSON.
urls=$(grep -oE 'https?://[^"]*\.fai' "$JSON_FILE" | sort -u)

if [[ -z "$urls" ]]; then
  echo "No .fai URLs found in $JSON_FILE" >&2
  exit 0
fi

total=0
ok=0
fail=0

while IFS= read -r url; do
  [[ -z "$url" ]] && continue
  total=$((total + 1))

  # GET request; -s silent, -L follow redirects, -o discard body,
  # -w print final status code. Fail (000) on connection errors.
  status=$(curl -s -L -A "IGV" -o /dev/null -w '%{http_code}' \
                --max-time 60 "$url" 2>/dev/null)

  if [[ "$status" == "200" ]]; then
    ok=$((ok + 1))
    printf 'OK    %s  %s\n' "$status" "$url"
  else
    fail=$((fail + 1))
    printf 'FAIL  %s  %s\n' "$status" "$url"
  fi
done <<< "$urls"

echo "----------------------------------------"
printf 'Total: %d   OK: %d   Failed: %d\n' "$total" "$ok" "$fail"

# Non-zero exit if any URL failed.
[[ "$fail" -eq 0 ]]
