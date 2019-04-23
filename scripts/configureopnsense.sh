#!/bin/sh
fetch https://raw.githubusercontent.com/dmauser/opnazure/master/scripts/config.xml
cp config.xml /usr/local/etc/config.xml

env ASSUME_ALWAYS_YES=YES pkg install ca_root_nss

#Permit Root Remote Login
fetch https://raw.githubusercontent.com/opnsense/update/master/bootstrap/opnsense-bootstrap.sh
sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config

#OPNSense
sed -i "" "s/reboot/shutdown -r +1/g" opnsense-bootstrap.sh
sh ./opnsense-bootstrap.sh -y