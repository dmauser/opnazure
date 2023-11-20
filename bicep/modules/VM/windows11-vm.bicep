param trustedSubnetId string
param publicIPId string
param virtualMachineName string
param TempUsername string
#disable-next-line secure-secrets-in-params
param TempPassword string
param virtualMachineSize string
param nsgId string
param Location string = resourceGroup().location

var trustedNicName = '${virtualMachineName}-NIC'

module trustedNic '../vnet/nic.bicep' = {
  name: trustedNicName
  params:{
    Location: Location
    nicName: trustedNicName
    subnetId: trustedSubnetId
    publicIPId: publicIPId
    enableIPForwarding: false
    nsgId: nsgId
  }
}

resource windows11 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: virtualMachineName
  location: Location
  properties: {
    osProfile: {
      computerName: virtualMachineName
      adminUsername: TempUsername
      adminPassword: TempPassword
    }
    hardwareProfile: {
      vmSize: virtualMachineSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
      }
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'windows-11'
        sku: 'win11-23h2-pro'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: trustedNic.outputs.nicId
          properties:{
            primary: true
          }
        }
      ]
    }
  }
}

output untrustedNicIP string = trustedNic.outputs.nicIP
