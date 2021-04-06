# OPNsense Firewall on FreeBSD VM

**New VNET + OPNSense with two NICs (Untrusted/Trusted)**

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fdmauser%2Fopnazure%2Fmaster%2Fazuredeploy.json)
[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fdmauser%2Fopnazure%2Fmaster%2Fazuredeploy.json)

**Existing VNET + OPNSense with two NICs (Untrusted/Trusted)**

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fdmauser%2Fopnazure%2Fmaster%2Fazuredeploy-TwoNICs.json)
[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fdmauser%2Fopnazure%2Fmaster%2Fazuredeploy-TwoNICs.json)

**New VNET + OPNSense with single NIC**

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fdmauser%2Fopnazure%2Fmaster%2Fazuredeploy-newvnet-single-nic.json)
[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fdmauser%2Fopnazure%2Fmaster%2Fazuredeploy-newvnet-single-nic.json)

**Existing VNET + OPNSense with single NIC**

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fdmauser%2Fopnazure%2Fmaster%2Fazuredeploy-SingleNIC.json)
[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fdmauser%2Fopnazure%2Fmaster%2Fazuredeploy-SingleNIC.json)


Those template allows you to deploy an OPNsense Firewall VM using the opnsense-bootsrtap installation method. It creates an FreeBSD VM, does a silent install of OPNsense using a modified version of opnsense-bootstrap.sh with the settings provided.

The login credentials are set during the installation process to:

- Username: root
- Password: opnsense (lowercase)

*** **Please** *** Change *default password!!!*

After deployment, you can go to <https://PublicIP>, then input the user and password, to configure the OPNsense firewall.

## Updates (Apr-2021)

- Added all templates on main page for new VNET and existing VNETs for both two NICs and single NIC.
- Added options to specific your own deployment script and configuration file.
- Added NSG to support Standard SKU Public and Internal Load Balancer.


## Overview

This OPNSense solution is installed in FreeBSD 11.2 (Azure Image). 
Here is what you will see when you deploy this Template:

1) VNET with Two Subnets and OPNSense VM with two NICs.
2) VNET Address space is: 10.0.0.0/16 (suggested Address space, you may change that).
3) External NIC named Untrusted Linked to Untrusted-Subnet (10.0.0.0/24).
4) Internal NIC named Trusted Linked to Trusted-Subnet (10.0.1.0/24).
5) It creates a NSG named OPN-NSG which allows incoming SSH and HTTPS. Same NSG is associated to both Subnets.

## Design

Here is a visual representation of this design of the two NIC deployment:

![opnsense design](./images/OPN-SenseProject.png)

## Deployment

Here are few considerations to deploy this solution correctly:

- When you deploy this template, it will leave only TCP 22 listening to Internet while OPNSense gets installed.
- To monitor the installation process during template deployment you can just probe the port 22 on OPNSense VM public IP (psping or tcping).
- When port is down which means OPNSense is installed and VM will get restarted automatically. At this point you will have only TCP 443.

**Note**: It takes about 10 min to complete the whole process when VM is created and a new VM CustomScript is started to install OPNSense.

## Usage

- First access can be done using <HTTPS://PublicIP.> Please ignore SSL/TLS errors and proceed.
- Your first login is going to be username "root" and password "opnsense" (**PLEASE change your password right the way**).
- To access SSH you can either deploy a Jumpbox VM on Trusted Subnet or create a Firewall Rule to allow SSH to Internet.
- To send traffic to OPNSense you need to create UDR 0.0.0.0 and set IP of trusted NIC IP (10.0.1.4) as next hop. Associate that NVA to Trusted-Subnet.
- **Note:** It is necessary to create appropriate Firewall rules inside OPNSense to desired traffic to work properly.

## Roadmap

The following improvements will be added soon:
- Add option to create Jumpbox VM for management

## Feedbacks

Please use Github [issues tab](https://github.com/dmauser/opnazure/issues) to provide feedback.

## Credits

Thanks for direct feedbacks and contributions from: Adam Torkar, Brian Wurzbacher, Victor Santana and Brady Sondreal.
