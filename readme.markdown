# CouchDB Continuous Integration (CI) support repo

The main purpose of this repository is to provide a number of Docker containers, Ansible roles/tasks and other configuration functionality so that the ASF Jenkins CI server (https://builds.apache.org/) is capable of building (and eventually packaging) CouchDB for a number of platforms. It intends to cover a range of both operating systems (Linux, macOS, BSD, Windows) and Erlang versions (OS default, 18.x, 19.x, etc.)

The current configuration builds CouchDB, Fauxton, its documentation, and runs the Erlang and JS test suites for each combination of OS and Erlang revision.

## Background 

See: 
* this [thread](https://www.mail-archive.com/dev%40couchdb.apache.org/msg43591.html) on the couchdb-dev mailing list and
* this [ASF Infra ticket](https://issues.apache.org/jira/browse/INFRA-10126).
for the origins of this work.

## Supported Configurations (updated 2017-03-22)

**OS/Erlang**       | **default ** | **18.3**
--------------------|--------------|--------------
**Ubuntu 12.04**    | ✗ (R14B04)   | ✔
**Ubuntu 14.04**    | ✔ (16B03-1)  | ✔
**Ubuntu 16.04**    | ✔ (18.3)     | ✔
**Debian 8**        | ✔ (17.3)     | ✔
**Debian 9**        | unreleased   | unreleased
**CentOS 6**        | ✗ (R14B04)   | ✔
**CentOS 7**        | ✔ (16B03-1)  | ✔
**macOS 10.12**     | -            | -
**FreeBSD**         | -            | -
**Windows**         | -            | -

Builds marked with an ✗ are skipped due to the version of Erlang being too old to build CouchDB >= 2.0.0.


## Open questions and TODOs
* Right now we run a CouchDB build on all combinations on each commit, but perhaps we don't need to run Jenkins this often. (We also have Travis CI for a single OS and a few Erlang revisions.) Should we just build them once a day?
* Right now we only build on the master branch. Travis CI handles PRs. ASF hasn't set up a Jenkins/Gitbox bridge yet, but if they do we can consider having Jenkins build PRs as well.
* Ideally, we'd also like to build convenience packages for some of these platforms on a regular basis, i.e. nightly - especially the platforms where building the software is harder (Windows).
* Currently, when changes occur to the base images (bugfixes, new OS/Erlang combinations added, etc.) new images are built manually using the scripts in `bin/`. TODO: automate this process in a way that avoids forcibly rebuilding every VM/Erlang combination with every checkin.

---

# Docker

For those OSes that support Docker, we run builds inside of Docker containers. The Dockerfiles typically use Ansible to handle all of their configuration and setup. This allows us to reuse the Ansible tasks for those OSes not supported by Docker for native apps (such as macOS and FreeBSD) where we must use VMs or bare hardware. The ASF has Windows Jenkins clients as an alternative to running Jenkins on Windows; a decision has not yet been reached here.

## Building a container

Run the `bin/<image-name>/create-container.sh` script.

## Interactively working in a built container

Run the `bin/<image-name>/enter-container.sh` script.

## Running the CouchDB build in a locally built (but not published) container

After using the `create-container.sh` script, run the command `docker run -it couchdbdev/<imagename>`. The build should immediately start.

## Publishing a container

1.  You need a Docker Cloud account with access to the `couchdbdev` organization. Ask the CouchDB PMC for assistance with this.
2. `export DOCKER_ID_USER="username"`
3. `docker login` and enter your password.
4.  Run the `bin/<image-name>/publish-container.sh` script.

## Running the CouchDB build in a published container

To pull down the latest image and run the CouchDB build in the container, run the `bin/<image-name>/run-build-in-container.sh` script. This does not work with `-base` images, which lack the full toolchain necessary to build CouchDB.


Vagrant
-------

Note: This section on creating the build machines on Vagrant might be outdated. Either we bring it up to date to have both possibilities (Docker & Vagrant) or we remove it completely and just go with Docker for now.

### Prerequisites

See the readme files in folder `baseboxes` for docs on building the base boxes.

You need to have [Vagrant](https://www.vagrantup.com/) and [VirtualBox](https://www.virtualbox.org/) installed.

When Vagrant is installed you need to install an additional plug-in:
```bash
vagrant plugin install vagrant-hosts
```

plus an additional Ansible role
```bash
[sudo] ansible-galaxy install nodesource.node
```

Also, you might need to run
```bash
VBoxManage dhcpserver remove --netname HostInterfaceNetworking-vboxnet0
```
before doing
```bash
vagrant up
```
because of <https://github.com/mitchellh/vagrant/issues/3083>.

### Building and Registering the Base Box

Each vagrant configuration requires its respective base box. For example, the configuration jenkins-master requires the base box `couchdb-ci-ubuntu-14.04`. You can build the base boxes locally with veewee (see `baseboxes/readme.markdown`). To make things easier we might upload the base boxes somewhere so people do not have to build them theirselves but can just download them but we are not there yet.

Either way, you have to add the image to the vagrant base image registry with the following command:
```
vagrant box add couchdb-ci-ubuntu-14.04 /path/to/your/base-box-file.box
```

When this has happened, `vagrant box list` should list the base box's name (`couchdb-ci-ubuntu-14.04` in our example).

The base box built with veewee is just a fresh minimal install of the OS. All relevant packages and configurations are provisioned with Ansible. Vagrant is used to make creating, provisioning and destroying these virtual machines easier.

### Launching and Provisioning the Boxes

Just execute `vagrant up`. This will start all the virtual machine and provision it using the scripts in `ansible`. That's it :-)

You can also selectively launch a single box, for example with
```bash
vagrant up couchdb-jenkins-master
```
