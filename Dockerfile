#
# nginx-proxy-manager Dockerfile
#
# https://github.com/jlesage/docker-nginx-proxy-manager
#

# Pull base image.
FROM jlesage/baseimage:alpine-3.15-v2.4.6

# Docker image version is provided via build arg.
ARG DOCKER_IMAGE_VERSION=unknown

# Define software versions.
ARG OPENRESTY_VERSION=1.19.9.1
ARG NGINX_PROXY_MANAGER_VERSION=2.9.15
ARG NGINX_HTTP_GEOIP2_MODULE_VERSION=3.3
ARG LIBMAXMINDDB_VERSION=1.5.0
ARG WATCH_VERSION=0.3.1

# Define software download URLs.
ARG OPENRESTY_URL=https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz
ARG NGINX_PROXY_MANAGER_URL=https://github.com/jc21/nginx-proxy-manager/archive/v${NGINX_PROXY_MANAGER_VERSION}.tar.gz
ARG NGINX_HTTP_GEOIP2_MODULE_URL=https://github.com/leev/ngx_http_geoip2_module/archive/${NGINX_HTTP_GEOIP2_MODULE_VERSION}.tar.gz
ARG LIBMAXMINDDB_URL=https://github.com/maxmind/libmaxminddb/releases/download/${LIBMAXMINDDB_VERSION}/libmaxminddb-${LIBMAXMINDDB_VERSION}.tar.gz
ARG WATCH_URL=https://github.com/tj/watch/archive/${WATCH_VERSION}.tar.gz

# Define working directory.
WORKDIR /tmp

