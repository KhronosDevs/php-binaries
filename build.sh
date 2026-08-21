#!/usr/bin/env bash
#
# build.sh — Portable ZTS PHP build for Khronos
# =================================================
#
# Builds PHP 8.2 with:
#   - ZTS (Zend Thread Safety)
#   - FFI
#   - pmmpthread
#   - Only the extensions Khronos needs
#   - Third-party dependencies built under work/deps
#   - Static third-party libraries where possible
#   - Debian Bullseye baseline for glibc compatibility
#
# Usage:
#   ./build.sh
#   ./build.sh --no-docker
#
# Output:
#   dist/php7/bin/php
#   dist/php7/bin/php-production.ini
#   dist/php7/bin/php-development.ini
#

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

PHP_BRANCH="${PHP_BRANCH:-PHP-8.2}"
PMMPTHREAD_BRANCH="${PMMPTHREAD_BRANCH:-fork}"
BASE_IMAGE="${BASE_IMAGE:-debian:bullseye}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$ROOT_DIR/work"
DEPS_PREFIX="$WORK_DIR/deps"
DIST_DIR="$ROOT_DIR/dist"

# ---------------------------------------------------------------------------
# Library versions
# ---------------------------------------------------------------------------

ZLIB_VERSION="1.3.1"
OPENSSL_VERSION="3.0.15"
CURL_VERSION="8.10.1"
YAML_VERSION="0.2.5"
ONIGURUMA_VERSION="6.9.9"
GMP_VERSION="6.3.0"
SQLITE_YEAR="2024"
SQLITE_VERSION="3460100"
LIBZIP_VERSION="1.10.1"
LIBFFI_VERSION="3.4.6"

# ---------------------------------------------------------------------------
# Docker
# ---------------------------------------------------------------------------

if [[ "${1:-}" != "--in-container" ]]; then

    if [[ "${1:-}" == "--no-docker" ]]; then
        echo "[build.sh] Running directly on host (--no-docker given)."
    else
        if ! command -v docker >/dev/null 2>&1; then
            echo "[build.sh] Docker not found." >&2
            echo "[build.sh] Install Docker or use --no-docker." >&2
            exit 1
        fi

        echo "[build.sh] Building inside ${BASE_IMAGE}..."
        echo "[build.sh] This provides a forward-compatible glibc baseline."

        docker run --rm \
            -e PHP_BRANCH="$PHP_BRANCH" \
            -e PMMPTHREAD_BRANCH="$PMMPTHREAD_BRANCH" \
            -e JOBS="$JOBS" \
            -v "$ROOT_DIR":/build \
            -w /build \
            "$BASE_IMAGE" \
            bash build.sh --in-container

        echo
        echo "[build.sh] Build complete."
        echo "[build.sh] Output: $DIST_DIR/php7/"
        exit 0
    fi
fi

# ---------------------------------------------------------------------------
# Initial setup
# ---------------------------------------------------------------------------

mkdir -p "$WORK_DIR" "$DEPS_PREFIX" "$DIST_DIR"

cd "$WORK_DIR"

log() {
    echo
    echo "[build.sh] =================================================="
    echo "[build.sh] === $*"
    echo "[build.sh] =================================================="
    echo
}

# ---------------------------------------------------------------------------
# Environment
#
# Keep pkg-config completely inside our dependency prefix.
# This is important because mixing /usr/lib/pkgconfig with our own
# libraries can result in curl being compiled against one OpenSSL while
# PHP later links it against another.
# ---------------------------------------------------------------------------

export PKG_CONFIG_PATH="$DEPS_PREFIX/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$DEPS_PREFIX/lib/pkgconfig"

export CPPFLAGS="-I$DEPS_PREFIX/include"
export LDFLAGS="-L$DEPS_PREFIX/lib"

# Make our static libraries discoverable first.
export LIBRARY_PATH="$DEPS_PREFIX/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
export C_INCLUDE_PATH="$DEPS_PREFIX/include${C_INCLUDE_PATH:+:$C_INCLUDE_PATH}"

