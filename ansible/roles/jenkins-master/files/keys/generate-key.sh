#!/usr/bin/env sh

# This script is not meant to be copied to the Jenkins master. It can be
# executed locally on the provisioning machine to generate a new keypair for
# Jenkins' master-worker communication. The public key is copied to the correct
# location for provisioning the worker. Do not commit the private key go git.
ssh-keygen -t rsa -N "" -b 4096 -q -f couchdb-ci-rsa
mv couchdb-ci-rsa.pub ../../../jenkins-worker/files/keys
