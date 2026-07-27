This is a backed up state of the Apache CouchDB Jenkins instance
(https://ci-couchdb.apache.org/, a CloudBees CI client controller attached to
the https://jenkins-ccos.apache.org/ operations center).

Last captured: 2026-07-27, controller version 2.541.2.35785-rolling,
immediately after the post-migration restore was verified green.

How to capture
---

Everything below is fetched while logged in to the controller. The one-stop
endpoint is the **CloudBees CasC bundle export**:

    https://ci-couchdb.apache.org/core-casc-export

It returns a single text stream with `bundle.yaml`, `jenkins.yaml`,
`plugins.yaml`, `plugin-catalog.yaml`, `rbac.yaml` and `items.yaml` sections,
which are stored here split into files. (The OSS equivalent for just the
system config is `POST /manage/configuration-as-code/export`, also available
via Manage Jenkins > Configuration as Code > Download.)

Job definitions are NOT included (`items.yaml` exports empty on this
controller). Those are captured separately in config.xml:

    https://ci-couchdb.apache.org/job/FullPlatformMatrix/config.xml
    https://ci-couchdb.apache.org/job/PullRequests/config.xml
    https://ci-couchdb.apache.org/job/Update%20Docker%20Containers/config.xml

**IMPORTANT — redact before committing.** The exports contain secrets:

  * Cedential's `password:`/`secret:` value (encrypted with the
    instance key, but still a secret — and the instance key itself lives in
    the ops-center backups),
  * The CloudBees `license:` section: the certificate and, in PLAINTEXT, the
    license private key
  * `operationsCenterRootAction.connectionDetails`.

Replace all of these with `"...redacted..."` (grep for `{AQ`, `BEGIN RSA`,
`BEGIN CERTIFICATE`, `BEGIN CONNECTION DETAILS` before committing).

The files
---

 * `bundle.yaml`, `jenkins.yaml`, `plugins.yaml`, `plugin-catalog.yaml`,
   `rbac.yaml`, `items.yaml`
 * `jobs/*.xml` : raw config.xml of the three jobs.

How to restore
---

 * **Nodes**: The definitions live under `jenkins.nodes` in `jenkins.yaml`.

 * **Jobs**: POST the saved config.xml to `/createItem?name=<JobName>`
   (`Content-Type: application/xml`) [note: untested yet] or create via the UI
   following the structure in the XML.

* **Credentials**: recreate under Manage Jenkins > Credentials > System >
   Global with the SAME IDs (IDs are referenced by the Jenkinsfile/job
   config and are immutable after creation). Currently required:
   `dockerhub_creds` (Username with password; Docker Hub account + read-only
   access token). The job configs pick out some hopefully available crds for fetching GitHub repos.
   For example, `ASF CI for Github PRs`.

General description of the jobs
---

The `jobs/*.xml` files have the details and this is a summary only

  * `Main + Release` (name `FullPlatformMatrix`):
     Builds main, release and jenkins-* branches
     Branch Sources:
        GitHub with the `ASF CI for Github PRs etc` credential
          (`5f95d117-...`, comes from the operations center)
        Repository URL: https://github.com/apache/couchdb.git
        Discover branches
           Strategy: "Exclude branches that are also filed as PRs"
        Filter by name: `main jenkins-* 3.5.*`
     Build configuration:
        by Jenkinsfile, script path: `build-aux/Jenkinsfile`
     Orphaned Item Strategy:
        Abort builds
        Discard old items, max # of old items to keep: `10`

  * `Pull Requests` (name `PullRequests`):
     Builds pull requests against apache/couchdb
     Branch Sources:
        GitHub with the `ASF CI for Github PRs etc` credential
        Repository URL: https://github.com/apache/couchdb.git
        Discover pull requests from origin
          Strategy: "Merging the pull request with the current target branch"
        Discover pull requests from forks
          Strategy: "Merging the pull request with the current target branch"
          Trust: "From users with Admin or Write permissions"
     Build configuration:
        by Jenkinsfile, script path: `build-aux/Jenkinsfile`
     Orphaned Item Strategy:
        Abort builds
        Discard old items
          Days to keep old items: `15`
          Max # of old items to keep: `20`

  * `Update Docker Containers`:
     Pulls recent docker CI images to the nodes and prunes
     unused ones. Weekly, Sundays 03:00-08:59 UTC.
     Build periodically:
        Schedule:
        ```
        TZ=UTC
        H H(3-8) * * 7
        ```
     Discard old builds: 7 days
     Pipeline speed/durability override: Performance-optimized
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
     ```
