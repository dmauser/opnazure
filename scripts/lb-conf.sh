#!/bin/sh
# Add Azure VIP on Arp table
echo # Add Azure Internal VIP >> /etc/rc.conf
echo static_arp_pairs=\"azvip\" >>  /etc/rc.conf
echo static_arp_azvip=\"168.63.129.16 12:34:56:78:9a:bc\" >> /etc/rc.conf
# Makes arp effective
service static_arp start
# To survive boots adding to OPNsense Autorun/Bootup:
echo service static_arp start >> /usr/local/etc/rc.syshook.d/start/20-freebsd