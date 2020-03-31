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
if [[ ${EUID} -ne 0 ]]; then
  echo "Sorry, this script must be run as root."
  echo "Try: sudo $0 $*"
  exit 1
fi

# install lsb-release
apt-get update && apt-get install -y lsb-release

SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${SCRIPTPATH}/detect-arch.sh >/dev/null
. ${SCRIPTPATH}/detect-os.sh >/dev/null
debians='(wheezy|jessie|stretch|buster)'
ubuntus='(precise|trusty|xenial|artful|bionic)'
echo "Detected Ubuntu/Debian version: ${VERSION_CODENAME}   arch: ${ARCH}"

# bionic Docker image seems to be missing /etc/timezone...
if [[ ! -f /etc/timezone ]]; then
  rm -f /etc/localtime
  ln -snf /usr/share/zoneinfo/Etc/UTC /etc/localtime
  echo "Etc/UTC" > /etc/timezone
  chmod 0644 /etc/timezone
  apt-get install -y tzdata
  export TZ=Etc/UTC
fi

# Upgrade all packages
apt-get -y dist-upgrade

# install build-time dependencies
if [[ ${VERSION_CODENAME} == "trusty" ]]; then
  VENV=python3.4-venv
else
  VENV=python3-venv
fi

# build deps, doc build deps, pkg building, then userland helper stuff
apt-get install -y apt-transport-https curl git pkg-config \
    python3 libpython3-dev python3-setuptools python3-pip ${VENV} \
    sudo wget zip unzip \
    build-essential ca-certificates libcurl4-openssl-dev \
    libicu-dev libnspr4-dev \
    help2man python3-sphinx \
    curl debhelper devscripts dh-exec dh-python equivs \
    dialog equivs lintian libwww-perl quilt \
    reprepro createrepo rsync \
    vim-tiny screen procps

if [[ ${VERSION_CODENAME} == "xenial" ]]; then
  apt remove -y ${VENV}
  apt install -y software-properties-common
  add-apt-repository ppa:deadsnakes/ppa
  apt-get update
  apt install -y python3.7 python3.7-dev python3.7-venv
  rm /usr/bin/python3
  ln -s /usr/bin/python3.7 /usr/bin/python3
  pip3 install --upgrade pip
  pip3 install setuptools
fi

# Node.js
if [ "${ARCH}" == "ppc64le" ]; then
  apt-get install -y nodejs npm
else
  wget https://deb.nodesource.com/setup_${NODEVERSION}.x
  /bin/bash setup_${NODEVERSION}.x
  apt-get install -y nodejs
  rm setup_${NODEVERSION}.x
fi
# maybe install node from scratch if pkg install failed...
if [ -z "$(which node)" ]; then
  apt-get purge -y nodejs || true
  # extracting the right version to dl is a pain :(
  node_filename="$(curl -s https://nodejs.org/dist/latest-v${NODEVERSION}.x/SHASUMS256.txt | grep linux-${ARCH}.tar.gz | cut -d ' ' -f 3)"
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
  apt-get install -y ./nodejs*.deb
  rm nodejs-control nodejs*deb
fi
# update to latest npm
npm install npm@latest -g --unsafe-perm

# rest of python dependencies
pip3 --default-timeout=10000 install --upgrade sphinx_rtd_theme nose requests hypothesis==3.79.0

# install dh-systemd if available
if [[ ${VERSION_CODENAME} != "precise" ]]; then
  apt-get install -y dh-systemd
fi

# relaxed lintian rules for CouchDB
mkdir -p /usr/share/lintian/profiles/couchdb
chmod 0755 /usr/share/lintian/profiles/couchdb
if [[ ${VERSION_CODENAME} =~ ${debians} ]]; then
  cp ${SCRIPTPATH}/../files/debian.profile /usr/share/lintian/profiles/couchdb/main.profile
  if [[ ${VERSION_CODENAME} == "jessie" ]]; then
    # remove unknown lintian rule privacy-breach-uses-embedded-file
    sed -i -e 's/, privacy-breach-uses-embedded-file//' /usr/share/lintian/profiles/couchdb/main.profile
    # add rule to suppress python-script-but-no-python-dep
    sed -i -e 's/Disable-Tags: /Disable-Tags: python-script-but-no-python-dep, /' /usr/share/lintian/profiles/couchdb/main.profile
  fi
elif [[ ${VERSION_CODENAME} =~ ${ubuntus} ]]; then
  cp ${SCRIPTPATH}/../files/ubuntu.profile /usr/share/lintian/profiles/couchdb/main.profile
  if [[ ${VERSION_CODENAME} == "xenial" ]]; then
    # add rule to suppress python-script-but-no-python-dep
    sed -i -e 's/Disable-Tags: /Disable-Tags: python-script-but-no-python-dep, /' /usr/share/lintian/profiles/couchdb/main.profile
  fi
else
  echo "Unrecognized Debian-like release: ${VERSION_CODENAME}! Skipping lintian work."
fi

MAINPROFILE=/usr/share/lintian/profiles/couchdb/main.profile
if [[ -e ${MAINPROFILE} ]]; then
    chmod 0644 ${MAINPROFILE}
fi

# js packages, as long as we're not told to skip them
if [[ $1 != "nojs" ]]; then
  # config the CouchDB repo & install the JS packages
  echo "deb https://apache.bintray.com/couchdb-deb ${VERSION_CODENAME} main" | \
      sudo tee /etc/apt/sources.list.d/couchdb.list
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys \
      8756C4F765C9AC3CB6B85D62379CE192D401AB61
  apt-get update && apt-get install -y couch-libmozjs185-dev
  if [ "${VERSION_CODENAME}" == "buster" ]; then
    apt-get install -y libmozjs-60-dev
  fi
else
  # install js build-time dependencies only
  # we can't add the CouchDB repo here because the plat may not exist yet
  apt-get install -y libffi-dev pkg-kde-tools autotools-dev
fi

# Erlang is installed by apt-erlang.sh

# FoundationDB
wget https://www.foundationdb.org/downloads/6.2.15/ubuntu/installers/foundationdb-clients_6.2.15-1_amd64.deb
wget https://www.foundationdb.org/downloads/6.2.15/ubuntu/installers/foundationdb-server_6.2.15-1_amd64.deb
dpkg -i ./foundationdb*deb
pkill -f fdb || true
pkill -f foundation || true

# clean up
apt-get clean
