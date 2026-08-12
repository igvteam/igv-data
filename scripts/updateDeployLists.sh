#!/usr/bin/env bash
# Regenerates the FILES=( ... ) list in deployGenomes.sh and deployHubs.sh from
# the current contents of genomes/json and genomes/hubs.
#
# Usage: updateDeployLists.sh
#
# The deploy scripts fetch from the "main" branch on raw.githubusercontent.com, so
# the lists are built from the git index (tracked files) rather than a raw directory
# listing -- an untracked file would only produce a 404 at deploy time.  Untracked
# files found in those directories are reported as warnings so nothing is dropped
# silently; commit them and re-run to include them.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# update_list <script> <directory relative to root> <path prefix for entries>
update_list() {
    local script="$SCRIPT_DIR/$1"
    local dir="$2"
    local prefix="$3"

    if [ ! -f "$script" ]; then
        echo "ERROR: no such script: $script" >&2
        return 1
    fi

    local listfile
    listfile="$(mktemp)"
    git -C "$ROOT" ls-files "$dir" |
        sed "s|^$dir/|$prefix|" |
        sed 's|^|    |' > "$listfile"

    local n
    n="$(wc -l < "$listfile" | tr -d ' ')"
    if [ "$n" -eq 0 ]; then
        echo "ERROR: no tracked files found under $dir, leaving $1 alone" >&2
        rm -f "$listfile"
        return 1
    fi

    # Warn about local files that are not tracked, and so will not be on GitHub.
    local untracked
    untracked="$(git -C "$ROOT" ls-files --others --exclude-standard "$dir")"
    if [ -n "$untracked" ]; then
        echo "WARNING: untracked, omitted from $1:" >&2
        echo "$untracked" | sed 's|^|    |' >&2
    fi

    local out
    out="$(mktemp)"
    awk -v listfile="$listfile" '
        /^FILES=\(/ {
            print
            while ((getline line < listfile) > 0) print line
            close(listfile)
            infiles = 1
            next
        }
        infiles && /^\)/ { infiles = 0; print; next }
        infiles { next }
        { print }
    ' "$script" > "$out"

    if ! grep -q '^FILES=(' "$out"; then
        echo "ERROR: no FILES=( ... ) block found in $1" >&2
        rm -f "$listfile" "$out"
        return 1
    fi

    cat "$out" > "$script"      # preserves the script's mode
    rm -f "$listfile" "$out"
    echo "Updated $1: $n file(s)"
}

update_list deployGenomes.sh genomes/json json/
update_list deployHubs.sh genomes/hubs ""
