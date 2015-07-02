Veewee Configurations for CouchDB CI Base Boxes
===============================================

To test CouchDB CI setups locally as virtual boxes we use we use Vagrant. Vagrant setups always need a base box. To make the creation and maintenance of these base boxes easy and reproducible we use [veewee](https://github.com/jedi4ever/veewee).

Each base box has its own sub folder in `definitions` and is based on a different template, usually a minimal install of the OS in question.

For example, the veewee configuration for the base box for Ubuntu 14.04 LTS is based on the template 'ubuntu-14.04-server-amd64' (created via
`veewee vbox define couchdb-ci-ubuntu-14.04 ubuntu-14.04-server-amd64`).

See the readme in each sub folder in `definitions` for more info on the base boxes.

Steps to Re-Build a Base Box From Scratch
========================================

## 0. Install Veewee

* <https://github.com/jedi4ever/veewee/blob/master/doc/requirements.md>
* <https://github.com/jedi4ever/veewee/blob/master/doc/installation.md>

## 1. Build and Export VirtualBox Images with Veewee

Execute the following commands in the `baseboxes` directory
```bash
veewee vbox build couchdb-ci-ubuntu-14.04
```

If there is already a box named `couchdb-ci-ubuntu-14.04`, you can use the additional parameter `--force` to overwrite the existing box or destroy the old box with `veewee vbox destroy couchdb-ci-ubuntu-14.04`.

When the box has been build, you could log in to the box with `ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 7222 -l vagrant 127.0.0.1` but actually there is no need to that.

## 2. Export the Box

```bash
veewee vbox export couchdb-ci-ubuntu-14.04
```

Now you have a `couchdb-ci-ubuntu-14.04.box` file in your directory. This file can be imported in Vagrant.

## 3. Import the Box in Vagrant

```bash
vagrant box add couchdb-ci-ubuntu-14.04 ./couchdb-ci-ubuntu-14.04.box
```
