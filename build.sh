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

DEBIANS="debian-stretch debian-buster"
UBUNTUS="ubuntu-xenial ubuntu-bionic ubuntu-focal"
CENTOSES="centos-6 centos-7 centos-8"
ERLANGALL_BASE="debian-buster"
XPLAT_BASE="debian-buster"
XPLAT_ARCHES="arm64v8 ppc64le"
BINTRAY_API="https://api.bintray.com"


check-envs() {
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
    buildargs="$buildargs --build-arg containerarch=${CONTAINERARCH} "
    CONTAINERARCH="${CONTAINERARCH}-"
  fi
}

build-base-platform() {
  # invoke as build-base <plat>
  # base images never get JavaScript, nor Erlang
  docker build -f dockerfiles/$1 \
      --build-arg js=nojs \
      --build-arg erlang=noerlang \
      $buildargs \
      --tag couchdbdev/${CONTAINERARCH}$1-base \
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
  find-erlang-version $1
  pull-os-image $1
  docker build -f dockerfiles/$1 \
      $buildargs \
      --no-cache \
      --tag couchdbdev/${CONTAINERARCH}$1-erlang-${ERLANGVERSION} \
      ${SCRIPTPATH}
}

clean() {
  docker rmi couchdbdev/$1 -f || true
}

clean-all() {
  for plat in $DEBIANS $UBUNTUS $CENTOSES; do
    find-erlang-version $plat
    clean $plat-erlang-${ERLANGVERSION}
    clean $plat-base
  done
}

upload-platform() {
  if [[ ! ${DOCKER_ID_USER} ]]; then
    echo "Please set your Docker credentials before using this command:"
    echo "  export DOCKER_ID_USER=<username>"
    echo "  docker login"
    exit 1
  fi
  find-erlang-version $1
  docker push couchdbdev/$1-erlang-${ERLANGVERSION}
}

build-test-couch() {
  find-erlang-version $1
  docker run \
      --mount type=bind,src=${SCRIPTPATH},dst=/home/jenkins/couchdb-ci \
      couchdbdev/$1-erlang-${ERLANGVERSION} \
      /home/jenkins/couchdb-ci/bin/build-test-couchdb.sh $2
}


# #######################

check-envs

case "$1" in
  clean)
    # removes image for a given target platform
    shift
    clean $1
    ;;
  clean-all)
    # removes all known target platform images
    clean-all
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
  platform)
    # build platform with JS and Erlang support
    shift
    build-platform $1
    ;;
  platform-all)
    # build all platforms with JS and Erlang support
    shift
    for plat in $DEBIANS $UBUNTUS $CENTOSES; do
      build-platform $plat $*
    done
    ERLANGVERSION=all build-platform $ERLANGALL_BASE
    for arch in $XPLAT_ARCHES; do
      CONTAINERARCH="$arch-" build-platform $XPLAT_BASE
    done
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
      upload-platform $arch-$XPLAT_BASE $*
    done
    ERLANGVERSION=all upload-platform debian-buster
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

EOF
    if [[ $1 ]]; then
      exit 1
    fi
    ;;
esac

exit 0
