#!/bin/sh
#
# Script to build certbot.
#
# NOTE: This script is called natively on the target architecture (no
#       cross-compilation).
#
# NOTE: certbot's acme dependency pulls the latest cffi version which is not
#       available yet on Alpine stable repos. There is no wheel for the 386
#       platform, so it has to be compiled.

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

log() {
    echo ">>> $*"
}

CERTBOT_VERSION="$1"
CERTBOT_PLUGINS="$2"

if [ -z "$CERTBOT_VERSION" ]; then
    log "ERROR: certbot version missing."
    exit 1
fi

#
# Install required packages.
#

apk --no-cache add \
    coreutils \
    patchelf \
    xxhash \
    curl \
    jq \
    python3 \
    py3-uv \
    py3-cryptography \

# Build tools.
apk --no-cache add \
    build-base \
    python3-dev \

# certbot-dns-multi 5.6.0 compiles a Go extension. Its go.mod requires
# Go >= 1.26.0. Alpine 3.23 ships Go 1.25 and sets GOTOOLCHAIN=local, so
# that toolchain refuses to download a newer one.
GO_VERSION=1.27.4
case "$TARGETPLATFORM" in
    linux/amd64)
        GO_ARCH=amd64
        GO_SHA256=7226736c2339719cda28fbf3a54d71aa63bcefe376e98cef00034268dab24840
        ;;
    linux/386)
        GO_ARCH=386
        GO_SHA256=6ecb45737d2315acb0dbbc97ea8e13e7c19d4c796abe8d68907c40bce6f50bf7
        ;;
    linux/arm64)
        GO_ARCH=arm64
        GO_SHA256=3392582988a273a87ab5043ee1b2c9c17a2c3c00580bf9326c47a2e0aaaeac92
        ;;
    linux/arm/v6|linux/arm/v7)
        GO_ARCH=armv6l
        GO_SHA256=e50964c41c6e187375387939e2f380de7250eba44e2259dfeb75c540d9d585c3
        ;;
    *)
        log "ERROR: Unsupported platform for Go: $TARGETPLATFORM"
        exit 1
        ;;
esac
log "Installing Go ${GO_VERSION} (${GO_ARCH})..."
curl -# -L -f "https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" -o /tmp/go.tgz
echo "${GO_SHA256}  /tmp/go.tgz" | sha256sum -c -
tar -C /usr/local -xzf /tmp/go.tgz
rm -f /tmp/go.tgz
export PATH="/usr/local/go/bin:${PATH}"
export GOTOOLCHAIN=local

# Needed to build cffi.
apk --no-cache add \
    libffi-dev \
    rust \
    cargo \

# Needed to build cryptography wheel.
case "$TARGETPLATFORM" in
    linux/386|linux/arm/v6|linux/arm/v7)
        apk --no-cache add \
            openssl-dev \
        ;;
esac

# Needed to build lxml wheel.
case "$TARGETPLATFORM" in
    linux/386)
        apk --no-cache add \
            libxml2-dev \
            libxml2-static \
            libxslt-dev \
            libxslt-static \
        ;;
esac

#
# Build certbot.
#

# Get the some ARM wheels to avoid their compilation on this architecture.
mkdir /packages
# TODO: None so far.

export OSTYPE='linux-gnu'
export STATIC_DEPS=true # For lxml wheel

# On linux/386 under QEMU/buildx, uname -m reports x86_64 (64-bit kernel) while
# userspace is 32-bit. Python/maturin then tag built wheels as linux_x86_64, and
# uv rejects them for musllinux i686 (e.g. pydantic-core for certbot-dns-hostinger).
# Force the correct platform tag for native extension builds.
case "$TARGETPLATFORM" in
    linux/386)
        export _PYTHON_HOST_PLATFORM=linux-i686
        ;;
esac

# lxml publishes no musllinux i686 wheel, so linux/386 builds it from source.
# STATIC_DEPS makes that build download zlib from https://zlib.net/. The
# tarball lxml checksums, zlib 1.3.2, is no longer there. Fetch it from
# /fossils/ and give the build that directory.
lxml_config=""
case "$TARGETPLATFORM" in
    linux/386)
        log "Downloading zlib 1.3.2 for the lxml build..."
        mkdir -p /tmp/lxml-deps
        curl -# -L -f "https://zlib.net/fossils/zlib-1.3.2.tar.gz" \
            -o /tmp/lxml-deps/zlib-1.3.2.tar.gz
        # lxml reads --download-dir when setup.py starts. setuptools applies
        # --build-option only to bdist_wheel, which is too late, so this has
        # to be a --global-option.
        lxml_config="--config-settings-package lxml:--global-option=--download-dir=/tmp/lxml-deps"
        ;;
esac

mkdir /tmp/certbot-symlinks

log "Installing certbot..."
uv venv /opt/certbot/certbot
. /opt/certbot/certbot/bin/activate
uv pip install --find-links /packages/ "certbot==$CERTBOT_VERSION"
uv pip uninstall setuptools
deactivate
ln -s /opt/certbot/certbot/bin/certbot /tmp/certbot-symlinks/certbot

