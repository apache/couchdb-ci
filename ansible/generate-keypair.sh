#!/usr/bin/env bash

# This script is not meant to be copied to the Jenkins master. It can be
# executed locally on the provisioning machine to generate a new keypair for
# Jenkins' master-worker communication. The key files are moved to the correct
# location for provisioning the master and the workers.
#
# Do not commit the keys to git!

# go to ansible directory
pushd `dirname $0` > /dev/null
pwd

if [[ -f roles/jenkins-master/files/keys/couchdb-ci-rsa ]] && [[ -f  roles/jenkins-worker/files/keys/couchdb-ci-rsa.pub ]]; then
  echo Keys found, not generating a new key pair.
else
  echo No keys found, generating new key pair.
  rm -f couchdb-ci-rsa couchdb-ci-rsa.pub
  ssh-keygen -t rsa -N "" -b 4096 -q -f couchdb-ci-rsa
  mv couchdb-ci-rsa.pub roles/jenkins-worker/files/keys
  mv couchdb-ci-rsa roles/jenkins-master/files/keys
fi

popd > /dev/null
