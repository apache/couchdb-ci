CouchDB CI Setup
================

Mission statement: Create a new continuous integration infrastructure for the CouchDB project.

For the background and goals, see this [thread](https://www.mail-archive.com/dev%40couchdb.apache.org/msg43591.html) on the couchdb-dev mailing list.

This is the repository for the automated creation of the CouchDB CI infrastructure. Well, at least it will be when it has grown up. This might take a while, though. Right now, it's just a bunch of Ansible scripts, a Vagrantfile and a Veewee definition.

See the readme files in folder `baseboxes` (for docs on building the base boxes) and the section about Vagrant below (for docs on how to spin up the setup locally).

Fair warning: This is very much work in progress.

Current state:

- [x] install bare Jenkins master with Ansible
- [x] install and configure nginx
- [x] create CouchDB build job in Jenkins via Ansible
- [x] switch to master-worker Jenkins setup
- [x] use ntp server for master and workers
- [ ] actually fetch CouchDB from VCS
- [ ] optional: switch to Jenkins Job DSL plug-in for defining jobs?
- [ ] all apt-get commands should pin a specific version, in the base box definition as well as in Ansible. How?
- [ ] create an additional Ubuntu worker with an older Erlang version
- [ ] create another base box (different linux distro) for a third worker
- [ ] talk to Infra people

*Remark: Throughout this repository we use the terms "master"/"worker" for the Jenkins build machines, whereas the Jenkins documentation uses the terms "master"/"slave".*

Vagrant Configuration for Testing the CouchDB CI Setup Locally
--------------------------------------------------------------

The project's root folder contains a Vagrantfile with a multi machine Vagrant configuration for the machines used in the CouchDB CI setup.

### Prerequesites

You need to have [Vagrant](https://www.vagrantup.com/) and [VirtualBox](https://www.virtualbox.org/) installed.

When Vagrant is installed you need to install an additional plug-in:
```bash
vagrant plugin install vagrant-hosts
```

plus an additional Ansible role
```bash
[sudo] ansible-galaxy install geerlingguy.ntp
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
