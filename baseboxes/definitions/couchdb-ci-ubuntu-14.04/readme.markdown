# Base Box couchdb-ci-ubuntu-14.04

This box has been created with

```bash
veewee vbox define couchdb-ci-ubuntu-14.04 ubuntu-14.04-server-amd64
```

That is, it has been created from the template ubuntu-14.04-server-amd64

## Modifications

After instantiating the template, chef.sh, puppet.sh and parallels.sh have been
removed (we don't need those).
