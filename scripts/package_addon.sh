#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MANIFEST="$ROOT_DIR/package/addon_manifest.txt"
DIST_DIR=${1:-"$ROOT_DIR/dist"}
ARCHIVE="$DIST_DIR/@aviorstudio_gd-env.zip"
STAGE=$(mktemp -d)
actual=$(mktemp)
expected=$(mktemp)
trap 'rm -rf "$STAGE" "$actual" "$expected"' EXIT

test -s "$MANIFEST"
mkdir -p "$DIST_DIR"
rm -f "$ARCHIVE" "$ARCHIVE.sha256"

while IFS= read -r relative || [ -n "$relative" ]; do
    [ -n "$relative" ] || continue
    source_file="$ROOT_DIR/addon/$relative"
    if [ -L "$source_file" ]; then
        echo "Package manifest rejects symlink: addon/$relative" >&2
        exit 1
    fi
    if [ ! -f "$source_file" ]; then
        echo "Package manifest entry is missing: addon/$relative" >&2
        exit 1
    fi
    mkdir -p "$STAGE/$(dirname "$relative")"
    cp "$source_file" "$STAGE/$relative"
    touch -t 198001010000 "$STAGE/$relative"
done <"$MANIFEST"

(cd "$ROOT_DIR/addon" && find . -type l -print -quit) | grep -q . && {
    echo "Addon tree contains a symlink" >&2
    exit 1
}
(cd "$ROOT_DIR/addon" && find . -type f -printf '%P\n' | LC_ALL=C sort) >"$actual"
LC_ALL=C sort "$MANIFEST" >"$expected"
if ! diff -u "$expected" "$actual"; then
    echo "Addon tree and closed package manifest differ" >&2
    exit 1
fi

(cd "$STAGE" && zip -X -q "$ARCHIVE" -@ <"$MANIFEST")
sha256sum "$ARCHIVE" | tee "$ARCHIVE.sha256"
