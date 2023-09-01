param rtName string
param location string = resourceGroup().location

resource rt 'Microsoft.Network/routeTables@2023-04-01' = {
  name: rtName
  location: location
}
output routetableID string = rt.id