# ---------------------------------------------------------------------------
# System build dependencies
# ---------------------------------------------------------------------------

if [[ "${1:-}" == "--in-container" ]] && [[ -f /etc/debian_version ]]; then

    log "Installing build toolchain"

    export DEBIAN_FRONTEND=noninteractive

    apt-get update -qq

    apt-get install -y -qq \
        build-essential \
        git \
        curl \
        ca-certificates \
        pkg-config \
        autoconf \
        automake \
        libtool \
        bison \
        re2c \
        cmake \
        m4 \
        wget \
        perl \
        python3 \
        openssl \
        libssl-dev \
        > /dev/null
fi

# ---------------------------------------------------------------------------
# Download helper
# ---------------------------------------------------------------------------

download() {
    local url="$1"
    local output="$2"
    local tmp="${output}.tmp"

    echo "  downloading $(basename "$output")..."

    rm -f "$tmp"

    wget \
        --https-only \
        --tries=5 \
        --timeout=30 \
        --waitretry=3 \
        --retry-on-http-error=408,429,500,502,503,504 \
        -O "$tmp" \
        "$url"

    if [[ ! -s "$tmp" ]]; then
        echo "[ERROR] Download produced an empty file:"
        echo "        $url"
        rm -f "$tmp"
        return 1
    fi

    mv -f "$tmp" "$output"
}

# ---------------------------------------------------------------------------
# 1. zlib
# ---------------------------------------------------------------------------

build_zlib() {

    log "zlib $ZLIB_VERSION"

    download \
        "https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/zlib-${ZLIB_VERSION}.tar.gz" \
        "zlib.tar.gz"

    rm -rf "zlib-${ZLIB_VERSION}"

    tar xzf zlib.tar.gz

    cd "zlib-${ZLIB_VERSION}"

    ./configure \
        --prefix="$DEPS_PREFIX" \
        --static

    make -j"$JOBS"
    make install

    cd ..
}

# ---------------------------------------------------------------------------
# 2. OpenSSL
#
# IMPORTANT:
#   no-shared
#   => libssl.a + libcrypto.a
#
# curl and PHP will both use these exact libraries.
# ---------------------------------------------------------------------------

build_openssl() {
    log "OpenSSL $OPENSSL_VERSION"

    download \
        "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" \
        "openssl.tar.gz"

    rm -rf "openssl-${OPENSSL_VERSION}"

    tar xzf openssl.tar.gz

    cd "openssl-${OPENSSL_VERSION}"

    ./Configure \
        --prefix="$DEPS_PREFIX" \
        --libdir=lib \
        --openssldir="$DEPS_PREFIX/ssl" \
        no-shared \
        no-tests \
        linux-x86_64

    make -j"$JOBS"
    make install_sw

    cd ..

    echo "[build.sh] Verifying OpenSSL static libraries..."

    test -f "$DEPS_PREFIX/lib/libssl.a"
    test -f "$DEPS_PREFIX/lib/libcrypto.a"

    echo "[build.sh] OpenSSL libraries:"
    ls -lh \
        "$DEPS_PREFIX/lib/libssl.a" \
        "$DEPS_PREFIX/lib/libcrypto.a"
}

# ---------------------------------------------------------------------------
# 3. Oniguruma
# ---------------------------------------------------------------------------

build_oniguruma() {

    log "Oniguruma $ONIGURUMA_VERSION"

    download \
        "https://github.com/kkos/oniguruma/releases/download/v${ONIGURUMA_VERSION}/onig-${ONIGURUMA_VERSION}.tar.gz" \
        "onig.tar.gz"

    rm -rf "onig-${ONIGURUMA_VERSION}"

    tar xzf onig.tar.gz

    cd "onig-${ONIGURUMA_VERSION}"

    ./configure \
        --prefix="$DEPS_PREFIX" \
        --enable-shared=no \
        --enable-static=yes

    make -j"$JOBS"
    make install

    cd ..
}

