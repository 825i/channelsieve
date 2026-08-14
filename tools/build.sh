#!/usr/bin/env bash
#
# SECURITY NOTE
# -------------
# Earlier versions of this script were destructive. Two unquoted expansions,
#
#     BASEDIR=$(dirname $(dirname $SCRIPT))     # $SCRIPT unquoted
#     clean() { rm -rf $DEST; }                 # $DEST unquoted
#
# meant that if the repository path contained a space, $SCRIPT word-split into two
# arguments, `dirname` received two operands and printed two lines, and $DEST became
# two separate paths. `rm -rf $DEST` then split again and deleted an unintended
# directory -- for a checkout under "C:\Users\<you>\Documents\Claude Desktop\blocktube"
# that resolved to `rm -rf /c/Users/<you> Desktop/...`, destroying the home directory.
# Running the script with no arguments also reached clean() with $DEST unset.
#
# This version quotes every expansion, fails fast, sets DEST before any clean, and
# refuses to delete anything that is not a build directory under $BASEDIR/dist.

set -euo pipefail

SCRIPT="$(realpath "$0")"
BASEDIR="$(dirname "$(dirname "$SCRIPT")")"
VERSION="${2:-$(cat "$BASEDIR/VERSION")}"

usage() {
    echo "Usage: ${0##*/} {firefox|firefox_selfhosted|chrome|clean} [version]" >&2
    exit 1
}

# Refuse to touch anything that is not a build output directory under $BASEDIR/dist.
assert_safe_dest() {
    local dest="${1-}"

    if [ -z "$dest" ]; then
        echo "FATAL: DEST is empty -- refusing to touch the filesystem" >&2
        exit 1
    fi

    case "$dest" in
        "$BASEDIR"/dist/?*) : ;;
        *)
            echo "FATAL: DEST '$dest' is outside '$BASEDIR/dist' -- refusing" >&2
            exit 1
            ;;
    esac

    if [ "${#dest}" -lt 12 ]; then
        echo "FATAL: DEST '$dest' is suspiciously short -- refusing" >&2
        exit 1
    fi
}

copy_files() {
    assert_safe_dest "$DEST"
    mkdir -p "$DEST"
    cp -R "$BASEDIR/src"     "$DEST"
    cp -R "$BASEDIR/assets"  "$DEST"
    cp -R "$BASEDIR/LICENSE" "$DEST"
    cp -R "$BASEDIR/VERSION" "$DEST"
    cp "$BASEDIR/platform/$BROWSER/manifest.json" "$DEST"
}

set_version() {
    sed -i -e "s/{EXT_VERSION}/${VERSION}/" "$DEST/manifest.json"
    sed -i -e "s/{EXT_VERSION}/${VERSION}/" "$DEST/src/ui/options.html"
}

zipfile() {
    ( cd "$DEST" && zip "$DEST/blocktube_${BROWSER}_v${VERSION}.zip" -qr ./* )
}

clean() {
    assert_safe_dest "${DEST-}"
    rm -rf -- "$DEST"
}

BROWSER="${1-}"

case "$BROWSER" in
    firefox|firefox_selfhosted|chrome)
        ;;
    clean)
        for b in firefox firefox_selfhosted chrome; do
            DEST="$BASEDIR/dist/$b"
            if [ -d "$DEST" ]; then
                echo "Cleaning $DEST"
                clean
            fi
        done
        exit 0
        ;;
    *)
        usage
        ;;
esac

DEST="$BASEDIR/dist/$BROWSER"
echo "Building $BROWSER to $DEST"
clean
copy_files
set_version
zipfile
echo "Built $DEST/blocktube_${BROWSER}_v${VERSION}.zip"
