param publicipName string
param publicipsku object
param publicipproperties object
param location string = resourceGroup().location

resource publicip 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: publicipName
  location: location
  sku: publicipsku
  properties: publicipproperties
}
output publicipId string = publicip.id
output publicipAddress string = publicip.properties.ipAddress