# ---------------------------------------------------------------------------
# 4. libyaml
# ---------------------------------------------------------------------------

build_libyaml() {

    log "libyaml $YAML_VERSION"

    download \
        "https://github.com/yaml/libyaml/releases/download/${YAML_VERSION}/yaml-${YAML_VERSION}.tar.gz" \
        "yaml.tar.gz"

    rm -rf "yaml-${YAML_VERSION}"

    tar xzf yaml.tar.gz

    cd "yaml-${YAML_VERSION}"

    ./configure \
        --prefix="$DEPS_PREFIX" \
        --enable-shared=no \
        --enable-static=yes

    make -j"$JOBS"
    make install

    cd ..
}

# ---------------------------------------------------------------------------
# 5. curl
#
# IMPORTANT:
#   curl MUST be compiled against the SAME OpenSSL we just built.
#
#   The previous build allowed curl's configure test to discover a different
#   OpenSSL installation, resulting in:
#
#     libcurl.a -> OpenSSL A
#     PHP       -> OpenSSL B
#
#   which caused undefined references such as:
#
#     SSL_get1_peer_certificate
#     EVP_PKEY_get_bn_param
#
# ---------------------------------------------------------------------------

build_curl() {

    log "curl $CURL_VERSION (static + OpenSSL $OPENSSL_VERSION)"

    CURL_TAG="curl-${CURL_VERSION//./_}"

    download \
        "https://github.com/curl/curl/releases/download/${CURL_TAG}/curl-${CURL_VERSION}.tar.gz" \
        "curl.tar.gz"

    rm -rf "curl-${CURL_VERSION}"

    tar xzf curl.tar.gz

    cd "curl-${CURL_VERSION}"

    # Make absolutely sure curl sees our dependency tree.
    export PKG_CONFIG_PATH="$DEPS_PREFIX/lib/pkgconfig"
    export PKG_CONFIG_LIBDIR="$DEPS_PREFIX/lib/pkgconfig"

    export CPPFLAGS="-I$DEPS_PREFIX/include"
    export LDFLAGS="-L$DEPS_PREFIX/lib"

    # Static OpenSSL dependencies required by libcurl.
    export LIBS="-lssl -lcrypto -lz -ldl -lpthread"

    ./configure \
        --prefix="$DEPS_PREFIX" \
        --disable-shared \
        --enable-static \
        --with-openssl="$DEPS_PREFIX" \
        --without-libpsl \
        --without-brotli \
        --without-zstd

    make -j"$JOBS"
    make install

    # Verify that curl actually produced a static library.
    test -f "$DEPS_PREFIX/lib/libcurl.a"

    echo "[build.sh] curl library:"
    ls -lh "$DEPS_PREFIX/lib/libcurl.a"

    unset LIBS

    cd ..
}

# ---------------------------------------------------------------------------
# 6. GMP
# ---------------------------------------------------------------------------

build_gmp() {
    log "GMP $GMP_VERSION"

    download \
        "https://ftp.gnu.org/gnu/gmp/gmp-${GMP_VERSION}.tar.xz" \
        "gmp.tar.xz"

    rm -rf "gmp-${GMP_VERSION}"

    tar xJf gmp.tar.xz

    cd "gmp-${GMP_VERSION}"

    ./configure \
        --prefix="$DEPS_PREFIX" \
        --disable-shared \
        --enable-static

    make -j"$JOBS"
    make install

    cd ..
}

# ---------------------------------------------------------------------------
# 7. SQLite
# ---------------------------------------------------------------------------

