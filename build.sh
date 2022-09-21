#!/usr/bin/env bash

# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing,
#   software distributed under the License is distributed on an
#   "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
#   KIND, either express or implied.  See the License for the
#   specific language governing permissions and limitations
#   under the License.

# This is the master shell script to build Docker containers
# for CouchDB 2.x.

# stop on error
set -e

# This works if we're not called through a symlink
# otherwise, see https://stackoverflow.com/questions/59895/
SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#
# NOTE!
#
# Defaults for these are now set in each Dockerfile, since some
# platform/default combinations don't work. If you are looking
# to upgrade the Erlang or Node or Elixir version across many
# platforms, go to dockerfiles/* and update all the files
# there...but be aware Erlang packages may be missing on
# some platforms!

# References:
#    https://wiki.debian.org/LTS
#    https://ubuntu.com/about/release-cycle
#    https://access.redhat.com/support/policy/updates/errata/ (same for CentOS)
#    also https://endoflife.software/operating-systems/linux/centos
DEBIANS="debian-buster debian-bullseye"
UBUNTUS="ubuntu-bionic ubuntu-focal ubuntu-jammy"
CENTOSES="centos-7 rockylinux-8"
ERLANGALL_BASE="debian-bullseye"
XPLAT_BASE="debian-bullseye"
XPLAT_ARCHES="arm64v8 ppc64le"
PASSED_BUILDARGS="$buildargs"

BUILDX_PLATFORMS="linux/amd64,linux/arm64,linux/ppc64le"

check-envs() {
  buildargs=$PASSED_BUILDARGS
  if [ ! -z "${NODEVERSION}" ]
  then
    buildargs="$buildargs --build-arg nodeversion=${NODEVERSION} "
  fi
  if [ ! -z "${ERLANGVERSION}" ]
  then
    buildargs="$buildargs --build-arg erlangversion=${ERLANGVERSION} "
  fi
  if [ ! -z "${ELIXIRVERSION}" ]
  then
    buildargs="$buildargs --build-arg elixirversion=${ELIXIRVERSION} "
  fi
  if [ ! -z "${CONTAINERARCH}" ]
  then
    buildargs="$buildargs --build-arg repository=${CONTAINERARCH}/debian "
    CONTAINERARCH="${CONTAINERARCH}-"
  fi
}

split-os-ver() {
  OLDIFS=$IFS
  IFS='-' tokens=( $1 )
  IFS=$OLDIFS
  os=${tokens[0]}
  version=${tokens[1]}
}

build-base-platform() {
  check-envs
  split-os-ver $1
  # invoke as build-base <plat>
  # base images never get JavaScript, nor Erlang
  docker build -f dockerfiles/${os}-${version} \
      --build-arg js=nojs \
      --build-arg erlang=noerlang \
      $buildargs \
      --tag apache/couchdbci-${os}:${CONTAINERARCH}${version}-base \
      ${SCRIPTPATH}
}

buildx-base-platform() {
  check-envs
  split-os-ver $1
  # invoke as build-base <plat>
  # base images never get JavaScript, nor Erlang
  if [ "$os" == "rockylinux" ]; then
    repo="centos"
  else
    repo="$os"
  fi
  docker buildx build -f dockerfiles/${os}-${version} \
      --build-arg js=nojs \
      --build-arg erlang=noerlang \
      $buildargs \
      --platform ${BUILDX_PLATFORMS} \
      --tag apache/couchdbci-${repo}:${version}-base \
      --push \
      ${SCRIPTPATH}
}

upload-base() {
  if [[ ! ${DOCKER_ID_USER} ]]; then
    echo "Please set your Docker credentials before using this command:"
    echo "  export DOCKER_ID_USER=<username>"
    echo "  docker login"
    exit 1
  fi
  docker push couchdbdev/$1-base
}

find-erlang-version() {
  if [ -z "${ERLANGVERSION}" ]
  then
    ERLANGVERSION="$(grep "ARG erlangversion" dockerfiles/$1 | cut -d = -f 2)"
  fi
}

pull-os-image() {
  image_name=$(echo $1 | tr "-" ":")
  docker pull $image_name
}

build-platform() {
  check-envs
  find-erlang-version $1
  pull-os-image $1
  split-os-ver $1
  docker build -f dockerfiles/${os}-${version} \
      $buildargs \
      --no-cache \
      --tag apache/couchdbci-${os}:${CONTAINERARCH}${version}-erlang-${ERLANGVERSION} \
      ${SCRIPTPATH}
  unset ERLANGVERSION
}

buildx-platform() {
  check-envs
  find-erlang-version $1
  pull-os-image $1
  split-os-ver $1
  if [ "$os" == "rockylinux" ]; then
    repo="centos"
  else
    repo="$os"
  fi
  docker buildx build -f dockerfiles/${os}-${version} \
      $buildargs \
      --no-cache \
      --platform ${BUILDX_PLATFORMS} \
      --tag apache/couchdbci-${repo}:${version}-erlang-${ERLANGVERSION} \
      --push \
      ${SCRIPTPATH}
  unset ERLANGVERSION
}

