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

@sys.description('Untrusted-Subnet Address Space')
param UntrustedSubnetCIDR string = '10.0.0.0/24'

@sys.description('Trusted-Subnet Address Space')
param TrustedSubnetCIDR string = '10.0.1.0/24'

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

// Variables
var untrustedSubnetName = 'Untrusted-Subnet'
var trustedSubnetName = 'Trusted-Subnet'
var publicIPAddressName = '${virtualMachineName}-PublicIP'
var networkSecurityGroupName = '${virtualMachineName}-NSG'

var winvmName = 'VM-Win11Client'
var winvmnetworkSecurityGroupName = '${winvmName}-NSG'
var winvmpublicipName = '${winvmName}-PublicIP'

// Resources
// Create NSG
module nsgappgwsubnet 'modules/vnet/nsg.bicep' = {
  name: networkSecurityGroupName
  params: {
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
    vnetAddressSpace: VNETAddress
    vnetName: virtualNetworkName
    subnets: [
      {
        name: untrustedSubnetName
        properties:{
          addressPrefix: UntrustedSubnetCIDR
        }
      }
      {
        name: trustedSubnetName
        properties:{
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
  name: '${virtualNetworkName}/${untrustedSubnetName}'
}

resource trustedSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  name: '${virtualNetworkName}/${trustedSubnetName}'
}

// Create OPNsense
module opnSense 'modules/VM/opnsense-vm.bicep' = {
  name: virtualMachineName
  params: {
    ShellScriptParameters: '${OpnScriptURI} TwoNics'
    OPNScriptURI: OpnScriptURI
    ShellScriptName: ShellScriptName
    TempPassword: TempPassword
    TempUsername: TempUsername
    trustedSubnetId: trustedSubnet.id
    untrustedSubnetId: untrustedSubnet.id
    virtualMachineName: virtualMachineName
    virtualMachineSize: virtualMachineSize
    publicIPId: publicip.outputs.publicipId
    nsgId: nsgappgwsubnet.outputs.nsgID
  }
  dependsOn:[
    vnet
    nsgappgwsubnet
  ]
}

// Windows11 Client Resources
module nsgwinvm 'modules/vnet/nsg.bicep' = if (DeployWindows) {
  name: winvmnetworkSecurityGroupName
  params: {
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
  dependsOn:[
    opnSense
  ]
}

module winvmpublicip 'modules/vnet/publicip.bicep' = if (DeployWindows) {
  name: winvmpublicipName
  params: {
    publicipName: winvmpublicipName
    publicipproperties: {
      publicIPAllocationMethod: 'Static'
    }
    publicipsku: {
      name: PublicIPAddressSku
      tier: 'Regional'
    }
  }
  dependsOn:[
    opnSense
  ]
}

module winvm 'modules/VM/windows11-vm.bicep' = if (DeployWindows) {
  name: winvmName
  params: {
    nsgId: nsgwinvm.outputs.nsgID
    publicIPId: winvmpublicip.outputs.publicipId
    TempPassword: TempPassword
    TempUsername: TempUsername
    trustedSubnetId: trustedSubnet.id
    virtualMachineName: winvmName
    virtualMachineSize: 'Standard_B4ms'
  }
  dependsOn:[
    opnSense
  ]
}
