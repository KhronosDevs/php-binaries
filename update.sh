#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SOURCE="$SCRIPT_DIR/dist/php7"
DEST="$SCRIPT_DIR/php7"

echo "========================================"
echo " PHP Runtime Update"
echo "========================================"
echo
echo "Source:      dist/php7"
echo "Destination: php7"
echo

updated=()
added=()

copy_file() {
    local src="$1"
    local dst="$2"

    mkdir -p "$(dirname "$dst")"

    if [[ ! -e "$dst" ]]; then
        cp -a "$src" "$dst"
        added+=("${dst#"$DEST"/}")
    elif ! cmp -s "$src" "$dst"; then
        cp -a "$src" "$dst"
        updated+=("${dst#"$DEST"/}")
    fi
}

# ============================================================
# PHP binary
#
# dist/php7/bin/php is the actual PHP binary.
# php7/bin/php is a wrapper, so install the binary as php-bin.
# ============================================================

if [[ -f "$SOURCE/bin/php" ]]; then
    copy_file "$SOURCE/bin/php" "$DEST/bin/php-bin"
fi

# ============================================================
# Other important binaries
# ============================================================

for file in \
    php-config \
    phpdbg \
    phpize \
    phar \
    phar.phar
do
    if [[ -f "$SOURCE/bin/$file" ]]; then
        copy_file "$SOURCE/bin/$file" "$DEST/bin/$file"
    fi
done

# ============================================================
# PHP modules
#
# Copy/update .so files from dist.
# Existing modules that aren't present in dist are untouched.
# ============================================================

if [[ -d "$SOURCE/lib/modules" ]]; then
    while IFS= read -r -d '' src; do
        relative="${src#"$SOURCE/lib/modules/"}"
        dst="$DEST/lib/modules/$relative"

        copy_file "$src" "$dst"
    done < <(find "$SOURCE/lib/modules" -type f -name '*.so' -print0)
fi

# ============================================================
# opcache
#
# Some PHP builds put opcache under:
#
# lib/extensions/no-debug-zts-20220829/opcache.so
#
# while the runtime expects it in lib/modules.
# ============================================================

if [[ -f "$SOURCE/lib/extensions/no-debug-zts-20220829/opcache.so" ]]; then
    copy_file \
        "$SOURCE/lib/extensions/no-debug-zts-20220829/opcache.so" \
        "$DEST/lib/modules/no-debug-zts-20220829/opcache.so"
fi

# ============================================================
# Summary
# ============================================================

echo
echo
echo "========================================"
echo " Update Summary"
echo "========================================"
echo

if (( ${#updated[@]} )); then
    echo "Updated:"
    for file in "${updated[@]}"; do
        echo "  ~ $file"
    done
    echo
fi

if (( ${#added[@]} )); then
    echo "Added:"
    for file in "${added[@]}"; do
        echo "  + $file"
    done
    echo
fi

if (( ! ${#updated[@]} && ! ${#added[@]} )); then
    echo "Nothing to update."
    echo
fi

echo "Done."
