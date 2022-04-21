param subnetId string
param publicIPId string = ''
param virtualMachineName string
param TempUsername string
param TempPassword string
param virtualMachineSize string
param OPNScriptURI string
param ShellScriptName string
param ShellScriptParameters string
param nsgId string = ''
param Location string = resourceGroup().location

var untrustedNicName = '${virtualMachineName}-NIC'

module untrustedNic '../vnet/publicnic.bicep' = {
  name: untrustedNicName
  params:{
    nicName: untrustedNicName
    subnetId: subnetId
    publicIPId: publicIPId
    enableIPForwarding: true
    nsgId: nsgId
  }
}

resource OPNsense 'Microsoft.Compute/virtualMachines@2021-03-01' = {
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
        publisher: 'MicrosoftOSTC'
        offer: 'FreeBSD'
        sku: '12.0'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: untrustedNic.outputs.nicId
          properties:{
            primary: true
          }
        }
      ]
    }
  }
}

resource vmext 'Microsoft.Compute/virtualMachines/extensions@2015-06-15' = {
  name: '${OPNsense.name}/CustomScript'
  location: Location
  properties: {
    publisher: 'Microsoft.OSTCExtensions'
    type: 'CustomScriptForLinux'
    typeHandlerVersion: '1.4'
    autoUpgradeMinorVersion: false
    settings:{
      fileUris: [
        '${OPNScriptURI}${ShellScriptName}'
      ]
      commandToExecute: 'sh ${ShellScriptName} ${ShellScriptParameters}'
    }
  }
}

output untrustedNicIP string = untrustedNic.outputs.nicIP
