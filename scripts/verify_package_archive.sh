#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "usage: $0 ARCHIVE EXPECTED_MANIFEST" >&2
    exit 2
fi

archive=$1
manifest=$2
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

test -f "$archive"
test -s "$manifest"
unzip -Z1 "$archive" | LC_ALL=C sort >"$work/actual"
LC_ALL=C sort "$manifest" >"$work/expected"
diff -u "$work/expected" "$work/actual"
if zipinfo -l "$archive" | grep -Eq '^l'; then
    echo "release ZIP contains a symlink" >&2
    exit 1
fi
echo "REACHED gd-env package_archive assertions=3"
