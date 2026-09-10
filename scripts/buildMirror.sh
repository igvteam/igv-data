#!/usr/bin/env bash
# Builds a mirror of the "genomes" tree from this repository.
#
# Usage: buildMirror.sh [options] <output directory> [<host>]
#
#   <output directory>  becomes the document root: <output>/genomes/... is served
#                       as <host>/genomes/...
#   <host>              base URL the mirror will be served from, default
#                       https://igv.org.  A bare host name is assumed to be https.
#                       A path is allowed, e.g. https://myserver/igv-data.
#
# Options:
#   --no-lists          leave the genome list files (see LISTS below) out of the
#                       mirror: they are not unpacked.  They rarely change, so with
#                       --update this leaves the deployed copies as they are.  A new
#                       mirror needs them.
#   --local             build from this checkout with git, rather than downloading.
#                       Use it to mirror work that is not pushed yet.
#   --ref <ref>         git ref to build from, implies --local.  Default "main".
#   --url <url>         download the genomes tarball from here instead of the
#                       release asset.
#   --update            write into an existing mirror, overwriting the files that
#                       are in the new tree and leaving the rest in place.  Without
#                       it an existing mirror is left alone, so a mistyped output
#                       directory cannot damage one.
#
# The genomes tree is downloaded as a tarball built by .github/workflows/genomes-tarball.yml
# and attached to the "genomes-latest" release, so curl and tar are the only requirements.
#
# Nothing is ever deleted: files in the new tree replace their counterparts, and anything
# else already in the output directory is left as it is.
#
# The repository is the source of truth and every internal URL in it points at
# raw.githubusercontent.com.  The same tree is also served from https://igv.org/genomes.
# This script produces that copy, and can produce the equivalent for any other host:
# URLs into the repository's own genomes tree are repointed at <host>.  References
# outside that tree -- the genome data files under igv.org/genomes/data, and
# raw.githubusercontent URLs into the repository's top level data/ directory -- are
# left alone, as neither is mirrored here.

set -euo pipefail

RAW_PREFIX="https://raw.githubusercontent.com/igvteam/igv-data/refs/heads/main/genomes"
DEFAULT_HOST="https://igv.org"
DEFAULT_URL="https://github.com/igvteam/igv-data/releases/download/genomes-latest/genomes.tar.gz"

# The genome lists for various versions of igv.js and IGV desktop, relative to the exported genomes/ directory.
# Note the genomes.txt files under hubs/ are UCSC hub genomesFile declarations, named by the hub.txt that references them,
# they are unrelated to the genome lists used by igv.js and IGV desktop, and are not included here.
LISTS=(
    genomes2.tsv
    genomes3.tsv
    legacy/genomes.json
    legacy/genomes.tab
    legacy/genomes.tsv
    legacy/genomes.txt
    web/genomes.json
)

usage() {
    echo "Usage: $0 [--no-lists] [--update] [--local] [--ref <ref>] [--url <url>] <output directory> [<host>]" >&2
    exit 1
}

lists=1
update=0
local_build=0
REF="main"
URL="$DEFAULT_URL"

while [ $# -gt 0 ]; do
    case "$1" in
        --no-lists) lists=0; shift ;;
        --update) update=1; shift ;;
        --local) local_build=1; shift ;;
        --ref) [ $# -ge 2 ] || usage; REF="$2"; local_build=1; shift 2 ;;
        --url) [ $# -ge 2 ] || usage; URL="$2"; shift 2 ;;
        -h | --help) usage ;;
        -*) echo "ERROR: unknown option: $1" >&2; usage ;;
        *) break ;;
    esac
done

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    usage
fi

OUT="$1"
HOST="${2:-$DEFAULT_HOST}"

# Accept a bare host name, and ignore a trailing slash.
case "$HOST" in
    http://* | https://*) ;;
    *) HOST="https://$HOST" ;;
esac
HOST="${HOST%/}"

HOST_PREFIX="$HOST/genomes"

if [ -e "$OUT/genomes" ] && [ $update -eq 0 ]; then
    echo "ERROR: $OUT/genomes already exists.  Pass --update to write into it." >&2
    exit 1
fi

mkdir -p "$OUT"

# --no-lists is done by not unpacking the lists, rather than by removing them after the
# fact, so a deployed copy is never touched.
EXCLUDES=()
if [ $lists -eq 0 ]; then
    for list in "${LISTS[@]}"; do
        # bash 3.2 treats an empty array as unset under "set -u", hence the guard.
        EXCLUDES=(${EXCLUDES[@]+"${EXCLUDES[@]}"} --exclude "genomes/$list")
    done
fi

if [ $local_build -eq 1 ]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

    if ! git -C "$ROOT" rev-parse --verify --quiet "$REF^{commit}" > /dev/null; then
        echo "ERROR: no such ref: $REF" >&2
        exit 1
    fi

    echo "Building from $REF ($(git -C "$ROOT" rev-parse --short "$REF")) in $ROOT"
    git -C "$ROOT" archive "$REF" genomes | tar -x ${EXCLUDES[@]+"${EXCLUDES[@]}"} -C "$OUT"
else
    echo "Downloading $URL"
    if ! curl -f -s -S -L "$URL" | tar -xz ${EXCLUDES[@]+"${EXCLUDES[@]}"} -C "$OUT"; then
        echo "ERROR: could not download the genomes tarball" >&2
        echo "       It is published by .github/workflows/genomes-tarball.yml; use --local to" >&2
        echo "       build from this checkout instead." >&2
        exit 1
    fi
fi

if [ ! -d "$OUT/genomes" ]; then
    echo "ERROR: no genomes directory in the extracted tree" >&2
    exit 1
fi

echo "Mirror of $OUT/genomes will be served as $HOST_PREFIX"

if [ $lists -eq 0 ]; then
    kept=0
    for list in "${LISTS[@]}"; do
        [ -f "$OUT/genomes/$list" ] && kept=$((kept + 1))
    done
    if [ $kept -eq 0 ]; then
        echo "Left out ${#LISTS[@]} genome list file(s)"
    else
        echo "Left out ${#LISTS[@]} genome list file(s), $kept already in the mirror and untouched"
    fi
fi

# Repoint the internal URLs.  Binary files (the hg18 track data) are skipped by
# grep -I, and files without a match are left untouched.  Each file is rewritten to
# its side and moved into place, so a file is only ever replaced.
edited=0
while IFS= read -r file; do
    sed "s|$RAW_PREFIX|$HOST_PREFIX|g" "$file" > "$file.new"
    mv "$file.new" "$file"
    edited=$((edited + 1))
done < <(grep -rIl "$RAW_PREFIX" "$OUT/genomes")

echo "Repointed URLs in $edited file(s)"

# Anything still pointing at raw.githubusercontent should be a reference outside the
# mirrored tree.  Report the rest, which would be a URL this script does not know how
# to map.
if remaining="$(grep -rIoh "https://raw.githubusercontent.com/igvteam/igv-data/[^\"' ,)]*" "$OUT/genomes" | grep -v "/refs/heads/main/data/" | sort -u)" \
   && [ -n "$remaining" ]; then
    echo "WARNING: unmapped raw.githubusercontent URLs remain:" >&2
    echo "$remaining" | sed 's|^|    |' >&2
fi

echo "Mirror written to $OUT"
