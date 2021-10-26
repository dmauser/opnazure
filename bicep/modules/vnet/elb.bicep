param lbName string
param fIPconName string = 'FW'
param publicIPId string
param backendAddressPools array
param loadBalancingRules array
param outboundRules array
param probe array

resource elb 'Microsoft.Network/loadBalancers@2021-03-01' = {
  name: lbName
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties:{
    frontendIPConfigurations: [
      {
        name: fIPconName
        properties: {
          publicIPAddress: {
            id: publicIPId
          }
        }
      }
    ]
    backendAddressPools: backendAddressPools
    loadBalancingRules: loadBalancingRules
    probes: probe
    outboundRules: outboundRules
  }
}
