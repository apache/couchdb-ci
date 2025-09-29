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

# This shell script installs all OS package dependencies for Apache
# CouchDB 2.x for deb-based systems.
#
# While these scripts are primarily written to support building CI
# Docker images, they can be used on any workstation to install a
# suitable build environment.

# stop on error
set -e

# TODO: support Mint, Devuan, etc.

# Check if running as root
if [ ${EUID} -ne 0 ]; then
  echo "Sorry, this script must be run as root."
  echo "Try: sudo $0 $*"
  exit 1
fi

# install lsb-release
apt-get update && apt-get install -y lsb-release

SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${SCRIPTPATH}/detect-arch.sh >/dev/null
. ${SCRIPTPATH}/detect-os.sh >/dev/null
debians='(bullseye|bookworm|trixie)'
ubuntus='(jammy|noble)'
echo "Detected Ubuntu/Debian version: ${VERSION_CODENAME}   arch: ${ARCH}"

# ubuntu docker image seems to be missing /etc/timezone...
if [ ! -f /etc/timezone ]; then
  rm -f /etc/localtime
  ln -snf /usr/share/zoneinfo/Etc/UTC /etc/localtime
  echo "Etc/UTC" > /etc/timezone
  chmod 0644 /etc/timezone
  apt-get install --no-install-recommends -y tzdata
  export TZ=Etc/UTC
fi

# Upgrade all packages
apt-get --no-install-recommends -y dist-upgrade

# install build-time dependencies

# build deps, doc build deps, pkg building, then userland helper stuff
apt-get install --no-install-recommends -y apt-transport-https curl git pkg-config \
    python3 libpython3-dev python3-setuptools python3-pip python3-venv \
    sudo wget zip unzip \
    build-essential ca-certificates libcurl4-openssl-dev \
    libicu-dev libnspr4-dev \
    help2man curl debhelper devscripts dh-exec dh-python equivs \
    dialog equivs lintian libwww-perl quilt \
    reprepro fakeroot rsync \
    vim-tiny screen procps dirmngr ssh-client createrepo-c time

# Node.js (ubuntu noble has version 18, otherwise build a package)

if [ "${VERSION_CODENAME}" == "noble" ] && [ "${NODEVERSION}" == "18" ]; then
    echo "--- Ubuntu Noble (24.04) has NodeJS 18 so we just install it from there"
    apt-get install --no-install-recommends -y nodejs npm
else
    wget https://deb.nodesource.com/setup_${NODEVERSION}.x
    if /bin/bash setup_${NODEVERSION}.x; then
      apt-get install --no-install-recommends -y nodejs
    fi
    rm setup_${NODEVERSION}.x

    # maybe install node from scratch if pkg install failed...
    if [ -z "$(which node)" ]; then
      apt-get purge -y nodejs || true
      # extracting the right version to dl is a pain :(
      if [ "${ARCH}" == "x86_64" ]; then
        NODEARCH=x64
      else
        NODEARCH=${ARCH}
      fi
      node_filename="$(curl -s https://nodejs.org/dist/latest-v${NODEVERSION}.x/SHASUMS256.txt | grep linux-${NODEARCH}.tar.gz | cut -d ' ' -f 3)"
      wget https://nodejs.org/dist/latest-v${NODEVERSION}.x/${node_filename}
      tar --directory=/usr --strip-components=1 -xzf ${node_filename}
      rm ${node_filename}
      # fake a package install
      cat << EOF > nodejs-control
Section: misc
Priority: optional
Standards-Version: 3.9.2
Package: nodejs
Provides: nodejs
Version: ${NODEVERSION}.99.99
Description: Fake nodejs package to appease package builder
EOF
      equivs-build nodejs-control
      apt-get install --no-install-recommends -y ./nodejs*.deb
      rm nodejs-control nodejs*deb
    fi
fi

