#!/bin/sh

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

# Set same default compilation flags as abuild.
export CFLAGS="-Os -fomit-frame-pointer"
export CXXFLAGS="$CFLAGS"
export CPPFLAGS="$CFLAGS"
export LDFLAGS="-Wl,--strip-all -Wl,--as-needed"

export CC=xx-clang
export CXX=xx-clang++

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ROOTFS=/tmp/nginx-proxy-manager-install

function log {
    echo ">>> $*"
}

NGINX_PROXY_MANAGER_VERSION="$1"
NGINX_PROXY_MANAGER_URL="$2"

if [ -z "$NGINX_PROXY_MANAGER_VERSION" ]; then
    log "ERROR: Nginx Proxy Manager version missing."
    exit 1
fi

if [ -z "$NGINX_PROXY_MANAGER_URL" ]; then
    log "ERROR: Nginx Proxy Manager URL missing."
    exit 1
fi

#
# Install required packages.
#

apk --no-cache add \
    build-base \
    clang \
    curl \
    patch \
    yarn \
    git \
    pythonispython3 \
    npm \
    bash \

xx-apk --no-cache --no-scripts add \
    musl-dev \
    gcc \
    g++ \

# Install node-prune.
log "Installing node-prune..."
curl -sfL https://gobinaries.com/tj/node-prune | sh

#
# Download sources.
#

log "Downloading Nginx Proxy Manager..."
mkdir /tmp/nginx-proxy-manager
curl -# -L -f ${NGINX_PROXY_MANAGER_URL} | tar xz --strip 1 -C /tmp/nginx-proxy-manager

#
# Compile
#

# Set the NginxProxyManager version.
sed -i "s/\"version\": \"0.0.0\",/\"version\": \"${NGINX_PROXY_MANAGER_VERSION}\",/" /tmp/nginx-proxy-manager/frontend/package.json
sed -i "s/\"version\": \"0.0.0\",/\"version\": \"${NGINX_PROXY_MANAGER_VERSION}\",/" /tmp/nginx-proxy-manager/backend/package.json

log "Patching Nginx Proxy Manager backend..."
PATCHES="
    pip-install.patch
    remove-certbot-dns-oci.patch
"
for P in $PATCHES; do
    echo "Applying $P..."
    patch -p1 -d /tmp/nginx-proxy-manager < "$SCRIPT_DIR"/"$P"
done

cp -r /tmp/nginx-proxy-manager /app

log "Building Nginx Proxy Manager frontend..."
(
    cd /app/frontend
    yarn install --network-timeout 100000
    yarn build
    node-prune
)

log "Building Nginx Proxy Manager backend..."
(
    # Determine the NPM architecture.
    # See https://nodejs.org/api/os.html#osarch
    case $(xx-info arch) in
        amd64) ARCH=x64   ;;
        386)   ARCH=ia32  ;;
        arm)   ARCH=arm   ;;
        arm64) ARCH=arm64 ;;
        *) echo "ERROR: Unsupported arch: $(xx-info arch)."; exit 1 ;;
    esac
    cd /app/backend
    # Use NPM instead of yarn because yarn doesn't seem to be able to install
    # for another achitecture.  Note that NPM install should also use yarn.lock.
    npm install --legacy-peer-deps --omit=dev --omit=optional --target_platform=linux --target_arch=$ARCH
    node-prune
    rm -rf /app/backend/node_modules/sqlite3/build
)

log "Installing Nginx Proxy Manager..."

mkdir \
    $ROOTFS \
    $ROOTFS/opt \
    $ROOTFS/etc \
    $ROOTFS/var \
    $ROOTFS/var/lib \
    $ROOTFS/var/lib/nginx \
    $ROOTFS/var/log \
    $ROOTFS/defaults \

cp -rv /app/backend $ROOTFS/opt/nginx-proxy-manager
cp -rv /app/frontend/dist $ROOTFS/opt/nginx-proxy-manager/frontend
cp -rv /app/global $ROOTFS/opt/nginx-proxy-manager/global

mkdir $ROOTFS/opt/nginx-proxy-manager/bin
cp -rv /tmp/nginx-proxy-manager/docker/rootfs/etc/nginx $ROOTFS/etc/
cp -rv /tmp/nginx-proxy-manager/docker/rootfs/var/www $ROOTFS/var/
cp -rv /tmp/nginx-proxy-manager/docker/rootfs/etc/letsencrypt.ini $ROOTFS/etc/
cp -rv /tmp/nginx-proxy-manager/docker/rootfs/etc/logrotate.d $ROOTFS/etc/

# Remove the nginx development config.
rm $ROOTFS/etc/nginx/conf.d/dev.conf

