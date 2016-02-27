// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing,
//   software distributed under the License is distributed on an
//   "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//   KIND, either express or implied.  See the License for the
//   specific language governing permissions and limitations
//   under the License.
'use strict';

const fs = require('fs');
const isString = require('is-string');
const jsonfile = require('jsonfile');
const mkdirp = require('mkdirp');
const parseXml = require('xml2js').parseString;
const path = require('path');
const process = require('process');
const request = require('request');

const apiXml = 'api/xml';
let baseDir;

function init() {
  if (!process.env.JENKINS_LOGS_DIR) {
    console.log('WARNING: JENKINS_LOGS_DIR is not set.');
  }
  baseDir = process.env.JENKINS_LOGS_DIR || __dirname;
  console.log('Will write logs to', baseDir);
}


function crawlFromRootUrl(url) {
  console.log(`
================================================================================
`);
  console.log(new Date());
  init();
  request(url, function(err, message, body) {
    if (err) {
      return exitOnError(err);
    }

    parseXml(body, function (err, result) {
      if (err) {
        return exitOnError(err);
      }

      if (!result.matrixProject) {
        return exitOnError(new Error('Not found: matrixProject'));
      }
      if (!result.matrixProject.build) {
        return exitOnError(new Error('Not found: matrixProject.build'));
      }
      if (!Array.isArray(result.matrixProject.build)) {
        return exitOnError(new Error('Not an array: matrixProject.build'));
      }
      result.matrixProject.build.forEach(build => {
        fetchBuild(build);
      });
    });
  });
}


function fetchBuild(build) {
  if (build.number == null) {
    return printWarning(new Error('Not found: build.number'));
  }
  if (build.url == null) {
    return printWarning(new Error('Not found: build.url'));
  }

  const url = build.url + apiXml;
  console.log('Retrieving meta data for build', build.number[0], 'from ', url);
  request(url, function(err, message, body) {
    if (err) {
      return printWarning(err);
    }
    parseXml(body, function (err, result) {
      if (err) {
        return printWarning(err);
      }

      if (!result.matrixBuild) {
        return printWarning(new Error('Not found: matrixBuild'));
      }
      if (!result.matrixBuild.run) {
        return printWarning(new Error('Not found: matrixBuild.run'));
      }
      if (!Array.isArray(result.matrixBuild.run)) {
        return printWarning(new Error('Not an array: matrixBuild.run'));
      }
      result.matrixBuild.run.forEach(run => {
        fetchRun(run);
      });
    });
  });
}


function fetchRun(run) {
  if (run.number == null) {
    return printWarning(new Error('Not found: run.number'));
  }
  if (run.url == null) {
    return printWarning(new Error('Not found: run.url'));
  }

  const url = run.url + apiXml;
  console.log('Retrieving meta data for run', run.number[0], 'from ', url);
  request(url, function(err, message, body) {
    if (err) {
      return printWarning(err);
    }
    parseXml(body, function (err, result) {
      if (err) {
        return printWarning(err);
      }

      if (!result.matrixRun) {
        return printWarning(new Error('Not found: matrixRun'));
      }
      if (!result.matrixRun.number) {
        return printWarning(new Error('Not found: matrixRun.number'));
      }
      if (!result.matrixRun.fullDisplayName) {
        return printWarning(new Error('Not found: matrixRun.fullDisplayName'));
      }
      if (!Array.isArray(result.matrixRun.fullDisplayName)) {
        return printWarning(new Error('Not an array: matrixRun.fullDisplayName'));

      }
      if (result.matrixRun.fullDisplayName.length !== 1) {
        return printWarning(new Error('Not an array of length 1: matrixRun.fullDisplayName'));
      }
      if (!isString(result.matrixRun.fullDisplayName[0])) {
        return printWarning(new Error('Not a string: matrixRun.fullDisplayName[0]'));
      }

      fetchMatrixRunAndLog(result.matrixRun, run.url);
    });
  });
}


function fetchMatrixRunAndLog(metaData, runBaseUrl) {
  const logUrl = runBaseUrl + 'consoleText';
  request(logUrl, function(err, message, body) {
    if (err) {
      return printWarning(err);
    }
    saveToDisk(metaData, body);
  });
}


function saveToDisk(metaData, buildLog) {
  const dir = path.join(baseDir, String(metaData.number), metaData.fullDisplayName[0]);
  mkdirp.sync(dir);
  const metaDataFile = path.join(dir, 'metadata.json');
  jsonfile.writeFile(metaDataFile, metaData, { spaces: 2 }, function (err) {
    if (err) {
      return printWarning(err);
    }
    console.log('Written meta data to ', metaDataFile);
  });
  const buildLogFile = path.join(dir, 'build.log');
  fs.writeFile(buildLogFile, buildLog, function(err) {
    if (err) {
      return printWarning(err);
    }
    console.log('Written build log to ', buildLogFile);
  });
}


function exitOnError(error) {
  console.error(error);
  process.exit(1);
}


function printWarning(error) {
  console.error(error);
}


const rootUrl = 'https://builds.apache.org/job/CouchDB/api/xml';

crawlFromRootUrl(rootUrl);
