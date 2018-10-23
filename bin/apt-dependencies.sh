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
VERSION=$(/usr/bin/lsb_release -cs)
ARCH=$(arch)
debians='(wheezy|jessie|stretch|buster)'
ubuntus='(precise|trusty|xenial|artful|bionic)'
echo "Detected Ubuntu/Debian version: ${VERSION}   arch: ${ARCH}"

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
apt-get install -y apt-transport-https curl git pkg-config python \
    libpython-dev python-pip sudo wget zip unzip \
    build-essential ca-certificates libcurl4-openssl-dev \
    libicu-dev libnspr4-dev

# Node.js
pushd /tmp
wget https://deb.nodesource.com/setup_${NODEVERSION}.x
/bin/bash setup_${NODEVERSION}.x
apt-get install -y nodejs
rm setup_${NODEVERSION}.x
popd

# documentation packages
apt-get install -y help2man python-sphinx

# fix for broken sphinx on ubuntu 12.04 only
if [[ ${VERSION} == "precise" ]]; then
  pip install docutils==0.13.1 sphinx==1.5.3
fi

# rest of python dependencies
pip install --upgrade sphinx_rtd_theme nose requests hypothesis==3.79.0

# package-building stuff
apt-get install -y curl debhelper devscripts dh-exec dh-python \
    dialog equivs lintian libwww-perl quilt

# install dh-systemd if available
if [[ ${VERSION} != "precise" ]]; then
  apt-get install -y dh-systemd
fi

# Stuff to make Debian and RPM repositories
apt-get install -y reprepro createrepo

# relaxed lintian rules for CouchDB
mkdir -p /usr/share/lintian/profiles/couchdb
chmod 0755 /usr/share/lintian/profiles/couchdb
if [[ ${VERSION} =~ ${debians} ]]; then
  cp ${SCRIPTPATH}/../files/debian.profile /usr/share/lintian/profiles/couchdb/main.profile
  if [[ ${VERSION} == "jessie" ]]; then
    # remove unknown lintian rule privacy-breach-uses-embedded-file
    sed -i -e 's/, privacy-breach-uses-embedded-file//' /usr/share/lintian/profiles/couchdb/main.profile
    # add rule to suppress python-script-but-no-python-dep
    sed -i -e 's/Disable-Tags: /Disable-Tags: python-script-but-no-python-dep, /' /usr/share/lintian/profiles/couchdb/main.profile
  fi
elif [[ ${VERSION} =~ ${ubuntus} ]]; then
  cp ${SCRIPTPATH}/../files/ubuntu.profile /usr/share/lintian/profiles/couchdb/main.profile
  if [[ ${VERSION} == "xenial" ]]; then
    # add rule to suppress python-script-but-no-python-dep
    sed -i -e 's/Disable-Tags: /Disable-Tags: python-script-but-no-python-dep, /' /usr/share/lintian/profiles/couchdb/main.profile
  fi
else
  echo "Unrecognized Debian-like release: ${VERSION}! Skipping lintian work."
fi
chmod 0644 /usr/share/lintian/profiles/couchdb/main.profile

# convenience stuff for the CI workflow maintainer ;)
apt-get install -y vim-tiny screen

# js packages, as long as we're not told to skip them
if [[ $1 != "nojs" ]]; then
  # config the CouchDB repo & install the JS packages
  echo "deb https://apache.bintray.com/couchdb-deb ${VERSION} main" | \
      sudo tee /etc/apt/sources.list.d/couchdb.list
  for server in $(shuf -e pgpkeys.mit.edu \
                          ha.pool.sks-keyservers.net \
                          hkp://p80.pool.sks-keyservers.net:80 \
                          pgp.mit.edu) ; do \
    gpg --keyserver $server --recv-key 379CE192D401AB61 && break || : ;
  done
  gpg -a --export 379CE192D401AB61 | apt-key add -
  apt-get update && apt-get install -y couch-libmozjs185-dev
else
  # install js build-time dependencies only
  # we can't add the CouchDB repo here because the plat may not exist yet
  apt-get install -y libffi-dev pkg-kde-tools autotools-dev
fi

# Erlang is installed by apt-erlang.sh

# clean up
apt-get clean
