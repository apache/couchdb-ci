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

# This shell script builds a CouchDB-compatible SpiderMonkey 1.8.5
# and assumes the build environment is already set up correctly.
# It expects to be run as root.

# stop on error
set -e

# This works if we're not called through a symlink
# otherwise, see https://stackoverflow.com/questions/59895/
SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ARCH=$(arch)

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  echo "Sorry, this script must be run as root."
  echo "Try: sudo $0 $*"
  exit 1
fi

. ${SCRIPTPATH}/detect-os.sh

cd /root
git clone https://github.com/apache/couchdb-pkg
cd /root/couchdb-pkg

redhats='(rhel|centos|fedora)'
debians='(debian|ubuntu)'
if [[ ${ID} =~ ${redhats} ]]; then
  make couch-js-rpms
  cp /root/rpmbuild/RPMS/${ARCH}/couch-js-* /root/output
elif [[ ${ID} =~ ${debians} ]]; then
  make couch-js-debs PLATFORM=${VERSION_CODENAME}
  # /root/output is mounted somewhere useful.
  cp /root/couchdb-pkg/js/couch-lib* /root/output
else
  echo "Sorry, we don't support this Linux (${ID}) yet."
  exit 1
fi

