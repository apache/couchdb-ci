# CouchDB Continuous Integration (CI) support repo

The main purpose of this repository is to provide scripts that:

* Install the necessary build-time dependencies for CouchDB on a number of platforms, either inside or outside of a container or VM
* Build Docker containers with those dependencies necessary to build binary JavaScript (SpiderMonkey 1.8.5) packages
* Build Docker containers with all dependencies necessary to build CouchDB, including Erlang and JavaScript

It intends to cover a range of both operating systems (Linux, macOS, BSD, Windows) and Erlang versions (17.x, 18.x, 19.x, etc.)

These images are used by [Apache Jenkins CI](https://ci-couchdb.apache.org/blue/organizations/jenkins/pipelines) to build CouchDB with every checkin to `main`, `3.x`, a release branch (*e.g.*, `2.3.0`), or an open Pull Request. CouchDB's CI build philosophy is to validate CouchDB against different Erlang versions with each commit to a Pull Request, and to validate CouchDB against different OSes and architectures on merged commits to `main`, `3.x`, and release branches. Where possible, Jenkins also auto-builds convenience binaries or packages. The eventual goal is that these auto-built binaries/packages/Docker images will be auto-pushed to our distribution repos for downstream consumption.

# Supported Configurations

See Docker Hub for the latest supported images:

- https://hub.docker.com/r/apache/couchdbci-debian/tags
- https://hub.docker.com/r/apache/couchdbci-ubuntu/tags
- https://hub.docker.com/r/apache/couchdbci-centos/tags

---

# Docker

For those OSes that support Docker, we run builds inside of Docker containers. These containers are built using the `build.sh` command at the root level.

## Authenticating to Docker Hub

1.  You need a Docker Cloud account with access to the `apache` organization to upload images. Ask the CouchDB PMC for assistance with this.
2. `export DOCKER_ID_USER="username"`
3. `docker login -u $username` and enter your password. (If using `podman` specify the registry `docker login -u $username docker.io`)

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
NODEVERSION=20 ELIXIRVERSION=v1.18.4 ERLANGVERSION=26.2.5.17 ./build.sh platform debian-bookworm
```

## Building images for other architectures

### Multi-arch images with Docker Buildx

Use Docker's
[Buildx](https://docs.docker.com/buildx/working-with-buildx/) plugin to generate
multi-architecture container images with a single command invocation.

Multi-arch images can be built locally, with archtectures emulated
with qemu, or using remote workers, if we have ssh acccess to hosts
running on each of the supported architectures. Aside from the initial
setup the rest of the commands are exactly the same.

##### Local setup

```
docker buildx create --name apache-couchdb --use
```

##### Remote setup

This requires your ssh key to be installed on the remote workers. See
the `couchdb-infra-cm` repo for the list of current keys.

To use shorter names for the servers can include the `ssh.cfg` file
from `couchdb-infra-cm` in your `ssh_config`.

Ensure ssh connection to each build server works. There maybe be a
different user for each one (root, ubuntu, linux1, etc), the `ssh.cfg`
file, if you're using that already handles that transparently.

If the user is not root, ensure the user can run `docker ps`. For instance:
```
sudo usermod -aG docker linux1
```

Test that `docker ps` run for each server:

```
ssh linux1 docker ps
ssh ubuntu-nc-arm64-12 docker ps
ssh ubuntu docker ps
ssh ubuntu-fra1-10 docker ps
```

Setup the `multiarch` xbuild context:

```
docker buildx rm multiarch  || true
docker buildx create --name multiarch --driver docker-container --platform linux/arm64 ssh://ubuntu-nc-arm64-12
docker buildx create --append --name multiarch --driver docker-container --platform linux/amd64 ssh://ubuntu-fra1-10
docker buildx create --append --name multiarch --driver docker-container --platform linux/s390x ssh://linux1
docker buildx create --append --name multiarch --driver docker-container --platform linux/ppc64le ssh://ubuntu
```

Before building, set `docker buildx` to `use` the new context as the new default.
When done, set to `default`, or whatever it was before:

```
docker buildx use multiarch
```

#### Building

The `build.sh` script has `buildx-base` and `buildx-platform` targets that will
will build **and upload** a new multi-arch container image to the registry. For
example:

```
./build.sh buildx-platform debian-bookworm
```

The `$BUILDX_PLATFORMS` environment variable can be used to override the default
set of target platforms that will be supplied to the buildx builder.

# Useful things you can do

## Update images used for package releases with new Erlang versions

```
ERLANGVERSION=27.3.3./build.sh buildx-platform-release
```

This will build all the Debian and RHEL-clone OS images on x86-64 with that version of Erlang

## Update images used for CI with new Erlang versions

```
ERLANGVERSION=24.3.4.7 ./build.sh buildx-platform debian-bookworm
```

This will update Debian Bullseye OS image for all architectures (x86,
ppc64le, arm64) with that version of Erlang. Do this for the images
which are used with non-x86 architectures.

If the same image is used for release package building and CI, run
this command after `buildx-platform-release` to ensure that the
debian-bullseye will be a rebuilt as a multi-arch image. Otherwise,
buildx-platform-release creates as x86 only.

## Update Debian Bullseye image with 25.2

```
BUILDX_PLATFORMS=linux/amd64 ERLANGVERSION=25.2 ./build.sh buildx-platform debian-bookworm
```

In this case, since we're not using 25.2 for multi-arch testing, opt to build it only for x86.

## Full `build.sh` options

```
./build.sh <command> [OPTIONS]

Recognized commands:
  clean <plat>              Removes all images for <plat>.
  clean-all                 Removes all images for all platforms.

  *buildx-platform <plat>   Builds a multi-architecture image with Erlang & JS support.
  *buildx-platform-release <plat> Builds x86-64 images with default Erlang for all supported release OSes

  couch <plat>              Builds and tests CouchDB for <plat>.
  couch-all                 Builds and tests CouchDB on all platforms.

  Commands marked with * require appropriate Docker Hub credentials.
```

## Interactively working in a built container

After building the image as above:

```
docker run -it couchdbdev/<tag>
```

where `<tag>` is of the format `<distro>-<version>-<type>`, such as `debian-bookworm-erlang-26.2.5.17`.

## Running the CouchDB build in a published container

```
./build.sh couch <distro>-<version>
```

## Building SpiderMonkey 1.8.5 convenience packages

This is only needed if a platform does not have a supported SpiderMonkey library. As of April 2021, this is no currently supported platform.

First, build the 'base' image with:

```
./build.sh base <distro>-<version>
```

After building the base image as above, head over to the [apache/couchdb-pkg](https://github.com/apache/couchdb-pkg) repository and follow the instructions there.

## Adding support for a new release/platform/architecture

1. Update the build scripts in the `bin/` directory to install the dependencies correctly on your new OS/version/platform. Push a PR with these changes.
1. Copy and customize an appropriate Dockerfile in the `dockerfiles` directory for your new OS.
1. If a supported SpiderMonkey library is not available on the target platform, build a base image using `./build.sh base <distro>-<version>`. Solve any problems with the build process here.
1. Using the [apache/couchdb-pkg](https://github.com/apache/couchdb-pkg) repository, validate you can build the JS package. Fix any problems in that repo that arise and raise a new PR. Open a new issue on that PR requesting that the JS packages be made available through the CouchDB repository/download infrastructure.
1. Build a full platform image with `./build.sh platform <distro>-<version>`. Solve any problems with the build process here.
1. Submit a PR against the [apache/couchdb](https://github.com/apache/couchdb) repository, adding the new platform to the top level `Jenkinsfile`. Ask if you need help.

---

# Other platforms

We are eager for contributions to enhance the build scripts to support setting up machines with the necessary build environment for:

* NetBSD
* OpenBSD
* macOS
* Windows x64 (see [apache/couchdb-glazier](https://github.com/apache/couchdb-glazier]) for the current approach)

as well as alternative architectures for the already supported image types (armhf, ppc64le, s390x, sparc, etc).

We know that Docker won't support some of these, but we should be able to at least expand the install scripts for all of these platforms.

# Background 

See: 
* this [thread](https://www.mail-archive.com/dev%40couchdb.apache.org/msg43591.html) on the couchdb-dev mailing list and
* this [ASF Infra ticket](https://issues.apache.org/jira/browse/INFRA-10126).
for the origins of this work.
