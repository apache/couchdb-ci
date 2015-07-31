#!/usr/bin/env bash
set -e

pushd `dirname $0` &> /dev/null

if [[ ! -f jenkins-api-token ]]; then
  echo Please create a file named jenkins-api-token and put your Jenkins API token in this file.
  exit 1
fi

JENKINS_API_TOKEN=$(<jenkins-api-token)
echo "using Jenkins API token: $JENKINS_API_TOKEN"

###############################################################################
# root Jenkins config
###############################################################################
curl --show-error "http://basti1302:$JENKINS_API_TOKEN@ci.couchdb.org:8888/api/xml" > root.tmp.xml
xmllint --format root.tmp.xml > root.xml || mv root.tmp.xml root.xml
rm -f root.tmp.xml

###############################################################################
# Job configs
###############################################################################
mkdir -p job

while IFS='' read -r jobname || [[ -n $jobname ]]; do
  echo "scraping job: $jobname"
  curl --show-error "http://basti1302:$JENKINS_API_TOKEN@ci.couchdb.org:8888/job/$jobname/config.xml" > "job/$jobname.config.xml"
done < jobnames.txt

# rename jobs to a sane naming pattern
./rename.sh

pop &> /dev/null

