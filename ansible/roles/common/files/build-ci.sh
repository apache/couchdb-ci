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

set +e

# create a distribution tarball from the requested git branch
cd /usr/src/couchdb-checkout
git reset --hard
git clean -ffdx
git pull
git checkout $GIT_BRANCH
./configure --with-curl
make dist

# use the created tarball to build CouchDB and run tests
cp apache-couchdb-*.tar.gz /usr/src/couchdb

cd /usr/src/couchdb
tar -xf apache-couchdb-*.tar.gz
cd apache-couchdb-*
./configure --with-curl
make all
make check
if [ $? -ne 0 ]; then
  /usr/src/couchdb-checkout/build-aux/logfile-uploader.py
  exit 1
fi
