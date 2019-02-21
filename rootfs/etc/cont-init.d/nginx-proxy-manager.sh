#!/usr/bin/with-contenv sh

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

log() {
    echo "[cont-init.d] $(basename $0): $*"
}

# Make sure mandatory directories exist.
mkdir -p \
    /config/log/nginx \
    /config/letsencrypt/archive \
    /config/letsencrypt-acme-challenge \
    /config/custom_ssl \
    /config/access \
    /config/nginx/cache \
    /config/nginx/proxy_host \
    /config/nginx/redirection_host \
    /config/nginx/stream \
    /config/nginx/dead_host \
    /config/nginx/temp \
    /config/log/letsencrypt \
    /config/letsencrypt-workdir \
    $XDG_CONFIG_HOME/letsencrypt

# Create nginx log files.
touch /config/log/nginx/error.log
touch /config/log/nginx/default.log
touch /config/log/nginx/manager.log

# Redirect the logs directory.
ln -sf log/nginx /config/logs

# Install default config.
[ -f /config/nginx/ip_ranges.conf ] || cp /defaults/ip_ranges.conf /config/nginx/
[ -f /config/production.json ] || cp /defaults/production.json /config/
[ -f $XDG_CONFIG_HOME/letsencrypt/cli.ini ] || cp /defaults/cli.ini $XDG_CONFIG_HOME/letsencrypt/

# Protect against database initialization failure: make sure to remove the
# database directory if it didn't initialized properly.
if [ -d /config/mysql ] && [ -f /config/db_init_in_progress ]; then
    rm -r /config/mysql
fi

# Initialize the database data directory.
if [ ! -d /config/mysql ]; then
    MYSQL_DATABASE=nginxproxymanager
    MYSQL_USER=nginxproxymanager
    MYSQL_PASSWORD=password123

    touch /config/db_init_in_progress

    log "Initializing database data directory..."
    mysql_install_db --datadir=/config/mysql >/config/log/init_db.log 2>&1
    log "Database data directory initialized."

    log "Starting database to perform its intialization..."

    # Start mysqld.
    chown -R "$USER_ID":"$GROUP_ID" /config/mysql
    /etc/services.d/mysqld/run >>/config/log/init_db.log 2>&1 &
    rc="$?"
    pid="$!"
    if [ "$rc" -ne 0 ]; then
        log "ERROR: Failed to start the database."
        exit 1
    fi

    # Wait until it is ready.
    for i in $(seq 1 30); do
        if /etc/services.d/mysqld/data/check; then
            break
        fi
        sleep 1
    done

    # Secure the installation.
    log "Securing database installation..."
    printf '\nn\n\n\n\n\n' | /usr/bin/mysql_secure_installation >>/config/log/init_db.log 2>&1

    log "Initializing database ..."
    # Create the database.
    echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;" | mysql >>/config/log/init_db.log 2>&1
    # Create the user.
    echo "CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' ;" | mysql >>/config/log/init_db.log 2>&1
    echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%' ;" | mysql >>/config/log/init_db.log 2>&1

    # Kill mysqld.
    log "Shutting down database..."
    if ! kill -s TERM "$pid" || ! wait "$pid"; then
        log "ERROR: initialization failed."
        exit 1
    fi
fi

# Database initialized properly.
rm -f /config/db_init_in_progress

# Generate dummy self-signed certificate.
if [ ! -f /config/nginx/dummycert.pem ] || [ ! -f /config/nginx/dummykey.pem ]
then
    env HOME=/tmp openssl req \
        -new \
        -newkey rsa:2048 \
        -days 3650 \
        -nodes \
        -x509 \
        -subj '/O=Nginx Proxy Manager/OU=Dummy Certificate/CN=localhost' \
        -keyout /config/nginx/dummykey.pem \
        -out /config/nginx/dummycert.pem \
        > /dev/null 2>&1
fi

# Take ownership of the config directory content.
find /config -mindepth 1 -exec chown $USER_ID:$GROUP_ID {} \;

# vim:ft=sh:ts=4:sw=4:et:sts=4
