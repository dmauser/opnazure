# OPNsense Firewall on FreeBSD VM

CI Name | Actions Workflow | CI Status |
|--------|--------|--------|
| BicepBuild | [bicepBuild.yml](./.github/workflows/bicepBuild.yml) | [![bicepBuildCI](https://github.com/dmauser/opnazure/actions/workflows/bicepBuild.yml/badge.svg?branch=dev)](https://github.com/dmauser/opnazure/actions/workflows/bicepBuild.yml) |
| Deployment Checker - Active Active | [deploymentChecker-active-active.yml](./.github/workflows/deploymentChecker-active-active.yml) | [![deploymentCheckeractiveactiveactiveCI](https://github.com/dmauser/opnazure/actions/workflows/deploymentChecker-active-active.yml/badge.svg?branch=master)](https://github.com/dmauser/opnazure/actions/workflows/deploymentChecker-active-active.yml) |
| Deployment Checker - two nics | [deploymentChecker-two-nics.yml](./.github/workflows/deploymentChecker-two-nics.yml) | [![deploymentCheckertwonicsCI](https://github.com/dmauser/opnazure/actions/workflows/deploymentChecker-two-nics.yml/badge.svg?branch=master)](https://github.com/dmauser/opnazure/actions/workflows/deploymentChecker-two-nics.yml) |
| Deployment Checker - single nic | [deploymentChecker-sing-nic.yml](./.github/workflows/deploymentChecker-sing-nic.yml) | [![deploymentCheckersingnicCI](https://github.com/dmauser/opnazure/actions/workflows/deploymentChecker-sing-nic.yml/badge.svg?branch=master)](https://github.com/dmauser/opnazure/actions/workflows/deploymentChecker-sing-nic.yml) |
| Deployment Checker - new vnet Active Active | [deploymentChecker-newvnet-active-active.yml](./.github/workflows/deploymentChecker-newvnet-active-active.yml) | [![deploymentCheckeractivenewvnetactiveactiveCI](https://github.com/dmauser/opnazure/actions/workflows/deploymentChecker-active-active.yml/badge.svg?branch=master)](https://github.com/dmauser/opnazure/actions/workflows/deploymentChecker-active-active.yml) |
| Deployment Checker - new vnet two nics | [deploymentChecker-newvnet-two-nics.yml](./.github/workflows/deploymentChecker-two-nics.yml) | [![deploymentCheckernewvnettwonicsCI](https://github.com/dmauser/opnazure/actions/workflows/deploymentChecker-newvnet-two-nics.yml/badge.svg?branch=master)](https://github.com/dmauser/opnazure/actions/workflows/deploymentChecker-newvnet-two-nics.yml) |
| Deployment Checker - new vnet single nic | [deploymentChecker-newvnet-sing-nic.yml](./.github/workflows/deploymentChecker-sing-nic.yml) | [![deploymentCheckernewvnetsingnicCI](https://github.com/dmauser/opnazure/actions/workflows/deploymentChecker-newvnet-sing-nic.yml/badge.svg?branch=master)](https://github.com/dmauser/opnazure/actions/workflows/deploymentChecker-newvnet-sing-nic.yml) |

**Deployment Wizard**

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fdmauser%2Fopnazure%2Fmaster%2FARM%2Fmain.json%3F/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2Fdmauser%2Fopnazure%2Fmaster%2Fbicep%2FuiFormDefinition.json)

The template allows you to deploy an OPNsense Firewall VM using the opnsense-bootsrtap installation method. It creates an FreeBSD VM, does a silent install of OPNsense using a modified version of opnsense-bootstrap.sh with the settings provided.

OPNSense is based in FreeBSD what is the official OS image publisher in Azure. This template deploys a FreeBSD 13.1 VM and installs OPNSense using the opnsense-bootstrap installation method. For the first deployment in an Azure Subscription it's ***required to accept the legal terms*** of the Offer with PublisherId: 'thefreebsdfoundation', OfferId: 'freebsd-13_1'.

You can accept it using either Azure CLI or Azure PowerShell as follow:

```bash
az vm image terms accept --urn thefreebsdfoundation:freebsd-13_1:13_1-release:13.1.0 -o none
```

```powershell
Get-AzMarketplaceTerms -Publisher 'thefreebsdfoundation' -Product 'freebsd-13_1' -Name '13_1-release' -OfferType 'latest' | Set-AzMarketplaceTerms -Accept
```

The login credentials are set during the installation process to:

- Username: root
- Password: opnsense (lowercase)

*** **Please** *** Change *default password!!!* (In case of using Active-Active scenario the password must be changed in both Firewalls and under Highavailability settings)

After deployment, you can go to <https://PublicIP>, then input the user and password, to configure the OPNsense firewall.
In case of Active-Active the URL should be <https://PublicIP:50443> for Primary server and <https://PublicIP:50444> for Secondary server.

## Updates

## Feb-2023
- Added support to OPNsense 23.1
- Added support to select versions (22.7, 23.1)

## October-2022
- Updated FreeBSD to 13.1
- Updated OPNSense to 22.7
- Updated Azure Linux Agent to 2.8.0
- Updated Python symbolic link to 3.9

## April-2022
- Updated FreeBSD 13 and OPNSense 22.1
- Added support for Floating IPs in External Load Balance Rules to allow Port Forwarding without causing assymetric issues.
- Enabled session Sync between Firewalls.
- Add Virtual IP of the External Load Balancer to support Floating Rules.
- Add support for a Windows Management VM in a management network.
- Create a new simplified deployment wizard.
- Bicep template refactory to support the new UI deployment wizard.

### Nov-2021
- Added Active-Active deployment option (using Azure Internal and External Loadbalancer and OPNsense HA settings).
- Templates are now auto-generated under the folder ARM from a Bicep template using Github Actions.

## Overview

This OPNsense solution is installed in FreeBSD 12.0 (Azure Image).
Here is what you will see when you deploy this Template:

There are 3 different deployment scenarios:

- Active-Active:
    1) VNET with Two Subnets and OPNsense VM with two NICs.
    2) VNET Address space is: 10.0.0.0/16 (suggested Address space, you may change that).
    3) External NIC named Untrusted Linked to Untrusted-Subnet (10.0.0.0/24).
    4) Internal NIC named Trusted Linked to Trusted-Subnet (10.0.1.0/24).
    5) It creates a NSG named OPN-NSG which allows incoming SSH and HTTPS. Same NSG is associated to both Subnets.
    6) Active-Active a Internal and External loadbalancer will be created.
    7) Two OPNsense firewalls will be created.
    8) OPNsense will be configured to allow loadbalancer probe connection.
    9) OPNsense HA settings will be configured to sync rules changed between both Firewalls.
    10) Option to deploy Windows management VM. (This option requires a management subnet to be created)

- TwoNics:
    1) VNET with Two Subnets and OPNsense VM with two NICs.
    2) VNET Address space is: 10.0.0.0/16 (suggested Address space, you may change that).
    3) External NIC named Untrusted Linked to Untrusted-Subnet (10.0.0.0/24).
    4) Internal NIC named Trusted Linked to Trusted-Subnet (10.0.1.0/24).
    5) It creates a NSG named OPN-NSG which allows incoming SSH and HTTPS. Same NSG is associated to both Subnets.
    6) Option to deploy Windows management VM. (This option requires a management subnet to be created)

