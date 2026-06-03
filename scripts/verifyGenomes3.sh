#!/usr/bin/env bash
# Verifies URLs in column 1 of genomes3.tsv using curl HEAD requests.

TSV="$(dirname "$0")/../genomes/genomes3.tsv"
failed=0

grep -v '^\s*#' "$TSV" | grep -v '^\s*$' | while IFS=$'\t' read -r url	accession	assembly	scientific name	common name	taxonId; do
    status=$(curl -s -o /dev/null -w "%{http_code}" --head "$url")
    if [ "$status" -ge 200 ] && [ "$status" -lt 400 ]; then
        echo "✅  [$status] $url"
    else
        echo "❌  [$status] $name"
        echo "       $url"
        failed=$((failed + 1))
    fi
done

exit $failed

