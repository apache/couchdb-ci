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

# This shell script installs all build-time dependencies for Apache
# CouchDB 2.x. It attempts to identify the OS on which it is running,
# and invokes the relevant sub-scripts.
#
# While these scripts are primarily written to support building CI
# Docker images, they can be used on any workstation to install a
# suitable build environment.

# stop on error
set -e

# Defaults updated 2023-03-20
NODEVERSION=${NODEVERSION:-20}
ERLANGVERSION=${ERLANGVERSION:-26.2.5.11}
ELIXIRVERSION=${ELIXIRVERSION:-v1.17.3}


# This works if we're not called through a symlink
# otherwise, see https://stackoverflow.com/questions/59895/
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# The directory when developers could put their own scripts which would be run
EXTRA_SCRIPTS_DIR=${SCRIPTPATH}/extra

# install JS by default, unless told otherwise (make-js images)
if [[ $1 == "nojs" ]]; then
  JSINSTALL="nojs"
else
  JSINSTALL=""
fi

if [[ $2 == "noerlang" ]]; then
  SKIPERLANG=1
fi

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  echo "Sorry, this script must be run as root."
  echo "Try: sudo $0 $*"
  exit 1
fi

# Unfortunately run-parts is not available in centos 6.
# Therefore need to roll our own
function run_scripts() {
  local scripts_dir="$1"
  local prefix="$2"
  if [[ -d ${scripts_dir%/} ]]; then
    scripts=$(LC_ALL=C; echo ${scripts_dir%/}/${prefix}*[^~,] | xargs -n 1 | sort -n)
    for script in $scripts ; do
        echo "Running ${script}" >&2
        ! ([[ -f ${script} && -x ${script} ]] && ${script}) \
            && echo "Failure in ${script}" >&2 && exit 1
    done
  fi
}

# TODO: help info on -h

. ${SCRIPTPATH}/detect-arch.sh
. ${SCRIPTPATH}/detect-os.sh

arms='(aarch64)'

case "${OSTYPE}" in
  linux*)
    redhats='(rhel|centos|fedora|almalinux)'
    debians='(debian|ubuntu)'

    if [[ ${ID} =~ ${redhats} ]]; then
      NODEVERSION=${NODEVERSION} \
          ${SCRIPTPATH}/yum-dependencies.sh ${JSINSTALL}
      if [[ ! ${SKIPERLANG} ]]; then
        ERLANGVERSION=${ERLANGVERSION} ${SCRIPTPATH}/yum-erlang.sh
        ELIXIRVERSION=${ELIXIRVERSION} ${SCRIPTPATH}/install-elixir.sh
      fi
      run_scripts ${EXTRA_SCRIPTS_DIR} 'yum-'
    elif [[ ${ID} =~ ${debians} ]]; then

      NODEVERSION=${NODEVERSION} ERLANGVERSION=${ERLANGVERSION} \
          ${SCRIPTPATH}/apt-dependencies.sh ${JSINSTALL}
      if [[ ! ${SKIPERLANG} ]]; then
        ERLANGVERSION=${ERLANGVERSION} ${SCRIPTPATH}/apt-erlang.sh
        ELIXIRVERSION=${ELIXIRVERSION} ${SCRIPTPATH}/install-elixir.sh
      fi
      run_scripts ${EXTRA_SCRIPTS_DIR} 'apt-'
    else
      echo "Sorry, we don't support this Linux (${ID}) yet."
      exit 1
    fi
    ;;

# useful for other platforms below:
# https://github.com/kerl/kerl/issues/240
  freebsd*)
    NODEVERSION=${NODEVERSION} ERLANGVERSION=${ERLANGVERSION} \
          ${SCRIPTPATH}/pkg-dependencies.sh ${JSINSTALL}
    if [[ ! ${SKIPERLANG} ]]; then
      ERLANGVERSION=${ERLANGVERSION} ${SCRIPTPATH}/pkg-erlang.sh
      ELIXIRVERSION=${ELIXIRVERSION} ${SCRIPTPATH}/install-elixir.sh
      run_scripts ${EXTRA_SCRIPTS_DIR} 'pkg-'
    fi
    ;;
  bsd*)
    # TODO: detect netbsd vs. freebsd vs. openbsd?
    echo "Detected OS: BSD - UNSUPPORTED"
    exit 1
    ;;
  darwin*)
    # TODO
    echo "Detected OS: macOS (OSX) - UNSUPPORTED"
    exit 1
    ;;
  solaris*)
    # TODO
    echo "Detected OS: Solaris-like"
    exit 1
    ;;
  msys*)
    # TODO
    echo "Detected OS: Windows (msys)"
    exit 1
    ;;
  cygwin*)
    # TODO
    echo "Detected OS: Windows (cygwin)"
    exit 1
    ;;
  *)
    echo "Unknown OS detected: ${OSTYPE}"
    exit 1
    ;;
esac

# user creation is done in the Dockerfiles, as non-Docker users don't need it