# Build and install the watch binary.
RUN \
    add-pkg --virtual build-dependencies \
        build-base \
        curl \
        && \
    # Set same default compilation flags as abuild.
    export CFLAGS="-Os -fomit-frame-pointer" && \
    export CXXFLAGS="$CFLAGS" && \
    export CPPFLAGS="$CFLAGS" && \
    export LDFLAGS="-Wl,--as-needed" && \
    # Download.
    echo "Downloading watch..." && \
    mkdir watch && \
    curl -# -L ${WATCH_URL} | tar xz --strip 1 -C watch && \
    # Compile.
    echo "Compiling watch..." && \
    cd watch && \
    make && \
    # Install.
    echo "Installing watch..." && \
    make install && \
    strip /usr/local/bin/watch && \
    # Cleanup.
    del-pkg build-dependencies && \
    rm -rf /tmp/* /tmp/.[!.]*

# Build and install OpenResty (nginx).
RUN \
    add-pkg --virtual build-dependencies \
        build-base \
        curl \
        linux-headers \
        perl \
        pcre-dev \
        openssl-dev \
        zlib-dev \
        && \
    # Set same default compilation flags as abuild.
    export CFLAGS="-Os -fomit-frame-pointer" && \
    export CXXFLAGS="$CFLAGS" && \
    export CPPFLAGS="$CFLAGS" && \
    export LDFLAGS="-Wl,--as-needed" && \
    # Download.
    echo "Downloading OpenResty..." && \
    mkdir openresty && \
    curl -# -L ${OPENRESTY_URL} | tar xz --strip 1 -C openresty && \
    echo "Downloading GeoIP2 module..." && \
    mkdir ngx_http_geoip2_module && \
    curl -# -L ${NGINX_HTTP_GEOIP2_MODULE_URL} | tar xz --strip 1 -C ngx_http_geoip2_module && \
    echo "Downloading libmaxminddb..." && \
    mkdir libmaxminddb && \
    curl -# -L ${LIBMAXMINDDB_URL} | tar xz --strip 1 -C libmaxminddb && \
    # Compile.
    echo "Compiling libmaxminddb..." && \
    cd libmaxminddb && \
    ./configure  \
        --prefix=/usr \
        --mandir=/tmp/libmaxminddb-man \
        --with-pic \
        --enable-shared=no \
        --enable-static=yes \
        && \
    make -j$(nproc) install && \
    cd .. && \
    echo "Compiling OpenResty..." && \
    cd openresty && \
    ./configure -j$(nproc) \
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
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_realip_module \
        --with-stream_ssl_preread_module \
        --with-pcre-jit \
        \
        --add-module=/tmp/ngx_http_geoip2_module \
        && \
    make -j$(nproc) && \
    # Install.
    echo "Installing OpenResty..." && \
    make install && \
    find /var/lib/nginx/ -type f -name '*.so*' -exec strip {} ';' && \
    strip /usr/sbin/nginx && \
    cd .. && \
    # Cleanup.
    del-pkg build-dependencies && \
    rm -r \
        /etc/nginx/*.default \
        /var/lib/nginx/bin/opm \
        /var/lib/nginx/bin/nginx-xml2pod \
        /var/lib/nginx/bin/restydoc-index \
        /var/lib/nginx/bin/restydoc \
        /var/lib/nginx/bin/md2pod.pl \
        /var/lib/nginx/luajit/include \
        /var/lib/nginx/luajit/lib/libluajit-5.1.a \
        /var/lib/nginx/luajit/lib/pkgconfig \
        /var/lib/nginx/luajit/share/man \
        /var/lib/nginx/pod \
        /var/lib/nginx/resty.index \
        /var/lib/nginx/site \
        && \
    rm \
        /usr/include/maxminddb*.h \
        /usr/lib/libmaxminddb* \
        /usr/lib/pkgconfig/libmaxminddb.pc \
        && \
    [ -n "$(ls /usr/include)" ] || rm -r /usr/include && \
    [ -n "$(ls /usr/lib/pkgconfig)" ] || rm -r /usr/lib/pkgconfig && \
    rm -rf /tmp/* /tmp/.[!.]*

# Install dependencies.
RUN \
    add-pkg \
        curl \
        nodejs \
        python3 \
        sqlite \
        openssl \
        apache2-utils \
        logrotate \
        # For /opt/nginx-proxy-manager/bin/handle-ipv6-setting.
        bash \
        # For openresty.
        pcre

# Build and install certbot.
RUN \
    add-pkg --virtual build-dependencies \
        build-base \
        python3-dev \
        libffi-dev \
        openssl-dev \
        cargo \
        && \
    # Install pip first.
    # NOTE: pip from the Alpine package repository is debundled, meaning that
    #       its dependencies are part of the system-wide ones.  This save a lot
    #       of space, but these dependencies conflict with the ones required by
    #       Certbot plugins. Thus, we need to manually install pip (with its
    #       built-in dependencies).  See:
    #       https://pip.pypa.io/en/stable/development/vendoring-policy/
    curl -# -L "https://bootstrap.pypa.io/get-pip.py" | python3 && \
    # Then install certbot.
    CARGO_HOME=/tmp/.cargo pip install --no-cache-dir --prefix=/usr certbot && \
    find /usr/lib/python3.9/site-packages -type f -name "*.so" -exec strip {} ';' && \
    find /usr/lib/python3.9/site-packages -type f -name "*.h" -delete && \
    find /usr/lib/python3.9/site-packages -type f -name "*.c" -delete && \
    find /usr/lib/python3.9/site-packages -type f -name "*.exe" -delete && \
    find /usr/lib/python3.9/site-packages -type d -name tests -print0 | xargs -0 rm -r && \
    # Cleanup.
    del-pkg build-dependencies && \
    rm -rf /tmp/* /tmp/.[!.]*

# Install Nginx Proxy Manager.
RUN \
    # Install packages needed by the build.
    add-pkg --virtual build-dependencies \
        build-base \
        curl \
        patch \
        yarn \
        git \
        python2 \
        python3 \
        npm \
        bash \
        && \

    # Install node-prune.
    echo "Installing node-prune..." && \
    curl -sfL https://install.goreleaser.com/github.com/tj/node-prune.sh | bash -s -- -b /tmp/bin && \

    # Download the Nginx Proxy Manager package.
    echo "Downloading Nginx Proxy Manager package..." && \
    mkdir nginx-proxy-manager && \
    curl -# -L ${NGINX_PROXY_MANAGER_URL} | tar xz --strip 1 -C nginx-proxy-manager && \

    sed-patch "s/\"version\": \"0.0.0\",/\"version\": \"${NGINX_PROXY_MANAGER_VERSION}\",/" nginx-proxy-manager/frontend/package.json && \
    sed-patch "s/\"version\": \"0.0.0\",/\"version\": \"${NGINX_PROXY_MANAGER_VERSION}\",/" nginx-proxy-manager/backend/package.json && \

    cp -r nginx-proxy-manager /app && \

    # Build Nginx Proxy Manager frontend.
    echo "Building Nginx Proxy Manager frontend..." && \
    cd /app/frontend && \
    yarn install && \
    yarn build && \
    /tmp/bin/node-prune && \
    cd /tmp && \

    # Build Nginx Proxy Manager backend.
    echo "Building Nginx Proxy Manager backend..." && \
    cd /app/backend && \
    yarn install --prod && \
    /tmp/bin/node-prune && \
    cd /tmp && \

    # Install Nginx Proxy Manager.
    echo "Installing Nginx Proxy Manager..." && \
    mkdir -p /opt && \
    cp -r /app/backend /opt/nginx-proxy-manager && \
    cp -r /app/frontend/dist /opt/nginx-proxy-manager/frontend && \
    cp -r /app/global /opt/nginx-proxy-manager && \
    mkdir /opt/nginx-proxy-manager/bin && \
    cp -r nginx-proxy-manager/docker/rootfs/bin/handle-ipv6-setting /opt/nginx-proxy-manager/bin/ && \
    cp -r nginx-proxy-manager/docker/rootfs/etc/nginx /etc/ && \
    cp -r nginx-proxy-manager/docker/rootfs/var/www /var/ && \
    cp -r nginx-proxy-manager/docker/rootfs/etc/letsencrypt.ini /etc/ && \
    cp -r nginx-proxy-manager/docker/rootfs/etc/logrotate.d /etc/ && \

    # Remove the nginx development config.
    rm /etc/nginx/conf.d/dev.conf && \

    # Change the management interface port to the unprivileged port 8181.
    sed-patch 's|81 default|8181 default|' /etc/nginx/conf.d/production.conf && \

    # Change the management interface root.
    sed-patch 's|/app/frontend;|/opt/nginx-proxy-manager/frontend;|' /etc/nginx/conf.d/production.conf && \

    # Change the HTTP port 80 to the unprivileged port 8080.
    sed-patch 's|80;|8080;|' /etc/nginx/conf.d/default.conf && \
    sed-patch 's|"80";|"8080";|' /etc/nginx/conf.d/default.conf && \
    sed-patch 's|listen 80;|listen 8080;|' /opt/nginx-proxy-manager/templates/letsencrypt-request.conf && \
    sed-patch 's|:80;|:8080;|' /opt/nginx-proxy-manager/templates/letsencrypt-request.conf && \
    sed-patch 's|listen 80;|listen 8080;|' /opt/nginx-proxy-manager/templates/_listen.conf && \
    sed-patch 's|:80;|:8080;|' /opt/nginx-proxy-manager/templates/_listen.conf && \
    sed-patch 's|80 default;|8080 default;|' /opt/nginx-proxy-manager/templates/default.conf && \

    # Change the HTTPs port 443 to the unprivileged port 4443.
    sed-patch 's|443 |4443 |' /etc/nginx/conf.d/default.conf && \
    sed-patch 's|"443";|"4443";|' /etc/nginx/conf.d/default.conf && \
    sed-patch 's|listen 443 |listen 4443 |' /opt/nginx-proxy-manager/templates/_listen.conf && \
    sed-patch 's|:443 |:4443 |' /opt/nginx-proxy-manager/templates/_listen.conf && \
    sed-patch 's|:443;|:4443;|' /opt/nginx-proxy-manager/templates/_listen.conf && \

    # Fix nginx test command line.
    sed-patch 's|-g "error_log off;"||' /opt/nginx-proxy-manager/internal/nginx.js && \

    # Remove the `user` directive, since we want nginx to run as non-root.
    sed-patch 's|user root;|#user root;|' /etc/nginx/nginx.conf && \

    # Change client_body_temp_path.
    sed-patch 's|/tmp/nginx/body|/var/tmp/nginx/body|' /etc/nginx/nginx.conf && \

    # Fix the logrotate config.
    sed-patch 's|root root|app app|' /etc/logrotate.d/nginx-proxy-manager && \
    sed-patch 's|/run/nginx.pid|/run/nginx/nginx.pid|' /etc/logrotate.d/nginx-proxy-manager && \
    sed-patch 's|logrotate /etc/logrotate.d/nginx-proxy-manager|logrotate -s /config/logrotate.status /etc/logrotate.d/nginx-proxy-manager|' /opt/nginx-proxy-manager/setup.js && \
    sed-patch 's|/data/logs/\*/access.log|/data/logs/access.log|' /etc/logrotate.d/nginx-proxy-manager && \
    sed-patch 's|/data/logs/\*/error.log|/data/logs/error.log|' /etc/logrotate.d/nginx-proxy-manager && \

    # Redirect `/data' to '/config'.
    ln -s /config /data && \

    # Make sure the config file for IP ranges is stored in persistent volume.
    mv /etc/nginx/conf.d/include/ip_ranges.conf /defaults/ && \
    ln -sf /config/nginx/ip_ranges.conf /etc/nginx/conf.d/include/ip_ranges.conf && \

    # Make sure the config file for resolvers is stored in persistent volume.
    ln -sf /config/nginx/resolvers.conf /etc/nginx/conf.d/include/resolvers.conf && \

    # Make sure nginx cache is stored on the persistent volume.
    ln -s /config/nginx/cache /var/lib/nginx/cache && \

    # Make sure the manager config file is stored in persistent volume.
    rm -r /opt/nginx-proxy-manager/config && \
    mkdir /opt/nginx-proxy-manager/config && \
    ln -s /config/production.json /opt/nginx-proxy-manager/config/production.json && \

    # Make sure letsencrypt certificates are stored in persistent volume.
    ln -s /config/letsencrypt /etc/letsencrypt && \

    # Make sure some default certbot directories are stored in persistent volume.
    ln -s /config/letsencrypt-workdir /var/lib/letsencrypt && \
    ln -s /config/log/letsencrypt /var/log/letsencrypt && \

    # Cleanup.
    del-pkg build-dependencies && \
    find /opt/nginx-proxy-manager -name "*.h" -delete && \
    find /opt/nginx-proxy-manager -name "*.cc" -delete && \
    find /opt/nginx-proxy-manager -name "*.c" -delete && \
    find /opt/nginx-proxy-manager -name "*.gyp" -delete && \
    rm -r \
        /app \
        /usr/lib/node_modules \
        && \
    rm -rf /tmp/* /tmp/.[!.]*

# Install bcrypt-tool.
RUN \
    # Install packages needed by the build.
    add-pkg --virtual build-dependencies \
        go \
        upx \
        git \
        musl-dev \
        && \
    mkdir /tmp/go && \
    env GOPATH=/tmp/go go get gophers.dev/cmds/bcrypt-tool && \
    strip /tmp/go/bin/bcrypt-tool && \
    upx /tmp/go/bin/bcrypt-tool && \
    cp -v /tmp/go/bin/bcrypt-tool /usr/bin/ && \
    # Cleanup.
    del-pkg build-dependencies && \
    rm -rf /tmp/* /tmp/.[!.]*

# Add files.
COPY rootfs/ /

# Set environment variables.
ENV APP_NAME="Nginx Proxy Manager" \
    DISABLE_IPV6=0

# Define mountable directories.
VOLUME ["/config"]

# Expose ports.
#   - 8080: HTTP traffic
#   - 4443: HTTPs traffic
#   - 8181: Management web interface
EXPOSE 8080 4443 8181

# Metadata.
LABEL \
      org.label-schema.name="nginx-proxy-manager" \
      org.label-schema.description="Docker container for Nginx Proxy Manager" \
      org.label-schema.version="$DOCKER_IMAGE_VERSION" \
      org.label-schema.vcs-url="https://github.com/jlesage/docker-nginx-proxy-manager" \
      org.label-schema.schema-version="1.0"
