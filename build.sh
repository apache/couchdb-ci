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

# TODO: support overriding these as env vars
# Node 8 as of 2018-05-08
NODEVERSION=${NODEVERSION:-8}
# Erlang 19.3.6 as of 2018-05-08
ERLANGVERSION=${ERLANGVERSION:-19.3.6}
# Elixir v1.6.6 as of 2018-07-25
ELIXIRVERSION=${ELIXIRVERSION:-v1.6.6}

DEBIANS="debian-jessie debian-stretch"
UBUNTUS="ubuntu-trusty ubuntu-xenial ubuntu-bionic"
debs="(debian-jessie|debian-stretch|ubuntu-trusty|ubuntu-xenial|ubuntu-bionic)"

CENTOSES="centos-6 centos-7"
rpms="(centos-6|centos-7)"

BINTRAY_API="https://api.bintray.com"


build-base-platform() {
  # invoke as build-base <plat>
  # base images never get JavaScript, nor Erlang
  docker build -f dockerfiles/$1 \
      --build-arg js=nojs \
      --build-arg erlang=noerlang \
      --build-arg nodeversion=${NODEVERSION} \
      --build-arg erlangversion=${ERLANGVERSION} \
      --tag couchdbdev/$1-base \
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

build-platform() {
  docker build -f dockerfiles/$1 \
      --build-arg nodeversion=${NODEVERSION} \
      --build-arg erlangversion=${ERLANGVERSION} \
      --build-arg elixirversion=${ELIXIRVERSION} \
      --tag couchdbdev/$1-erlang-${ERLANGVERSION} \
      ${SCRIPTPATH}
}

clean() {
  docker rmi couchdbdev/$1 -f || true
}

clean-all() {
  for plat in $DEBIANS $UBUNTUS $CENTOSES; do
    clean $plat-erlang-${ERLANGVERSION}
    clean ubuntu-trusty-erlang-default
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
  docker push couchdbdev/$1-erlang-${ERLANGVERSION}
}

build-test-couch() {
  docker run \
      --mount type=bind,src=${SCRIPTPATH},dst=/home/jenkins/couchdb-ci \
      couchdbdev/$1-erlang-${ERLANGVERSION} \
      /home/jenkins/couchdb-ci/bin/build-test-couchdb.sh $2
}


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
