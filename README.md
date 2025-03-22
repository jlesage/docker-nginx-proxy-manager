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

This project implements a Docker container for [Nginx Proxy Manager](https://nginxproxymanager.com).



---

[![Nginx Proxy Manager logo](https://images.weserv.nl/?url=raw.githubusercontent.com/jlesage/docker-templates/master/jlesage/images/nginx-proxy-manager-icon.png&w=110)](https://nginxproxymanager.com)[![Nginx Proxy Manager](https://images.placeholders.dev/?width=608&height=110&fontFamily=monospace&fontWeight=400&fontSize=52&text=Nginx%20Proxy%20Manager&bgColor=rgba(0,0,0,0.0)&textColor=rgba(121,121,121,1))](https://nginxproxymanager.com)

Nginx Proxy Manager enables you to easily forward to your websites running at
home or otherwise, including free SSL, without having to know too much about
Nginx or Letsencrypt.

---

## Table of Content

   * [Quick Start](#quick-start)
   * [Usage](#usage)
      * [Environment Variables](#environment-variables)
         * [Deployment Considerations](#deployment-considerations)
      * [Data Volumes](#data-volumes)
      * [Ports](#ports)
      * [Changing Parameters of a Running Container](#changing-parameters-of-a-running-container)
   * [Docker Compose File](#docker-compose-file)
   * [Docker Image Versioning](#docker-image-versioning)
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
> The Docker command provided in this quick start is given as an example and
> parameters should be adjusted to your need.

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

  - `/docker/appdata/nginx-proxy-manager`: This is where the application stores its configuration, states, log and any files needing persistency.

Browse to `http://your-host-ip:8181` to access the Nginx Proxy Manager web interface.

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
| -d        | Run the container in the background. If not set, the container runs in the foreground. |
| -e        | Pass an environment variable to the container. See the [Environment Variables](#environment-variables) section for more details. |
| -v        | Set a volume mapping (allows to share a folder/file between the host and the container). See the [Data Volumes](#data-volumes) section for more details. |
| -p        | Set a network port mapping (exposes an internal container port to the host). See the [Ports](#ports) section for more details. |

### Environment Variables

To customize some properties of the container, the following environment
variables can be passed via the `-e` parameter (one for each variable). Value
of this parameter has the format `<VARIABLE_NAME>=<VALUE>`.

| Variable       | Description                                  | Default |
|----------------|----------------------------------------------|---------|
|`USER_ID`| ID of the user the application runs as. See [User/Group IDs](#usergroup-ids) to better understand when this should be set. | `1000` |
|`GROUP_ID`| ID of the group the application runs as. See [User/Group IDs](#usergroup-ids) to better understand when this should be set. | `1000` |
|`SUP_GROUP_IDS`| Comma-separated list of supplementary group IDs of the application. | (no value) |
|`UMASK`| Mask that controls how permissions are set for newly created files and folders. The value of the mask is in octal notation. By default, the default umask value is `0022`, meaning that newly created files and folders are readable by everyone, but only writable by the owner. See the online umask calculator at http://wintelguy.com/umask-calc.pl. | `0022` |
|`LANG`| Set the [locale](https://en.wikipedia.org/wiki/Locale_(computer_software)), which defines the application's language, **if supported**. Format of the locale is `language[_territory][.codeset]`, where language is an [ISO 639 language code](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes), territory is an [ISO 3166 country code](https://en.wikipedia.org/wiki/ISO_3166-1#Current_codes) and codeset is a character set, like `UTF-8`. For example, Australian English using the UTF-8 encoding is `en_AU.UTF-8`. | `en_US.UTF-8` |
|`TZ`| [TimeZone](http://en.wikipedia.org/wiki/List_of_tz_database_time_zones) used by the container. Timezone can also be set by mapping `/etc/localtime` between the host and the container. | `Etc/UTC` |
|`KEEP_APP_RUNNING`| When set to `1`, the application will be automatically restarted when it crashes or terminates. | `0` |
|`APP_NICENESS`| Priority at which the application should run. A niceness value of -20 is the highest priority and 19 is the lowest priority. The default niceness value is 0. **NOTE**: A negative niceness (priority increase) requires additional permissions. In this case, the container should be run with the docker option `--cap-add=SYS_NICE`. | `0` |
|`INSTALL_PACKAGES`| Space-separated list of packages to install during the startup of the container. List of available packages can be found at https://pkgs.alpinelinux.org. **ATTENTION**: Container functionality can be affected when installing a package that overrides existing container files (e.g. binaries). | (no value) |
|`PACKAGES_MIRROR`| Mirror of the repository to use when installing packages. List of mirrors is available at https://mirrors.alpinelinux.org. | (no value) |
|`CONTAINER_DEBUG`| Set to `1` to enable debug logging. | `0` |
|`DISABLE_IPV6`| When set to `1`, IPv6 support is disabled.  This is needed when IPv6 is not enabled/supported on the host. | `0` |

#### Deployment Considerations

Many tools used to manage Docker containers extract environment variables
defined by the Docker image and use them to create/deploy the container. For
example, this is done by:
  - The Docker application on Synology NAS
  - The Container Station on QNAP NAS
  - Portainer
  - etc.

While this can be useful for the user to adjust the value of environment
variables to fit its needs, it can also be confusing and dangerous to keep all
of them.

A good practice is to set/keep only the variables that are needed for the
container to behave as desired in a specific setup. If the value of variable is
kept to its default value, it means that it can be removed. Keep in mind that
all variables are optional, meaning that none of them is required for the
container to start.

Removing environment variables that are not needed provides some advantages:

  - Prevents keeping variables that are no longer used by the container. Over
    time, with image updates, some variables might be removed.
  - Allows the Docker image to change/fix a default value. Again, with image
    updates, the default value of a variable might be changed to fix an issue,
    or to better support a new feature.
  - Prevents changes to a variable that might affect the correct function of
    the container. Some undocumented variables, like `PATH` or `ENV`, are
    required to be exposed, but are not meant to be changed by users. However,
    container management tools still show these variables to users.
  - There is a bug with the Container Station on QNAP and the Docker application
    on Synology, where an environment variable without value might not be
    allowed. This behavior is wrong: it's absolutely fine to have a variable
    without value. In fact, this container does have variables without value by
    default. Thus, removing unneeded variables is a good way to prevent
    deployment issue on these devices.

### Data Volumes

The following table describes data volumes used by the container. The mappings
are set via the `-v` parameter. Each mapping is specified with the following
format: `<HOST_DIR>:<CONTAINER_DIR>[:PERMISSIONS]`.

| Container path  | Permissions | Description |
|-----------------|-------------|-------------|
|`/config`| rw | This is where the application stores its configuration, states, log and any files needing persistency. |

### Ports

Here is the list of ports used by the container.

When using the default bridge network, ports can be mapped to the host via the
`-p` parameter (one per port mapping). Each mapping is defined with the
following format: `<HOST_PORT>:<CONTAINER_PORT>`. The port number used inside
the container might not be changeable, but you are free to use any port on the
host side.

See the [Docker Container Networking](https://docs.docker.com/config/containers/container-networking)
documentation for more details.

| Port | Protocol | Mapping to host | Description |
|------|----------|-----------------|-------------|
| 8181 | TCP | Mandatory | Port used to access the web interface of the application. |
| 8080 | TCP | Mandatory | Port used to serve HTTP requests. |
| 4443 | TCP | Mandatory | Port used to serve HTTPs requests. |

### Changing Parameters of a Running Container

As can be seen, environment variables, volume and port mappings are all specified
while creating the container.

The following steps describe the method used to add, remove or update
parameter(s) of an existing container. The general idea is to destroy and
re-create the container:

  1. Stop the container (if it is running):
```shell
docker stop nginx-proxy-manager
```

  2. Remove the container:
```shell
docker rm nginx-proxy-manager
```

  3. Create/start the container using the `docker run` command, by adjusting
     parameters as needed.

> [!NOTE]
> Since all application's data is saved under the `/config` container folder,
> destroying and re-creating a container is not a problem: nothing is lost and
> the application comes back with the same state (as long as the mapping of the
> `/config` folder remains the same).

## Docker Compose File

Here is an example of a `docker-compose.yml` file that can be used with
[Docker Compose](https://docs.docker.com/compose/overview/).

Make sure to adjust according to your needs. Note that only mandatory network
ports are part of the example.

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

## Docker Image Versioning

Each release of a Docker image is versioned. Prior to october 2022, the
[semantic versioning](https://semver.org) was used as the versioning scheme.

Since then, versioning scheme changed to
[calendar versioning](https://calver.org). The format used is `YY.MM.SEQUENCE`,
where:
  - `YY` is the zero-padded year (relative to year 2000).
  - `MM` is the zero-padded month.
  - `SEQUENCE` is the incremental release number within the month (first release
    is 1, second is 2, etc).

## Docker Image Update

Because features are added, issues are fixed, or simply because a new version
of the containerized application is integrated, the Docker image is regularly
updated. Different methods can be used to update the Docker image.

The system used to run the container may have a built-in way to update
containers. If so, this could be your primary way to update Docker images.

An other way is to have the image be automatically updated with [Watchtower].
Watchtower is a container-based solution for automating Docker image updates.
This is a "set and forget" type of solution: once a new image is available,
Watchtower will seamlessly perform the necessary steps to update the container.

Finally, the Docker image can be manually updated with these steps:

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

  4. Create and start the container using the `docker run` command, with the
the same parameters that were used when it was deployed initially.

[Watchtower]: https://github.com/containrrr/watchtower

### Synology

For owners of a Synology NAS, the following steps can be used to update a
container image.

  1.  Open the *Docker* application.
  2.  Click on *Registry* in the left pane.
  3.  In the search bar, type the name of the container (`jlesage/nginx-proxy-manager`).
  4.  Select the image, click *Download* and then choose the `latest` tag.
  5.  Wait for the download to complete. A notification will appear once done.
  6.  Click on *Container* in the left pane.
  7.  Select your Nginx Proxy Manager container.
  8.  Stop it by clicking *Action*->*Stop*.
  9.  Clear the container by clicking *Action*->*Reset* (or *Action*->*Clear* if
      you don't have the latest *Docker* application). This removes the
      container while keeping its configuration.
  10. Start the container again by clicking *Action*->*Start*. **NOTE**:  The
      container may temporarily disappear from the list while it is re-created.

### unRAID

For unRAID, a container image can be updated by following these steps:

  1. Select the *Docker* tab.
  2. Click the *Check for Updates* button at the bottom of the page.
  3. Click the *update ready* link of the container to be updated.

## User/Group IDs

When using data volumes (`-v` flags), permissions issues can occur between the
host and the container. For example, the user within the container may not
exist on the host. This could prevent the host from properly accessing files
and folders on the shared volume.

To avoid any problem, you can specify the user the application should run as.

This is done by passing the user ID and group ID to the container via the
`USER_ID` and `GROUP_ID` environment variables.

To find the right IDs to use, issue the following command on the host, with the
user owning the data volume on the host:

    id <username>

Which gives an output like this one:
```text
uid=1000(myuser) gid=1000(myuser) groups=1000(myuser),4(adm),24(cdrom),27(sudo),46(plugdev),113(lpadmin)
```

The value of `uid` (user ID) and `gid` (group ID) are the ones that you should
be given the container.

## Accessing the GUI

Assuming that container's ports are mapped to the same host's ports, the
interface of the application can be accessed with a web browser at:

```text
http://<HOST IP ADDR>:8181
```

## Shell Access

To get shell access to the running container, execute the following command:

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

Having troubles with the container or have questions?  Please
[create a new issue].

For other great Dockerized applications, see https://jlesage.github.io/docker-apps.

[create a new issue]: https://github.com/jlesage/docker-nginx-proxy-manager/issues
