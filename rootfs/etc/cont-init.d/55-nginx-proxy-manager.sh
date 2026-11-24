#!/bin/sh

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

log() {
    echo "$@"
}

resolve_port() {
    _name=$1
    _value=$2
    _default=$3

    if [ -z "$_value" ]; then
        _value=$_default
    fi
    case "$_value" in
        *[!0-9]*)
            log "ERROR: ${_name} must be a number between 1 and 65535." >&2
            exit 1
            ;;
    esac
    while [ "${_value#0}" != "$_value" ] && [ "$_value" != 0 ]
    do
        _value=${_value#0}
    done
    if [ "$_value" -lt 1 ] || [ "$_value" -gt 65535 ]; then
        log "ERROR: ${_name} must be a number between 1 and 65535." >&2
        exit 1
    fi
    echo "$_value"
}

render_listen_template() {
    _src=$1
    _dst=$2

    cp "$_src" "$_dst"
    sed -i \
        -e "s/__HTTP_PORT__/${http_port}/g" \
        -e "s/__HTTPS_PORT__/${https_port}/g" \
        "$_dst"
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

# Generate the administration interface server from the template.
admin_port=$(resolve_port NPM_ADMIN_PORT "${NPM_ADMIN_PORT:-}" 8181)
mkdir -p /tmp/nginx
cp /etc/nginx/conf.d/production.conf.template /tmp/nginx/production.conf
sed-patch "s/{{NPM_ADMIN_PORT}}/${admin_port}/g" /tmp/nginx/production.conf

# Handle HTTP and HTTPs listen ports.
http_port=$(resolve_port NPM_HTTP_PORT "${NPM_HTTP_PORT:-}" 8080)
https_port=$(resolve_port NPM_HTTPS_PORT "${NPM_HTTPS_PORT:-}" 4443)

if [ "$http_port" = "$https_port" ]; then
    log "ERROR: NPM_HTTP_PORT and NPM_HTTPS_PORT must be different ports."
    exit 1
fi
if [ "$http_port" = "$admin_port" ] || [ "$https_port" = "$admin_port" ]; then
    log "ERROR: NPM_HTTP_PORT and NPM_HTTPS_PORT must be different from NPM_ADMIN_PORT."
    exit 1
fi
if [ "$http_port" = 3000 ] || [ "$https_port" = 3000 ]; then
    log "ERROR: NPM_HTTP_PORT and NPM_HTTPS_PORT must not be 3000."
    exit 1
fi

log "HTTP listen port: ${http_port}, HTTPs listen port: ${https_port}."

# Render templates containing the HTTP/HTTPs port.
mkdir -p /tmp/nginx-proxy-manager/templates
render_listen_template \
    /etc/nginx/conf.d/default.conf.template \
    /tmp/nginx/default.conf
render_listen_template \
    /opt/nginx-proxy-manager/templates/_listen.conf.in \
    /tmp/nginx-proxy-manager/templates/_listen.conf
render_listen_template \
    /opt/nginx-proxy-manager/templates/default.conf.in \
    /tmp/nginx-proxy-manager/templates/default.conf
render_listen_template \
    /opt/nginx-proxy-manager/templates/letsencrypt-request.conf.in \
    /tmp/nginx-proxy-manager/templates/letsencrypt-request.conf

# Backup the database if needed.
if [ -f /config/database.sqlite ]; then
    cur_version="$(awk '/"version"/ { gsub(/[",]/, "", $2); print $2 }' /opt/nginx-proxy-manager/package.json)"
    prev_version="$(cat /config/.npm_version 2>/dev/null || true)"
    if [ "$prev_version" != "$cur_version" ]; then
        echo "creating database backup..."
        cp /config/database.sqlite /config/"database.sqlite.bk-${prev_version:-unknown}"
    fi
    echo "$cur_version" > /config/.npm_version
fi

# Regenerate nginx configs if listen ports changed.
old_http=8080
old_https=4443
if [ -f /config/.listen_ports ]; then
    http_line=$(sed -n '1p' /config/.listen_ports)
    https_line=$(sed -n '2p' /config/.listen_ports)
    old_http=${http_line#http=}
    old_https=${https_line#https=}
fi
if [ "$old_http" != "$http_port" ] || [ "$old_https" != "$https_port" ]; then
    if [ -f /config/database.sqlite ]; then
        log "Regenerating Nginx Proxy Manager configs for listen ports ${http_port}/${https_port}."
        (
            cd /opt/nginx-proxy-manager
            NODE_ENV=production SUPPRESS_NO_CONFIG_WARNING=1 \
                su-exec app \
                node --abort_on_uncaught_exception --max_old_space_size=250 \
                /opt/nginx-proxy-manager/bin/regenerate-listen-ports.js
        )
    fi
fi

printf 'http=%s\nhttps=%s\n' "$http_port" "$https_port" > /config/.listen_ports.tmp
mv /config/.listen_ports.tmp /config/.listen_ports

# Handle IPv6 settings.
/opt/nginx-proxy-manager/bin/handle-ipv6-setting /etc/nginx/conf.d
/opt/nginx-proxy-manager/bin/handle-ipv6-setting /config/nginx
/opt/nginx-proxy-manager/bin/handle-ipv6-setting /tmp/nginx

# vim:ft=sh:ts=4:sw=4:et:sts=4
