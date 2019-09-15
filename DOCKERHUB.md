# Docker container for Nginx Proxy Manager
[![Docker Image Size](https://img.shields.io/microbadger/image-size/jlesage/nginx-proxy-manager)](http://microbadger.com/#/images/jlesage/nginx-proxy-manager) [![Build Status](https://travis-ci.org/jlesage/docker-nginx-proxy-manager.svg?branch=master)](https://travis-ci.org/jlesage/docker-nginx-proxy-manager) [![GitHub Release](https://img.shields.io/github/release/jlesage/docker-nginx-proxy-manager.svg)](https://github.com/jlesage/docker-nginx-proxy-manager/releases/latest) [![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://paypal.me/JocelynLeSage/0usd)

This is a Docker container for [Nginx Proxy Manager](https://nginxproxymanager.jc21.com).

---

[![Nginx Proxy Manager logo](https://images.weserv.nl/?url=raw.githubusercontent.com/jlesage/docker-templates/master/jlesage/images/nginx-proxy-manager-icon.png&w=200)](https://nginxproxymanager.jc21.com)[![Nginx Proxy Manager](https://dummyimage.com/400x110/ffffff/575757&text=Nginx+Proxy+Manager)](https://nginxproxymanager.jc21.com)

Nginx Proxy Manager enables you to easily forward to your websites running at home or otherwise, including free SSL, without having to know too much about Nginx or Letsencrypt.

---

## Quick Start

**NOTE**: The Docker command provided in this quick start is given as an example
and parameters should be adjusted to your need.

Launch the Nginx Proxy Manager docker container with the following command:
```
docker run -d \
    --name=nginx-proxy-manager \
    -p 8181:8181 \
    -p 8080:8080 \
    -p 4443:4443 \
    -v /docker/appdata/nginx-proxy-manager:/config:rw \
    jlesage/nginx-proxy-manager
```

Where:
  - `/docker/appdata/nginx-proxy-manager`: This is where the application stores its configuration, log and any files needing persistency.

Browse to `http://your-host-ip:8181` to access the Nginx Proxy Manager web interface.

## Documentation

Full documentation is available at https://github.com/jlesage/docker-nginx-proxy-manager.

## Support or Contact

Having troubles with the container or have questions?  Please
[create a new issue].

For other great Dockerized applications, see https://jlesage.github.io/docker-apps.

[create a new issue]: https://github.com/jlesage/docker-nginx-proxy-manager/issues
