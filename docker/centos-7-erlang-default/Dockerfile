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

# NOTE: All docker files need to be run from ../../, that is
# docker build -f /docker/<container>/Dockerfile

# Base Image: Plain Vanilla CentOS with Ansible installed
FROM williamyeh/ansible:centos7-onbuild

# Add ansible directory and cd to it
ADD ./ansible /ansible
WORKDIR /ansible

# Install Ansible roles
RUN ansible-galaxy install geerlingguy.repo-epel
RUN ansible-galaxy install nodesource.node

# Run Ansible to provision container
RUN ansible-playbook site.yml \
  --connection=local \
  --inventory-file=./docker-inventories/centos-7-erlang-default

# USER couchdb

CMD ["/home/couchdb/build-ci.sh"]