build_sqlite3() {

    log "SQLite3 $SQLITE_VERSION"

    download \
        "https://www.sqlite.org/${SQLITE_YEAR}/sqlite-autoconf-${SQLITE_VERSION}.tar.gz" \
        "sqlite.tar.gz"

    rm -rf "sqlite-autoconf-${SQLITE_VERSION}"

    tar xzf sqlite.tar.gz

    cd "sqlite-autoconf-${SQLITE_VERSION}"

    ./configure \
        --prefix="$DEPS_PREFIX" \
        --disable-shared \
        --enable-static

    make -j"$JOBS"
    make install

    cd ..
}

# ---------------------------------------------------------------------------
# 8. libzip
# ---------------------------------------------------------------------------

build_libzip() {

    log "libzip $LIBZIP_VERSION"

    download \
        "https://libzip.org/download/libzip-${LIBZIP_VERSION}.tar.gz" \
        "libzip.tar.gz"

    rm -rf "libzip-${LIBZIP_VERSION}"

    tar xzf libzip.tar.gz

    cd "libzip-${LIBZIP_VERSION}"

    rm -rf build
    mkdir build
    cd build

    cmake .. \
        -DCMAKE_INSTALL_PREFIX="$DEPS_PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_PREFIX_PATH="$DEPS_PREFIX" \
        -DENABLE_BZIP2=OFF \
        -DENABLE_LZMA=OFF \
        -DENABLE_ZSTD=OFF

    make -j"$JOBS"
    make install

    cd ../..
}

build_libffi() {
    log "libffi $LIBFFI_VERSION"

    download \
        "https://github.com/libffi/libffi/releases/download/v${LIBFFI_VERSION}/libffi-${LIBFFI_VERSION}.tar.gz" \
        "libffi.tar.gz"

    rm -rf "libffi-${LIBFFI_VERSION}"
    tar xzf libffi.tar.gz

    cd "libffi-${LIBFFI_VERSION}"

    ./configure \
        --prefix="$DEPS_PREFIX" \
        --disable-shared \
        --enable-static

    make -j"$JOBS"
    make install

    cd ..

    echo "[build.sh] Verifying libffi static library..."
    ls -lh "$DEPS_PREFIX/lib/libffi.a"
}

# ---------------------------------------------------------------------------
# Build all third-party dependencies
# ---------------------------------------------------------------------------

build_zlib
build_openssl
build_oniguruma
build_libyaml
build_curl
build_gmp
build_sqlite3
build_libzip
build_libffi

# ---------------------------------------------------------------------------
# Dependency sanity check
# ---------------------------------------------------------------------------

log "Dependency sanity check"

echo "[build.sh] Static libraries installed under:"
echo "  $DEPS_PREFIX/lib"
echo

for lib in \
    libz.a \
    libssl.a \
    libcrypto.a \
    libcurl.a \
    libonig.a \
    libyaml.a \
    libgmp.a \
    libsqlite3.a
do
    if [[ -f "$DEPS_PREFIX/lib/$lib" ]]; then
        echo "  OK  $lib"
    else
        echo "  MISSING  $lib"
    fi
done

# ---------------------------------------------------------------------------
# 9. pmmpthread
# ---------------------------------------------------------------------------

log "Fetching ext-pmmpthread ($PMMPTHREAD_BRANCH)"

rm -rf ext-pmmpthread

git clone \
    --depth 1 \
    --branch "$PMMPTHREAD_BRANCH" \
    https://github.com/pmmp/ext-pmmpthread.git \
    ext-pmmpthread

# ---------------------------------------------------------------------------
# 10. PHP source
# ---------------------------------------------------------------------------

log "Fetching php-src ($PHP_BRANCH)"

rm -rf php-src

git clone \
    --depth 1 \
    --branch "$PHP_BRANCH" \
    https://github.com/php/php-src.git

cp -r ext-pmmpthread php-src/ext/pmmpthread

cd php-src

# ---------------------------------------------------------------------------
# buildconf
# ---------------------------------------------------------------------------

log "buildconf"

./buildconf --force

# ---------------------------------------------------------------------------
# PHP configure
#
# Again, PKG_CONFIG_LIBDIR prevents the system pkg-config database from
# leaking into this build.
# ---------------------------------------------------------------------------

