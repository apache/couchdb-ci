CouchDB CI Setup
================

Mission statement: Create a new continuous integration infrastructure for the CouchDB project.

For the background and goals, see

* this [thread](https://www.mail-archive.com/dev%40couchdb.apache.org/msg43591.html) on the couchdb-dev mailing list and
* this [ASF Infra ticket](https://issues.apache.org/jira/browse/INFRA-10126).

*Remark: Throughout this repository we use the terms "master"/"worker" for the Jenkins build machines, whereas the Jenkins documentation uses the terms "master"/"slave".*

The main purpose of this repository is to provide a number of Docker containers that the ASF infrastructure team can use in their Jenkins setups and which are capable of building CouchDB. The idea is to provide containers for a number of different operating systems and Erlang versions to make sure CouchDB builds and runs on all supported setups.

The current (rough) plan for the build matrix is this:

**OS/Erlang**       | **default ** | **17.5** | **18.x**
--------------------|--------------|----------|---------
**Ubuntu 14.04**    | ✔ (16B03-1)  | -        | ✔
**Ubuntu latest ?** | -            | -        | -
**Debian 7**        | -            | -        | -
**Debian 8**        | -            | -        | -
**CentOS 6**        | -            | -        | -
**CentOS 7**        | -            | -        | -
**OS X latest**     | -            | -        | -
**Free BSD**        | -            | -        | -
**Windows**         | -            | -        | -

### Open questions

* Do we run a CouchDB build on all combinations on each commit? This would probably be too much for the ASF Infra build systems. Do we build them once a day? We need to find a good balance between early feedback and resource consumption here.
* Do we even want to build the master branch or some other branch/tag? I guess the master branch would be most interesting for now, but not entirely sure. Also, it might make sense to make the branch/tag parameterizable so we could also use this to create releases from a specific tag etc.
* What exactly do we do in each Jenkins build? Just build CouchDB? Also build docs? Start CouchDB? Run some test suite?
* The build is currently triggered as the CMD in the Dockerfile via the script build-ci.sh. Is that okay? If we need more steps (beyond simply building CouchDB) we would need to add it to build-ci.sh.

### TODOs

- [ ] Check with ASF infra how to integrate our Docker containers into their build infrastructure.
- [ ] Set up first CouchDB build on <https://builds.apache.org/>.
- [ ] All apt-get commands should pin a specific version in Ansible. We are doing this for Erlang, we should do it for the other deps too.
- [ ] Create more containers - other Erlang versions, other OSes.

Docker
------

The docker containers are provisioned via Ansible. That is, the dockerfiles usually only kicks of the Ansible scripts and the actual setup is then done in Ansible. Part of the reason is that the initial idea was to just provision build workers to virtual machines instead of containers. I kept Ansible around to do the heavy lifting because the Ansible syntax is more expressive and flexible than plain vanilla Dockerfiles. The idea is that this will make things a bit easier once we create multiple containers for the build matrix. Also, you could still use the Ansible files to create a Vagrant VM instead of a Docker container. Last but not least, we plan to target operating systems on which Docker is not an option (FreeBDS, Windows, MacOS), so the final CI setup will use Docker for some points in the matrix but not all.

### Building the Containers

For each container that this repository can produce there is a shell script in the bin/create-docker-container directory. To build a container, execute the corresponding script.


### Running the CouchDB build on a Container

To run a CouchDB build in a particular container (after it has been build), use the corresponding script in `bin/run-build-in-container/`. This will start the container which will then immediately start the CouchDB build. (The build script is the container's CMD entrypoint.)

Vagrant
-------

Note: This section on creating the build machines on Vagrant might be outdated. Either we bring it up to date to have both possibilities (Docker & Vagrant) or we remove it completely and just go with Docker for now.

### Prerequesites

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
