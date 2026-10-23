#!/bin/bash

# Build a self-contained copy of the legacy IGV 2.x "Load from Server" files for hosting at another location.
#
# Usage:  downloadFiles.sh <new_base_url> [output_dir]
#
# Every <genomeId>_dataServerRegistry.txt in this directory is read, each XML file it references is copied
# (or downloaded) into <output_dir>/<genomeId>/, and a registry is written to <output_dir> whose entries point
# at <new_base_url>/<genomeId>/<filename>.  Host <output_dir> at <new_base_url> and set the IGV 2.x data
# registry URL (View > Preferences > Advanced) to:
#
#     <new_base_url>/$$_dataServerRegistry.txt

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Base URL of this directory as hosted on GitHub; files under it are copied locally rather than downloaded
REPO_BASE_URL="https://raw.githubusercontent.com/igvteam/igv-data/refs/heads/main/genomes/legacy/xml"

NEW_BASE_URL="${1%/}"
OUTPUT_DIR="${2:-./legacy_xml_mirror}"

if [ -z "$NEW_BASE_URL" ]; then
  echo "Usage: $0 <new_base_url> [output_dir]"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

for registry_file in "$SCRIPT_DIR"/*_dataServerRegistry.txt; do
  registry_name=$(basename "$registry_file")
  genome_id="${registry_name%_dataServerRegistry.txt}"
  echo "Processing $genome_id"

  mkdir -p "$OUTPUT_DIR/$genome_id"
  new_registry_file="$OUTPUT_DIR/$registry_name"
  : > "$new_registry_file"

  while IFS= read -r url || [[ -n "$url" ]]; do
    trimmed_url=$(echo "$url" | xargs)
    if [ -z "$trimmed_url" ]; then
      continue
    fi
    filename=$(basename "$trimmed_url")

    local_file="$SCRIPT_DIR/${trimmed_url#$REPO_BASE_URL/}"
    if [ "$local_file" != "$SCRIPT_DIR/$trimmed_url" ] && [ -f "$local_file" ]; then
      cp "$local_file" "$OUTPUT_DIR/$genome_id/$filename"
    else
      echo "  Downloading $filename"
      curl -s -f -L -o "$OUTPUT_DIR/$genome_id/$filename" "$trimmed_url" || echo "  WARNING: failed to download $trimmed_url"
    fi

    echo "$NEW_BASE_URL/$genome_id/$filename" >> "$new_registry_file"
  done < "$registry_file"
done

echo "Done.  Host '$OUTPUT_DIR' at $NEW_BASE_URL and use the registry URL $NEW_BASE_URL/\$\$_dataServerRegistry.txt"
