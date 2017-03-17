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
# #   Unless required by applicable law or agreed to in writing, #   software distributed under the License is distributed on an
#   "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
#   KIND, either express or implied.  See the License for the
#   specific language governing permissions and limitations
#   under the License.

# CAUTION: This script runs the Ansible scripts directly on your machine
# instead of inside a Docker container or Vagrant box. It might mess up your
# system. Only use this if you know what you are doing.

# Call this script with sudo (that is `sudo ./run-local.sh` to run the playbook
# locally, without ssh. You can optionally provide a tag
# (http://docs.ansible.com/playbooks_tags.html) as an additional argument.

set -e

if [ "$(id -u)" != "0" ]; then
  echo "This script needs to run with root privileges."
  echo "Please start it as root or with sudo."
  exit 1
fi

pushd `dirname $0`

if [[ -n "$1" ]]; then
  TAG="-t $1"
fi

ANSIBLE_FORCE_COLOR=1 ANSIBLE_NOCOWS=1 \
  ansible-playbook \
  --connection=local \
  --inventory-file=./docker-inventories/ubuntu-14.04-erlang-18.2 \
  --sudo \
  $TAG \
  site.yml

popd
