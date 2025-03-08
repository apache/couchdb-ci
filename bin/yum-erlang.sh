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

# This shell script installs Erlang dependencies for Apache
# CouchDB 2.x for yum-based systems.
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
  yum -y --nogpgcheck localinstall $tmpdir/rpmbuild/RPMS/*/*.rpm
  rm -rf $tmpdir
}

# TODO: Do the Right Things(tm) for Fedora
if [[ ${ERLANGVERSION} == "default" ]]; then
  yum install -y erlang
fi

# fallback to source install if all else fails
if [ ! -x /usr/bin/erl -a ! -x /usr/local/bin/erl ]; then
  export ERLANGVERSION=$(echo ${ERLANGVERSION} | cut -d- -f 1)
  ${SCRIPTPATH}/source-erlang.sh
  fake-rpm esl-erlang $(date "+%Y%m%d%H%M%S")
fi

# clean up
yum clean all -y
