#!/bin/sh
#OPNSense default configuration template
fetch https://raw.githubusercontent.com/dmauser/opnazure/dev_active_active/scripts/$1
#fetch https://raw.githubusercontent.com/dmauser/opnazure/master/scripts/$1
cp $1 /usr/local/etc/config.xml

# 1. Package to get root certificate bundle from the Mozilla Project (FreeBSD)
# 2. Install bash to support Azure Backup integration
env IGNORE_OSVERSION=yes
pkg bootstrap -f; pkg update -f
env ASSUME_ALWAYS_YES=YES pkg install ca_root_nss && pkg install -y bash

#Dowload OPNSense Bootstrap and Permit Root Remote Login
fetch https://raw.githubusercontent.com/opnsense/update/master/src/bootstrap/opnsense-bootstrap.sh.in
#fetch https://raw.githubusercontent.com/opnsense/update/master/src/bootstrap/opnsense-bootstrap.sh.in
sed -i "" 's/#PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config

#OPNSense
sed -i "" "s/reboot/shutdown -r +1/g" opnsense-bootstrap.sh.in
sh ./opnsense-bootstrap.sh.in -y -r "21.7"
#Adds support to LB probe from IP 168.63.129.16
fetch https://raw.githubusercontent.com/dmauser/opnazure/dev_active_active/scripts/lb-conf.sh
#fetch https://raw.githubusercontent.com/dmauser/opnazure/master/scripts/lb-conf.sh
sh ./lb-conf.sh
