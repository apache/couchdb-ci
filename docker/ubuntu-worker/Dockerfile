# NOTE: All docker files need to be run from ../../, that is
# docker build -f /docker/ubuntu-worker/Dockerfile

# Base Image: Plain Vanilla Ubuntu 14.04 with Ansible installed
FROM williamyeh/ansible:ubuntu14.04

# Add ansible directory and cd to it
ADD ./ansible /ansible
WORKDIR /ansible

# Install Node.js role
RUN ansible-galaxy install nodesource.node

# Run Ansible to provision container
RUN ansible-playbook site.yml \
  --connection=local \
  --inventory-file=./docker-inventories/ubuntu-worker

USER couchdb

CMD ["/home/couchdb/build-ci.sh"]
