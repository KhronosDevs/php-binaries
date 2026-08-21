#!/usr/bin/env bash

set -euo pipefail

DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
ROOT="$(dirname "$DIR")"

SOURCE="$DIR/php7"
OUTPUT="$DIR/bin.zip"

if [[ ! -d "$SOURCE" ]]; then
    echo "Error: $SOURCE does not exist."
    exit 1
fi

echo "========================================"
echo " PHP Runtime Packaging"
echo "========================================"
echo
echo "Source: $SOURCE"
echo "Output: $OUTPUT"
echo

rm -f "$OUTPUT"

cd "$ROOT"

echo "Creating archive..."

zip -r -q "$OUTPUT" "bin/php7"

echo
echo "Done!"
echo
echo "Archive: $OUTPUT"
echo "Size:    $(du -h "$OUTPUT" | cut -f1)"
echo
echo "Archive structure:"
unzip -l "$OUTPUT" | head -20
