## Note

This is a drop in replacement for [jlesage/nginx-proxy-manager](https://hub.docker.com/r/jlesage/nginx-proxy-manager)

This fork includes the [OpenResty Crowdsec Bouncer](https://github.com/crowdsecurity/cs-openresty-bouncer)

Please see the [crowdsec_support](https://github.com/LePresidente/docker-nginx-proxy-manager/tree/crowdsec_support) branch for the changes as 

Docker images hosted on dockerhub.

https://hub.docker.com/r/lepresidente/nginx-proxy-manager

| TAG       | cs-openresty-bouncer version|
|-----------|-----------------------------|
| latest    | 0.1.10 (PreRelease)          |


Instructions to use:
Starting the container at this point will start Nginx-Proxy-Manager as before but will create a new file in /config/crowdsec/ called crowdsec-openresty-bouncer.conf

You will need to edit this file with at least the following changes then restart the container.

```
ENABLED=true
API_URL=http://<crowdsecserver>:8080
API_KEY=<APIKEY>
```

the crowdsec api key can be generated on the crowdsec instance using the following command 

```
cscli bouncers add npm-proxy
```

Currently this is a side project and I will try keep this up to date

# Docker container for Nginx Proxy Manager
[![Release](https://img.shields.io/github/release/jlesage/docker-nginx-proxy-manager.svg?logo=github&style=for-the-badge)](https://github.com/jlesage/docker-nginx-proxy-manager/releases/latest)
[![Docker Image Size](https://img.shields.io/docker/image-size/jlesage/nginx-proxy-manager/latest?logo=docker&style=for-the-badge)](https://hub.docker.com/r/jlesage/nginx-proxy-manager/tags)
[![Docker Pulls](https://img.shields.io/docker/pulls/jlesage/nginx-proxy-manager?label=Pulls&logo=docker&style=for-the-badge)](https://hub.docker.com/r/jlesage/nginx-proxy-manager)
[![Docker Stars](https://img.shields.io/docker/stars/jlesage/nginx-proxy-manager?label=Stars&logo=docker&style=for-the-badge)](https://hub.docker.com/r/jlesage/nginx-proxy-manager)
[![Build Status](https://img.shields.io/github/actions/workflow/status/jlesage/docker-nginx-proxy-manager/build-image.yml?logo=github&branch=master&style=for-the-badge)](https://github.com/jlesage/docker-nginx-proxy-manager/actions/workflows/build-image.yml)
[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg?style=for-the-badge)](https://paypal.me/JocelynLeSage)

This project provides a Docker container for [Nginx Proxy Manager](https://nginxproxymanager.com).



---

[![Nginx Proxy Manager logo](https://images.weserv.nl/?url=raw.githubusercontent.com/jlesage/docker-templates/master/jlesage/images/nginx-proxy-manager-icon.png&w=110)](https://nginxproxymanager.com)[![Nginx Proxy Manager](https://images.placeholders.dev/?width=608&height=110&fontFamily=monospace&fontWeight=400&fontSize=52&text=Nginx%20Proxy%20Manager&bgColor=rgba(0,0,0,0.0)&textColor=rgba(121,121,121,1))](https://nginxproxymanager.com)

Nginx Proxy Manager enables you to easily forward to your websites running at
home or otherwise, including free SSL, without having to know too much about
Nginx or Letsencrypt.

---

## Table of Contents

   * [Quick Start](#quick-start)
   * [Usage](#usage)
      * [Environment Variables](#environment-variables)
         * [Deployment Considerations](#deployment-considerations)
      * [Data Volumes](#data-volumes)
      * [Ports](#ports)
      * [Changing Parameters of a Running Container](#changing-parameters-of-a-running-container)
      * [Docker Compose File](#docker-compose-file)
   * [Docker Image Versioning and Tags](#docker-image-versioning-and-tags)
   * [Docker Image Update](#docker-image-update)
      * [Synology](#synology)
      * [unRAID](#unraid)
   * [User/Group IDs](#usergroup-ids)
   * [Accessing the GUI](#accessing-the-gui)
   * [Shell Access](#shell-access)
   * [Default Administrator Account](#default-administrator-account)
   * [Accessibility From The Internet](#accessibility-from-the-internet)
   * [Troubleshooting](#troubleshooting)
      * [Password Reset](#password-reset)
   * [Support or Contact](#support-or-contact)

## Quick Start

> [!IMPORTANT]
> The Docker command provided in this quick start is an example, and parameters
> should be adjusted to suit your needs.

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

## Usage

```shell
docker run [-d] \
    --name=nginx-proxy-manager \
    [-e <VARIABLE_NAME>=<VALUE>]... \
    [-v <HOST_DIR>:<CONTAINER_DIR>[:PERMISSIONS]]... \
    [-p <HOST_PORT>:<CONTAINER_PORT>]... \
    jlesage/nginx-proxy-manager
```

| Parameter | Description |
|-----------|-------------|
| -d        | Runs the container in the background. If not set, the container runs in the foreground. |
| -e        | Passes an environment variable to the container. See [Environment Variables](#environment-variables) for details. |
| -v        | Sets a volume mapping to share a folder or file between the host and the container. See [Data Volumes](#data-volumes) for details. |
| -p        | Sets a network port mapping to expose an internal container port to the host). See [Ports](#ports) for details. |

### Environment Variables

To customize the container's behavior, you can pass environment variables using
the `-e` parameter in the format `<VARIABLE_NAME>=<VALUE>`.

| Variable       | Description                                  | Default |
|----------------|----------------------------------------------|---------|
|`USER_ID`| ID of the user the application runs as. See [User/Group IDs](#usergroup-ids) for details. | `1000` |
|`GROUP_ID`| ID of the group the application runs as. See [User/Group IDs](#usergroup-ids) for details. | `1000` |
|`SUP_GROUP_IDS`| Comma-separated list of supplementary group IDs for the application. | (no value) |
|`UMASK`| Mask controlling permissions for newly created files and folders, specified in octal notation. By default, `0022` ensures files and folders are readable by all but writable only by the owner. See the umask calculator at http://wintelguy.com/umask-calc.pl. | `0022` |
|`LANG`| Sets the [locale](https://en.wikipedia.org/wiki/Locale_(computer_software)), defining the application's language, if supported. Format is `language[_territory][.codeset]`, where language is an [ISO 639 language code](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes), territory is an [ISO 3166 country code](https://en.wikipedia.org/wiki/ISO_3166-1#Current_codes), and codeset is a character set, like `UTF-8`. For example, Australian English using UTF-8 is `en_AU.UTF-8`. | `en_US.UTF-8` |
|`TZ`| [TimeZone](http://en.wikipedia.org/wiki/List_of_tz_database_time_zones) used by the container. The timezone can also be set by mapping `/etc/localtime` between the host and the container. | `Etc/UTC` |
|`KEEP_APP_RUNNING`| When set to `1`, the application is automatically restarted if it crashes or terminates. | `0` |
|`APP_NICENESS`| Priority at which the application runs. A niceness value of -20 is the highest, 19 is the lowest and 0 the default. **NOTE**: A negative niceness (priority increase) requires additional permissions. The container must be run with the Docker option `--cap-add=SYS_NICE`. | `0` |
|`INSTALL_PACKAGES`| Space-separated list of packages to install during container startup. List of available packages can be found at https://pkgs.alpinelinux.org. | (no value) |
|`PACKAGES_MIRROR`| Mirror of the repository to use when installing packages. List of mirrors is available at https://mirrors.alpinelinux.org. | (no value) |
|`CONTAINER_DEBUG`| When set to `1`, enables debug logging. | `0` |
|`DISABLE_IPV6`| When set to `1`, IPv6 support is disabled.  This is needed when IPv6 is not enabled/supported on the host. | `0` |

#### Deployment Considerations

Many tools used to manage Docker containers extract environment variables
defined by the Docker image to create or deploy the container.

For example, this behavior is seen in:
  - The Docker application on Synology NAS
  - The Container Station on QNAP NAS
  - Portainer
  - etc.

While this is useful for users to adjust environment variable values to suit
their needs, keeping all of them can be confusing and even risky.

A good practice is to set or retain only the variables necessary for the
container to function as desired in your setup. If a variable is left at its
default value, it can be removed. Keep in mind that all environment variables
are optional; none are required for the container to start.

Removing unneeded environment variables offers several benefits:

  - Prevents retaining variables no longer used by the container. Over time,
    with image updates, some variables may become obsolete.
  - Allows the Docker image to update or fix default values. With image updates,
    default values may change to address issues or support new features.
  - Avoids changes to variables that could disrupt the container's
    functionality. Some undocumented variables, like `PATH` or `ENV`, are
    required but not meant to be modified by users, yet container management
    tools may expose them.
  - Addresses a bug in Container Station on QNAP and the Docker application on
    Synology, where variables without values may not be allowed. This behavior
    is incorrect, as variables without values are valid. Removing unneeded
    variables prevents deployment issues on these devices.

### Data Volumes

The following table describes the data volumes used by the container. Volume
mappings are set using the `-v` parameter with a value in the format
`<HOST_DIR>:<CONTAINER_DIR>[:PERMISSIONS]`.

| Container path  | Permissions | Description |
|-----------------|-------------|-------------|
|`/config`| rw | Stores the application's configuration, state, logs, and any files requiring persistency. |

### Ports

The following table lists the ports used by the container.

When using the default bridge network, ports can be mapped to the host using the
`-p` parameter with value in the format `<HOST_PORT>:<CONTAINER_PORT>`. The
internal container port may not be changeable, but you can use any port on the
host side.

See the Docker [Docker Container Networking](https://docs.docker.com/config/containers/container-networking)
documentation for details.

| Port | Protocol | Mapping to Host | Description |
|------|----------|-----------------|-------------|
| 8181 | TCP | Mandatory | Port used to access the web interface of the application. |
| 8080 | TCP | Mandatory | Port used to serve HTTP requests. |
| 4443 | TCP | Mandatory | Port used to serve HTTPs requests. |

### Changing Parameters of a Running Container

Environment variables, volume mappings, and port mappings are specified when
creating the container. To modify these parameters for an existing container,
follow these steps:

  1. Stop the container (if it is running):
```shell
docker stop nginx-proxy-manager
```

  2. Remove the container:
```shell
docker rm nginx-proxy-manager
```

  3. Recreate and start the container using the `docker run` command, adjusting
     parameters as needed.

> [!NOTE]
> Since all application data is saved under the `/config` container folder,
> destroying and recreating the container does not result in data loss, and the
> application resumes with the same state, provided the `/config` folder
> mapping remains unchanged.

### Docker Compose File

Below is an example `docker-compose.yml` file for use with
[Docker Compose](https://docs.docker.com/compose/overview/).

Adjust the configuration to suit your needs. Only mandatory settings are
included in this example.

```yaml
version: '3'
services:
  nginx-proxy-manager:
    image: jlesage/nginx-proxy-manager
    ports:
      - "8181:8181"
      - "8080:8080"
      - "4443:4443"
    volumes:
      - "/docker/appdata/nginx-proxy-manager:/config:rw"
```

## Docker Image Versioning and Tags

Each release of a Docker image is versioned, and each version as its own image
tag. Before October 2022, the versioning scheme followed
[semantic versioning](https://semver.org).

Since then, the versioning scheme has shifted to
[calendar versioning](https://calver.org) with the format `YY.MM.SEQUENCE`,
where:
  - `YY` is the zero-padded year (relative to year 2000).
  - `MM` is the zero-padded month.
  - `SEQUENCE` is the incremental release number within the month (first release
    is 1, second is 2, etc).

View all available tags on [Docker Hub] or check the [Releases] page for version
details.

[Releases]: https://github.com/jlesage/docker-nginx-proxy-manager/releases
[Docker Hub]: https://hub.docker.com/r/jlesage/nginx-proxy-manager/tags

## Docker Image Update

The Docker image is regularly updated to incorporate new features, fix issues,
or integrate newer versions of the containerized application. Several methods
can be used to update the Docker image.

If your system provides a built-in method for updating containers, this should
be your primary approach.

Alternatively, you can use [Watchtower], a container-based solution for
automating Docker image updates. Watchtower seamlessly handles updates when a
new image is available.

To manually update the Docker image, follow these steps:

  1. Fetch the latest image:
```shell
docker pull jlesage/nginx-proxy-manager
```

  2. Stop the container:
```shell
docker stop nginx-proxy-manager
```

  3. Remove the container:
```shell
docker rm nginx-proxy-manager
```

  4. Recreate and start the container using the `docker run` command, with the
     same parameters used during initial deployment.

[Watchtower]: https://github.com/containrrr/watchtower

### Synology

For Synology NAS users, follow these steps to update a container image:

  1.  Open the *Docker* application.
  2.  Click *Registry* in the left pane.
  3.  In the search bar, type the name of the container (`jlesage/nginx-proxy-manager`).
  4.  Select the image, click *Download*, and choose the `latest` tag.
  5.  Wait for the download to complete. A notification will appear once done.
  6.  Click *Container* in the left pane.
  7.  Select your Nginx Proxy Manager container.
  8.  Stop it by clicking *Action* -> *Stop*.
  9.  Clear the container by clicking *Action* -> *Reset* (or *Action* ->
      *Clear* if you don't have the latest *Docker* application). This removes
      the container while keeping its configuration.
  10. Start the container again by clicking *Action* -> *Start*. **NOTE**:  The
      container may temporarily disappear from the list while it is recreated.

### unRAID

For unRAID users, update a container image with these steps:

  1. Select the *Docker* tab.
  2. Click the *Check for Updates* button at the bottom of the page.
  3. Click the *apply update* link of the container to be updated.

## User/Group IDs

When mapping data volumes (using the `-v` flag of the `docker run` command),
permission issues may arise between the host and the container. Files and
folders in a data volume are owned by a user, which may differ from the user
running the application. Depending on permissions, this could prevent the
container from accessing the shared volume.

To avoid this, specify the user the application should run as using the
`USER_ID` and `GROUP_ID` environment variables.

To find the appropriate IDs, run the following command on the host for the user
owning the data volume:

```shell
id <username>
```

This produces output like:

```
uid=1000(myuser) gid=1000(myuser) groups=1000(myuser),4(adm),24(cdrom),27(sudo),46(plugdev),113(lpadmin)
```

Use the `uid` (user ID) and `gid` (group ID) values to configure the container.

## Accessing the GUI

Assuming that container's ports are mapped to the same host's ports, the
interface of the application can be accessed with a web browser at:

```text
http://<HOST IP ADDR>:8181
```

## Shell Access

To access the shell of a running container, execute the following command:

```shell
docker exec -ti CONTAINER sh
```

Where `CONTAINER` is the ID or the name of the container used during its
creation.

## Default Administrator Account

After a fresh install, use the following credentials to login:
  - Email address: `admin@example.com`
  - Password: `changeme`

After you login with this default user, you will be asked to modify your details
and change your password.

## Accessibility From The Internet

**NOTE:** This section assumes that the container is using the default `bridge`
network type.

For this container to be accessible from the Internet, port forwarding must be
configured on your router.  This allows HTTP (port 80) and HTTPs (port 443)
traffic from the Internet to reach this container on your private network.

Configuration of port forwarding differs from one router to another, but in
general the same information must be configured:
  - **External port**: The Internet-side port to be forwarded.
  - **Internal port**: The port to forward to.  Also called private port.
  - **Destination IP address**: The IP address of the device on the local
    network to forward to.  Also called private IP address.

The IP address to forward to should be the IP address of the host running the
container.  The port to forward to should be the port mapped to the container
during its creation (via the `-p` parameter of the `docker run` command).

Since the container needs to handle both HTTP and HTTPs traffic, two ports need
to be forwarded:

| Traffic type | Container port | Host port mapped to container | External port | Internal port | Internal IP address                           |
|--------------|----------------|-------------------------------|---------------|---------------|-----------------------------------------------|
| HTTP         | 8080           | XXXX                          | 80            | XXXX          | IP address of the host running the container. |
| HTTPs        | 4443           | YYYY                          | 443           | YYYY          | IP address of the host running the container. |

`XXXX` and `YYYY` are configurable port values.  Unless they conflict with other
used ports on the host, they can simply be set to the same value as the
container port.

**NOTE**: Some routers don't offer the ability to configure the internal port
to forward to.  This means that internal port is the same as the external one.
In a such scenario, `XXXX` must be set to `80` and `YYYY` to `443`.

For more details about port forwarding, see the following links:
  - [How to Port Forward - General Guide to Multiple Router Brands](https://www.noip.com/support/knowledgebase/general-port-forwarding-guide/)
  - [How to Forward Ports on Your Router](https://www.howtogeek.com/66214/how-to-forward-ports-on-your-router/)

## Troubleshooting

### Password Reset

The password of a user can be reset to `changeme` with the following command:

```
docker exec CONTAINER_NAME /opt/nginx-proxy-manager/bin/reset-password USER_EMAIL
```

Where:

  - `CONTAINER_NAME` is the name of the running container.
  - `USER_EMAIL` is the email of the address to reset the password.

## Support or Contact

Having troubles with the container or have questions? Please
[create a new issue](https://github.com/jlesage/docker-nginx-proxy-manager/issues).

For other Dockerized applications, visit https://jlesage.github.io/docker-apps.
