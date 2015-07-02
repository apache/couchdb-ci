Veewee configurations for CouchDB CI basebox
============================================

To test CouchDB CI setups locally as virtual boxes we use we use Vagrant. Vagrant setups always need a base box. To make the creation and maintenance of these base boxes easy and reproducible we use [veewee](https://github.com/jedi4ever/veewee).

Each base box has its own sub folder in defintions and is based on a different template, usually a minimal install of the OS in question.

For example, the veewee configuration for the base box for Ubuntu 14.04 LTS is based on the template 'ubuntu-14.04-server-amd64' (created via
`veewee vbox define couchdb-ci-ubuntu-14.04 ubuntu-14.04-server-amd64`).

See the readme in each sub folder in definitions for more info on the base boxes.

Steps to re-build a basebox from scratch
========================================

## 0. Install Veewee

* https://github.com/jedi4ever/veewee/blob/master/doc/requirements.md
* https://github.com/jedi4ever/veewee/blob/master/doc/installation.md

## 1. Build and export virtualbox image with veewee

Execute the following commands in the `baseboxes` directory
```bash
veewee vbox build 'couchdb-ci-ubuntu-14.04'
```

If there is already a box named 'couchdb-ci-ubuntu-14.04', you can use the additional parameter `--force` to overwrite the existing box.

## 2. Export the box
```
veewee vbox export 'couchdb-ci-ubuntu-14.04'
```

Now you have a 'couchdb-ci-ubuntu-14.04.box' file in your directory. This file can be imported in Vagrant.

## 3. Import box in vagrant
```
vagrant box add 'couchdb-ci-ubuntu-14.04' './couchdb-ci-ubuntu-14.04.box'
```
