// Parameters
@sys.description('VM size, please choose a size which allow 2 NICs.')
param virtualMachineSize string = 'Standard_B2s'

@sys.description('OPN NVA Manchine Name')
param virtualMachineName string

@sys.description('Default Temporary Admin username (Used for JumpBox and temporarily deploy FreeBSD VM).')
param TempUsername string

@sys.description('Default Temporary Admin password (Used for JumpBox and temporarily deploy FreeBSD VM).')
@secure()
param TempPassword string

@sys.description('Virtual Nework Name')
param virtualNetworkName string = 'OPN-VNET'

@sys.description('Virtual Address Space')
param VNETAddress array = [
  '10.0.0.0/16'
]

@sys.description('OPNsense subnet name')
param OpnsenseSubnetName string = 'OPNSenseSubnet'

@sys.description('OPNsense subnet Address Space')
param OpnsenseSubnetCIDR string = '10.0.0.0/24'

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

@sys.description('In case of deploying Windows, this is the Windows VM Subnet Address Space')
param DeployWindowsSubnet string = '10.0.2.0/24'
param Location string = resourceGroup().location

// Variables
var publicIPAddressName = '${virtualMachineName}-PublicIP'
var networkSecurityGroupName = '${virtualMachineName}-NSG'

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
module vnet 'modules/vnet/vnet.bicep' = {
  name: virtualNetworkName
  params: {
    location: Location
    vnetAddressSpace: VNETAddress
    vnetName: virtualNetworkName
    subnets: DeployWindows == true ? [
      {
        name: OpnsenseSubnetName
        properties: {
          addressPrefix: OpnsenseSubnetCIDR
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
        name: OpnsenseSubnetName
        properties: {
          addressPrefix: OpnsenseSubnetCIDR
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
resource OpnsenseSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  name: '${virtualNetworkName}/${OpnsenseSubnetName}'
}

resource windowsvmsubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = if (DeployWindows) {
  name: '${virtualNetworkName}/${windowsvmsubnetname}'
}

// Create OPNsense
module opnSense 'modules/VM/opnsense-vm-sing-nic.bicep' = {
  name: virtualMachineName
  params: {
    Location: Location
    ShellScriptParameters: '${OpnScriptURI} SingNic'
    OPNScriptURI: OpnScriptURI
    ShellScriptName: ShellScriptName
    TempPassword: TempPassword
    TempUsername: TempUsername
    subnetId: OpnsenseSubnet.id
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
    opnSense
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
    opnSense
  ]
}

module winvmroutetable 'modules/vnet/routetable.bicep' = if (DeployWindows) {
  name: winvmroutetablename
  params: {
    location: Location
    rtName: winvmroutetablename
  }
  dependsOn: [
    opnSense
  ]
}

module winvmroutetableroutes 'modules/vnet/routetableroutes.bicep' = if (DeployWindows) {
  name: 'default'
  params: {
    routetableName: winvmroutetablename
    routeName: 'default'
    properties: {
      nextHopType: 'VirtualAppliance'
      nextHopIpAddress: opnSense.outputs.untrustedNicIP
      addressPrefix: '0.0.0.0/0'
    }
  }
  dependsOn: [
    opnSense
    winvmroutetable
  ]
}
module winvm 'modules/VM/windows11-vm.bicep' = if (DeployWindows) {
  name: winvmName
  params: {
    Location: Location
    nsgId: DeployWindows ? nsgwinvm.outputs.nsgID : ''
    publicIPId: DeployWindows ? winvmpublicip.outputs.publicipId : ''
    TempPassword: TempPassword
    TempUsername: TempUsername
    trustedSubnetId: OpnsenseSubnet.id
    virtualMachineName: winvmName
    virtualMachineSize: 'Standard_B4ms'
  }
  dependsOn: [
    opnSense
    nsgwinvm
    winvmpublicip
  ]
}
