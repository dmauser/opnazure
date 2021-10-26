param subnetId string
param publicIPId string
param enableIPForwarding bool = false
param nicName string
param nsgId string

resource nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: nicName
  location: resourceGroup().location
  properties: {
    enableIPForwarding: enableIPForwarding
    networkSecurityGroup:{
      id: nsgId
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPId
          }
        }
      }
    ]
  }
}

output nicName string = nic.name
output nicId string = nic.id
output nicIP string = nic.properties.ipConfigurations[0].properties.privateIPAddress
