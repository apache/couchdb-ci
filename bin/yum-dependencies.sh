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

fake-rpm() {
  tmpdir=/tmp/$1rpm
  mkdir -p $tmpdir/rpmbuild/{SOURCES,BUILD,RPMS}/noarch
  cat > $tmpdir/rpmbuild/SOURCES/README <<EOF
Fake package to appease later package builders.
EOF
  cat > $tmpdir/fake$1.spec <<EOF
Name:        fake-$1
Version:     $2
Release:     1%{?dist}
Summary:     Fake package for $1
Group:       Fake
License:     BSD
BuildRoot:   %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
Source:      README
Provides:    $1
BuildArch:   noarch

%description
%{summary}

%prep
%setup -c -T

%build
cp %{SOURCE0} .

%install

%files
%defattr(-,root,root,-)
%doc README

%changelog

EOF
  rpmbuild --verbose -bb --define "_topdir $tmpdir/rpmbuild" $tmpdir/fake$1.spec
  yum --nogpgcheck localinstall -y $tmpdir/rpmbuild/RPMS/*/*.rpm
  rm -rf $tmpdir
}


# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  echo "Sorry, this script must be run as root."
  echo "Try: sudo $0 $*"
  exit 1
fi

SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

. ${SCRIPTPATH}/detect-os.sh >/dev/null
. ${SCRIPTPATH}/detect-arch.sh >/dev/null
echo "Detected RedHat/Centos/Fedora version: ${VERSION_ID}   arch: ${ARCH}"

# TODO: Do the Right Things(tm) for Fedora

# Enable EPEL
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-${VERSION_ID}.noarch.rpm || true
# PowerTools for Rocky 8
if [[ ${VERSION_ID} -eq 8 ]]; then
  dnf install -y 'dnf-command(config-manager)'
  dnf config-manager --set-enabled powertools
  yum update -y
fi
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY*
if [[ ${VERSION_ID} -ne 6 ]]; then
  # more for RHEL than CentOS...
  yum install subscription-manager -y
  subscription-manager repos \
    --enable "rhel-*-optional-rpms" \
    --enable "rhel-*-extras-rpms" \
  >/dev/null 2>&1 || true
fi

# Upgrade all packages
yum upgrade -y

# Install auxiliary packages
yum groupinstall -y 'Development Tools'

# Dependencies for make couch, except erlang and package building stuff.
# help2man is for docs
yum install -y sudo git wget which autoconf autoconf-archive automake curl-devel libicu-devel \
    libtool ncurses-devel nspr-devel zip readline-devel unzip perl \
    createrepo xfsprogs-devel rpmdevtools
if [[ ${VERSION_ID} -eq 9 ]]; then
  dnf --enablerepo=crb install -y help2man
else
  yum install -y help2man
fi

# Node.js
pushd /tmp
wget https://rpm.nodesource.com/setup_${NODEVERSION}.x
set +e
/bin/bash setup_${NODEVERSION}.x
if [ $? -ne 0 ]; then
  set -e
  # extracting the right version to dl is a pain :(
  SAVEARCH=${ARCH}
  if [ ${SAVEARCH} == "x86_64" ]; then SAVEARCH=x64; fi
  node_filename="$(curl -s https://nodejs.org/dist/latest-v${NODEVERSION}.x/SHASUMS256.txt | grep linux-${SAVEARCH}.tar.gz | cut -d ' ' -f 3)"
  wget https://nodejs.org/dist/latest-v${NODEVERSION}.x/${node_filename}
  tar --directory=/usr --strip-components=1 -xzf ${node_filename}
  rm ${node_filename}
  # then, fake a package install
  fake-rpm nodejs ${NODEVERSION}.0.0
else
  set -e
  yum install -y nodejs
fi
rm setup_${NODEVERSION}.x
npm install npm@latest -g
popd

# python for testing and documentaiton
if [[ ${VERSION_ID} -eq 7 ]]; then
  yum install -y python36 python36-pip python-virtualenv
  PIP=pip3.6
  ln -s /usr/bin/python3.6 /usr/local/bin/python3
elif [[ ${VERSION_ID} -eq 8 ]]; then
  yum install -y python3-pip python3-virtualenv
  PIP=pip3
else
  yum install -y python3-pip
  PIP=pip3
fi

${PIP} --default-timeout=1000 install docutils==0.13.1 sphinx==1.5.3 sphinx_rtd_theme \
    typing nose requests hypothesis==3.79.0
if [[ ${VERSION_ID} -eq 9 ]]; then
  ${PIP} --default-timeout=1000 install wheel virtualenv
fi

# js packages, as long as we're not told to skip them
if [[ $1 != "nojs" ]]; then
  if [[ ${VERSION_ID} -lt 8 ]]; then
  # config the CouchDB repo & install the JS packages
    yum install -y yum-utils
    yum-config-manager --add-repo https://couchdb.apache.org/repo/couchdb.repo
    # install the JS packages
    yum install -y couch-js-devel
  elif [[ ${VERSION_ID} -eq 8 ]]; then
    yum install -y mozjs60-devel
  else
    yum install -y mozjs78-devel
  fi
else
  # install js build-time dependencies only
  # we can't add the CouchDB repo here because the plat may not exist yet
  yum install -y libffi-devel
fi

# clean up
yum clean all -y
