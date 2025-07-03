#
# nginx-proxy-manager Dockerfile
#
# https://github.com/jlesage/docker-nginx-proxy-manager
#

# Docker image version is provided via build arg.
ARG DOCKER_IMAGE_VERSION=

# Define software versions.
ARG OPENRESTY_VERSION=1.27.1.1
ARG NGINX_PROXY_MANAGER_VERSION=2.12.3
ARG NGINX_HTTP_GEOIP2_MODULE_VERSION=3.3
ARG LIBMAXMINDDB_VERSION=1.5.0
ARG BCRYPT_TOOL_VERSION=1.1.2
ARG CROWDSEC_OPENRESTY_BOUNCER_VERSION=1.0.5

# Define software download URLs.
ARG OPENRESTY_URL=https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz
ARG CROWDSEC_OPENRESTY_BOUNCER_URL=https://github.com/crowdsecurity/cs-openresty-bouncer/releases/download/v${CROWDSEC_OPENRESTY_BOUNCER_VERSION}/crowdsec-openresty-bouncer.tgz
ARG NGINX_PROXY_MANAGER_URL=https://github.com/jc21/nginx-proxy-manager/archive/v${NGINX_PROXY_MANAGER_VERSION}.tar.gz
ARG NGINX_HTTP_GEOIP2_MODULE_URL=https://github.com/leev/ngx_http_geoip2_module/archive/${NGINX_HTTP_GEOIP2_MODULE_VERSION}.tar.gz
ARG LIBMAXMINDDB_URL=https://github.com/maxmind/libmaxminddb/releases/download/${LIBMAXMINDDB_VERSION}/libmaxminddb-${LIBMAXMINDDB_VERSION}.tar.gz

# Get Dockerfile cross-compilation helpers.
FROM --platform=$BUILDPLATFORM tonistiigi/xx AS xx

# Get Python cryptography wheel. It is needed for certbot.
FROM moonbuggy2000/python-musl-wheels:cryptography43.0.0-py3.11-${TARGETARCH}${TARGETVARIANT} AS mod_cryptography

# Get UPX (statically linked).
# NOTE: UPX 5.x is not compatible with old kernels, e.g. 3.10 used by some
#       Synology NASes. See https://github.com/upx/upx/issues/902
FROM --platform=$BUILDPLATFORM alpine:3.20 AS upx
ARG UPX_VERSION=4.2.4
RUN apk --no-cache add curl && \
    mkdir /tmp/upx && \
    curl -# -L https://github.com/upx/upx/releases/download/v${UPX_VERSION}/upx-${UPX_VERSION}-amd64_linux.tar.xz | tar xJ --strip 1 -C /tmp/upx && \
    cp -v /tmp/upx/upx /usr/bin/upx

# Build Nginx Proxy Manager.
FROM --platform=$BUILDPLATFORM alpine:3.18 AS npm
ARG TARGETPLATFORM
ARG NGINX_PROXY_MANAGER_VERSION
ARG NGINX_PROXY_MANAGER_URL
COPY --from=xx / /
COPY src/nginx-proxy-manager /build
RUN /build/build.sh "$NGINX_PROXY_MANAGER_VERSION" "$NGINX_PROXY_MANAGER_URL"

# Build OpenResty (nginx).
FROM --platform=$BUILDPLATFORM alpine:3.18 AS nginx
ARG TARGETPLATFORM
ARG OPENRESTY_URL
ARG NGINX_HTTP_GEOIP2_MODULE_URL
ARG LIBMAXMINDDB_URL
COPY --from=xx / /
COPY src/openresty /build
RUN /build/build.sh "$OPENRESTY_URL" "$NGINX_HTTP_GEOIP2_MODULE_URL" "$LIBMAXMINDDB_URL"
RUN xx-verify /tmp/openresty-install/usr/sbin/nginx

# Build bcrypt-tool.
FROM --platform=$BUILDPLATFORM alpine:3.18 AS bcrypt-tool
ARG TARGETPLATFORM
ARG BCRYPT_TOOL_VERSION
COPY --from=xx / /
COPY src/bcrypt-tool /build
RUN /build/build.sh "$BCRYPT_TOOL_VERSION"
RUN xx-verify /tmp/go/bin/bcrypt-tool
COPY --from=upx /usr/bin/upx /usr/bin/upx
RUN upx /tmp/go/bin/bcrypt-tool

