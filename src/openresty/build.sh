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

function log {
    echo ">>> $*"
}

OPENRESTY_URL="${1:-}"
NGINX_HTTP_GEOIP2_MODULE_URL="${2:-}"
LIBMAXMINDDB_URL="${3:-}"

if [ -z "$OPENRESTY_URL" ]; then
    log "ERROR: OpenResty URL missing."
    exit 1
fi

if [ -z "$NGINX_HTTP_GEOIP2_MODULE_URL" ]; then
    log "ERROR: Nginx HTTP GeoIP2 module URL missing."
    exit 1
fi

if [ -z "$LIBMAXMINDDB_URL" ]; then
    log "ERROR: libmaxminddb URL missing."
    exit 1
fi

#
# Install required packages.
#

apk --no-cache add \
    curl \
    build-base \
    clang \
    perl \
    file \

xx-apk --no-cache --no-scripts add \
    musl-dev \
    gcc \
    g++ \
    linux-headers \
    pcre-dev \
    openssl-dev \
    zlib-dev \
    luajit-dev \

#
# Download sources.
#

log "Downloading OpenResty..."
mkdir /tmp/openresty
curl -# -L -f ${OPENRESTY_URL} | tar xz --strip 1 -C /tmp/openresty

log "Downloading GeoIP2 module..."
mkdir /tmp/ngx_http_geoip2_module
curl -# -L -f ${NGINX_HTTP_GEOIP2_MODULE_URL} | tar xz --strip 1 -C /tmp/ngx_http_geoip2_module

log "Downloading libmaxminddb..."
mkdir /tmp/libmaxminddb
curl -# -L -f ${LIBMAXMINDDB_URL} | tar xz --strip 1 -C /tmp/libmaxminddb

#
# Compile.
#

log "Configuring libmaxminddb..."
(
    cd /tmp/libmaxminddb && ./configure  \
        --build=$(TARGETPLATFORM= xx-clang --print-target-triple) \
        --host=$(xx-clang --print-target-triple) \
        --prefix=/usr \
        --with-pic \
        --enable-shared=no \
        --enable-static=yes \
)

log "Compiling libmaxminddb..."
make -C /tmp/libmaxminddb -j$(nproc)

log "Installing libmaxminddb..."
make DESTDIR=$(xx-info sysroot) -C /tmp/libmaxminddb install

log "Patching OpenResty..."
# Patch Nginx for cross-compile support.  See the Yocto Nginx recipe: https://github.com/openembedded/meta-openembedded/tree/master/meta-webserver/recipes-httpd/nginx
NGINX_SRC_DIR="$(find /tmp/openresty/bundle -mindepth 1 -maxdepth 1 -type d -name 'nginx-*')"
curl -# -L -f https://github.com/openembedded/meta-openembedded/raw/master/meta-webserver/recipes-httpd/nginx/files/nginx-cross.patch | patch -p1 -d "$NGINX_SRC_DIR"
curl -# -L -f https://github.com/openembedded/meta-openembedded/raw/master/meta-webserver/recipes-httpd/nginx/files/0001-Allow-the-overriding-of-the-endianness-via-the-confi.patch | patch -p1 -d "$NGINX_SRC_DIR"

case "$(xx-info arch)" in
    amd64) PTRSIZE=8; ENDIANNESS=little ;;
    arm64) PTRSIZE=8; ENDIANNESS=little ;;
    386)   PTRSIZE=4; ENDIANNESS=little ;;
    arm)   PTRSIZE=4; ENDIANNESS=little ;;
    *) echo "Unknown ARCH: $(xx-info arch)" ; exit 1 ;;
esac

log "Configuring OpenResty..."
(
    cd /tmp/openresty && ./configure -j$(nproc) \
        --crossbuild=Linux:$(xx-info arch) \
        --with-cc="xx-clang" \
        --with-cc-opt="-Os -fomit-frame-pointer -Wno-sign-compare" \
        --with-ld-opt="-Wl,--strip-all -Wl,--as-needed" \
        --with-luajit=$(xx-info sysroot)usr \
        --prefix=/var/lib/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --pid-path=/var/run/nginx/nginx.pid \
        --lock-path=/var/run/nginx/nginx.lock \
        --error-log-path=/config/log/error.log \
        --http-log-path=/config/log/access.log \
        \
        --http-client-body-temp-path=/var/tmp/nginx/client_body \
        --http-proxy-temp-path=/var/tmp/nginx/proxy \
        --http-fastcgi-temp-path=/var/tmp/nginx/fastcgi \
        --http-uwsgi-temp-path=/var/tmp/nginx/uwsgi \
        --http-scgi-temp-path=/var/tmp/nginx/scgi \
        --with-perl_modules_path=/usr/lib/perl5/vendor_perl \
        \
        --user=app \
        --group=app \
        --with-threads \
        --with-file-aio \
        \
        --with-endian=$ENDIANNESS \
        --with-int=4 \
        --with-long=${PTRSIZE} \
        --with-long-long=8 \
        --with-ptr-size=${PTRSIZE} \
        --with-sig-atomic-t=4 \
        --with-size-t=${PTRSIZE} \
        --with-off-t=8 \
        --with-time-t=${PTRSIZE} \
        --with-sys-nerr=132 \
        \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-http_realip_module \
        --with-http_addition_module \
        --with-http_sub_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_mp4_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_auth_request_module \
        --with-http_random_index_module \
        --with-http_secure_link_module \
        --with-http_degradation_module \
        --with-http_slice_module \
        --with-http_stub_status_module \
        --with-mail \
        --with-mail_ssl_module \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_realip_module \
        --with-stream_ssl_preread_module \
        --with-pcre-jit \
        \
        --add-module=/tmp/ngx_http_geoip2_module \
)

log "Compiling OpenResty..."
make -C /tmp/openresty -j$(nproc)

log "Installing OpenResty..."
make DESTDIR=/tmp/openresty-install -C /tmp/openresty install

#Install lua-resty-http required for Crowdsec OpenResty Bouncer 
/tmp/openresty-install/var/lib/nginx/bin/opm --install-dir="/tmp/openresty-install/var/lib/nginx/site/" get pintsized/lua-resty-http

rm -r \
    /tmp/openresty-install/etc/nginx/*.default \
    /tmp/openresty-install/var/lib/nginx/bin/opm \
    /tmp/openresty-install/var/lib/nginx/bin/nginx-xml2pod \
    /tmp/openresty-install/var/lib/nginx/bin/restydoc-index \
    /tmp/openresty-install/var/lib/nginx/bin/restydoc \
    /tmp/openresty-install/var/lib/nginx/bin/md2pod.pl \
    /tmp/openresty-install/var/lib/nginx/pod \
    /tmp/openresty-install/var/lib/nginx/resty.index \
    /tmp/openresty-install/var/run \
