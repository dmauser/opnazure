// Parameters
@sys.description('VM size, please choose a size which allow 2 NICs.')
param virtualMachineSize string = 'Standard_B2s'

@sys.description('OPN NVA Manchine Name')
param virtualMachineName string

@sys.description('Default Temporary Admin username (Only used to deploy FreeBSD VM)')
param TempUsername string

@sys.description('Default Temporary Admin password (Only used to deploy FreeBSD VM)')
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

@sys.description('OPNSense XML Config File')
param OpnConfigFile string = 'config.xml'

// Variables
var untrustedSubnetName = 'Untrusted-Subnet'
var trustedSubnetName = 'Trusted-Subnet'
var publicIPAddressName = '${virtualMachineName}-PublicIP'
var networkSecurityGroupName = '${virtualMachineName}-NSG'
var externalLoadBalanceName = 'External-LoadBalance'
var externalLoadBalanceFIPConfName = 'FW'
var externalLoadBalanceBAPName = 'OPNSense'
var externalLoadBalanceProbeName = 'DNS'
var externalLoadBalancingRuleName = 'WEB'
var externalLoadBalanceOutRuleName = 'OutBound-OPNSense'
var internalLoadBalanceName = 'Internal-LoadBalance'
var internalLoadBalanceFIPConfName = 'FW'
var internalLoadBalanceBAPName = 'OPNSense'
var internalLoadBalanceProbeName = 'SSH'
var internalLoadBalancingRuleName = 'Internal-HA-Port-Rule"'

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
module opnSense1 'modules/VM/virtualmachine-active-active.bicep' = {
  name: '${virtualMachineName}-1'
  params: {
    OPNConfigFile: OpnConfigFile
    OPNScriptURI: OpnScriptURI
    ShellScriptName: ShellScriptName
    TempPassword: TempPassword
    TempUsername: TempUsername
    trustedSubnetId: trustedSubnet.id
    untrustedSubnetId: untrustedSubnet.id
    virtualMachineName: '${virtualMachineName}-1'
    virtualMachineSize: virtualMachineSize
    nsgId: nsgappgwsubnet.outputs.nsgID
  }
  dependsOn:[
    vnet
    nsgappgwsubnet
  ]
}

module opnSense2 'modules/VM/virtualmachine-active-active.bicep' = {
  name: '${virtualMachineName}-2'
  params: {
    OPNConfigFile: OpnConfigFile
    OPNScriptURI: OpnScriptURI
    ShellScriptName: ShellScriptName
    TempPassword: TempPassword
    TempUsername: TempUsername
    trustedSubnetId: trustedSubnet.id
    untrustedSubnetId: untrustedSubnet.id
    virtualMachineName: '${virtualMachineName}-2'
    virtualMachineSize: virtualMachineSize
    nsgId: nsgappgwsubnet.outputs.nsgID
  }
  dependsOn:[
    vnet
    nsgappgwsubnet
    opnSense1
  ]
}

// External Load Balancer
module elb 'modules/vnet/lb.bicep' = {
  name: externalLoadBalanceName
  params: {
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
        properties: {
          loadBalancerBackendAddresses:[
            {
              name: guid('guid1')
              properties: {
                ipAddress: opnSense1.outputs.untrustedNicIP
                virtualNetwork: {
                  id: vnet.outputs.vnetId
                }
              }
            }
            {
              name: guid('guid2')
              properties: {
                ipAddress: opnSense2.outputs.untrustedNicIP
                virtualNetwork: {
                  id: vnet.outputs.vnetId
                }
              }
            }
          ]
        }
      }
    ]
    loadBalancingRules: [
      {
        name: externalLoadBalancingRuleName
        properties:{
          frontendPort: 4443
          backendPort: 443
          protocol: 'Tcp'
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/', externalLoadBalanceName, 'frontendIPConfigurations', externalLoadBalanceFIPConfName)
          }
          disableOutboundSnat: true
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/', externalLoadBalanceName, 'backendAddressPools', externalLoadBalanceBAPName)
          }
          backendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/', externalLoadBalanceName, 'backendAddressPools', externalLoadBalanceBAPName)
            }
          ]
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/', externalLoadBalanceName, 'probes', externalLoadBalanceProbeName)
          }

        }
      }
    ]
    probe:[
      {
        name: externalLoadBalanceProbeName
        properties: {
          port: 53
          protocol: 'Tcp'
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    outboundRules: [
      {
        name: externalLoadBalanceOutRuleName
        properties:{
          allocatedOutboundPorts: 0
          idleTimeoutInMinutes: 4
          enableTcpReset: true
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/', externalLoadBalanceName, 'backendAddressPools', externalLoadBalanceBAPName)
          }
          frontendIPConfigurations: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/', externalLoadBalanceName, 'frontendIPConfigurations', externalLoadBalanceFIPConfName)
            }
          ]
          protocol: 'All'
        }
      }
    ]
  }
}

