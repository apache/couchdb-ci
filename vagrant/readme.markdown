Vagrant Configuration for Testing the CouchDB CI Setup Locally
==============================================================

Each sub folder in this directory contains the Vagrant configuration for one of the machines used in the CouchDB CI setup.

## Prerequesites

You need to have [Vagrant](https://www.vagrantup.com/) and [VirtualBox](https://www.virtualbox.org/) installed.

## Building and Registering the Base Box

Each vagrant configuration requires its respective base box. For example, the configuration couchdb-jenkins-master requires the base box `couchdb-ci-ubuntu-14.04`. You can build the base boxes locally with veewee (see `../baseboxes/readme.markdown`). To make things easier we might upload the base boxes somewhere so people do not have to build them theirselves but can just download them but we are not there yet.

Either way, you have to add the image to the vagrant base image registry with the following command:
```
vagrant box add couchdb-ci-ubuntu-14.04 /path/to/your/base-box-file.box
```

When this has happened, `vagrant box list` should list the base box's name (`couchdb-ci-ubuntu-14.04` in our example).

The base box built with veewee is just a fresh minimal install of the OS. All relevant packages and configurations are provisioned with Ansible. Vagrant is used to make creating, provisioning and destroying these virtual machines easier.

## Launching and Provisioning the Box

Just execute `vagrant up`. This will start the virtual machine and provision it using the scripts in `../ansible`. That's it :-)
