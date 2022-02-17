#!/usr/bin/with-contenv sh

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

log() {
    echo "[cont-init.d] $(basename $0): $*"
}

if [ ${CROWDSEC_BOUNCER} == "1" ]; then
    #Install Crowdsec Bouncer Config.
    [ -f /config/crowdsec-openresty-bouncer.conf ] || cp /crowdsec/crowdsec-openresty-bouncer.conf /config/crowdsec-openresty-bouncer.conf
    mkdir -p /var/lib/nginx/lualib/plugins/crowdsec/
    cp /crowdsec/lua/* /var/lib/nginx/lualib/plugins/crowdsec/
    cp /crowdsec/crowdsec_openresty.conf /etc/nginx/conf.d/
fi

