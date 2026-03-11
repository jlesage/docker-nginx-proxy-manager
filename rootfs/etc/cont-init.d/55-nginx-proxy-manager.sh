#!/bin/sh

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

log() {
    echo "$@"
}

# Make sure mandatory directories exist.
mkdir -p \
    /config/log \
    /config/letsencrypt/archive \
    /config/letsencrypt-acme-challenge \
    /config/custom_ssl \
    /config/access \
    /config/nginx/default_host \
    /config/nginx/default_www \
    /config/nginx/cache \
    /config/nginx/proxy_host \
    /config/nginx/redirection_host \
    /config/nginx/stream \
    /config/nginx/dead_host \
    /config/nginx/temp \
    /config/log/letsencrypt \
    /config/letsencrypt-workdir \

# Make sure directories required for nginx exist.
for DIR in /var/run/nginx /var/tmp/nginx
do
    mkdir -p "$DIR"
    chown app:app "$DIR"
done

# Create the Python cache directory.
mkdir -p $PYTHONPYCACHEPREFIX
chown app:app $PYTHONPYCACHEPREFIX

# Create symlinks for logs.
[ ! -L /config/log/log ] || rm /config/log/log
ln -snf log /config/logs

# Make sure to remove old letsencrypt config file.
[ ! -f $XDG_CONFIG_HOME/letsencrypt/cli.ini ] || mv $XDG_CONFIG_HOME/letsencrypt/cli.ini $XDG_CONFIG_HOME/letsencrypt/cli.ini.removed

# Fix any references to the old log path.
find /config/nginx -not \( -path /config/nginx/custom -prune \) -type f -name '*.conf' | while read file
do
    sed -i 's|/data/logs/|/config/log/|' "$file"
done

# Install default config files.
[ -f /config/nginx/ip_ranges.conf ] || cp /defaults/ip_ranges.conf /config/nginx/

# Make sure there is no migration lock held.
# See https://github.com/jlesage/docker-nginx-proxy-manager/issues/4
if [ -f /config/database.sqlite ]; then
    echo 'DELETE FROM migrations_lock WHERE is_locked = 1;' | sqlite3 /config/database.sqlite
fi

# Generate the resolvers configuration file.
if is-bool-val-false "${DISABLE_RESOLVER:-0}"; then
    if is-bool-val-true "${DISABLE_IPV6:-0}"; then
        echo resolver "$(awk 'BEGIN{ORS=" "} $1=="nameserver" { sub(/%.*$/,"",$2); print ($2 ~ ":")? "["$2"]": $2}' /etc/resolv.conf) ipv6=off valid=10s;" > /etc/nginx/conf.d/include/resolvers.conf
    else
        echo resolver "$(awk 'BEGIN{ORS=" "} $1=="nameserver" { sub(/%.*$/,"",$2); print ($2 ~ ":")? "["$2"]": $2}' /etc/resolv.conf) valid=10s;" > /etc/nginx/conf.d/include/resolvers.conf
    fi
fi

# Handle IPv6 settings.
/opt/nginx-proxy-manager/bin/handle-ipv6-setting /etc/nginx/conf.d
/opt/nginx-proxy-manager/bin/handle-ipv6-setting /config/nginx

# vim:ft=sh:ts=4:sw=4:et:sts=4
