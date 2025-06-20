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

# When updating the images, consider updating pull-all-couchdbdev-docker
# script as well
#
DEBIANS="debian-bullseye debian-bookworm"
UBUNTUS="ubuntu-jammy ubuntu-noble"
CENTOSES="almalinux-8 almalinux-9"

PASSED_BUILDARGS="$buildargs"

#  Allow overriding this list from the command line
#  BUILDX_PLATFORMS=foo,bar ./build.sh ...
#
: "${BUILDX_PLATFORMS:=linux/amd64,linux/arm64,linux/ppc64le,linux/s390x}"

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

set-platforms() {
   if [ "$1" == "debian-bullseye" ]; then
       # Debian LTSs apparently start dropping random arches with time
       echo "!!! reducing list of arches for $1 !!!"
       actual_buildx_platforms="linux/amd64,linux/arm64"
   else
       actual_buildx_platforms=${BUILDX_PLATFORMS}
   fi
}

buildx-platform() {
  check-envs
  find-erlang-version $1
  pull-os-image $1
  split-os-ver $1
  if [ "$os" == "almalinux" ]; then
    repo="centos"
  else
    repo="$os"
  fi
  set-platforms $1
  docker buildx build -f dockerfiles/${os}-${version} \
      $buildargs \
      --no-cache \
      --platform ${actual_buildx_platforms} \
      --tag apache/couchdbci-${repo}:${version}-erlang-${ERLANGVERSION} \
      --push \
      ${SCRIPTPATH}
}

clean() {
  check-envs
  split-os-ver $1
  docker rmi apache/couchdbci-${os} -f || true
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
  buildx-platform)
    # Build and upload multi-arch platform with JS and Erlang support
    shift
    buildx-platform $1
    ;;
  buildx-platform-release)
    # Build and upload multi-arch platform with JS and Erlang support
    # For all platforms
    shift
    for plat in $DEBIANS $UBUNTUS $CENTOSES; do
        buildx-platform $plat
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
  clean <plat>              Removes all images for <plat>.
  clean-all                 Removes all images for all platforms.

  *buildx-base <plat>       Builds a multi-architecture base image.
  *buildx-platform <plat>   Builds a multi-architecture image with Erlang & JS support.

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