# rest of python dependencies
# Since Debian bookworm and Ubuntu noble, to install python packages as system packages, add the "python3-"prefix
if [ "${VERSION_CODENAME}" == "bookworm" ] || [ "${VERSION_CODENAME}" == "noble" ]; then
    apt-get -y --no-install-recommends install python3-nose python3-requests python3-hypothesis
elif [ "${VERSION_CODENAME}" == "trixie" ]; then
    apt-get -y --no-install-recommends install python3-nose2 python3-requests python3-hypothesis
else
    pip3 --default-timeout=10000 install --upgrade nose requests hypothesis==3.79.0
fi

# relaxed lintian rules for CouchDB
mkdir -p /usr/share/lintian/profiles/couchdb
chmod 0755 /usr/share/lintian/profiles/couchdb
if [[ ${VERSION_CODENAME} =~ ${debians} ]]; then
  cp ${SCRIPTPATH}/../files/debian.profile /usr/share/lintian/profiles/couchdb/main.profile
elif [[ "${VERSION_CODENAME}" =~ ${ubuntus} ]]; then
  cp ${SCRIPTPATH}/../files/ubuntu.profile /usr/share/lintian/profiles/couchdb/main.profile
else
  echo "Unrecognized Debian-like release: ${VERSION_CODENAME}! Skipping lintian work."
fi

MAINPROFILE=/usr/share/lintian/profiles/couchdb/main.profile
if [ -e ${MAINPROFILE} ]; then
    chmod 0644 ${MAINPROFILE}
fi

# js packages, as long as we're not told to skip them
if [ "$1" != "nojs" ]; then
  # older releases don't have libmozjs60+, and we provide 1.8.5
  if [ "${VERSION_CODENAME}" != "noble" ] && \
     [ "${VERSION_CODENAME}" != "jammy" ] && \
     [ "${VERSION_CODENAME}" != "bullseye" ] && \
     [ "${VERSION_CODENAME}" != "bookworm" ] && \
     [ "${VERSION_CODENAME}" != "trixie" ] && \
     [ "${ARCH}" != "s390x" ]; then
    curl https://couchdb.apache.org/repo/keys.asc | gpg --dearmor | tee /usr/share/keyrings/couchdb-archive-keyring.gpg >/dev/null 2>&1
    source /etc/os-release
    echo "deb [signed-by=/usr/share/keyrings/couchdb-archive-keyring.gpg] https://apache.jfrog.io/artifactory/couchdb-deb/ ${VERSION_CODENAME} main" \
    | tee /etc/apt/sources.list.d/couchdb.list >/dev/null
    apt-get update
    apt-get install --no-install-recommends -y couch-libmozjs185-dev
  fi
  # newer releases have newer libmozjs
  if [ "${VERSION_CODENAME}" == "noble" ]; then
    apt-get install --no-install-recommends -y libmozjs-102-dev libmozjs-115-dev
  fi
  if [ "${VERSION_CODENAME}" == "jammy" ]; then
    apt-get install --no-install-recommends -y libmozjs-78-dev libmozjs-91-dev
  fi
  if [ "${VERSION_CODENAME}" == "bullseye" ]; then
    apt-get install --no-install-recommends -y libmozjs-78-dev
  fi
  if [ "${VERSION_CODENAME}" == "bookworm" ]; then
      apt-get install --no-install-recommends -y libmozjs-78-dev
  fi
  if [ "${VERSION_CODENAME}" == "trixie" ]; then
        apt-get install --no-install-recommends -y libmozjs-128-dev
  fi
else
  # install js build-time dependencies only
  # we can't add the CouchDB repo here because the plat may not exist yet
  apt-get install --no-install-recommends -y libffi-dev pkg-kde-tools autotools-dev
fi

# Configure Adoptium for Java
apt-get update && apt-get install -y wget apt-transport-https gpg
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor | tee /etc/apt/trusted.gpg.d/adoptium.gpg > /dev/null
echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list > /dev/null

# Erlang is installed by apt-erlang.sh

# clean up
apt-get clean
