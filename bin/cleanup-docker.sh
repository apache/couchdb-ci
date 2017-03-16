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

echo WARNING! This script will delete all stopped containers!
read -n1 -r -p "Press any key to continue..." key
echo 

# Delete all stopped containers
docker rm $(docker ps -aq --filter status=exited) 2&>/dev/null

# Delete all untagged or dangling images
docker rmi $(docker images -q -f dangling=true) 2&>/dev/null

# Clean up dangling volumes, if any
docker volume rm $(docker volume ls -qf dangling=true) 2&>/dev/null

