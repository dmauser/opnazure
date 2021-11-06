import re
import socket
import struct
import sys

def inet_atoi(ipv4_str):
    """Convert dotted ipv4 string to int"""
    # note: use socket for packed binary then struct to unpack
    return struct.unpack("!I", socket.inet_aton(ipv4_str))[0]

def inet_itoa(ipv4_int):
    """Convert int to dotted ipv4 string"""
    # note: use struct to pack then socket to string
    return socket.inet_ntoa(struct.pack("!I", ipv4_int))

def ipv4_range(ipaddr):
    """Return a list of IPv4 address contianed in a cidr address range"""
    # split out for example 192.168.1.1:22/24
    ipv4_str, port_str, cidr_str = re.match(
        r'([\d\.]+)(:\d+)?(/\d+)?', ipaddr).groups()

    # convert as needed
    ipv4_int = inet_atoi(ipv4_str)
    port_str = port_str or ''
    cidr_str = cidr_str or ''
    cidr_int = int(cidr_str[1:]) if cidr_str else 0

    # mask ipv4
    ipv4_base = ipv4_int & (0xffffffff << (32 - cidr_int))

    # generate list
    addrs = [inet_itoa(ipv4_base + val)
        for val in range(1 << (32 - cidr_int) + 2)]
    return addrs

nic = sys.argv[1]
#print(ipv4_range('10.0.1.0/24')[1])
print(ipv4_range(nic)[1])