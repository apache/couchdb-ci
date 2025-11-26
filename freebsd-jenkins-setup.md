# Setting up jails as freebsd build agents for Apache CouchDB & ASF Jenkins

-----

# Host system config

In /etc/rc.conf:

```
# https://iocage.readthedocs.io/en/latest/networking.html
# and https://www.reddit.com/r/freebsd/comments/4ad6te/how_on_earth_do_i_get_ipfw_iocage_vnet_to_work/
# set up bridge interface for iocage
cloned_interfaces="bridge0"
ifconfig_bridge0="up"
ifconfig_bridge0_alias0="inet 10.0.0.1/24"

pf_enable="YES"
gateway_enable="YES"

pflog_enable="YES"
pflog_logfile="/var/log/pflog"
```

-----

In /etc/pf.conf:

```
# vim: set ft=pf

ext_if="em0"
vnet_ip_range="10.0.0.0/24"
tcp_services = "{ smtp, http, https }"

table <martians> { 0.0.0.0/8 10.0.0.0/8 127.0.0.0/8 169.254.0.0/16     \
                   172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 224.0.0.0/3 \
                   192.168.0.0/16 198.18.0.0/15 198.51.100.0/24        \
                   203.0.113.0/24 }
table <bruteforce> persist

set block-policy drop
set loginterface $ext_if
set skip on lo0

scrub in all

nat on $ext_if from $vnet_ip_range to any -> ($ext_if)

antispoof quick for { $ext_if }

block in log all
block log quick from <bruteforce>
block in quick on $ext_if from <martians> to any
block return out quick on $ext_if from any to <martians>

pass in quick inet proto icmp all
pass in quick on $ext_if proto tcp from any to any port ssh flags S/SA keep state (max-src-conn 10, max-src-conn-rate 5/5, overload <bruteforce> flush global)
pass in quick on $ext_if proto tcp from any to any port $tcp_services flags S/SA keep state
pass from $vnet_ip_range to any keep state
pass out all keep state
```

-----

In /etc/sysctl.conf:

```
net.inet.ip.forwarding=1       # Enable IP forwarding between interfaces
net.link.bridge.pfil_onlyip=0  # Only pass IP packets when pfil is enabled
net.link.bridge.pfil_bridge=0  # Packet filter on the bridge interface
net.link.bridge.pfil_member=0  # Packet filter on the member interface
security.bsd.unprivileged_read_msgbuf=0
security.jail.allow_raw_sockets=1
# This is only for routing tables if any
# (do not create default routing tables for all FIB's)
#net.add_addr_allfibs=0
net.inet.ip.fw.one_pass=0
```

and reboot

-----

# Installing the prerequisites

    pkg install synth
    synth build ~joant/jenkins-pkgs.txt

contents of `jenkins-pkgs.txt` follow:

    java/openjdk8
    sysutils/runit
    sysutils/iocage-devel@py36

then

    pkg install iocage-devel
    echo 'iocage_enable="YES"' >> /etc/rc.conf

then

```
# iocage fetch --release=12.0-RELEASE
# or, see https://github.com/iocage/iocage/issues/472
iocage fetch -F base.txz -F lib32.txz -F src.txz -r 12.0-RELEASE

iocage create boot=on vnet=on defaultrouter=10.0.0.1 ip4_addr="vnet0|10.0.0.2/24" -r 12.0-RELEASE -n jenkins1
iocage create boot=on vnet=on defaultrouter=10.0.0.1 ip4_addr="vnet0|10.0.0.3/24" allow_raw_sockets=1 -r 12.0-RELEASE -n jenkins2
```

Time to test:

```
iocage start jenkins1
iocage console jenkins1
# inside the jail
ping 10.0.0.1
ping 8.8.8.8
# all should be good
# repeat for jenkins2
```

# Building the packages for the jails so we have them, always

reference: https://github.com/jrmarino/synth/issues/13

```
mkdir -p /usr/local/etc/pkg/repos /packages
cat <<EOF >/usr/local/etc/pkg/repos/00_synth.conf
Synth: {
  url      : file:///packages,
  priority : 0,
  enabled  : yes,
}
EOF
```

