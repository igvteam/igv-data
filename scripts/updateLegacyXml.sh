#!/usr/bin/env bash
# Updates the legacy "Load from Server" XML tree of an existing mirror built by buildMirror.sh.
#
# Usage: updateLegacyXml.sh [options] <mirror directory> [<host>]
#
#   <mirror directory>  the output directory given to buildMirror.sh, the one containing
#                       "genomes"
#   <host>              base URL the mirror is served from, default https://igv.org
#
# Options:
#   --dry-run           report what would change and change nothing.
#   --local             build from this checkout with git, rather than downloading.
#   --ref <ref>         git ref to build from, implies --local.  Default "main".
#   --url <url>         download the genomes tarball from here instead of the release asset.
#
# Only genomes/legacy/xml is touched: the XML resource files and the <genome>_dataServerRegistry.txt
# files IGV 2.x reads from the root of that directory.  Nothing else in the mirror is read or
# written.  Unlike buildMirror.sh, files under genomes/legacy/xml that are no longer in the
# repository ARE deleted, so retired registries and resource files disappear from the mirror.
#
# URLs into the repository's genomes tree are repointed at <host>, as buildMirror.sh does, so
# the registries reference <host>/genomes/legacy/xml/...  Requires curl, tar and rsync.

set -euo pipefail

RAW_PREFIX="https://raw.githubusercontent.com/igvteam/igv-data/refs/heads/main/genomes"
DEFAULT_HOST="https://igv.org"
DEFAULT_URL="https://github.com/igvteam/igv-data/releases/download/genomes-latest/genomes.tar.gz"
SUBTREE="genomes/legacy/xml"

usage() {
    echo "Usage: $0 [--dry-run] [--local] [--ref <ref>] [--url <url>] <mirror directory> [<host>]" >&2
    exit 1
}

dry_run=0
local_build=0
REF="main"
URL="$DEFAULT_URL"

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) dry_run=1; shift ;;
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
case "$HOST" in
    http://* | https://*) ;;
    *) HOST="https://$HOST" ;;
esac
HOST="${HOST%/}"
HOST_PREFIX="$HOST/genomes"

TARGET="$OUT/$SUBTREE"
if [ ! -d "$TARGET" ]; then
    echo "ERROR: $TARGET does not exist.  This script updates an existing mirror; build one with buildMirror.sh first." >&2
    exit 1
fi

command -v rsync > /dev/null || { echo "ERROR: rsync is required" >&2; exit 1; }

# The staging directory is the one thing this script removes, and it made it.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

if [ $local_build -eq 1 ]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
    if ! git -C "$ROOT" rev-parse --verify --quiet "$REF^{commit}" > /dev/null; then
        echo "ERROR: no such ref: $REF" >&2
        exit 1
    fi
    echo "Building from $REF ($(git -C "$ROOT" rev-parse --short "$REF")) in $ROOT"
    git -C "$ROOT" archive "$REF" "$SUBTREE" | tar -x -C "$STAGE"
else
    echo "Downloading $URL"
    if ! curl -f -s -S -L "$URL" | tar -xz -C "$STAGE" "$SUBTREE"; then
        echo "ERROR: could not download and unpack the genomes tarball" >&2
        echo "       It is published by .github/workflows/genomes-tarball.yml; use --local to" >&2
        echo "       build from this checkout instead." >&2
        exit 1
    fi
fi

if [ ! -d "$STAGE/$SUBTREE" ]; then
    echo "ERROR: no $SUBTREE directory in the unpacked tree" >&2
    exit 1
fi

# Repoint the internal URLs while the tree is still staged.
edited=0
while IFS= read -r file; do
    sed "s|$RAW_PREFIX|$HOST_PREFIX|g" "$file" > "$file.new"
    mv "$file.new" "$file"
    edited=$((edited + 1))
done < <(grep -rIl "$RAW_PREFIX" "$STAGE/$SUBTREE")
echo "Repointed URLs in $edited file(s) to $HOST_PREFIX"

# Sync the staged subtree into the mirror.  --checksum so an unchanged file is not rewritten,
# --inplace so a changed file needs only write permission on the file itself, --delete so
# files gone from the repository are removed.  Only this subtree is ever touched.
RSYNC_OPTS=(-r --checksum --inplace --delete --itemize-changes --no-perms --no-owner --no-group --no-times)

# Keep only the itemized lines that matter: files written (">f"), directories created ("cd")
# and deletions.  Timestamps are not synced, so rsync also lists every unchanged file with a
# "T" flag; those are dropped.
report() {
    local n
    n=$({ grep -E '^(>f|cd|\*deleting)' || true; } | sed 's|^|    |' | tee /dev/stderr | wc -l)
    [ "$n" -gt 0 ] || echo "    (nothing to change)"
}
if [ $dry_run -eq 1 ]; then
    echo "Dry run; changes that would be made to $TARGET:"
    rsync "${RSYNC_OPTS[@]}" --dry-run "$STAGE/$SUBTREE/" "$TARGET/" | report
    exit 0
fi

echo "Changes made to $TARGET:"
rsync "${RSYNC_OPTS[@]}" "$STAGE/$SUBTREE/" "$TARGET/" | report

# As in buildMirror.sh: a new file should stay writable for the next person to update the mirror.
if ! chmod -R a+rwX "$TARGET" 2> /dev/null; then
    echo "WARNING: could not set permissions on every file, some are owned by another user" >&2
fi

echo "Updated $TARGET, served as $HOST_PREFIX/legacy/xml"
