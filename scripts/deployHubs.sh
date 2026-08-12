#!/usr/bin/env bash
# Downloads the IGV track hub files into the directory this script is run from.
#
# Usage: deployHubs.sh
#
# Files are written preserving their path relative to genomes/hubs, e.g.
# hg18/gbm/hub.txt, so the relative references within the hub files resolve.
#
# The file list is explicit -- update FILES below when hubs are added or removed
# from genomes/hubs in the igv-data repository.

set -u

PREFIX="https://raw.githubusercontent.com/igvteam/igv-data/refs/heads/main/genomes/hubs"

FILES=(
    bosTau9/genomes.txt
    bosTau9/groups.txt
    bosTau9/hub.txt
    bosTau9/trackDb.txt
    canFam3/genomes.txt
    canFam3/groups.txt
    canFam3/hub.txt
    canFam3/trackDb.txt
    canFam4/genomes.txt
    canFam4/groups.txt
    canFam4/hub.txt
    canFam4/trackDb.txt
    canFam5/genomes.txt
    canFam5/groups.txt
    canFam5/hub.txt
    canFam5/trackDb.txt
    canFam6/genomes.txt
    canFam6/groups.txt
    canFam6/hub.txt
    canFam6/trackDb.txt
    ce11/genomes.txt
    ce11/groups.txt
    ce11/hub.txt
    ce11/trackDb.txt
    danRer10/genomes.txt
    danRer10/groups.txt
    danRer10/hub.txt
    danRer10/trackDb.txt
    danRer11/genomes.txt
    danRer11/groups.txt
    danRer11/hub.txt
    danRer11/trackDb.txt
    dm6/genomes.txt
    dm6/groups.txt
    dm6/hub.txt
    dm6/trackDb.txt
    galGal6/genomes.txt
    galGal6/groups.txt
    galGal6/hub.txt
    galGal6/trackDb.txt
    gorGor6/genomes.txt
    gorGor6/groups.txt
    gorGor6/hub.txt
    gorGor6/trackDb.txt
    hg18/gbm/Broad.080528.subtypes.seg.gz
    hg18/gbm/Broad_standard_080606.gistic.txt
    hg18/gbm/TCGA_GBM_Level3_Somatic_Mutations_08.28.2008.maf.gz
    hg18/gbm/hub.txt
    hg18/gbm/sampleTable.txt.gz
    hg18/genomes.txt
    hg18/groups.txt
    hg18/hub.txt
    hg18/trackDb.txt
    hg18/tumorscape/hub.txt
    hg18/tumorscape/tumorscape.html
    hg19/groups.txt
    hg19/hub.txt
    hg19/hub_1kg.txt
    hg19/hub_tutorials.txt
    hg38/genomes.txt
    hg38/groups.txt
    hg38/hub.txt
    hg38/trackDb.txt
    hs1/genomes.txt
    hs1/groups.txt
    hs1/hub.txt
    hs1/trackDb.txt
    macFas5/genomes.txt
    macFas5/groups.txt
    macFas5/hub.txt
    macFas5/trackDb.txt
    mm10/genomes.txt
    mm10/groups.txt
    mm10/hub.txt
    mm10/trackDb.txt
    mm39/genomes.txt
    mm39/groups.txt
    mm39/hub.txt
    mm39/trackDb.txt
    panTro6/genomes.txt
    panTro6/groups.txt
    panTro6/hub.txt
    panTro6/trackDb.txt
    rn7/genomes.txt
    rn7/groups.txt
    rn7/hub.txt
    rn7/trackDb.txt
    sacCer3/genomes.txt
    sacCer3/groups.txt
    sacCer3/hub.txt
    sacCer3/trackDb.txt
    susScr11/genomes.txt
    susScr11/groups.txt
    susScr11/hub.txt
    susScr11/trackDb.txt
    template/genomes.txt
    template/groups.txt
    template/hub.txt
    template/trackDb.txt
)

failed=0
count=0

for file in "${FILES[@]}"; do
    url="$PREFIX/$file"
    dir="$(dirname "$file")"
    echo "Downloading $file"
    mkdir -p "$dir"
    if curl -f -s -S -L -o "$file.tmp" "$url"; then
        mv "$file.tmp" "$file"
        count=$((count + 1))
    else
        rm -f "$file.tmp"
        echo "ERROR: failed to download $url" >&2
        failed=$((failed + 1))
    fi
done

echo "Downloaded $count file(s) to $(pwd)"
if [ $failed -ne 0 ]; then
    echo "$failed file(s) failed" >&2
    exit 1
fi
