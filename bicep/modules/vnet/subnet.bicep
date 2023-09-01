param vnetName string
param subnetName string
param properties object

resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = {
  name: '${vnet.name}/${subnetName}'
   properties: properties
}

output subnetId string = subnet.id
