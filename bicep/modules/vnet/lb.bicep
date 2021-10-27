param lbName string
param frontendIPConfigurations array
param backendAddressPools array
param loadBalancingRules array
param outboundRules array = []
param probe array

resource elb 'Microsoft.Network/loadBalancers@2021-03-01' = {
  name: lbName
  location: resourceGroup().location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties:{
    frontendIPConfigurations: frontendIPConfigurations
    backendAddressPools: backendAddressPools
    loadBalancingRules: loadBalancingRules
    probes: probe
    outboundRules: outboundRules
  }
}
