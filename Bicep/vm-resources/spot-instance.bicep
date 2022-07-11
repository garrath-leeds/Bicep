targetScope= 'resourceGroup'

param vmName string
param vmUser string //'azureuser'
param vmPassword string
// https://azureprice.net/vm/Standard_D4a_v4?tier=spot&timeoption=month
param vmSize string //= 'Standard_D2as_v4'
param vmLocation string //'Australia Southeast'
param maxSpotPrice string
param userassignedIdentity string // '/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/{identityName}'
param script string //base64 of script. maximum of 256 kb
// nic
param tags object
param diskDeleteOption string
param nicDeleteOption string

// param sshPrincipalId string

param subnetId string //"/subscriptions/2f7bd7c9-4d79-45a8-87ee-390e82f6683a/resourceGroups/Default-Networking/providers/Microsoft.Network/virtualNetworks/VNET-MEL0205/subnets/Core"

// resource storageaccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
//   name: '${vmName}-sa'
//   location: vmLocation
//   kind: 'StorageV2'
//   sku: {
//     name: 'Standard_LRS'
//   }
// }


resource networkInterface 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: '${vmName}-nic'
  location: vmLocation
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
  tags: tags
}


resource vm 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: vmName
  location: vmLocation
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userassignedIdentity}':{}
    }

  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: vmUser
      adminPassword: vmPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '16.04-LTS'
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}_OS'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        deleteOption: diskDeleteOption
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
          properties: { 
            deleteOption: nicDeleteOption
          } 
        }
      ]
    }
    billingProfile: {
      maxPrice: maxSpotPrice
    }
    evictionPolicy:'Delete'
    priority: 'Spot'
   
    // diagnosticsProfile: {
    //   bootDiagnostics: {
    //     enabled: true
    //     storageUri: 'storageUri'
    //   }
    // }
  }

}

// resource vmPermissions 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
//   name: 'role-assignment-${vmName}'
//   scope: guid(vm.id, sshPrincipalId, role[builtInRoleType])
//   properties: {
//     condition: 'string'
//     conditionVersion: 'string'
//     delegatedManagedIdentityResourceId: 'string'
//     description: 'string'
//     principalId: 'string'
//     principalType: 'string'
//     roleDefinitionId: 'string'
//   }
// }

resource vmAADAuth 'Microsoft.Compute/virtualMachines/extensions@2020-06-01' = {
  parent: vm
  name: 'vm-aadAuth-${vmName}'
  tags: tags
  location: vmLocation
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory.LinuxSSH'
    type: 'AADLoginForLinux'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}

resource vmRunScripts 'Microsoft.Compute/virtualMachines/extensions@2020-06-01' = {
  parent: vm
  name: 'vm-script-${vmName}'
  tags: tags
  location: vmLocation
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      script: script
    }
  }
}


