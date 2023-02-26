#
# nginx-proxy-manager Dockerfile
#
# https://github.com/jlesage/docker-nginx-proxy-manager
#

# Docker image version is provided via build arg.
ARG DOCKER_IMAGE_VERSION=

# Define software versions.
ARG OPENRESTY_VERSION=1.19.9.1
ARG NGINX_PROXY_MANAGER_VERSION=2.9.19
ARG NGINX_HTTP_GEOIP2_MODULE_VERSION=3.3
ARG LIBMAXMINDDB_VERSION=1.5.0
ARG BCRYPT_TOOL_VERSION=1.1.2

# Define software download URLs.
ARG OPENRESTY_URL=https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz
ARG NGINX_PROXY_MANAGER_URL=https://github.com/jc21/nginx-proxy-manager/archive/v${NGINX_PROXY_MANAGER_VERSION}.tar.gz
ARG NGINX_HTTP_GEOIP2_MODULE_URL=https://github.com/leev/ngx_http_geoip2_module/archive/${NGINX_HTTP_GEOIP2_MODULE_VERSION}.tar.gz
ARG LIBMAXMINDDB_URL=https://github.com/maxmind/libmaxminddb/releases/download/${LIBMAXMINDDB_VERSION}/libmaxminddb-${LIBMAXMINDDB_VERSION}.tar.gz

# Get Dockerfile cross-compilation helpers.
FROM --platform=$BUILDPLATFORM tonistiigi/xx AS xx

# Get Python cryptography wheel.  It is needed for certbot.
# NOTE: It seems to have a bug where `TARGETVARIANT` is not provided for
# arm64/v8, thus we cannot directly use moonbuggy2000/python-musl-wheels.  For
# now, manually download the wheels.
#FROM moonbuggy2000/python-musl-wheels:cryptography-openssl38.0.1-py3.10-${TARGETARCH}${TARGETVARIANT} AS mod_cryptography
FROM alpine:3.16 as mod_cryptography
ARG TARGETARCH
ARG TARGETVARIANT
ARG WHEELS_DIR=/wheels
RUN \
    mkdir "$WHEELS_DIR" && cd "$WHEELS_DIR" && \
    case "$TARGETARCH" in \
        amd64) \
            wget https://github.com/moonbuggy/docker-python-musl-wheels/raw/main/wheels/amd64/cffi-1.15.1-cp310-cp310-musllinux_1_1_x86_64.whl && \
            wget https://github.com/moonbuggy/docker-python-musl-wheels/raw/main/wheels/amd64/cryptography-38.0.1-cp36-abi3-musllinux_1_1_x86_64.whl && \
            wget https://github.com/moonbuggy/docker-python-musl-wheels/raw/main/wheels/amd64/pycparser-2.21-py2.py3-none-any.whl \
            ;; \
        386) \
            wget https://github.com/moonbuggy/docker-python-musl-wheels/raw/main/wheels/i386/cffi-1.15.1-cp310-cp310-musllinux_1_1_i686.whl && \
            wget https://github.com/moonbuggy/docker-python-musl-wheels/raw/main/wheels/i386/cryptography-38.0.1-cp310-cp310-musllinux_1_2_i686.whl && \
            wget https://github.com/moonbuggy/docker-python-musl-wheels/raw/main/wheels/i386/pycparser-2.21-py2.py3-none-any.whl \
            ;; \
        arm) \
            case "$TARGETVARIANT" in \
                v6) \
                    wget https://github.com/moonbuggy/docker-python-musl-wheels/raw/main/wheels/armv6/cffi-1.15.1-cp310-cp310-musllinux_1_2_armv7l.whl && \
                    wget https://github.com/moonbuggy/docker-python-musl-wheels/raw/main/wheels/armv6/cryptography-38.0.1-cp310-cp310-musllinux_1_2_armv7l.whl && \
                    wget https://github.com/moonbuggy/docker-python-musl-wheels/raw/main/wheels/armv6/pycparser-2.21-py2.py3-none-any.whl \
                    ;; \
                v7) \
                    wget https://github.com/moonbuggy/docker-python-musl-wheels/raw/main/wheels/armv7/cffi-1.15.1-cp310-cp310-musllinux_1_2_armv7l.whl && \
                    wget https://github.com/moonbuggy/docker-python-musl-wheels/raw/main/wheels/armv7/cryptography-38.0.1-cp310-cp310-musllinux_1_2_armv7l.whl && \
                    wget https://github.com/moonbuggy/docker-python-musl-wheels/raw/main/wheels/armv7/pycparser-2.21-py2.py3-none-any.whl \
                    ;; \
                *) echo "ERROR: Unknown variant: $TARGETVARIANT" && exit 1 ;; \
            esac \
            ;; \
        arm64) \
            wget https://github.com/moonbuggy/docker-python-musl-wheels/raw/main/wheels/arm64v8/cffi-1.15.1-cp310-cp310-musllinux_1_2_aarch64.whl && \
            wget https://github.com/moonbuggy/docker-python-musl-wheels/raw/main/wheels/arm64v8/cryptography-38.0.1-cp36-abi3-musllinux_1_1_aarch64.whl && \
            wget https://github.com/moonbuggy/docker-python-musl-wheels/raw/main/wheels/arm64v8/pycparser-2.21-py2.py3-none-any.whl \
            ;; \
        *) echo "ERROR: Unknown arch: $TARGETARCH" && exit 1 ;; \
    esac

