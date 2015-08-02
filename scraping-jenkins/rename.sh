#!/usr/bin/env bash
set -e

pushd `dirname $0`/jobs > /dev/null

shopt -s nullglob   # empty directory will return empty list

# convert to all-lower-case
for dir in ./*/;do
  mv "$dir" "${dir,,}" 2> /dev/null || true
done

# replace %20% by hyphen
for dir in ./*/;do
  mv "$dir" "${dir//%20/-}" 2> /dev/null || true
done

popd > /dev/null

