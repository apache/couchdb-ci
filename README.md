# CouchDB Continuous Integration (CI) support repo

The main purpose of this repository is to provide scripts that:

* Install the necessary build-time dependencies for CouchDB on a number of platforms, either inside or outside of a container or VM
* Build Docker containers with those dependencies necessary to build binary JavaScript (SpiderMonkey 1.8.5) packages
* Build Docker containers with all dependencies necessary to build CouchDB, including Erlang and JavaScript

It intends to cover a range of both operating systems (Linux, macOS, BSD, Windows) and Erlang versions (17.x, 18.x, 19.x, etc.)

These images are used by [Apache Jenkins CI](https://builds.apache.org/blue/organizations/jenkins/CouchDB/branches/) to build CouchDB with every checkin to `master` or a release branch (*e.g.*, `2.3.0`).

CouchDB's CI build philosophy is to use Travis (with `kerl`) to validate CouchDB against different Erlang versions, and to use Jenkins to validate CouchDB against different OSes and architectures. Where possible, Jenkins also auto-builds convenience binaries or packages. The eventual goal is that these auto-built binaries/packages/Docker images will be auto-pushed to our distribution repos for downstream consumption.

# Supported Configurations (updated 2019-10-08)

**OS / distro** | **Version** | **Erlang Versions** | **Architectures** | **Docker?**
----------------|-------------|--------------------|------------------|--------------------
**debian**      | stretch     | 19.3.6, 20.3.8.22  | `x86_64`, `arm64v8`, `ppc64le`         | :heavy_check_mark:
**debian**      | buster      | 20.3.8.22          | `x86_64`, `arm64v8`                    | :heavy_check_mark:
**ubuntu**      | xenial      | 20.3.8.22          | `x86_64`         | :heavy_check_mark:
**ubuntu**      | bionic      | 20.3.8.22          | `x86_64`         | :heavy_check_mark:
**centos**      | 6           | 20.3.8.22          | `x86_64`         | :heavy_check_mark:
**centos**      | 7           | 20.3.8.22          | `x86_64`         | :heavy_check_mark:
**centos**      | 8           | 20.3.8.22          | `x86_64`         | :heavy_check_mark:
**freebsd**     | 11.x        | *default*          | `x86_64`         | :x:
**freebsd**     | 12.0        | *default*          | `x86_64`         | :x:

...with support now for _any_ arbitrary Erlang version!

---

# Docker

For those OSes that support Docker, we run builds inside of Docker containers. These containers are built using the `build.sh` command at the root level.

## Building a "base image"

The base images include all of the build dependencies necessary to build CouchDB **except** for Erlang and SpiderMonkey 1.8.5. These images are typically used to build the CouchDB SpiderMonkey 1.8.5 binaries for a given OS/version/architecture combination.

Build a base image with:

```
./build.sh base <distro>-<version>
```

## Building a "platform image"

The platform images include all of the build dependencies necessary to build and full test CouchDB on a given OS/version/architecture combination.

Build a platform image with:

```
./build.sh platform <distro>-<version>
```

## Overriding the Erlang, Elixir or Node version

We want to generate a `rebar` binary compatible with all versions of Erlang we support. If we do this on too new a version, older Erlangs won't recognize it. So we always keep an image around with that version.

On the other hand, some OSes won't run older Erlangs because of library changes, so you need to override that environment variable.

Just specify on the command line any of the `ERLANGVERSION`, `NODEVERSION`, or `ELIXIRVERSION` environment variables:

```
NODEVERSION=8 ELIXIRVERSION=v1.6.1 ERLANGVERSION=17.5.3 ./build.sh platform debian-jessie
```

# Building a cross-architecture Docker image

This only works from an `x86_64` build host.

First, configure your machine with the correct dependencies to build multi-arch binaries:

```
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes --credential yes
```

This is a one-time setup step. The `multiarch/qemu-user-static` docker container run will install the correct qemu static binaries necessary for running foreign architecture binaries on your host machine. It includes special magic to ensure `sudo` works correctly inside a container, too.

Then, override the `CONTAINERARCH` environment variable when starting `build.sh`:


```
CONTAINERARCH=aarch64 ./build.sh platform debian-stretch
```

## Publishing a container

1.  You need a Docker Cloud account with access to the `couchdbdev` organization. Ask the CouchDB PMC for assistance with this.
2. `export DOCKER_ID_USER="username"`
3. `docker login` and enter your password.
4. `./build.sh platform-upload <distro>-<version>` just as above.

---

# Useful things you can do

## Full `build.sh` options

```
./build.sh <command> [OPTIONS]

Recognized commands:
  clean <plat>          Removes all images for <plat>.
  clean-all             Removes all images for all platforms & base images.

  base <plat>           Builds the base (no JS/Erlang) image for <plat>.
  base-all              Builds all base (no JS/Erlang) images.
  *base-upload          Uploads the specified couchdbdev/*-base image
                        to Docker Hub.
  *base-upload-all      Uploads all the couchdbdev/*-base images.

  platform <plat>       Builds the image for <plat> with Erlang & JS support.
  platform-all          Builds all images with Erlang and JS support.
  *platform-upload      Uploads the couchdbdev/*-erlang-* images to Docker Hub.
  *platform-upload-all  Uploads all the couchdbdev/*-erlang-* images to Docker.

  couch <plat>          Builds and tests CouchDB for <plat>.
  couch-all             Builds and tests CouchDB on all platforms.

  Commands marked with * require appropriate Docker Hub credentials.
```

## Interactively working in a built container

After building the image as above:

```
docker run -it couchdbdev/<tag>
```

where `<tag>` is of the format `<distro>-<version>-<type>`, such as `debian-stretch-erlang-19.3.6`.

## Running the CouchDB build in a published container

```
./build.sh couch <distro>-<version>
```

## Building SpiderMonkey 1.8.5 convenience packages

After building the base image as above, head over to the [apache/couchdb-pkg](https://github.com/apache/couchdb-pkg) repository and follow the instructions there.

## Adding support for a new release/platform/architecture

1. Update the build scripts in the `bin/` directory to install the dependencies correctly on your new OS/version/platform. Push a PR with these changes.
1. Copy and customize an appropriate Dockerfile in the `dockerfiles` directory for your new OS.
1. Build a base image using `./build.sh base <distro>-<version>`. Solve any problems with the build process here. Add your new platform combination to the `.travis.yml` file, then push a PR with these changes.
1. Using the [apache/couchdb-pkg](https://github.com/apache/couchdb-pkg) repository, validate you can build the JS package. Fix any problems in that repo that arise and raise a new PR. Open a new issue on that PR requesting that the JS packages be made available through the CouchDB repository/download infrastructure.
1. Build a full platform image with `./build.sh platform <distro>-<version>`. Solve any problems with the build process here. Add your new platform combination to the `.travis.yml` file, then push a PR with these changes.
1. Submit a PR against the [apache/couchdb](https://github.com/apache/couchdb) repository, adding the new platform to the top level `Jenkinsfile`. Ask if you need help.

---

# Other platforms

We are eager for contributions to enhance the build scripts to support setting up machines with the necessary build environment for:

* NetBSD
* OpenBSD
* macOS
* Windows x64 (see [apache/couchdb-glazier](https://github.com/apache/couchdb-glazier]) for the current approach)

as well as alternative architectures for the already supported image types (arm, ppc64le, s390x, sparc, etc).

We know that Docker won't support some of these, but we should be able to at least expand the install scripts for all of these platforms.

# Background 

See: 
* this [thread](https://www.mail-archive.com/dev%40couchdb.apache.org/msg43591.html) on the couchdb-dev mailing list and
* this [ASF Infra ticket](https://issues.apache.org/jira/browse/INFRA-10126).
for the origins of this work.
