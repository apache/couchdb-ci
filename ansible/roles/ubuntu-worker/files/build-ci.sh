#!/usr/bin/env bash

set -e

cd /usr/src/couchdb
git reset --hard
git pull
./configure
make
