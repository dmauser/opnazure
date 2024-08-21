resource trustedSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' existing = {
  name: 'HUB-VNet/Trusted-Subnet'
}

resource untrustedSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' existing = {
  name: 'HUB-VNet/Untrusted-Subnet'
}

//output trustedSubnetPrefix string = trustedSubnet.properties.addressPrefix
output trustedSubnetName string = trustedSubnet.name
output trustedSubnetProperties object = trustedSubnet.properties
output trustedSubnetNewPro string = contains(trustedSubnet.properties, 'addressPrefixes') ? trustedSubnet.properties.addressPrefixes[0] : trustedSubnet.properties.addressPrefix
//trustedSubnet.properties.addressPrefixes[0]
