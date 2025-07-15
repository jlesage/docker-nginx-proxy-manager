# Docker container for Nginx Proxy Manager
[![Release](https://img.shields.io/github/release/jlesage/docker-nginx-proxy-manager.svg?logo=github&style=for-the-badge)](https://github.com/jlesage/docker-nginx-proxy-manager/releases/latest)
[![Docker Image Size](https://img.shields.io/docker/image-size/jlesage/nginx-proxy-manager/latest?logo=docker&style=for-the-badge)](https://hub.docker.com/r/jlesage/nginx-proxy-manager/tags)
[![Docker Pulls](https://img.shields.io/docker/pulls/jlesage/nginx-proxy-manager?label=Pulls&logo=docker&style=for-the-badge)](https://hub.docker.com/r/jlesage/nginx-proxy-manager)
[![Docker Stars](https://img.shields.io/docker/stars/jlesage/nginx-proxy-manager?label=Stars&logo=docker&style=for-the-badge)](https://hub.docker.com/r/jlesage/nginx-proxy-manager)
[![Build Status](https://img.shields.io/github/actions/workflow/status/jlesage/docker-nginx-proxy-manager/build-image.yml?logo=github&branch=master&style=for-the-badge)](https://github.com/jlesage/docker-nginx-proxy-manager/actions/workflows/build-image.yml)
[![Source](https://img.shields.io/badge/Source-GitHub-blue?logo=github&style=for-the-badge)](https://github.com/jlesage/docker-nginx-proxy-manager)
[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg?style=for-the-badge)](https://paypal.me/JocelynLeSage)

This is a Docker container for [Nginx Proxy Manager](https://nginxproxymanager.com).



---

[![Nginx Proxy Manager logo](https://images.weserv.nl/?url=raw.githubusercontent.com/jlesage/docker-templates/master/jlesage/images/nginx-proxy-manager-icon.png&w=110)](https://nginxproxymanager.com)[![Nginx Proxy Manager](https://images.placeholders.dev/?width=608&height=110&fontFamily=monospace&fontWeight=400&fontSize=52&text=Nginx%20Proxy%20Manager&bgColor=rgba(0,0,0,0.0)&textColor=rgba(121,121,121,1))](https://nginxproxymanager.com)

Nginx Proxy Manager enables you to easily forward to your websites running at
home or otherwise, including free SSL, without having to know too much about
Nginx or Letsencrypt.

---

## Quick Start

**NOTE**:
    The Docker command provided in this quick start is an example, and parameters
    should be adjusted to suit your needs.

Launch the Nginx Proxy Manager docker container with the following command:
```shell
docker run -d \
    --name=nginx-proxy-manager \
    -p 8181:8181 \
    -p 8080:8080 \
    -p 4443:4443 \
    -v /docker/appdata/nginx-proxy-manager:/config:rw \
    jlesage/nginx-proxy-manager
```

Where:

  - `/docker/appdata/nginx-proxy-manager`: Stores the application's configuration, state, logs, and any files requiring persistency.

Access the Nginx Proxy Manager GUI by browsing to `http://your-host-ip:8181`.

## Documentation

Full documentation is available at https://github.com/jlesage/docker-nginx-proxy-manager.

## Support or Contact

Having troubles with the container or have questions? Please
[create a new issue](https://github.com/jlesage/docker-nginx-proxy-manager/issues).

For other Dockerized applications, visit https://jlesage.github.io/docker-apps.
