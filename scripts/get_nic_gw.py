#!/usr/bin/python3
import ipaddress
import os
import sys

# def convertip(user_option):
#   hex_data=user_option[2:]
#   #Check length, should be 8 , leading 0 is matter
#   if len(hex_data)< 8:
#     hex_data = ''.join(('0',hex_data))
#   def hex_to_ip_decimal(hex_data):
#     ipaddr = "%i.%i.%i.%i" % (int(hex_data[0:2],16),int(hex_data[2:4],16),int(hex_data[4:6],16),int(hex_data[6:8],16))
#     return ipaddr
#   result=hex_to_ip_decimal(hex_data)
#   return result
#   #print (result)

nic = sys.argv[1]
#print(nic)

#ipv4IP = os.popen('ifconfig '+nic+' | grep "\<inet\>" | awk \'{ print $2 }\' | awk -F "/" \'{ print $1 }\'').read().strip()
#ipv4mask = os.popen('ifconfig '+nic+' | grep "\<inet\>" | awk \'{ print $4 }\' | awk -F "/" \'{ print $1 }\'').read().strip()
#print(ipv4IP)
#print(ipv4mask)
n = ipaddress.IPv4Network(nic, strict=False)
#n = ipaddress.IPv4Network('10.10.128.253/255.255.255.224', strict=False)
first, last = n[0+1], n[-1]
print(first)
#print(last)