log "Installing certbot plugins..."
total_plugins="$(jq -r 'keys[]' "$CERTBOT_PLUGINS" | wc -l)"
installed_plugins="0"
for plugin in $(jq -r 'keys[]' "$CERTBOT_PLUGINS"); do
    name="$(jq -r .\"${plugin}\".name $CERTBOT_PLUGINS)"
    full_plugin_name="$(jq -r .\"${plugin}\".full_plugin_name $CERTBOT_PLUGINS)"
    pkg_name="$(jq -r .\"${plugin}\".package_name $CERTBOT_PLUGINS)"
    pkg_ver="$(jq -r .\"${plugin}\".version $CERTBOT_PLUGINS | sed "s/{{certbot-version}}/$CERTBOT_VERSION/")"
    deps="$(jq -r .\"${plugin}\".dependencies $CERTBOT_PLUGINS | sed "s/{{certbot-version}}/$CERTBOT_VERSION/")"
    installed_plugins="$(($installed_plugins + 1))"

    log "Installing certbot plugin $name [$pkg_ver] ($installed_plugins/$total_plugins)..."
    case "$pkg_name:$pkg_ver" in
        certbot-dns-mijn-host:~=0.0.4)
            echo "Skipping installation of incompatible certbot plugin '$name'."
            continue
            ;;
    esac
    uv venv /opt/certbot/$full_plugin_name
    . /opt/certbot/$full_plugin_name/bin/activate
    uv pip install --find-links /packages/ $lxml_config $deps $pkg_name$pkg_ver
    uv pip uninstall setuptools
    deactivate
    ln -s /opt/certbot/$full_plugin_name/bin/certbot /tmp/certbot-symlinks/certbot-$full_plugin_name
done

log "Cleaning Python venv..."
rm -rf /opt/certbot/*/lib/python*/site-packages/__pycache__
rm -rf /opt/certbot/*/lib/python*/site-packages/*.dist-info/licenses
rm -rf /opt/certbot/*/lib/python*/site-packages/*.dist-info/sboms
rm -f /opt/certbot/*/bin/activate.*
find /opt/certbot/*/lib/python*/site-packages -type d -name "tests" -exec rm -rf {} +
find /opt/certbot/*/lib/python*/site-packages -type d -name "test" -exec rm -rf {} +
# Remove documentation trees only. Keep directories that are real Python packages
# (have __init__.py): botocore/docs and boto3/docs are imported at runtime by
# certbot-dns-route53 (via boto3), and deleting them causes:
#   No module named 'botocore.docs'
find /opt/certbot/*/lib/python*/site-packages -type d -name "docs" | while IFS= read -r dir; do
    if [ -f "$dir/__init__.py" ]; then
        continue
    fi
    rm -rf "$dir"
done
find /opt/certbot/*/lib/python*/site-packages -type f -name "CACHEDIR.TAG" -delete

log "Stripping libraries..."
find /opt/certbot -type f -name "*.so" -exec strip {} +

log "Deduplicating libraries (1/2)..."
TMP_FILE="$(mktemp)"
# Step 1: compute hash for all .so files
find /opt/certbot -type f -name "*.so" | while IFS= read -r sofile; do
    sofile=$(echo "$sofile")
    hash=$(xxh3sum "$sofile" | cut -d' ' -f1)
    echo "$hash $sofile" >> "$TMP_FILE"
done
log "Deduplicating libraries (2/2)..."
# Step 2: deduplicate
while IFS= read -r line; do
    hash=$(echo "$line" | cut -d' ' -f1)
    file=$(echo "$line" | cut -d' ' -f2-)

    # check if we have already seen this hash
    if [ -f "/tmp/.seen_$hash" ]; then
        orig=$(cat "/tmp/.seen_$hash")

        # compute relative path from duplicate to original
        dir_dup=$(dirname "$file")
        rel_path=$(realpath --relative-to="$dir_dup" "$orig")

        log "  -> Duplicate found: $file -> $orig"
        rm -f "$file"
        ln -s "$rel_path" "$file"
    else
        # first time seeing this hash
        echo "$file" > "/tmp/.seen_$hash"
    fi
done < "$TMP_FILE"
rm -f "$TMP_FILE" /tmp/.seen*

log "Checking libraries dependencies..."
for lib in $(find /opt/certbot/ -type f -name "*.so" -exec patchelf --print-needed {} ';' | sort -u)
do
    case "$TARGETPLATFORM" in
        linux/386|linux/arm/v6|linux/arm/v7)
            case "$lib" in
                libgcc_s*)
                    ;;
                libc.musl-*|libc.so)
                    ;;
                libffi.so.8)
                    ;;
                libcrypto.so.3)
                    ;;
                libssl.so.3)
                    ;;
                *)
                    echo "ERROR: New library dependency for $TARGETPLATFORM: $lib"
                    find /opt/certbot/ -type f -name "*.so" -exec echo {} ":" ';' -exec patchelf --print-needed {} ';'
                    exit 1
                    ;;
            esac
            ;;
        *)
            case "$lib" in
                libgcc_s*)
                    ;;
                libc.musl-*|libc.so)
                    ;;
                *)
                    echo "ERROR: New library dependency for $TARGETPLATFORM: $lib"
                    find /opt/certbot/ -type f -name "*.so" -exec echo {} ":" ';' -exec patchelf --print-needed {} ';'
                    exit 1
                    ;;
            esac
            ;;
    esac
done