log "configure (ZTS + FFI + pmmpthread)"

export PKG_CONFIG_PATH="$DEPS_PREFIX/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$DEPS_PREFIX/lib/pkgconfig"

export CPPFLAGS="-I$DEPS_PREFIX/include"
export LDFLAGS="-L$DEPS_PREFIX/lib"

./configure \
    --prefix="$DIST_DIR/php7" \
    --disable-all \
    \
    --enable-cli \
    --disable-cgi \
    \
    --enable-zts \
    --enable-ffi \
    --enable-sockets \
    --enable-pmmpthread \
    \
    --enable-yaml \
    --with-libyaml="$DEPS_PREFIX" \
    \
    --with-curl="$DEPS_PREFIX" \
    --with-openssl="$DEPS_PREFIX" \
    \
    --enable-mbstring \
    --with-onig="$DEPS_PREFIX" \
    \
    --with-gmp="$DEPS_PREFIX" \
    --with-zlib="$DEPS_PREFIX" \
    \
    --enable-phar \
    --with-zip="$DEPS_PREFIX" \
    --with-ffi="$DEPS_PREFIX" \
    \
    --enable-bcmath \
    --enable-ctype \
    \
    --with-sqlite3="$DEPS_PREFIX" \
    --enable-pdo \
    --with-pdo-sqlite="$DEPS_PREFIX" \
    \
    --enable-mysqlnd \
    --with-mysqli=mysqlnd \
    --with-pdo-mysql=mysqlnd \
    \
    --enable-opcache

# ---------------------------------------------------------------------------
# Build PHP
# ---------------------------------------------------------------------------

log "make"

make -j"$JOBS"

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

log "make install"

make install

cd "$WORK_DIR"

# ---------------------------------------------------------------------------
# 11. Verify binary
# ---------------------------------------------------------------------------

log "Verifying resulting PHP binary"

PHP_BIN="$DIST_DIR/php7/bin/php"

if [[ ! -x "$PHP_BIN" ]]; then
    echo "[ERROR] PHP binary was not produced:"
    echo "        $PHP_BIN"
    exit 1
fi

echo
echo "[build.sh] PHP version:"
"$PHP_BIN" -v

echo
echo "[build.sh] PHP modules:"
"$PHP_BIN" -m

echo
echo "[build.sh] ZTS:"
"$PHP_BIN" -i | grep -i "Thread Safety" || true

echo
echo "[build.sh] pmmpthread:"
"$PHP_BIN" -m | grep -i "pmmpthread" || true

# ---------------------------------------------------------------------------
# 12. Dynamic dependency verification
#
# Third-party libraries should NOT appear here.
# glibc/base system libraries are expected.
# ---------------------------------------------------------------------------

log "Verifying dynamic dependencies"

ldd "$PHP_BIN" || true

echo
echo "[build.sh] IMPORTANT:"
echo "  curl / ssl / crypto / yaml / sqlite / zip / gmp / oniguruma"
echo "  should not appear as external runtime dependencies."
echo
echo "  glibc and other basic system libraries are expected."

# ---------------------------------------------------------------------------
# 13. Copy php.ini files
# ---------------------------------------------------------------------------

mkdir -p "$DIST_DIR/php7/bin"

for ini in \
    php-production.ini \
    php-development.ini
do
    if [[ -f "$ROOT_DIR/$ini" ]]; then
        cp "$ROOT_DIR/$ini" "$DIST_DIR/php7/bin/$ini"
    fi
done

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

log "Build complete"

echo "PHP binary:"
echo "  $PHP_BIN"
echo

echo "Sanity checks:"
echo "  $PHP_BIN -v"
echo "  $PHP_BIN -m"
echo "  $PHP_BIN -i | grep 'Thread Safety'"
echo "  $PHP_BIN -m | grep -i pmmpthread"
echo

echo "Output:"
echo "  $DIST_DIR/php7/"
