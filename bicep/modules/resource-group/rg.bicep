targetScope = 'subscription'
param location string = deployment().location
param rgName string
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  location: location
  name: rgName
}
output rgId string = rg.id
output rgName string = rg.name
