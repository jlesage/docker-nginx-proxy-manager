#!/bin/sh

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

function log {
    echo ">>> $*"
}

BCRYPT_TOOL_VERSION="${1:-}"

if [ -z "$BCRYPT_TOOL_VERSION" ]; then
    log "ERROR: bcrypt tool version missing."
    exit 1
fi

#
# Install required packages.
#

apk --no-cache add \
    build-base \
    go \
    git \

#
# Compile.
#

log "Compiling bcrypt tool..."
mkdir /tmp/go && \
env GOPATH=/tmp/go xx-go install -ldflags="-s -w" github.com/shoenig/bcrypt-tool@v$BCRYPT_TOOL_VERSION
if [ ! -f /tmp/go/bin/bcrypt-tool ]; then
    cp -v /tmp/go/bin/*/bcrypt-tool /tmp/go/bin/bcrypt-tool
fi
