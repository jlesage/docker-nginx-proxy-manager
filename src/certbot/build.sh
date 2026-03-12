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
    go \

# Needed to build cffi.
apk --no-cache add \
    libffi-dev \
    rust \
    cargo \

# Needed to build cryptography wheel (linux/386).
if [ "$TARGETPLATFORM" = "linux/386" ]; then
    apk --no-cache add \
        openssl-dev \

fi

# Needed to build lxml wheel (linux/386).
if [ "$TARGETPLATFORM" = "linux/386" ]; then
    apk --no-cache add \
        libxml2-dev \
        libxml2-static \
        libxslt-dev \
        libxslt-static \

fi

#
# Build certbot.
#

# Get the some ARM wheels to avoid their compilation on this architecture.
mkdir /packages
curl -# -L -o /packages/cffi-2.0.0-cp312-cp312-linux_armv7l.whl \
    https://wheels.eeems.codes/cffi/cffi-2.0.0-cp312-cp312-linux_armv7l.whl
curl -# -L -o /packages/cryptography-46.0.5-cp312-abi3-linux_armv7l.whl \
    https://wheels.eeems.codes/cryptography/cryptography-46.0.5-cp312-abi3-linux_armv7l.whl

export OSTYPE='linux-gnu'
export STATIC_DEPS=true # For lxml wheel
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
    uv pip install --find-links /packages/ $deps $pkg_name$pkg_ver
    uv pip uninstall setuptools
    deactivate
    ln -s /opt/certbot/$full_plugin_name/bin/certbot /tmp/certbot-symlinks/certbot-$full_plugin_name
done

log "Cleaning Python venv..."
rm -rf /opt/certbot/*/lib/python*/site-packages/__pycache__
rm -rf /opt/certbot/*/lib/python*/site-packages/*.dist-info/licenses
rm -rf /opt/certbot/*/lib/python*/site-packages/*.dist-info/sboms
rm -f /opt/certbot/*/bin/activate.*
find /opt/certbot/*/lib/python*/site-packages/*.dist-info -type f -not -name "*.txt" -delete
find /opt/certbot/*/lib/python*/site-packages -type d -name "tests" -exec rm -rf {} +
find /opt/certbot/*/lib/python*/site-packages -type d -name "test" -exec rm -rf {} +
find /opt/certbot/*/lib/python*/site-packages -type d -name "docs" -exec rm -rf {} +
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
    if [ "$TARGETPLATFORM" = "linux/386" ]; then
        case "$lib" in
            libgcc_s*)
                ;;
            libc.musl-*)
                ;;
            libffi.so.8)
                ;;
            libcrypto.so.3)
                ;;
            libssl.so.3)
                ;;
            *)
                echo "ERROR: New library dependency: $lib"
                exit 1
                ;;
        esac
    else
        case "$lib" in
            libgcc_s*)
                ;;
            libc.musl-*)
                ;;
            *)
                echo "ERROR: New library dependency: $lib"
                exit 1
                ;;
        esac
    fi
done
