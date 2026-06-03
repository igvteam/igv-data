#!/usr/bin/env bash
# Reads web_genomes.txt and assembles a genomes.json array from the json/ subfolder.
# Usage: buildGenomesJson.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INPUT="$DIR/web_genomes.txt"
JSON_DIR="$DIR/json"
OUTPUT="$DIR/web/genomes.json"

printf '[\n' > "$OUTPUT"
first=1

while IFS= read -r line || [ -n "$line" ]; do
    # skip blank lines and comments
    [[ -z "$line" || "$line" == \#* ]] && continue

    # ensure .json extension
    [[ "$line" != *.json ]] && line="${line}.json"

    file="$JSON_DIR/$line"
    if [ ! -f "$file" ]; then
        echo "WARNING: file not found, skipping: $file" >&2
        continue
    fi

    if [ $first -eq 0 ]; then
        printf ',\n' >> "$OUTPUT"
    fi
    cat "$file" >> "$OUTPUT"
    first=0

done < "$INPUT"

printf '\n]\n' >> "$OUTPUT"
echo "Written: $OUTPUT"

