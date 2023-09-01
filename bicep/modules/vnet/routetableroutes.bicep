param routetableName string
param routeName string
param properties object

resource rtroutes 'Microsoft.Network/routeTables/routes@2023-04-01'  = {
  name: '${routetableName}/${routeName}'
  properties: properties
}
