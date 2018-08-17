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
QEMUVERSION=v2.9.1

# Node 8 as of 2018-05-08
NODEVERSION=${NODEVERSION:-8.12.0}
# Erlang 19.3.6 as of 2018-05-08
ERLANGVERSION=${ERLANGVERSION:-19.3.6}
# Elixir v1.6.6 as of 2018-07-25
ELIXIRVERSION=${ELIXIRVERSION:-v1.6.6}

DEBIANS="debian-jessie debian-stretch"
UBUNTUS="ubuntu-trusty ubuntu-xenial ubuntu-bionic ubuntu-xenial-ppc64le"
debs="(debian-jessie|debian-stretch|ubuntu-trusty|ubuntu-xenial|ubuntu-bionic)"

CENTOSES="centos-6 centos-7"
rpms="(centos-6|centos-7)"

BINTRAY_API="https://api.bintray.com"


build-base-platform() {
  # invoke as build-base <plat>
  # base images never get JavaScript, nor Erlang
  if [[ $1 == 'ubuntu-xenial-ppc64le' ]]; then
      ERLANGVERSION="default"
      QEMUARCH=ppc64le

      docker run --rm --privileged multiarch/qemu-user-static:register --reset --credential yes
      #docker run --rm --privileged multiarch/qemu-user-static:register --reset
      curl -sSL https://github.com/multiarch/qemu-user-static/releases/download/${QEMUVERSION}/x86_64_qemu-${QEMUARCH}-static.tar.gz | tar -xz -C ${SCRIPTPATH}/bin
  fi
    docker build -f dockerfiles/$1 \
        --build-arg js=nojs \
        --build-arg erlang=noerlang \
        --build-arg nodeversion=${NODEVERSION} \
        --build-arg erlangversion=${ERLANGVERSION} \
        --tag couchdbdev/$1-base \
        ${SCRIPTPATH}
}

build-js() {
  # TODO: check if image is built first, if not, complain
  # invoke as build-js <plat>
  rm -rf ${SCRIPTPATH}/js/$1
  mkdir -p ${SCRIPTPATH}/js/$1
  docker run \
      --mount type=bind,src=${SCRIPTPATH}/js/$1,dst=/root/output \
      --mount type=bind,src=${SCRIPTPATH},dst=/root/couchdb-ci \
      couchdbdev/$1-base \
      sudo /root/couchdb-ci/bin/build-js.sh
}

build-all-js() {
  rm -rf ${SCRIPTPATH}/js/*
  for plat in $DEBIANS $UBUNTUS $CENTOSES; do
    if [[ $1 != "no-rebuild" ]]; then
      build-base-platform $plat
    fi
    build-js $plat
  done
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

bintray-check-credentials() {
  if [[ ! ${BINTRAY_USER} || ! ${BINTRAY_API_KEY} ]]; then
    echo "Please set your Bintray credentials before using this command:"
    echo "  export BINTRAY_USER=<username>"
    echo "  export BINTRAY_API_KEY=<key>"
    exit 1
  fi
}

upload-js() {
  # invoke with $1 as plat, expect to find the binaries under js/$plat/*
  bintray-check-credentials
  for pkg in $(find js/$1 -type f); do
    if [[ $1 =~ ${debs} ]]; then
      # TODO: pull this stuff from buildinfo / changes files, perhaps? Not sure it matters.
      if [[ $pkg =~ (changes|buildinfo)$ ]]; then
        continue
      fi
      repo="couchdb-deb"
      dist=$(echo $1 | cut -d- -f 2)
      arch=$(echo $pkg | cut -d_ -f 3 | cut -d. -f 1)
      relpath="pool/s/spidermonkey/${pkg##*/}"
      HEADERS=("--header" "X-Bintray-Debian-Distribution: ${dist}")
      HEADERS+=("--header" "X-Bintray-Debian-Component: main")
      HEADERS+=("--header" "X-Bintray-Debian-Architecture: ${arch}")
    elif [[ $1 =~ ${rpms} ]]; then
      repo="couchdb-rpm"
      # better not put any extra . in the filename...
      dist=$(echo $pkg | cut -d. -f 4)
      arch=$(echo $pkg | cut -d. -f 5)
      relpath="${dist}/${arch}/${pkg##*/}"
      HEADERS=()
    else
      echo "Unknown repo type $1, aborting"
      exit 1
    fi
    local ret="$(curl \
        --request PUT \
        --upload-file $pkg \
        --user ${BINTRAY_USER}:${BINTRAY_API_KEY} \
        --header "X-Bintray-Package: spidermonkey" \
        --header "X-Bintray-Version: 1.8.5" \
        --header "X-Bintray-Publish: 1" \
        --header "X-Bintray-Override: 1" \
        --header "X-Bintray-Explode: 0" \
        "${HEADERS[@]}" \
        "${BINTRAY_API}/content/apache/${repo}/${relpath}")"
    if [[ ${ret} == '{"message":"success"}' ]]; then
      echo "Uploaded ${pkg} successfully."
    else
      echo "Failed to upload $pkg, ${ret}"
      exit 1
    fi
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

