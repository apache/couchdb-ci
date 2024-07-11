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

# Build Erlang from source on systems where desired package
# versions are not available
#
# While these scripts are primarily written to support building CI
# Docker images, they can be used on any workstation to install a
# suitable build environment.

# stop on error
set -e

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  echo "Sorry, this script must be run as root."
  echo "Try: sudo $0 $*"
  exit 1
fi

SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

. ${SCRIPTPATH}/detect-os.sh

redhats='(rhel|centos|fedora|almalinux)'
debians='(debian|ubuntu)'

echo "Erlang source build started @ $(date)"

# Install per-distro dependencies according to:
#  http://docs.basho.com/riak/1.3.0/tutorials/installation/Installing-Erlang/
# NB: Dropping suggested superfluous packages; fop and unixodbc-dev
if [[ ${ID} =~ ${redhats} ]]; then
  yum install -y git gcc glibc-devel make ncurses-devel openssl-devel autoconf procps
elif [[ ${ID} =~ ${debians} ]]; then
  apt-get update
  apt-get install -y git build-essential autoconf libncurses5-dev openssl libssl-dev xsltproc procps
else
  echo "Sorry, we don't support this Linux (${ID}) yet."
  exit 1
fi


# Build from source tarball
# Pull down and checkout the requested Erlang version

ERL_TOP=/tmp/build/otp_src_${ERLANGVERSION}
mkdir -p $ERL_TOP
cd /tmp/build
wget --quiet https://github.com/erlang/otp/releases/download/OTP-${ERLANGVERSION}/otp_src_${ERLANGVERSION}.tar.gz || \
    wget --quiet https://github.com/erlang/otp/archive/refs/tags/OTP-${ERLANGVERSION}.tar.gz
tar -C $ERL_TOP --strip-components=1 -xf *${ERLANGVERSION}.tar.gz
cd $ERL_TOP

ERLANGMAJORVERSION=`echo $ERLANGVERSION | cut -d. -f 1`
if [[ ${ERLANGMAJORVERSION} -ge 25 ]] && [[ ${ARCH} == "aarch64" ]]; then
    echo "*************************  WARNING ***************************"
    echo "Currently, as of 2022-07-02, Erlang 25.0.2 segfaults building"
    echo "the linux/arm64 image on linux/amd64 in QEMU. Because"
    echo "of that we disable JIT for arm64."
    echo "**************************************************************"
    DISABLE_JIT="--disable-jit"
else
    DISABLE_JIT=""
fi

if [[ ${ERLANGMAJORVERSION} -gt 25 ]]; then
    echo "*************************  WARNING ***************************"
    echo "As of 2024-07-11 Erlang 26.2.5* fails access any crypto functions"
    echo "on OSes with OpenSSL 3.0.x (Debian Bookworm, at least) if the "
    echo "--enable-fips flag is enabled. See: github.com/erlang/otp/issues/8562"
    echo "**************************************************************"
    ENABLE_FIPS=""
else
    ENABLE_FIPS="--enable-fips"
fi

# Configure Erlang - skip building things we don't want or need
./configure \
  --without-javac --without-wx --without-odbc \
  --without-debugger --without-observer --without-et  \
  --without-diameter --without-megaco --without-tftp \
  --without-ftp \
  ${ENABLE_FIPS} ${DISABLE_JIT}

make -j $(nproc)
make install
cd -
rm -rf otp

if [[ ${ID} =~ ${redhats} ]]; then
    yum clean all
elif [[ ${ID} =~ ${debians} ]]; then
    apt-get clean
fi

echo "Erlang source build finished @ $(date)"
