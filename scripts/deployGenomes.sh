#!/usr/bin/env bash
# Downloads the IGV genome json files into the directory this script is run from.
#
# Usage: deployGenomes.sh
#
# The file list is explicit -- update FILES below when genomes are added or removed
# from genomes/json in the igv-data repository.

set -u

PREFIX="https://raw.githubusercontent.com/igvteam/igv-data/refs/heads/main/genomes"

FILES=(
    json/ASM294v2.json
    json/ASM985889v3.json
    json/GCA_000022165.1.json
    json/b37_1kg.json
    json/bosTau8.json
    json/bosTau9.json
    json/canFam3.json
    json/canFam4.json
    json/canFam5.json
    json/canFam6.json
    json/ce11.json
    json/danRer10.json
    json/danRer11.json
    json/dm3.json
    json/dm6.json
    json/galGal6.json
    json/gorGor4.json
    json/gorGor6.json
    json/hg18.json
    json/hg19.json
    json/hg38.json
    json/hg38_1kg.json
    json/hs1.json
    json/macFas5.json
    json/mm10.json
    json/mm39.json
    json/mm9.json
    json/panPan2.json
    json/panTro4.json
    json/panTro5.json
    json/panTro6.json
    json/rn6.json
    json/rn7.json
    json/sacCer3.json
    json/strPur2.json
    json/susScr11.json
    json/tair10.json
)

failed=0
count=0

for file in "${FILES[@]}"; do
    name="$(basename "$file")"
    url="$PREFIX/$file"
    echo "Downloading $name"
    if curl -f -s -S -L -o "$name.tmp" "$url"; then
        mv "$name.tmp" "$name"
        count=$((count + 1))
    else
        rm -f "$name.tmp"
        echo "ERROR: failed to download $url" >&2
        failed=$((failed + 1))
    fi
done

echo "Downloaded $count file(s) to $(pwd)"
if [ $failed -ne 0 ]; then
    echo "$failed file(s) failed" >&2
    exit 1
fi