build-package() {
  # $1 is plat, $2 is the optional path to a dist tarball
  rm -rf ${SCRIPTPATH}/couch/$1
  mkdir -p ${SCRIPTPATH}/couch/$1
  chmod 777 ${SCRIPTPATH}/couch/$1
  if [[ $2 ]]; then
    cp $2 ${SCRIPTPATH}/${2##*/} || true
  fi
  if [[ ! -d ../couchdb-pkg ]]; then
    git clone https://github.com/apache/couchdb-pkg ../couchdb-pkg
  fi
  docker run \
      --mount type=bind,src=${SCRIPTPATH},dst=/home/jenkins/couchdb-ci \
      --mount type=bind,src=${SCRIPTPATH}/../couchdb-pkg,dst=/home/jenkins/couchdb-pkg \
      couchdbdev/$1-erlang-${ERLANGVERSION} \
      /home/jenkins/couchdb-ci/bin/build-couchdb-pkg.sh ${2##*/}
}

# TODO help
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
  js)
    # Build js packages for a given platform
    shift
    build-base-platform $1
    build-js $1
    ;;
  js-no-rebuild)
    # Build js packages for a given platform but do NOT rebuild base img
    shift
    build-js $1
    ;;
  js-all)
    # build all supported JS packages
    shift
    build-all-js
    ;;
  js-all-no-rebuild)
    # build all supported JS packages with no rebuild
    shift
    build-all-js no-rebuild
    ;;
  js-upload)
    shift
    upload-js $1
    ;;
  js-upload-all)
    shift
    for dir in $(ls js); do
      upload-js $dir
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
  couch-pkg)
    # build CouchDB pkgs for <plat>
    shift
    build-package $*
    ;;
  couch-pkg-all)
    # build CouchDB pkgs for all platforms
    shift
    rm -rf ${SCRIPTPATH}/couch/*
    for plat in $DEBIANS $UBUNTUS $CENTOSES; do
      build-package $plat $*
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
  clean <plat>		Removes all images for <plat>.
  clean-all		Cleans all images for all platforms.

  base <plat>		Builds the base (no JS/Erlang) image for <plat>.
  base-all		Builds all base (no JS/Erlang) images.

  js			Builds the JS packages for <plat>.
  js-all		Builds the JS packages for all platforms.
  js-no-rebuild		Builds the JS packages for <plat> without rebuilding
                	the base image first.
  js-all-no-rebuild	Same as above, with the same condition.
  js-upload <plat>	Uploads the JS packages for <plat> to bintray.
			Requires BINTRAY_USER and BINTRAY_API_KEY env vars.

  platform <plat>	Builds the image for <plat> with Erlang & JS support.
  platform-all		Builds all images with Erlang and JS support.

  platform-upload	Uploads the couchdbdev/* images to Docker Hub.
			Requires appropriate credentials.
  platform-upload-all	Uploads all the couchdbdev/* images to Docker Hub.

  couch <plat>		Builds and tests CouchDB for <plat>.
  couch-all		Builds and tests CouchDB on all platforms.

  couch-pkg <plat>	Builds CouchDB packages for <plat>.
  couch-pkg-all		Builds CouchDB packages for all platforms.
EOF
    if [[ $1 ]]; then
      exit 1
    fi
    ;;
esac

exit 0
