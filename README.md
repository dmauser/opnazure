# OPNsense Firewall on FreeBSD VM

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fdmauser%2Fopnazure%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fdmauser%2Fopnazure%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

This template allows you to deploy an OPNsense Firewall VM using the opnsense-bootsrtap installation method. It creates an FreeBSD VM, does a silent install of OPNsense using a modified version of opnsense-bootstrap.sh with the settings provided.

The login credentials are set during the installation process to:

user: root
pass: opnsense (lowercase)

***Please*** change the default password and update the Network Security Group to remove access via public ip!

After deployment, you can go to https://PublicIP:443 , then input the user and password, to configure the OPNsense firewall.

## Overview

This OPNSense solution is installed in FreeBSD 11.2 (Azure Image). 
Here what you will see when you deploy this Template:
1) VNET with Two Subnets and OPNSense with two NICs.
2) VNET Address space is: 10.0.0.0/16
3) External NIC named Untrusted Linked to Untrusted-Subnet (10.0.0.0/24)
4) Internal NIC named Trusted Linked to Trusted-Subnet (10.0.1.0/24)
5) It creates a NSG named OPN-NSG which allows incoming SSH and HTTPS. Same NSG is associated to both Subnets.

## Deployment
Here few observations to use this solution correctly.

- When you deploy this template, it will leave only TCP 22 listening to Internet while OPNSense gets installed.
- To monitor the installation process during template deployment you can just probe the port 22 on OPNSense VM public IP (psping or tcping). 
- When port is down which means OPNSense is installed and VM will get restarted automatically. At this point you will have only TCP 443.

## Usage
- First access can be done using HTTPS://PublicIP. Please ignore SSL/TLS errors and proceed.
- Your first login is going to be username Root and password OPNsense (PLEASE change your password right the way)
- To access SSH you can either deploy a Jumpbox VM on Trusted Subnet or create a Firewall Rule to allow SSH to Internet.

## Roadmap

The following improvements will be added soon:
1) Give an option to specify VNET Address during deployment.
2) Give an option or new template to add extra Subnets like management and DMZ.
3) Create Jumpbox automatically on Trusted Subnet or DMZ.
