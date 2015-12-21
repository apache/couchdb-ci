#!/usr/bin/env bash

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
  --inventory-file=./docker-inventories/ubuntu-worker \
  --sudo \
  $TAG \
  site.yml

popd