- SingleNic:
    1) VNET with single Subnet and OPNsense VM with single NIC.
    2) VNET Address space is: 10.0.0.0/16 (suggested Address space, you may change that).
    3) External NIC named Untrusted Linked to Untrusted-Subnet (10.0.0.0/24).
    4) It creates a NSG named OPN-NSG which allows incoming SSH and HTTPS.
    5) Option to deploy Windows management VM. (This option requires a management subnet to be created)

## Design

Design of two Nic deployment | Design of Active-Active deployment |
|--------|--------|
|![opnsense design](./images/two-nics.png)|![opnsense design](./images/active-active.png)|

## Deployment

Here are few considerations to deploy this solution correctly:

- When you deploy this template, it will leave only TCP 22 listening to Internet while OPNsense gets installed.
- To monitor the installation process during template deployment you can just probe the port 22 on OPNsense VM public IP (psping or tcping).
- When port is down which means OPNsense is installed and VM will get restarted automatically. At this point you will have only TCP 443.

**Note**: It takes about 10 min to complete the whole process when VM is created and a new VM CustomScript is started to install OPNsense.

## Usage

- First access can be done using <HTTPS://PublicIP.> Please ignore SSL/TLS errors and proceed. In case of Active-Active the URL should be <https://PublicIP:50443> for Primary server and <https://PublicIP:50444> for Secondary server.
- Your first login is going to be username "root" and password "opnsense" (**PLEASE change your password right the way**).
- To access SSH you can either deploy a Jumpbox VM on Trusted Subnet or create a Firewall Rule to allow SSH to Internet.
- To send traffic to OPNsense you need to create UDR 0.0.0.0 and set IP of trusted NIC IP (10.0.1.4) as next hop. Associate that NVA to Trusted-Subnet.
- **Note:** It is necessary to create appropriate Firewall rules inside OPNsense to desired traffic to work properly.

## Roadmap

Build custom deployment form

## Feedbacks

Please use Github [issues tab](https://github.com/dmauser/opnazure/issues) to provide feedback.

## Credits

Thanks for direct feedbacks and contributions from: Adam Torkar, Brian Wurzbacher, [Victor Santana](https://github.com/welasco) and Brady Sondreal.
