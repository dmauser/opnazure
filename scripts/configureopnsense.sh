#!/bin/sh

# Script Params
# $1 = OPNScriptURI
# $2 = Primary/Secondary/SingNic/TwoNics
# $3 = Private IP Secondary Server

# Check if Primary or Secondary Server to setup Firewal Sync
# Note: Firewall Sync should only be setup in the Primary Server
if [ "$2" = "Primary" ]; then
    fetch $1config-active-active-primary.xml
    sed -i "" "s/xxx.xxx.xxx.xxx/$3/" config-active-active-primary.xml
    cp config-active-active-primary.xml /usr/local/etc/config.xml
elif [ "$2" = "Secondary" ]; then
    fetch $1config.xml
    cp config.xml /usr/local/etc/config.xml
elif [ "$2" = "SingNic" ]; then
    fetch $1config-snic.xml
    cp config-snic.xml /usr/local/etc/config.xml
elif [ "$2" = "TwoNics" ]; then
    fetch $1config.xml
    cp config.xml /usr/local/etc/config.xml
fi

#OPNSense default configuration template
#fetch https://raw.githubusercontent.com/dmauser/opnazure/dev_active_active/scripts/$1
#fetch https://raw.githubusercontent.com/dmauser/opnazure/master/scripts/$1
#cp $1 /usr/local/etc/config.xml

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
# Add Azure VIP on Arp table
echo # Add Azure Internal VIP >> /etc/rc.conf
echo static_arp_pairs=\"azvip\" >>  /etc/rc.conf
echo static_arp_azvip=\"168.63.129.16 12:34:56:78:9a:bc\" >> /etc/rc.conf
# Makes arp effective
service static_arp start
# To survive boots adding to OPNsense Autorun/Bootup:
echo service static_arp start >> /usr/local/etc/rc.syshook.d/start/20-freebsd