// Parameters
@sys.description('Select a valid scenario. Active Active: Two OPNSenses deployed in HA mode using SLB and ILB. Two Nics: Single OPNSense deployed with two Nics. Single Nic: Single OPNSense deployed with one Nic.')
@allowed([
  'Active-Active'
  'TwoNics'
  'SingleNic'
])
param scenarioOption string = 'TwoNics'

@sys.description('VM size, please choose a size which allow 2 NICs.')
param virtualMachineSize string = 'Standard_B2s'

@sys.description('OPN NVA Manchine Name')
param virtualMachineName string

@sys.description('Virtual Nework Name. This is a required parameter to build a new VNet or find an existing one.')
param virtualNetworkName string = 'OPN-VNET'

@sys.description('Use Existing Virtual Nework. The value must be new or existing.')
param existingvirtualNetwork string = 'new'

@sys.description('Virtual Network Address Space. Only required if you want to create a new VNet.')
param VNETAddress array = [
  '10.0.0.0/16'
]

@sys.description('Untrusted-Subnet Address Space. Only required if you want to create a new VNet.')
param UntrustedSubnetCIDR string = '10.0.0.0/24'

@sys.description('Trusted-Subnet Address Space. Only required if you want to create a new VNet.')
param TrustedSubnetCIDR string = '10.0.1.0/24'

@sys.description('Untrusted-Subnet Name. Only required if you want to use an existing VNet and Subnet.')
param existingUntrustedSubnetName string = ''

@sys.description('Trusted-Subnet Name. Only required if you want to use an existing VNet and Subnet.')
param existingTrustedSubnetName string = ''

@sys.description('Specify Public IP SKU either Basic (lowest cost) or Standard (Required for HA LB)"')
@allowed([
  'Basic'
  'Standard'
])
param PublicIPAddressSku string = 'Standard'

@sys.description('URI for Custom OPN Script and Config')
param OpnScriptURI string = 'https://raw.githubusercontent.com/dmauser/opnazure/master/scripts/'

@sys.description('Shell Script to be executed')
param ShellScriptName string = 'configureopnsense.sh'

@sys.description('Deploy Windows VM Trusted Subnet')
param DeployWindows bool = false

@sys.description('Only required in case of Deploying Windows VM. Windows Admin username (Used to login in Windows VM).')
param WinUsername string = ''

@sys.description('Only required in case of Deploying Windows VM. Windows Password (Used to login in Windows VM).')
@secure()
param WinPassword string = ''

@sys.description('Existing Windows Subnet Name. Only requried in case of deploying Windows in a exising subnet.')
param existingWindowsSubnet string = ''

@sys.description('In case of deploying Windows in a New VNet this will be the Windows VM Subnet Address Space')
param DeployWindowsSubnet string = '10.0.2.0/24'

param Location string = resourceGroup().location

// Variables
var TempUsername = 'azureuser'
var TempPassword = guid(subscription().id,resourceGroup().id)
var untrustedSubnetName = 'Untrusted-Subnet'
var trustedSubnetName = 'Trusted-Subnet'
var VMOPNsensePrimaryName = '${virtualMachineName}-Primary'
var VMOPNsenseSecondaryName = '${virtualMachineName}-Secondary'
var publicIPAddressName = '${virtualMachineName}-PublicIP'
var networkSecurityGroupName = '${virtualMachineName}-NSG'
var externalLoadBalanceName = 'External-LoadBalance'
var externalLoadBalanceFIPConfName = 'FW'
var externalLoadBalanceBAPName = 'OPNSense'
var externalLoadBalanceProbeName = 'HTTPs'
var externalLoadBalancingRuleName = 'RDP'
var externalLoadBalanceOutRuleName = 'OutBound-OPNSense'
var internalLoadBalanceName = 'Internal-LoadBalance'
var internalLoadBalanceFIPConfName = 'FW'
var internalLoadBalanceBAPName = 'OPNSense'
var internalLoadBalanceProbeName = 'HTTPs'
var internalLoadBalancingRuleName = 'Internal-HA-Port-Rule'
var externalLoadBalanceNatRuleName1 = 'primary-nva-mgmt'
var externalLoadBalanceNatRuleName2 = 'scondary-nva-mgmt'
var useexistingvirtualNetwork = existingvirtualNetwork == 'new' ? false : true

