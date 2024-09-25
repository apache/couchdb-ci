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
# CouchDB 2.x for yum-based systems.
#
# While these scripts are primarily written to support building CI
# Docker images, they can be used on any workstation to install a
# suitable build environment.

# stop on error
set -e


ELIXIR_VSN=${ELIXIRVERSION:-v1.17.2}
ERLANG_VSN=`erl -noshell -eval 'io:fwrite(erlang:system_info(otp_release)), halt().'`
# See https://github.com/hexpm/bob
URL=https://repo.hex.pm/builds/elixir/${ELIXIR_VSN}-otp-${ERLANG_VSN}.zip

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  echo "Sorry, this script must be run as root."
  echo "Try: sudo $0 $*"
  exit 1
fi

SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function ensure_tool() {
    type "${1}" > /dev/null 2>&1 && return 0
    return 1
}

ensure_tool 'unzip' || { echo 'Please install `unzip`'; exit 1; }
ensure_tool 'wget' || { echo 'Please install `wget`'; exit 1; }

# Elixir release versions are pre-compiled on Erlang 22 which means
# they won't be compatible with Erlang 25. Instead use https://github.com/hexpm/bob
# to install Elixir versions pre-compiled for a specific major Erlang versions.
#
echo "==> Downloading Elixir from ${URL}"
wget -q --max-redirect=1 -O elixir.zip ${URL} \
    || { echo "===> Cannot download Elixir from ${URL}"; exit 1; }

mkdir -p /usr/local/bin/
unzip -qq elixir.zip -d /usr/local \
    ||  { echo "===> Cannot unpack elixir.zip"; exit 1; }

rm elixir.zip


# Install hex otherwise some Makefile operations like "@mix clean" won't work.
# They expect ./configure to have run and installed hex, but sometimes
# it may be called without a preceding configure call, for instance when
# building packages from a dist tarball. So we ensure it has hex there already.
echo "===> Installing Hex"
MIX_HOME=/home/jenkins/.mix /usr/local/bin/mix local.hex --force
if id jenkins >/dev/null 2>&1; then
  chown -R jenkins:jenkins /home/jenkins
else
  echo 'no jenkins user'
fi
