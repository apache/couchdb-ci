#!/usr/bin/env bash

CONTAINER=$1
if [[ -z $CONTAINER ]]; then
  CONTAINER="couchdb-build-ubuntu-14.04-erlang-18.2"
  echo "No container ID provided, using default ID $CONTAINER"
fi

docker run -it $CONTAINER bash
