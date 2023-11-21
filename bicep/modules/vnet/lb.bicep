param lbName string
param frontendIPConfigurations array = []
param backendAddressPools array = []
param loadBalancingRules array = []
param outboundRules array = []
param inboundNatRules array = []
param probe array = []
param Location string = resourceGroup().location

resource lb 'Microsoft.Network/loadBalancers@2023-05-01' = {
  name: lbName
  location: Location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties:{
    frontendIPConfigurations: frontendIPConfigurations
    backendAddressPools: backendAddressPools
    loadBalancingRules: loadBalancingRules
    inboundNatRules: inboundNatRules
    probes: probe
    outboundRules: outboundRules
  }
}

output backendAddressPools array = lb.properties.backendAddressPools
//output frontendIP string = contains(lb.properties.frontendIPConfigurations[0].properties.privateIPAddress,'.') ? '' :lb.properties.frontendIPConfigurations[0].properties.privateIPAddress
//output test string = lb.properties.frontendIPConfigurations[0].privateIPAddress
output frontendIP object = lb.properties.frontendIPConfigurations[0].properties
output inboundNatRules array = lb.properties.inboundNatRules