clean() {
  check-envs
  split-os-ver $1
  docker rmi apache/couchdbci-${os} -f || true
}

upload-platform() {
  if [[ ! ${DOCKER_ID_USER} ]]; then
    echo "Please set your Docker credentials before using this command:"
    echo "  export DOCKER_ID_USER=<username>"
    echo "  docker login"
    exit 1
  fi
  find-erlang-version $1
  check-envs
  split-os-ver $1
  docker push apache/couchdbci-${os}:${CONTAINERARCH}${version}-erlang-${ERLANGVERSION}
}

build-test-couch() {
  find-erlang-version $1
  docker run \
      --mount type=bind,src=${SCRIPTPATH},dst=/home/jenkins/couchdb-ci \
      couchdbdev/$1-erlang-${ERLANGVERSION} \
      /home/jenkins/couchdb-ci/bin/build-test-couchdb.sh $2
}


# #######################

case "$1" in
  clean)
    # removes image for a given target platform
    shift
    clean $1
    ;;
  clean-all)
    # removes all known target platform images
    # docker rmi apache/couchdbci-ubuntu should remove all tags under that...
    for plat in $DEBIANS $UBUNTUS $CENTOSES; do
      clean $plat
    done
    ;;
  buildx-base)
    # Build and upload multi-arch base image using Docker Buildx
    shift
    buildx-base-platform $1
    ;;
  base)
    # Build base image for requested target platform
    shift
    build-base-platform $1
    ;;
  base-all)
    # build all base images
    shift
    for plat in $DEBIANS $UBUNTUS $CENTOSES; do
      build-base-platform $plat $*
    done
    ;;
  base-upload)
    shift
    upload-base $plat $*
    ;;
  base-upload-all)
    shift
    for plat in $DEBIANS $UBUNTUS $CENTOSES; do
      upload-base $plat $*
    done
    ;;
  buildx-platform)
    # Build and upload multi-arch platform with JS and Erlang support
    shift
    buildx-platform $1
    ;;
  platform)
    # build platform with JS and Erlang support
    shift
    build-platform $1
    ;;
  platform-foreign)
    # makes only foreign arch platforms
    shift
    for arch in $XPLAT_ARCHES; do
      CONTAINERARCH=$arch build-platform $XPLAT_BASE
    done
    ;;
  platform-all)
    # build all platforms with JS and Erlang support
    shift
    for plat in $DEBIANS $UBUNTUS $CENTOSES; do
      build-platform $plat $*
    done
    for arch in $XPLAT_ARCHES; do
      CONTAINERARCH=$arch build-platform $XPLAT_BASE
    done
    ERLANGVERSION=all build-platform $ERLANGALL_BASE
    ;;
  platform-upload)
    shift
    upload-platform $plat $*
    ;;
  platform-upload-all)
    shift
    for plat in $DEBIANS $UBUNTUS $CENTOSES; do
      upload-platform $plat $*
    done
    for arch in $XPLAT_ARCHES; do
      CONTAINERARCH=$arch upload-platform $XPLAT_BASE $*
    done
    ERLANGVERSION=all upload-platform $ERLANGALL_BASE
    ;;
  couch)
    # build and test CouchDB on <plat>
    # TODO: check if img exists/pull first
    shift
    build-test-couch $*
    ;;
  couch-all)
    # build and test CouchDB on all platforms
    shift
    for plat in $DEBIANS $UBUNTUS $CENTOSES; do
      build-test-couch $plat $*
    done
    ;;
  *)
    if [[ $1 ]]; then
      echo "Unknown target $1."
      echo
    fi
    cat << EOF
$0 <command> [OPTIONS]

Recognized commands:
  clean <plat>              Removes all images for <plat>.
  clean-all                 Removes all images for all platforms.

  *buildx-base <plat>       Builds a multi-architecture base image.
  *buildx-platform <plat>   Builds a multi-architecture image with Erlang & JS support.

  base <plat>               Builds the image for <plat> without Erlang or JS support.
  base-all                  Builds all images without Erlang or JS support.
  *base-upload <plat>       Uploads the apache/couchdbci-{os} base images to Docker Hub.
  *base-upload-all          Uploads all the apache/couchdbci base images to Docker Hub.

  platform <plat>           Builds the image for <plat> with Erlang & JS support.
  platform-all              Builds all images with Erlang and JS support.
  *platform-upload <plat>   Uploads the apache/couchdbci-{os} images to Docker Hub.
  *platform-upload-all      Uploads all the apache/couchdbci images to Docker Hub.

  couch <plat>              Builds and tests CouchDB for <plat>.
  couch-all                 Builds and tests CouchDB on all platforms.

  Commands marked with * require appropriate Docker Hub credentials.

EOF
    if [[ $1 ]]; then
      exit 1
    fi
    ;;
esac

exit 0
