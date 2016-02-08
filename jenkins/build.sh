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

# This is the script used by ASF Jenkins
# (https://builds.apache.org/job/CouchDB) to build and check CouchDB for
# a given OS and Erlang combination.

# Parts of this have been yoinked from
# https://github.com/jimenez/mesos/blob/master/support/jenkins_build.sh

set -xe

# Require the following environment variables to be set.
: ${OS:?"Environment variable 'OS' must be set"}
: ${ERLANG:?"Environment variable 'ERLANG' must be set"}

# Change to the couchdb-ci checkout for docker build context.
COUCHDB_CI_DIRECTORY=$( cd "$( dirname "$0" )/.." && pwd )
cd "$COUCHDB_CI_DIRECTORY"

rm -f $DOCKERFILE # Just in case a stale one exists.

DOCKER_IMAGE="basti1302/couchdb-build-"
DOCKER_OPTIONS=""

case $OS in
  centos-7*)
    echo "Using CentOS 7"
    DOCKER_IMAGE=$DOCKER_IMAGE"centos-7-"
    DOCKER_OPTIONS="-e LD_LIBRARY_PATH='/usr/local/lib'"
    ;;
  debian-8*)
    echo "Using Debian 8"
    DOCKER_IMAGE=$DOCKER_IMAGE"debian-8-"
    ;;
  ubuntu-14.04*)
    echo "Using Ubuntu 14.04"
    DOCKER_IMAGE=$DOCKER_IMAGE"ubuntu-14.04-"
    ;;
  *)
    echo "Unknown OS $OS"
    exit 1
    ;;
esac

case $ERLANG in
  default*)
    echo "Using Erlang 18.2"
    DOCKER_IMAGE=$DOCKER_IMAGE"erlang-default"
    ;;
  18.2*)
    echo "Using Erlang 18.2"
    DOCKER_IMAGE=$DOCKER_IMAGE"erlang-18.2"
    ;;
  *)
    echo "Unknown Erlang version $ERLANG"
    exit 1
    ;;
esac

docker pull $DOCKER_IMAGE

docker run $DOCKER_OPTIONS $DOCKER_IMAGE