# Build UPX.
FROM --platform=$BUILDPLATFORM alpine:3.16 AS upx
RUN apk --no-cache add build-base curl make cmake git && \
    mkdir /tmp/upx && \
    curl -# -L https://github.com/upx/upx/releases/download/v4.0.1/upx-4.0.1-src.tar.xz | tar xJ --strip 1 -C /tmp/upx && \
    make -C /tmp/upx build/release-gcc -j$(nproc) && \
    cp -v /tmp/upx/build/release-gcc/upx /usr/bin/upx

# Build Nginx Proxy Manager.
FROM --platform=$BUILDPLATFORM alpine:3.16 AS npm
ARG TARGETPLATFORM
ARG NGINX_PROXY_MANAGER_VERSION
ARG NGINX_PROXY_MANAGER_URL
COPY --from=xx / /
COPY src/nginx-proxy-manager /build
RUN /build/build.sh "$NGINX_PROXY_MANAGER_VERSION" "$NGINX_PROXY_MANAGER_URL"

# Build OpenResty (nginx).
FROM --platform=$BUILDPLATFORM alpine:3.16 AS nginx
ARG TARGETPLATFORM
ARG OPENRESTY_URL
ARG NGINX_HTTP_GEOIP2_MODULE_URL
ARG LIBMAXMINDDB_URL
COPY --from=xx / /
COPY src/openresty /build
RUN /build/build.sh "$OPENRESTY_URL" "$NGINX_HTTP_GEOIP2_MODULE_URL" "$LIBMAXMINDDB_URL"
RUN xx-verify /tmp/openresty-install/usr/sbin/nginx

# Build bcrypt-tool.
FROM --platform=$BUILDPLATFORM alpine:3.16 AS bcrypt-tool
ARG TARGETPLATFORM
ARG BCRYPT_TOOL_VERSION
COPY --from=xx / /
COPY src/bcrypt-tool /build
RUN /build/build.sh "$BCRYPT_TOOL_VERSION"
RUN xx-verify /tmp/go/bin/bcrypt-tool
COPY --from=upx /usr/bin/upx /usr/bin/upx
RUN upx /tmp/go/bin/bcrypt-tool

# Build certbot.
FROM alpine:3.16 AS certbot
COPY --from=mod_cryptography /wheels /wheels
RUN \
    apk --no-cache add build-base curl python3 && \
    curl -# -L "https://bootstrap.pypa.io/get-pip.py" | python3 && \
    pip install --no-cache-dir --root=/tmp/certbot-install --prefix=/usr --find-links /wheels/ --prefer-binary certbot && \
    find /tmp/certbot-install/usr/lib/python3.10/site-packages -type f -name "*.so" -exec strip {} ';' && \
    find /tmp/certbot-install/usr/lib/python3.10/site-packages -type f -name "*.h" -delete && \
    find /tmp/certbot-install/usr/lib/python3.10/site-packages -type f -name "*.c" -delete && \
    find /tmp/certbot-install/usr/lib/python3.10/site-packages -type f -name "*.exe" -delete && \
    find /tmp/certbot-install/usr/lib/python3.10/site-packages -type d -name tests -print0 | xargs -0 rm -r

# Pull base image.
FROM jlesage/baseimage:alpine-3.16-v3.4.5

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
        apache2-utils \
        logrotate \
        # For /opt/nginx-proxy-manager/bin/handle-ipv6-setting.
        bash \
        # For openresty.
        pcre \
        luajit \
        && \
    # Install pip.
    # NOTE: pip from the Alpine package repository is debundled, meaning that
    #       its dependencies are part of the system-wide ones.  This save a lot
    #       of space, but these dependencies conflict with the ones required by
    #       Certbot plugins. Thus, we need to manually install pip (with its
    #       built-in dependencies).  See:
    #       https://pip.pypa.io/en/stable/development/vendoring-policy/
    curl -# -L "https://bootstrap.pypa.io/get-pip.py" | python3

# Add files.
COPY rootfs/ /
COPY --from=nginx /tmp/openresty-install/ /
COPY --from=npm /tmp/nginx-proxy-manager-install/ /
COPY --from=bcrypt-tool /tmp/go/bin/bcrypt-tool /usr/bin/
COPY --from=certbot /tmp/certbot-install/ /

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
