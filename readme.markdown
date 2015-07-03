CouchDB CI Setup
================

This is the repository for the automated creation of the CouchDB CI infrastructure. Well, at least it will be when it has grown up. This might take a while, though. Right now, it's just a bunch of Ansible scripts, a Vagrantfile and a Veewee definition.

See the readme files in folder `baseboxes` (for docs on building the base boxes) and in folder `vagrant` (for docs on how to spin up the setup locally).

Fair warning: This is very much work in progress.

Current state:

- [x] install bare Jenkins master with Ansible
- [x] install and configure nginx
- [x] create CouchDB build job in Jenkins via Ansible
- [ ] actually fetch CouchDB from VCS
- [ ] switch to master slave Jenkins setup
- [ ] optional: switch to Jenkins Job DSL plug-in for defining jobs?
- [ ] all apt-get commands should pin a specific version, in the base box definition as well as in Ansible. How?
- [ ] create an additional Ubuntu slave with an older Erlang version
- [ ] create another base box (different linux distro) for a third slave
- [ ] talk to Infra people
