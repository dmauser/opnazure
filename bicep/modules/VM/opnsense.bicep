param untrustedSubnetId string
param trustedSubnetId string = ''
param publicIPId string = ''
param virtualMachineName string
param TempUsername string
param TempPassword string
param virtualMachineSize string
param OPNScriptURI string
param ShellScriptName string
param ShellScriptParameters string
param nsgId string = ''
param ExternalLoadBalancerBackendAddressPoolId string = ''
param InternalLoadBalancerBackendAddressPoolId string = ''
param ExternalloadBalancerInboundNatRulesId string = ''
param multiNicSupport bool
param Location string = resourceGroup().location

var untrustedNicName = '${virtualMachineName}-Untrusted-NIC'
var trustedNicName = '${virtualMachineName}-Trusted-NIC'

module untrustedNic '../vnet/nic.bicep' = {
  name: untrustedNicName
  params:{
    Location: Location
    nicName: untrustedNicName
    subnetId: untrustedSubnetId
    publicIPId: publicIPId
    enableIPForwarding: true
    nsgId: nsgId
    loadBalancerBackendAddressPoolId: ExternalLoadBalancerBackendAddressPoolId
    loadBalancerInboundNatRules: ExternalloadBalancerInboundNatRulesId
  }
}

module trustedNic '../vnet/nic.bicep' = if(multiNicSupport){
  name: trustedNicName
  params:{
    Location: Location
    nicName: trustedNicName
    subnetId: trustedSubnetId
    enableIPForwarding: true
    nsgId: nsgId
    loadBalancerBackendAddressPoolId: InternalLoadBalancerBackendAddressPoolId
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
      networkInterfaces: multiNicSupport == true ?[
        {
          id: untrustedNic.outputs.nicId
          properties:{
            primary: true
          }
        }
        {
          id: trustedNic.outputs.nicId
          properties:{
            primary: false
          }
        }
      ]:[
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
output trustedNicIP string = multiNicSupport == true ? trustedNic.outputs.nicIP : ''
output untrustedNicProfileId string = untrustedNic.outputs.nicIpConfigurationId