# Build certbot.
FROM alpine:3.18 AS certbot
COPY --from=mod_cryptography / /wheels
RUN \
    apk --no-cache add build-base curl python3 && \
    curl -# -L "https://bootstrap.pypa.io/get-pip.py" | python3 && \
    pip install --no-cache-dir --root=/tmp/certbot-install --prefix=/usr --find-links /wheels/ --prefer-binary --only-binary=:all: certbot && \
    find /tmp/certbot-install/usr/lib/python3.11/site-packages -type f -name "*.so" -exec strip {} ';' && \
    find /tmp/certbot-install/usr/lib/python3.11/site-packages -type f -name "*.h" -delete && \
    find /tmp/certbot-install/usr/lib/python3.11/site-packages -type f -name "*.c" -delete && \
    find /tmp/certbot-install/usr/lib/python3.11/site-packages -type f -name "*.exe" -delete && \
    find /tmp/certbot-install/usr/lib/python3.11/site-packages -type d -name tests -print0 | xargs -0 rm -r

# Build cs-openresty-boucner.
FROM alpine:3.16 AS cs-openresty-bouncer
ARG TARGETPLATFORM
ARG CROWDSEC_OPENRESTY_BOUNCER_URL
COPY --from=xx / /
COPY src/cs-openresty-bouncer /build
RUN /build/build.sh "$CROWDSEC_OPENRESTY_BOUNCER_URL"

# Pull base image.
FROM jlesage/baseimage:alpine-3.18-v3.7.1

ARG NGINX_PROXY_MANAGER_VERSION
ARG DOCKER_IMAGE_VERSION

# Define working directory.
WORKDIR /tmp

# Install dependencies.
RUN \
    add-pkg \
        curl \
        nodejs \
        python3 \
        sqlite \
        openssl \
        # For /opt/nginx-proxy-manager/bin/handle-ipv6-setting.
        bash \
        # For openresty.
        pcre \
        luajit \
        && \
    # Install pip.
    # NOTE: pip from the Alpine package repository is debundled, meaning that
    #       its dependencies are part of the system-wide ones. This save a lot
    #       of space, but these dependencies conflict with the ones required by
    #       Certbot plugins. Thus, we need to manually install pip (with its
    #       built-in dependencies). See:
    #       https://pip.pypa.io/en/stable/development/vendoring-policy/
    curl -# -L "https://bootstrap.pypa.io/get-pip.py" | python3

# Add files.
COPY rootfs/ /
COPY --from=nginx /tmp/openresty-install/ /
COPY --from=npm /tmp/nginx-proxy-manager-install/ /
COPY --from=bcrypt-tool /tmp/go/bin/bcrypt-tool /usr/bin/
COPY --from=certbot /tmp/certbot-install/ /
COPY --from=cs-openresty-bouncer /tmp/crowdsec-openresty-bouncer-install/ /

# Set internal environment variables.
RUN \
    set-cont-env APP_NAME "Nginx Proxy Manager" && \
    set-cont-env APP_VERSION "$NGINX_PROXY_MANAGER_VERSION" && \
    set-cont-env DOCKER_IMAGE_VERSION "$DOCKER_IMAGE_VERSION" && \
    true

# Set public environment variables.
ENV \
    DISABLE_IPV6=0

# Expose ports.
#   - 8080: HTTP traffic
#   - 4443: HTTPs traffic
#   - 8181: Management web interface
EXPOSE 8080 4443 8181

# Metadata.
LABEL \
      org.label-schema.name="nginx-proxy-manager" \
      org.label-schema.description="Docker container for Nginx Proxy Manager" \
      org.label-schema.version="${DOCKER_IMAGE_VERSION:-unknown}" \
      org.label-schema.vcs-url="https://github.com/jlesage/docker-nginx-proxy-manager" \
      org.label-schema.schema-version="1.0"
