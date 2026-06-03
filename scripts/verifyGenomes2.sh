#!/usr/bin/env bash
# Verifies URLs in column 2 of genomes2.tsv using curl HEAD requests.

TSV="$(dirname "$0")/../genomes/genomes2.tsv"
failed=0

grep -v '^\s*#' "$TSV" | grep -v '^\s*$' | while IFS=$'\t' read -r name url _rest; do
    status=$(curl -s -o /dev/null -w "%{http_code}" --head "$url")
    if [ "$status" -ge 200 ] && [ "$status" -lt 400 ]; then
        echo "✅  [$status] $name"
    else
        echo "❌  [$status] $name"
        echo "       $url"
        failed=$((failed + 1))
    fi
done

exit $failed