then, on host:

```
iocage fstab -a jenkins1 /var/synth/live_packages /packages nullfs ro 0 0
```

back inside the jail:

```
# now install the stuff we need
pkg install -r Synth openjdk8 runit
git clone https://github.com/apache/couchdb-ci
couchdb-ci/bin/install-dependencies.sh js erlang
couchdb-ci/bin/install-elixir.sh

# or, if you don't trust our CI scripts
pkg install -y -r Synth unzip autoconf automake git gmake icu libtool py37-hypothesis py37-nose py37-pip vim-console curl wget elixir erlang python3 spidermonkey185 py37-progressbar openssl111 bash screen py37-sphinx py37-sphinx_rtd_theme node10 npm-node10 py37-requests
```

now, fix 2 broken things

```
# see https://unix.stackexchange.com/questions/485073/how-to-backport-freebsd-13-current-c-utf-8-locale-to-11-2-release
# here, I've done it on the host first, and am then scp'ing it to the jail
scp -r joant@10.0.0.1:/usr/share/locale/C.UTF-8 /usr/share/locale
# see https://github.com/fabric8io/jenkins-pipeline-library/issues/193#issuecomment-360903266
ln -s /usr/local/bin/bash /bin/bash
```

# Setting up runit & Jenkins agent inside the jail

```
mkdir -p /var/service/jenkins
cp -R /usr/local/etc/runit /etc/runit
echo runsvdir_enable=yes >> /etc/rc.conf
service runsvdir start
vigr
```

in the groups file, add:

```
jenkins:*:910:
```

back at the command line:

```
adduser
Username: jenkins
Full name: Jenkins CI
Uid (Leave empty for default): 910
Login group [jenkins]:
Login group is jenkins. Invite jenkins into other groups? []:
Login class [default]:
Shell (sh csh tcsh nologin) [sh]:
Home directory [/home/jenkins]:
Home directory permissions (Leave empty for default):
Use password-based authentication? [yes]:
Use an empty password? (yes/no) [no]: yes
Lock out the account after creation? [no]:
Username   : jenkins
Password   : <blank>
Full Name  : Jenkins CI
Uid        : 910
Class      :
Groups     : jenkins
Home       : /home/jenkins
Home Mode  :
Shell      : /bin/sh
Locked     : no
OK? (yes/no): yes
adduser: INFO: Successfully added (jenkins) to the user database.
Add another user? (yes/no): no
Goodbye!
```

now install the agent and set up runit

```
wget https://builds.apache.org/jnlpJars/agent.jar
chown jenkins:jenkins /home/jenkins/agent.jar

mkdir -p /var/service/jenkins/log/supervise
chown root:daemon /var/service/jenkins/log
chmod g+w /var/service/jenkins/log
cat <<EOF >/var/service/jenkins/run
#!/bin/sh
exec 2>&1
cd ~jenkins
chpst -ujenkins java -jar agent.jar -jnlpUrl https://builds.apache.org/computer/<NODE-NAME>/slave-agent.jnlp -secret <SECRET-PROVIDED-BY-ASF-INFRA>
EOF

cat <<EOF >/var/service/jenkins/log/run
#!/bin/sh
exec chpst -udaemon svlogd -tt .
EOF

chmod +x /var/service/jenkins/run /var/service/jenkins/log/run
sv start jenkins
```

at this point:
* use `ps` to make sure the agent is running
* check the contents of `/var/service/jenkinx/log/current` to make sure it connected
* double check https://builds.apache.org/computer/<nodename> to make sure it's connected

-----

# Updating/upgrading the host + packages

follow the guidelines for OS updates/upgrades here: https://www.freebsd.org/doc/handbook/updating-upgrading-freebsdupdate.html

then, update/upgrade the jails: https://iocage.readthedocs.io/en/latest/advanced-use.html#updating-jails

then, rebuild the packages on the host:

```
portsnap fetch update
synth build ~joant/jenkins-pkgs.txt
```

then, in each jail:

```
pkg update -r Synth
```
