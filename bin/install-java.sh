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

JAVAVERSION=${JAVAVERSION:-11}

# extracting the right version to dl is a pain :(
if [ ${ARCH} == "x86_64" ]; then
  JAVAARCH=x64
else
  JAVAARCH=${ARCH}
fi

# Specify the Java version and platform
API_URL="https://api.adoptium.net/v3/binary/latest/${JAVAVERSION}/ga/linux/${JAVAARCH}/jdk/hotspot/normal/eclipse"

# Fetch the archive
FETCH_URL=$(curl -s -w %{redirect_url} "${API_URL}")
FILENAME=$(curl -OLs -w %{filename_effective} "${FETCH_URL}")

# Validate the checksum
curl -Ls "${FETCH_URL}.sha256.txt" | sha256sum -c --status

# Install
export JAVA_HOME=/opt/java/openjdk
tar -C "${JAVA_HOME}" --strip-components=1 -xzf "$FILENAME"
export PATH="${JAVA_HOME}/bin:${PATH}"
