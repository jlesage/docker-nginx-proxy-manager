#!/bin/sh

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

log() {
    echo ">>> $*"
}

CROWDSEC_OPENRESTY_BOUNCER_URL="${1:-}"

ROOTFS=/tmp/crowdsec-openresty-bouncer-install

if [ -z "$CROWDSEC_OPENRESTY_BOUNCER_URL" ]; then
    log "ERROR: bcrypt tool version missing."
    exit 1
fi

#
# Install required packages.
#

apk --no-cache add \
    build-base \
    gettext \
    curl \
    bash \

#
# Build.
#

log "Downloading Crowdsec Openresty Bouncer package..."
mkdir /tmp/crowdsec-openresty-bouncer
curl -# -L "${CROWDSEC_OPENRESTY_BOUNCER_URL}" | tar xz --strip 1 -C /tmp/crowdsec-openresty-bouncer
log "Deploy Crowdsec Openresty Bouncer..."
cd /tmp/crowdsec-openresty-bouncer
bash ./install.sh --NGINX_CONF_DIR=${ROOTFS}/etc/nginx/conf.d --LIB_PATH=${ROOTFS}/var/lib/nginx/lualib --CONFIG_PATH=${ROOTFS}/defaults/crowdsec/ --DATA_PATH=${ROOTFS}/defaults/crowdsec/ --SSL_CERTS_PATH=/etc/ssl/certs/ca-cert-GTS_Root_R1.pem --docker
sed -i 's|/tmp/crowdsec-openresty-bouncer-install||g' ${ROOTFS}/etc/nginx/conf.d/crowdsec_openresty.conf
sed -i 's|ENABLED=.*|ENABLED=false|' ${ROOTFS}/defaults/crowdsec/crowdsec-openresty-bouncer.conf 