var windowsvmsubnetname = 'Windows-VM-Subnet'
var winvmroutetablename = 'winvmroutetable'
var winvmName = 'VM-Win11Client'
var winvmnetworkSecurityGroupName = '${winvmName}-NSG'
var winvmpublicipName = '${winvmName}-PublicIP'

// Resources
// Create NSG
module nsgopnsense 'modules/vnet/nsg.bicep' = {
  name: networkSecurityGroupName
  params: {
    Location: Location
    nsgName: networkSecurityGroupName
    securityRules: [
      {
        name: 'In-Any'
        properties: {
          priority: 4096
          sourceAddressPrefix: '*'
          protocol: '*'
          destinationPortRange: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Out-Any'
        properties: {
          priority: 4096
          sourceAddressPrefix: '*'
          protocol: '*'
          destinationPortRange: '*'
          access: 'Allow'
          direction: 'Outbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Create VNET
module vnet 'modules/vnet/vnet.bicep' = if(useexistingvirtualNetwork == false) {
  name: virtualNetworkName
  params: {
    location: Location
    vnetAddressSpace: VNETAddress
    vnetName: virtualNetworkName
    subnets: DeployWindows == true && scenarioOption == 'SingleNic' ? [
      {
        name: untrustedSubnetName
        properties: {
          addressPrefix: UntrustedSubnetCIDR
        }
      }
      {
        name: windowsvmsubnetname
        properties: {
          addressPrefix: DeployWindowsSubnet
        }
      }
    ]: DeployWindows == false && scenarioOption == 'SingleNic' ? [
      {
        name: untrustedSubnetName
        properties: {
          addressPrefix: UntrustedSubnetCIDR
        }
      }
    ]: DeployWindows == true ? [
      {
        name: untrustedSubnetName
        properties: {
          addressPrefix: UntrustedSubnetCIDR
        }
      }
      {
        name: trustedSubnetName
        properties: {
          addressPrefix: TrustedSubnetCIDR
        }
      }
      {
        name: windowsvmsubnetname
        properties: {
          addressPrefix: DeployWindowsSubnet
        }
      }
    ]:[
      {
        name: untrustedSubnetName
        properties: {
          addressPrefix: UntrustedSubnetCIDR
        }
      }
      {
        name: trustedSubnetName
        properties: {
          addressPrefix: TrustedSubnetCIDR
        }
      }
    ]
  }
}

// Create OPNsense Public IP
module publicip 'modules/vnet/publicip.bicep' = {
  name: publicIPAddressName
  params: {
    location: Location
    publicipName: publicIPAddressName
    publicipproperties: {
      publicIPAllocationMethod: 'Static'
    }
    publicipsku: {
      name: PublicIPAddressSku
      tier: 'Regional'
    }
  }
}

// Build reference of existing subnets
resource untrustedSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  name: '${virtualNetworkName}/${useexistingvirtualNetwork ? existingUntrustedSubnetName : untrustedSubnetName}'
}

resource trustedSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  name: '${virtualNetworkName}/${useexistingvirtualNetwork ? existingTrustedSubnetName : trustedSubnetName}'
}

resource windowsvmsubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = if (DeployWindows) {
  name: '${virtualNetworkName}/${useexistingvirtualNetwork ? existingWindowsSubnet : windowsvmsubnetname}'
}

// External Load Balancer
module elb 'modules/vnet/lb.bicep' = if(scenarioOption == 'Active-Active'){
  name: externalLoadBalanceName
  params: {
    Location: Location
    lbName: externalLoadBalanceName
    frontendIPConfigurations: [
      {
        name: externalLoadBalanceFIPConfName
        properties: {
          publicIPAddress: {
            id: publicip.outputs.publicipId
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: externalLoadBalanceBAPName
      }
    ]
    loadBalancingRules: [
      {
        name: externalLoadBalancingRuleName
        properties: {
          frontendPort: 3389
          backendPort: 3389
          enableFloatingIP: true
          protocol: 'Tcp'
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', externalLoadBalanceName, externalLoadBalanceFIPConfName)
          }
          disableOutboundSnat: true
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', externalLoadBalanceName, externalLoadBalanceBAPName)
          }
          backendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', externalLoadBalanceName, externalLoadBalanceBAPName)
            }
          ]
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', externalLoadBalanceName, externalLoadBalanceProbeName)
          }
        }
      }
    ]
    inboundNatRules: [
      {
        name: externalLoadBalanceNatRuleName1
        properties: {
          frontendPort: 50443
          backendPort: 443
          protocol: 'Tcp'
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', externalLoadBalanceName, externalLoadBalanceFIPConfName)
          }
        }
      }
      {
        name: externalLoadBalanceNatRuleName2
        properties: {
          frontendPort: 50444
          backendPort: 443
          protocol: 'Tcp'
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', externalLoadBalanceName, externalLoadBalanceFIPConfName)
          }
        }
      }
    ]
    probe: [
      {
        name: externalLoadBalanceProbeName
        properties: {
          port: 443
          protocol: 'Tcp'
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    outboundRules: [
      {
        name: externalLoadBalanceOutRuleName
        properties: {
          allocatedOutboundPorts: 0
          idleTimeoutInMinutes: 4
          enableTcpReset: true
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', externalLoadBalanceName, externalLoadBalanceBAPName)
          }
          frontendIPConfigurations: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', externalLoadBalanceName, externalLoadBalanceFIPConfName)
            }
          ]
          protocol: 'All'
        }
      }
    ]
  }
}

