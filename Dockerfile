#
# nginx-proxy-manager Dockerfile
#
# https://github.com/jlesage/docker-nginx-proxy-manager
#

# Pull base image.
FROM jlesage/baseimage:alpine-3.9-v2.4.3

# Docker image version is provided via build arg.
ARG DOCKER_IMAGE_VERSION=unknown

# Define software versions.
ARG NGINX_PROXY_MANAGER_VERSION=2.2.3

# Define software download URLs.
ARG NGINX_PROXY_MANAGER_URL=https://github.com/jc21/nginx-proxy-manager/archive/v${NGINX_PROXY_MANAGER_VERSION}.tar.gz

# Define working directory.
WORKDIR /tmp

# Install dependencies.
RUN \
    add-pkg \
        nodejs \
        nginx \
        nginx-mod-stream \
        mariadb \
        mariadb-client \
        mariadb-server-utils \
        certbot \
        openssl \
        apache2-utils \
        logrotate \
        && \
    # Adjust the logrotate config file.
    sed-patch 's|^/var/log/messages|#/var/log/messages|' /etc/logrotate.conf && \
    # Clean some uneeded stuff from mariadb.
    rm -r \
        /var/lib/mysql \
        && \
    # Clean some uneeded stuff from nginx.
    mv /etc/nginx/fastcgi.conf /tmp/ && \
    mv /etc/nginx/fastcgi_params /tmp/ && \
    rm -r \
        /var/log/nginx \
        /var/lib/nginx \
        /var/tmp/nginx \
        /etc/nginx \
        /etc/init.d/nginx \
        /etc/logrotate.d/nginx \
        /var/www && \
    mkdir /etc/nginx && \
    mv /tmp/fastcgi.conf /etc/nginx/ && \
    mv /tmp/fastcgi_params /etc/nginx/ && \
    ln -s /tmp/nginx /var/tmp/nginx && \
    # nginx always tries to open /var/lib/nginx/logs/error.log before reading
    # its configuration.  Make sure it exists.
    mkdir -p /var/lib/nginx/logs && \
    ln -sf /config/log/nginx/error.log /var/lib/nginx/logs/error.log && \
    # Make sure mariadb listen on port 3306
    sed-patch 's/^skip-networking/#skip-networking/' /etc/my.cnf.d/mariadb-server.cnf

# Install Nginx Proxy Manager.
RUN \
    # Install packages needed by the build.
    add-pkg --virtual build-dependencies \
        build-base \
        curl \
        patch \
        yarn \
        git \
        python \
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
    cp -r nginx-proxy-manager/docker/rootfs/etc/nginx /etc/ && \
    cp -r nginx-proxy-manager/docker/rootfs/var/www /var/ && \
    cp -r nginx-proxy-manager/docker/rootfs/etc/letsencrypt.ini /etc/ && \

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
    sed-patch 's|listen 80;|listen 8080;|' /opt/nginx-proxy-manager/templates/_listen.conf && \
    sed-patch 's|:80;|:8080;|' /opt/nginx-proxy-manager/templates/_listen.conf && \
    sed-patch 's|listen 80 |listen 8080 |' /opt/nginx-proxy-manager/templates/default.conf && \

    # Change the HTTPs port 443 to the unprivileged port 4443.
    sed-patch 's|443 |4443 |' /etc/nginx/conf.d/default.conf && \
    sed-patch 's|"443";|"4443";|' /etc/nginx/conf.d/default.conf && \
    sed-patch 's|listen 443 |listen 4443 |' /opt/nginx-proxy-manager/templates/_listen.conf && \
    sed-patch 's|:443;|:4443;|' /opt/nginx-proxy-manager/templates/_listen.conf && \

    # Fix nginx test command line.
    sed-patch 's|-g "error_log off;"||' /opt/nginx-proxy-manager/internal/nginx.js && \

    # Remove the `user` directive, since we want nginx to run as non-root.
    sed-patch 's|user root;|#user root;|' /etc/nginx/nginx.conf && \

    # Make sure nginx loads the stream module.
    sed-patch '/daemon off;/a load_module /usr/lib/nginx/modules/ngx_stream_module.so;' /etc/nginx/nginx.conf && \

    # Redirect `/data' to '/config'.
    ln -s /config /data && \

    # Make sure the config file for IP ranges is stored in persistent volume.
    mv /etc/nginx/conf.d/include/ip_ranges.conf /defaults/ && \
    ln -sf /config/nginx/ip_ranges.conf /etc/nginx/conf.d/include/ip_ranges.conf && \

    # Make sure the config file for resovers is stored in persistent volume.
    ln -sf /config/nginx/resolvers.conf /etc/nginx/conf.d/include/resolvers.conf && \

    # Make sure nginx cache is stored on the persistent volume.
    ln -s /config/nginx/cache /var/lib/nginx/cache && \

    # Make sure the manager config file is stored in persistent volume.
    rm -r /opt/nginx-proxy-manager/config && \
    mkdir /opt/nginx-proxy-manager/config && \
    ln -s /config/production.json /opt/nginx-proxy-manager/config/production.json && \

    # Make sure letencrypt certificates are stored in persistent volume.
    ln -s /config/letsencrypt /etc/letsencrypt && \

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
    KEEP_APP_RUNNING=1

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
