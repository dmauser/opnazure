param lbName string
param properties object
param Location string = resourceGroup().location

resource lb 'Microsoft.Network/loadBalancers@2021-03-01' = {
  name: lbName
  location: Location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: properties
}

output backendAddressPools array = lb.properties.backendAddressPools
//output frontendIP string = contains(lb.properties.frontendIPConfigurations[0].properties.privateIPAddress,'.') ? '' :lb.properties.frontendIPConfigurations[0].properties.privateIPAddress
//output test string = lb.properties.frontendIPConfigurations[0].privateIPAddress
output frontendIP object = lb.properties.frontendIPConfigurations[0].properties
