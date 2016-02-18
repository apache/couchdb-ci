#!/usr/bin/env bash
JENKINS_LOGS_DIR=/home/bastian/projekte/couchdb/ci-logs /home/bastian/.nvm/versions/node/v4.2.6/bin/node `dirname $0`/analyze-jenkins-logs