// Internal Load Balancer
module ilb 'modules/vnet/lb.bicep' = if(scenarioOption == 'Active-Active'){
  name: internalLoadBalanceName
  params: {
    Location: Location
    lbName: internalLoadBalanceName
    frontendIPConfigurations: [
      {
        name: internalLoadBalanceFIPConfName
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: trustedSubnet.id
          }
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    backendAddressPools: [
      {
        name: internalLoadBalanceBAPName
      }
    ]
    loadBalancingRules: [
      {
        name: internalLoadBalancingRuleName
        properties: {
          frontendPort: 0
          backendPort: 0
          protocol: 'All'
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', internalLoadBalanceName, internalLoadBalanceFIPConfName)
          }
          disableOutboundSnat: true
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', internalLoadBalanceName, internalLoadBalanceBAPName)
          }
          backendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', internalLoadBalanceName, internalLoadBalanceBAPName)
            }
          ]
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', internalLoadBalanceName, internalLoadBalanceProbeName)
          }
        }
      }
    ]
    probe: [
      {
        name: internalLoadBalanceProbeName
        properties: {
          port: 443
          protocol: 'Tcp'
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
  }
  dependsOn: [
    vnet
    nsgopnsense
    publicip
  ]
}

// Create OPNSense Active-Active
// Create OPNsense Secondary
module opnSenseSecondary 'modules/VM/opnsense.bicep' = if(scenarioOption == 'Active-Active'){
  name: VMOPNsenseSecondaryName
  params: {
    Location: Location
    //ShellScriptParameters: '${OpnScriptURI} Secondary ${trustedSubnet.properties.addressPrefix} ${DeployWindows ? windowsvmsubnet.properties.addressPrefix : '1.1.1.1/32'} ${publicip.outputs.publicipAddress}'
    ShellScriptObj: {
      'OpnScriptURI': OpnScriptURI
      'OpnType': 'Secondary'
      'TrustedSubnetName': scenarioOption != 'SingleNic' ? '${virtualNetworkName}/${useexistingvirtualNetwork ? existingTrustedSubnetName : trustedSubnetName}' : ''
      'WindowsSubnetName': DeployWindows ? '${virtualNetworkName}/${useexistingvirtualNetwork ? existingWindowsSubnet : windowsvmsubnetname}' : ''
      'publicIPAddress': publicip.outputs.publicipAddress
      'opnSenseSecondarytrustedNicIP': ''
    }
    OPNScriptURI: OpnScriptURI
    ShellScriptName: ShellScriptName
    TempPassword: TempPassword
    TempUsername: TempUsername
    multiNicSupport: true
    trustedSubnetId: trustedSubnet.id
    untrustedSubnetId: untrustedSubnet.id
    virtualMachineName: VMOPNsenseSecondaryName
    virtualMachineSize: virtualMachineSize
    nsgId: nsgopnsense.outputs.nsgID
    ExternalLoadBalancerBackendAddressPoolId: scenarioOption == 'Active-Active' ? elb.outputs.backendAddressPools[0].id : ''
    InternalLoadBalancerBackendAddressPoolId: scenarioOption == 'Active-Active' ? ilb.outputs.backendAddressPools[0].id : ''
    ExternalloadBalancerInboundNatRulesId: scenarioOption == 'Active-Active' ? elb.outputs.inboundNatRules[1].id : ''
  }
  dependsOn: [
    vnet
    nsgopnsense
    untrustedSubnet
    trustedSubnet
    windowsvmsubnet
  ]
}

// Create OPNsense Primary
module opnSensePrimary 'modules/VM/opnsense.bicep' = if(scenarioOption == 'Active-Active'){
  name: VMOPNsensePrimaryName
  params: {
    Location: Location
    //ShellScriptParameters: '${OpnScriptURI} Primary ${TrustedSubnetCIDR} ${DeployWindows ? windowsvmsubnet.properties.addressPrefix : '1.1.1.1/32'} ${publicip.outputs.publicipAddress} ${opnSenseSecondary.outputs.trustedNicIP}'
    ShellScriptObj: {
      'OpnScriptURI': OpnScriptURI
      'OpnType': 'Primary'
      'TrustedSubnetName': scenarioOption != 'SingleNic' ? '${virtualNetworkName}/${useexistingvirtualNetwork ? existingTrustedSubnetName : trustedSubnetName}' : ''
      'WindowsSubnetName': DeployWindows ? '${virtualNetworkName}/${useexistingvirtualNetwork ? existingWindowsSubnet : windowsvmsubnetname}' : ''
      'publicIPAddress': publicip.outputs.publicipAddress
      'opnSenseSecondarytrustedNicIP': scenarioOption == 'Active-Active' ? opnSenseSecondary.outputs.trustedNicIP : ''
    }
    OPNScriptURI: OpnScriptURI
    ShellScriptName: ShellScriptName
    TempPassword: TempPassword
    TempUsername: TempUsername
    multiNicSupport: true
    trustedSubnetId: trustedSubnet.id
    untrustedSubnetId: untrustedSubnet.id
    virtualMachineName: VMOPNsensePrimaryName
    virtualMachineSize: virtualMachineSize
    nsgId: nsgopnsense.outputs.nsgID
    ExternalLoadBalancerBackendAddressPoolId: scenarioOption == 'Active-Active' ? elb.outputs.backendAddressPools[0].id : ''
    InternalLoadBalancerBackendAddressPoolId: scenarioOption == 'Active-Active' ? ilb.outputs.backendAddressPools[0].id : ''
    ExternalloadBalancerInboundNatRulesId: scenarioOption == 'Active-Active' ? elb.outputs.inboundNatRules[0].id : ''
  }
  dependsOn: [
    vnet
    nsgopnsense
    opnSenseSecondary
  ]
}

// Create OPNsense TwoNics
module opnSenseTwoNics 'modules/VM/opnsense.bicep' = if(scenarioOption == 'TwoNics'){
  name: '${virtualMachineName}-TwoNics'
  params: {
    Location: Location
    //ShellScriptParameters: '${OpnScriptURI} TwoNics ${trustedSubnet.properties.addressPrefix} ${DeployWindows ? windowsvmsubnet.properties.addressPrefix: '1.1.1.1/32'}'
    ShellScriptObj: {
      'OpnScriptURI': OpnScriptURI
      'OpnType': 'TwoNics'
      'TrustedSubnetName': scenarioOption != 'SingleNic' ? '${virtualNetworkName}/${useexistingvirtualNetwork ? existingTrustedSubnetName : trustedSubnetName}' : ''
      'WindowsSubnetName': DeployWindows ? '${virtualNetworkName}/${useexistingvirtualNetwork ? existingWindowsSubnet : windowsvmsubnetname}' : ''
      'publicIPAddress': ''
      'opnSenseSecondarytrustedNicIP': ''
    }
    OPNScriptURI: OpnScriptURI
    ShellScriptName: ShellScriptName
    TempPassword: TempPassword
    TempUsername: TempUsername
    multiNicSupport: true
    trustedSubnetId: trustedSubnet.id
    untrustedSubnetId: untrustedSubnet.id
    virtualMachineName: virtualMachineName
    virtualMachineSize: virtualMachineSize
    publicIPId: publicip.outputs.publicipId
    nsgId: nsgopnsense.outputs.nsgID
  }
  dependsOn: [
    vnet
    nsgopnsense
    trustedSubnet
  ]
}

// Create OPNSense SingleNic
module opnSenseSingleNic 'modules/VM/opnsense.bicep' = if(scenarioOption == 'SingleNic'){
  name: '${virtualMachineName}-SingleNic'
  params: {
    Location: Location
    //ShellScriptParameters: '${OpnScriptURI} SingNic'
    ShellScriptObj: {
      'OpnScriptURI': OpnScriptURI
      'OpnType': 'SingleNic'
      'TrustedSubnetName': ''
      'WindowsSubnetName': ''
      'publicIPAddress': ''
      'opnSenseSecondarytrustedNicIP': ''
    }
    OPNScriptURI: OpnScriptURI
    ShellScriptName: ShellScriptName
    TempPassword: TempPassword
    TempUsername: TempUsername
    multiNicSupport: false
    untrustedSubnetId: untrustedSubnet.id
    virtualMachineName: virtualMachineName
    virtualMachineSize: virtualMachineSize
    publicIPId: publicip.outputs.publicipId
    nsgId: nsgopnsense.outputs.nsgID
  }
  dependsOn: [
    vnet
    nsgopnsense
  ]
}

// Windows11 Client Resources
module nsgwinvm 'modules/vnet/nsg.bicep' = if (DeployWindows) {
  name: winvmnetworkSecurityGroupName
  params: {
    Location: Location
    nsgName: winvmnetworkSecurityGroupName
    securityRules: [
      {
        name: 'RDP'
        properties: {
          priority: 4096
          sourceAddressPrefix: '*'
          protocol: 'Tcp'
          destinationPortRange: '3389'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Out-Any'
        properties: {
          priority: 4096
          sourceAddressPrefix: '*'
          protocol: '*'
          destinationPortRange: '*'
          access: 'Allow'
          direction: 'Outbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
  dependsOn: [
    opnSenseSecondary
    opnSensePrimary
    opnSenseTwoNics
    opnSenseSingleNic
  ]
}

module winvmpublicip 'modules/vnet/publicip.bicep' = if (DeployWindows) {
  name: winvmpublicipName
  params: {
    location: Location
    publicipName: winvmpublicipName
    publicipproperties: {
      publicIPAllocationMethod: 'Static'
    }
    publicipsku: {
      name: PublicIPAddressSku
      tier: 'Regional'
    }
  }
  dependsOn: [
    opnSenseSecondary
    opnSensePrimary
    opnSenseTwoNics
    opnSenseSingleNic
  ]
}

module winvmroutetable 'modules/vnet/routetable.bicep' = if (DeployWindows) {
  name: winvmroutetablename
  params: {
    location: Location
    rtName: winvmroutetablename
  }
  dependsOn: [
    opnSenseSecondary
    opnSensePrimary
    opnSenseTwoNics
    opnSenseSingleNic
  ]
}

module winvmroutetableroutes 'modules/vnet/routetableroutes.bicep' = if (DeployWindows) {
  name: '${winvmroutetablename}-default'
  params: {
    routetableName: winvmroutetablename
    routeName: 'default'
    properties: {
      nextHopType: 'VirtualAppliance'
      nextHopIpAddress: scenarioOption == 'Active-Active' ? ilb.outputs.frontendIP.privateIPAddress : scenarioOption == 'TwoNics' ? opnSenseTwoNics.outputs.trustedNicIP : scenarioOption == 'SingleNic' ? opnSenseSingleNic.outputs.untrustedNicIP : ''
      addressPrefix: '0.0.0.0/0'
    }
  }
  dependsOn: [
    winvmroutetable
  ]
}

module winvm 'modules/VM/windows11-vm.bicep' = if (DeployWindows) {
  name: winvmName
  params: {
    Location: Location
    nsgId: DeployWindows ? nsgwinvm.outputs.nsgID : ''
    publicIPId: DeployWindows ? winvmpublicip.outputs.publicipId : ''
    TempUsername: WinUsername
    TempPassword: WinPassword
    trustedSubnetId: windowsvmsubnet.id
    virtualMachineName: winvmName
    virtualMachineSize: 'Standard_B4ms'
  }
  dependsOn: [
    nsgwinvm
    winvmpublicip
    opnSenseSecondary
    opnSensePrimary
    opnSenseTwoNics
    opnSenseSingleNic
  ]
}
