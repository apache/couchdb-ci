'use strict';

const _ = require('lodash');
const fs = require('fs');
const jsonfile = require('jsonfile');
const glob = require('glob');
const path = require('path');
const process = require('process');


let baseDir;
let success = 0;
let failure = 0;
let unrecognized;

// TODO Verify that the errors are indeed in the log file

const reasons = {};

const regexes = {
  aborted: [ /Build was aborted/ ],
  network: [
    /fatal: unable to access 'https:\/\/git-wip-us.apache.org/,
  /fatal: read error: Connection reset by peer/,
  ],
  docker: [
    /Cannot connect to the Docker daemon. Is the docker daemon running on this host?/
    ],
  libdl:  [ /sed: error while loading shared libraries: libdl.so.2/ ],
  eunit_replicator: [
    /\\*\\*in function couch_replicator_filtered_tests:should_succeed/,
  /\\*\\*error:\{assertion_failed,\[\{module,couch_replicator_compact_tests\}/,
  ],
  eunit_compression: [
    /couchdb_file_compression_tests:110: should_compare_compression_methods.*\\*failed\\*/,
  /in call from couchdb_file_compression_tests:setup\/0 \(test\/couchdb_file_compression_tests.erl, line 38\)/
    ],
  eunit: [ /XRROR: One or more eunit tests failed./ ],
};

// from https://gist.github.com/colingourlay/82506396503c05e2bb94
_.mixin({
  'sortKeysBy': function (obj, comparator) {
    var keys = _.sortBy(_.keys(obj), function (key) {
      return comparator ? comparator(obj[key], key) : key;
    });

    return _.zipObject(keys, _.map(keys, function (key) {
      return obj[key];
    }));
  }
});

function init() {
  if (!process.env.JENKINS_LOGS_DIR) {
    console.log('WARNING: JENKINS_LOGS_DIR is not set.\n');
  }
  baseDir = process.env.JENKINS_LOGS_DIR || __dirname;
  // console.log('Will read logs from', baseDir, '\n\n');

  process.on('exit', function() {

    console.log('# Summary');
    console.log('\nSuccesses:', success, 'Failures:', failure);
    if (reasons.unrecognized.counter > 0) {
      console.log('\n\n# Uncategorized Failures');
      console.log('\n* Number of failures: ' + reasons.unrecognized.counter);
      console.log('\n## Builds');
      reasons.unrecognized.urls.forEach( url => {
        console.log('* <' + url + '>');
      });
    }

    // print results, most frequent errors first
    _(reasons)
    .omit(['unrecognized'])
    .sortKeysBy((value, key) => {
      return -value.counter;
    })
    .forOwn((reasonObject, reasonKey) => {
      console.log('\n\n# Failures with reason "' + reasonKey + '"');
      console.log('\n* Number of failures: ' + reasonObject.counter);
      console.log('## Regular Expressions');
      console.log('When one of these regular expression has a match in the build log, I assume this build failure falls into this category.\n');
      regexes[reasonKey].forEach( regex => {
        console.log('* `' + regex + '`');
      });
      console.log('\n## Builds\n');
      console.log('Links to the build logs:\n');
      reasonObject.urls.forEach( url => {
        console.log('* <' + url + '>');
      });
    });
  });
}


function initReasonObject() {
  return {
    counter: 0,
    urls: [],
    directories: [],
  };
}


function analyzeLogs() {
  init();
  glob('+([0123456789])/', { cwd: baseDir,  }, function (err, buildDirectories) {
    if (err) {
      exitOnError(err);
    }
    if (buildDirectories.length === 0) {
      exitOnError(new Error('No matching directories found.'));
    }
    buildDirectories.forEach(buildDir => {
      readBuild(path.join(baseDir, buildDir));
    });
  });
}


function readBuild(buildDirectory) {
  fs.readdir(buildDirectory, function(err, runDirectories) {
    if (err) {
      return printWarning(err);
    }
    runDirectories.forEach(runDirectory => {
      readRun(path.join(buildDirectory, runDirectory));
    });
  });
}


function readRun(directory) {
  const metaDataFile = path.join(directory, 'metadata.json');
  const buildLogFile = path.join(directory, 'build.log');
  jsonfile.readFile(metaDataFile, 'utf-8', (err, metaData) => {
    if (err) {
      return printWarning(err);
    }
    const result = metaData.result[0];
    if (metaData.result[0] !== 'SUCCESS') {
      // console.error('Failure:', directory, result);
      failure++;
      fs.readFile(buildLogFile, 'utf-8', (err, buildLog) => {
        if (err) {
          return printWarning(err);
        }

        for (var key in regexes) {
          for (var i = 0; i < regexes[key].length; i++) {
            if (contains(buildLog, regexes[key][i])) {
              appendToReason(key, metaData, directory);
              return;
            }
          }
        }
        // console.error('Uncategorized failure', buildLogFile);
        appendToReason('unrecognized', metaData, directory);
      });
    } else {
      // console.error('Success:', directory, result);
      success++;
    }
  });
}


function appendToReason(key, metaData, directory) {
  let reasonObject = reasons[key];
  if (!reasonObject) {
    reasonObject = reasons[key] = initReasonObject();
  }
  reasonObject.counter++;
  reasonObject.urls.push(metaData.url + 'consoleText');
  reasonObject.directories.push(directory);
}


function contains(buildLog, regex) {
  return buildLog.search(regex) >= 0;
}


function exitOnError(error) {
  console.error(error);
  process.exit(1);
}


function printWarning(error) {
  console.error(error);
}


analyzeLogs();
