#!/usr/bin/env bash
set -e

pushd `dirname $0`/job &> /dev/null

# convert to all-lower-case
for i in *.config.xml; do
  mv "$i" "${i,,}" 2> /dev/null || true
done

# replace %20% by hyphen
for i in *.config.xml; do
  mv "$i" "${i//%20/-}" 2> /dev/null || true
done

popd &> /dev/null

