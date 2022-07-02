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

# This shell script installs Erlang dependencies for Apache
# CouchDB 2.x for deb-based systems.
#
# While these scripts are primarily written to support building CI
# Docker images, they can be used on any workstation to install a
# suitable build environment.

# stop on error
set -e

# TODO: support Mint, Devuan, etc.

# Check if running as root
if [[ ${EUID} -ne 0 ]]
then
  echo "Sorry, this script must be run as root."
  echo "Try: sudo $0 $*"
  exit 1
fi

SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# you DID run apt-dependencies.sh first, didn't you?
VERSION=$(/usr/bin/lsb_release -cs)

arms='(aarch64)'

fake-pkg() {
  cat << EOF > $1-control
Section: misc
Priority: optional
Standards-Version: 3.9.2
Package: $1
Provides: $1
Version: 2:${ERLANGVERSION}
Description: Fake $1 package to appease package builder
EOF
  equivs-build $1-control
  apt install --no-install-recommends -y ./$1*.deb
  rm $1-control $1*.deb
}


apt-get update || true

if [ "${ERLANGVERSION}" = "default" ]
then
  apt-get update && apt-get install --no-install-recommends -y erlang-nox erlang-dev erlang erlang-eunit erlang-dialyzer
elif [ "${ARCH}" = x86_64 ]
then
  wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
  dpkg -i erlang-solutions_*_all.deb || true
  rm erlang-solutions_*_all.deb
  apt-get update || true
  apt-get install --no-install-recommends -y esl-erlang=1:${ERLANGVERSION} || true
fi

# fallback to source install if all else fails
if [ ! -x /usr/bin/erl -a ! -x /usr/local/bin/erl ]
then
  # remove any trailing -### in version used for erlang solutions packages
  apt-get purge -y erlang-solutions && apt-get update
  export ERLANGVERSION=$(echo ${ERLANGVERSION} | cut -d- -f 1)
  ${SCRIPTPATH}/source-erlang.sh
  for pkg in \
      erlang-dev erlang-crypto erlang-dialyzer \
      erlang-eunit erlang-inets erlang-xmerl \
      erlang-os-mon erlang-reltool erlang-syntax-tools; do
    ERLANGVERSION=99.99.99 fake-pkg $pkg
  done
fi

# dangling symlinks cause make release to fail.
# so, we remove the manpage symlink
# see endless complaints about this on GH issues, SO, etc.
if [[ -h /usr/lib/erlang/man ]]
then
    rm /usr/lib/erlang/man
fi

# clean up
apt-get clean