// Internal Load Balancer
module ilb 'modules/vnet/lb.bicep' = {
  name: internalLoadBalanceName
  params: {
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
        properties: {
          loadBalancerBackendAddresses:[
            {
              name: guid('guid1internal')
              properties: {
                ipAddress: opnSense1.outputs.trustedNicIP
                virtualNetwork: {
                  id: vnet.outputs.vnetId
                }
              }
            }
            {
              name: guid('guid2internal')
              properties: {
                ipAddress: opnSense2.outputs.trustedNicIP
                virtualNetwork: {
                  id: vnet.outputs.vnetId
                }
              }
            }
          ]
        }
      }
    ]

    loadBalancingRules: [
      {
        name: internalLoadBalancingRuleName
        properties:{
          frontendPort: 0
          backendPort: 0
          protocol: 'All'
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/', internalLoadBalanceName, 'frontendIPConfigurations', internalLoadBalanceFIPConfName)
          }
          disableOutboundSnat: true
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/', internalLoadBalanceName, 'backendAddressPools', internalLoadBalanceBAPName)
          }
          backendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/', internalLoadBalanceName, 'backendAddressPools', internalLoadBalanceBAPName)
            }
          ]
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/', internalLoadBalanceName, 'probes', internalLoadBalanceProbeName)
          }

        }
      }
    ]
    probe: [
      {
        name: internalLoadBalanceProbeName
        properties: {
          port: 22
          protocol: 'Tcp'
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
  }
}



// resource elb1 'Microsoft.Network/loadBalancers@2021-03-01' = {
//   name: externalLoadBalanceName
//   sku: {
//     name: 'Standard'
//     tier: 'Regional'
//   }
//   properties:{
//     frontendIPConfigurations: [
//       {
//         name: externalLoadBalanceFIPConfName
//         properties: {
//           publicIPAddress: {
//             id: publicip.outputs.publicipId
//           }
//         }
//       }
//     ]
//     backendAddressPools: [
//       {
//         name: externalLoadBalanceBAPName
//         properties: {
//           loadBalancerBackendAddresses:[
//             {
//               name: guid('guid1')
//               properties: {
//                 ipAddress: opnSense1.outputs.untrustedNicIP
//                 virtualNetwork: {
//                   id: vnet.outputs.vnetId
//                 }
//               }
//             }
//             {
//               name: guid('guid2')
//               properties: {
//                 ipAddress: opnSense2.outputs.untrustedNicIP
//                 virtualNetwork: {
//                   id: vnet.outputs.vnetId
//                 }
//               }
//             }
//           ]
//         }
//       }
//     ]
//     loadBalancingRules: [
//       {
//         name: 'WEB'
//         properties:{
//           frontendPort: 4443
//           backendPort: 443
//           protocol: 'Tcp'
//           frontendIPConfiguration: {
//             id: resourceId('Microsoft.Network/loadBalancers/', externalLoadBalanceName, 'frontendIPConfigurations', externalLoadBalanceFIPConfName)
//           }
//           disableOutboundSnat: true
//           backendAddressPool: {
//             id: resourceId('Microsoft.Network/loadBalancers/', externalLoadBalanceName, 'backendAddressPools', externalLoadBalanceBAPName)
//           }
//           backendAddressPools: [
//             {
//               id: resourceId('Microsoft.Network/loadBalancers/', externalLoadBalanceName, 'backendAddressPools', externalLoadBalanceBAPName)
//             }
//           ]
//           probe: {
//             id: resourceId('Microsoft.Network/loadBalancers/', externalLoadBalanceName, 'probes', externalLoadBalanceProbeName)
//           }

//         }
//       }
//     ]
//     probes: [
//       {
//         name: externalLoadBalanceProbeName
//         properties: {
//           port: 53
//           protocol: 'Tcp'
//           intervalInSeconds: 5
//           numberOfProbes: 2
//         }
//       }
//     ]
//     outboundRules: [
//       {
//         name: externalLoadBalanceOutRuleName
//         properties:{
//           allocatedOutboundPorts: 0
//           idleTimeoutInMinutes: 4
//           enableTcpReset: true
//           backendAddressPool: {
//             id: resourceId('Microsoft.Network/loadBalancers/', externalLoadBalanceName, 'backendAddressPools', externalLoadBalanceBAPName)
//           }
//           frontendIPConfigurations: [
//             {
//               id: resourceId('Microsoft.Network/loadBalancers/', externalLoadBalanceName, 'frontendIPConfigurations', externalLoadBalanceFIPConfName)
//             }
//           ]
//           protocol: 'All'
//         }
//       }
//     ]
//   }
// }

// resource ilb 'Microsoft.Network/loadBalancers@2021-03-01' = {
//   name: internalLoadBalanceName
//   sku: {
//     name: 'Standard'
//     tier: 'Regional'
//   }
//   properties:{
//     frontendIPConfigurations: [
//       {
//         name: internalLoadBalanceFIPConfName
//         properties: {
//           privateIPAllocationMethod: 'Dynamic'
//           subnet: {
//             id: trustedSubnet.id
//           }
//           privateIPAddressVersion: 'IPv4'
//         }
//       }
//     ]
//     backendAddressPools: [
//       {
//         name: internalLoadBalanceBAPName
//         properties: {
//           loadBalancerBackendAddresses:[
//             {
//               name: guid('guid1internal')
//               properties: {
//                 ipAddress: opnSense1.outputs.trustedNicIP
//                 virtualNetwork: {
//                   id: vnet.outputs.vnetId
//                 }
//               }
//             }
//             {
//               name: guid('guid2internal')
//               properties: {
//                 ipAddress: opnSense2.outputs.trustedNicIP
//                 virtualNetwork: {
//                   id: vnet.outputs.vnetId
//                 }
//               }
//             }
//           ]
//         }
//       }
//     ]
//     loadBalancingRules: [
//       {
//         name: internalLoadBalancingRuleName
//         properties:{
//           frontendPort: 0
//           backendPort: 0
//           protocol: 'All'
//           frontendIPConfiguration: {
//             id: resourceId('Microsoft.Network/loadBalancers/', internalLoadBalanceName, 'frontendIPConfigurations', internalLoadBalanceFIPConfName)
//           }
//           disableOutboundSnat: true
//           backendAddressPool: {
//             id: resourceId('Microsoft.Network/loadBalancers/', internalLoadBalanceName, 'backendAddressPools', internalLoadBalanceBAPName)
//           }
//           backendAddressPools: [
//             {
//               id: resourceId('Microsoft.Network/loadBalancers/', internalLoadBalanceName, 'backendAddressPools', internalLoadBalanceBAPName)
//             }
//           ]
//           probe: {
//             id: resourceId('Microsoft.Network/loadBalancers/', internalLoadBalanceName, 'probes', internalLoadBalanceProbeName)
//           }

//         }
//       }
//     ]
//     probes: [
//       {
//         name: internalLoadBalanceProbeName
//         properties: {
//           port: 22
//           protocol: 'Tcp'
//           intervalInSeconds: 5
//           numberOfProbes: 2
//         }
//       }
//     ]
//   }
// }


// module elb 'modules/vnet/elb.bicep' = {
//   name: externalLoadBalanceName
//   params: {
//     lbName: externalLoadBalanceName
//     publicIPId: publicip.outputs.publicipId
//     fIPconName: externalLoadBalanceFIPConfName
//     backendAddressPools: [
//       {
//         name: externalLoadBalanceBAPName
//         properties: {
//           loadBalancerBackendAddresses:[
//             {
//               name: guid('guid1')
//               properties: {
//                 ipAddress: opnSense1.outputs.untrustedNicIP
//                 virtualNetwork: {
//                   id: vnet.outputs.vnetId
//                 }
//               }
//             }
//             {
//               name: guid('guid2')
//               properties: {
//                 ipAddress: opnSense2.outputs.untrustedNicIP
//                 virtualNetwork: {
//                   id: vnet.outputs.vnetId
//                 }
//               }
//             }
//           ]
//         }
//       }
//     ]
//     loadBalancingRules: [
//       {
//         name: externalLoadBalancingRuleName
//         properties:{
//           frontendPort: 4443
//           backendPort: 443
//           protocol: 'Tcp'
//           frontendIPConfiguration: {
//             id: resourceId('Microsoft.Network/loadBalancers/', externalLoadBalanceName, 'frontendIPConfigurations', externalLoadBalanceFIPConfName)
//           }
//           disableOutboundSnat: true
//           backendAddressPool: {
//             id: resourceId('Microsoft.Network/loadBalancers/', externalLoadBalanceName, 'backendAddressPools', externalLoadBalanceBAPName)
//           }
//           backendAddressPools: [
//             {
//               id: resourceId('Microsoft.Network/loadBalancers/', externalLoadBalanceName, 'backendAddressPools', externalLoadBalanceBAPName)
//             }
//           ]
//           probe: {
//             id: resourceId('Microsoft.Network/loadBalancers/', externalLoadBalanceName, 'probes', externalLoadBalanceProbeName)
//           }

//         }
//       }
//     ]
//     probe:[
//       {
//         name: externalLoadBalanceProbeName
//         properties: {
//           port: 53
//           protocol: 'Tcp'
//           intervalInSeconds: 5
//           numberOfProbes: 2
//         }
//       }
//     ]
//     outboundRules: [
//       {
//         name: externalLoadBalanceOutRuleName
//         properties:{
//           allocatedOutboundPorts: 0
//           idleTimeoutInMinutes: 4
//           enableTcpReset: true
//           backendAddressPool: {
//             id: resourceId('Microsoft.Network/loadBalancers/', externalLoadBalanceName, 'backendAddressPools', externalLoadBalanceBAPName)
//           }
//           frontendIPConfigurations: [
//             {
//               id: resourceId('Microsoft.Network/loadBalancers/', externalLoadBalanceName, 'frontendIPConfigurations', externalLoadBalanceFIPConfName)
//             }
//           ]
//           protocol: 'All'
//         }
//       }
//     ]
//   }
// }