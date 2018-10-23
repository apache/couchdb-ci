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
# CouchDB 2.x for pkg-based systems such as FreeBSD.

# stop on error
set -e

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  echo "Sorry, this script must be run as root."
  echo "Try: sudo $0 $*"
  exit 1
fi

# Upgrade all packages
pkg upgrade -y

pkg install -y gmake help2man openssl icu curl git bash unzip \
    autoconf automake libtool node8 npm-node8 lang/python \
    py27-sphinx py27-pip

# rest of python dependencies
pip install --upgrade sphinx_rtd_theme nose requests hypothesis==3.79.0

# TODO: package building stuff?

# convenience stuff for the CI workflow maintainer ;)
pkg install -y vim-tiny screen wget

# js packages, as long as we're not told to skip them
if [[ $1 != "nojs" ]]; then
  pkg install -y spidermonkey185
else
  # install js build-time dependencies only
  # we can't add the CouchDB repo here because the plat may not exist yet
  pkg install -y libffi autotools
fi

# Erlang is installed by pkg-erlang.sh

