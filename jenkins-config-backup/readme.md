
This is an attempt to have a backed up state of the Apache CouchDB Jenkins instance.

This became relevant since https://issues.apache.org/jira/browse/INFRA-27718 , when a Jenkins upgrade completely nerfed our CI pipeline and it took a bit of effort to restore it. Most of it was having to rediscover which plugins to reinstall and what configuration was now missing or erased.


The files are:

 * `jenkins.yml` : Dump of https://ci-couchdb.apache.org/manage/configuration-as-code/ with some license and credential removed
 
 * `system_information_plugins.md` : The list of plugins from Manage Jenkins > System Information > Plugins. Just a plain copy and paste from the browser interface into the file.
 
 
The general description of the main sections in Jenkins, in case the files above don't capture it:
 
  * `Controllers > CouchDB > ci-couchdb.apache.org > CouchDB > Main + Release > Configuration`:
     What it does: Builder for main, x.y.* and jenkins-* branches
     Branch Sources:
        GitHub with `ASF CI for Github PRs etc` credential
        Repository URL: https://github.com/apache/couchdb.git
        Discover branches
           Strategy > "Exclude branches that are also filed as PRs"
        Filter by name: `main jenkins-* 3.5.*`
     Build configuration:
        by Jenkinsfile, script path: `build-aux/Jenkinsfile`
     Orphaned Item Strategy:
        Abort builds
        Discard old items
          Max # of old items to keep: `10`
    
  * `Controllers > CouchDB > ci-couchdb.apache.org > CouchDB > Pull Requests > Configuration`:
     What it does: Builds pull requests
     Branch Sources:
        GitHub with `ASF CI for Github PRs etc` credential
        Repository URL: https://github.com/apache/couchdb.git
        Discover pull requests from origin
          Strategy > "Merging the pull request with the current target branch"
        Discover pull requests from forks
          Strategy > "Merging the pull request with the current target branch"
          Trust: "From users with Admin or Write permissions"
        Orphaned Item Strategy:
          Abort builds
        Discard old items
          Days to keep old items: `15`
          Max # of old items to keep: `25`

  * `Controllers > CouchDB > ci-couchdb.apache.org > CouchDB > Update Docker Containers`
     What it does: Pull recent docker CI images to the nodes and prunes unused one.
     Build periodically:
        Schedule: 
        ```
        TZ=UTC
        H H(3-8) * * 7
        ```
     Pipeline script:
     ```
     def nodes = [:]

     (nodesByLabel('docker') + nodesByLabel('s390x') + nodesByLabel('ppc64le')).each {
       nodes[it] = { ->
         node(it) {
           stage("docker-prune-refresh@${it}") {
             sh '''
                 wget -N https://raw.githubusercontent.com/apache/couchdb-ci/main/pull-all-couchdbdev-docker
                 bash ./pull-all-couchdbdev-docker
             '''
           }
         }
       }
     }

     parallel nodes
     ```
     Pipeline speed/durability override:
        Custom Pipeline Speed/Durability level:
          Performance-optimized
     
