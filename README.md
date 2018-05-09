# CouchDB Continuous Integration (CI) support repo

The main purpose of this repository is to provide a number of Docker containers, Ansible roles/tasks and other configuration functionality so that the ASF Jenkins CI server (https://builds.apache.org/) is capable of building (and eventually packaging) CouchDB for a number of platforms. It intends to cover a range of both operating systems (Linux, macOS, BSD, Windows) and Erlang versions (OS default, 18.x, 19.x, etc.)

The current configuration builds CouchDB, Fauxton, its documentation, and runs the Erlang and JS test suites for each combination of OS and Erlang revision.

# Supported Configurations (updated 2018-05-19)

**OS / distro** | **Version** | **Erlang Version**
----------------|-------------|-----------------------
**ubuntu**      | trusty      | R16B03 (tag: default)
**ubuntu**      | trusty      | 19.3.6
**ubuntu**      | xenial      | 19.3.6
**ubuntu**      | bionic      | 19.3.6
**debian**      | jessie      | 19.3.6
**debian**      | stretch     | 19.3.6
**centos**      | 6           | 19.3.6
**centos**      | 7           | 19.3.6

CouchDB's CI build philosophy is to use Travis (with `kerl`) to validate CouchDB against different Erlang versions, and to use Jenkins to validate CouchDB against different OSes and architectures. Where possible, Jenkins also auto-builds convenience binaries or packages.

---

# Docker

For those OSes that support Docker, we run builds inside of Docker containers. These containers are built using the `build.sh` command at the root level.

Separate targets exist to build a compatible SpiderMonkey 1.8.5 package for each Linux target release.

## Building a container

```
./build.sh platform <distro>-<version>
```

Valid `distro` and `version` values come from the table above.

## Building the special Ubuntu Trusty default Erlang image

```
ERLANGVERSION=default ./build.sh platform ubuntu-trusty
```

## Publishing a container

1.  You need a Docker Cloud account with access to the `couchdbdev` organization. Ask the CouchDB PMC for assistance with this.
2. `export DOCKER_ID_USER="username"`
3. `docker login` and enter your password.
4. `./build.sh publish <distro>-<version>` just as above.

---

# Useful things you can do

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

The Linux docker containers are also used to build suitable SpiderMonkey 1.8.5 binary packages.

```
./build.sh js <distro>-<version>
```

To build packages for all supported platforms:

```
./build.sh js-all
```

## Adding support for a new release/platform

1. Copy and customize an appropriate Dockerfile in the `dockerfiles` directory.
1. Build a base image using `./build.sh base <distro>-<version>`. Solve any problems with the build process here.
1. Build the JS packages using `./build.sh js <distro>-<version>`. Again, fix any problems that arise.
1. Publish the new JS packages with `./build.sh js-upload <distro>-<version>`.
1. Build the full platform image with `./build.sh platform <distro>-<version>`.
1. Publish the new image with `./build.sh platform-upload <distro>-<version>`.
1. Be sure to add the new platform to Apache CouchDB's `Jenkinsfile`.
1. Push any changes to this repo, or to `couchdb-pkg`, out for review and merging.

---

# Other platforms

We are eager for contributions to enhance the build scripts to support setting up machines with the necessary build environment for:

* FreeBSD
* NetBSD
* OpenBSD
* macOS
* Windows x64

as well as alternative architectures for the already supported image types (arm, ppc64le, s390x, sparc, etc).

We know that Docker won't support most of these, but we should be able to at least expand the install scripts for all of these platforms (save Win x64).

# Background 

See: 
* this [thread](https://www.mail-archive.com/dev%40couchdb.apache.org/msg43591.html) on the couchdb-dev mailing list and
* this [ASF Infra ticket](https://issues.apache.org/jira/browse/INFRA-10126).
for the origins of this work.