# Change the management interface port to the unprivileged port 8181.
sed -i 's|81 default|8181 default|' $ROOTFS/etc/nginx/conf.d/production.conf

# Change the management interface root.
sed -i 's|/app/frontend;|/opt/nginx-proxy-manager/frontend;|' $ROOTFS/etc/nginx/conf.d/production.conf

# Change the HTTP port 80 to the unprivileged port 8080.
sed -i 's|80;|8080;|' $ROOTFS/etc/nginx/conf.d/default.conf
sed -i 's|"80";|"8080";|' $ROOTFS/etc/nginx/conf.d/default.conf
sed -i 's|listen 80;|listen 8080;|' $ROOTFS/opt/nginx-proxy-manager/templates/letsencrypt-request.conf
sed -i 's|:80;|:8080;|' $ROOTFS/opt/nginx-proxy-manager/templates/letsencrypt-request.conf
sed -i 's|listen 80;|listen 8080;|' $ROOTFS/opt/nginx-proxy-manager/templates/_listen.conf
sed -i 's|:80;|:8080;|' $ROOTFS/opt/nginx-proxy-manager/templates/_listen.conf
sed -i 's|80 default;|8080 default;|' $ROOTFS/opt/nginx-proxy-manager/templates/default.conf

# Change the HTTPs port 443 to the unprivileged port 4443.
sed -i 's|443 |4443 |' $ROOTFS/etc/nginx/conf.d/default.conf
sed -i 's|"443";|"4443";|' $ROOTFS/etc/nginx/conf.d/default.conf
sed -i 's|listen 443 |listen 4443 |' $ROOTFS/opt/nginx-proxy-manager/templates/_listen.conf
sed -i 's|:443 |:4443 |' $ROOTFS/opt/nginx-proxy-manager/templates/_listen.conf
sed -i 's|:443;|:4443;|' $ROOTFS/opt/nginx-proxy-manager/templates/_listen.conf

# Fix nginx test command line.
sed -i 's|-g "error_log off;"||' $ROOTFS/opt/nginx-proxy-manager/internal/nginx.js

# Remove the `user` directive, since we want nginx to run as non-root.
sed -i 's|user npm;|#user npm;|' $ROOTFS/etc/nginx/nginx.conf

# Change client_body_temp_path.
sed -i 's|/tmp/nginx/body|/var/tmp/nginx/body|' $ROOTFS/etc/nginx/nginx.conf

# Fix the logrotate config.
sed -i 's|npm npm|app app|' $ROOTFS/etc/logrotate.d/nginx-proxy-manager
sed -i 's|/run/nginx.pid|/run/nginx/nginx.pid|' $ROOTFS/etc/logrotate.d/nginx-proxy-manager
sed -i 's|logrotate /etc/logrotate.d/nginx-proxy-manager|logrotate -s /config/logrotate.status /etc/logrotate.d/nginx-proxy-manager|' $ROOTFS/opt/nginx-proxy-manager/setup.js
sed -i 's|/data/logs/\*/access.log|/data/logs/access.log|' $ROOTFS/etc/logrotate.d/nginx-proxy-manager
sed -i 's|/data/logs/\*/error.log|/data/logs/error.log|' $ROOTFS/etc/logrotate.d/nginx-proxy-manager

# Redirect `/data' to '/config'.
ln -s /config $ROOTFS/data

# Make sure the config file for IP ranges is stored in persistent volume.
mv $ROOTFS/etc/nginx/conf.d/include/ip_ranges.conf $ROOTFS/defaults/
ln -sf /config/nginx/ip_ranges.conf $ROOTFS/etc/nginx/conf.d/include/ip_ranges.conf

# Make sure the config file for resolvers is stored in persistent volume.
ln -sf /config/nginx/resolvers.conf $ROOTFS/etc/nginx/conf.d/include/resolvers.conf

# Make sure nginx cache is stored on the persistent volume.
ln -s /config/nginx/cache $ROOTFS/var/lib/nginx/cache

# Make sure the manager config file is stored in persistent volume.
rm -r $ROOTFS/opt/nginx-proxy-manager/config
mkdir $ROOTFS/opt/nginx-proxy-manager/config
ln -s /config/production.json $ROOTFS/opt/nginx-proxy-manager/config/production.json

# Make sure letsencrypt certificates are stored in persistent volume.
ln -s /config/letsencrypt $ROOTFS/etc/letsencrypt

# Cleanup.
find $ROOTFS/opt/nginx-proxy-manager -name "*.h" -delete
find $ROOTFS/opt/nginx-proxy-manager -name "*.cc" -delete
find $ROOTFS/opt/nginx-proxy-manager -name "*.c" -delete
find $ROOTFS/opt/nginx-proxy-manager -name "*.gyp" -delete
