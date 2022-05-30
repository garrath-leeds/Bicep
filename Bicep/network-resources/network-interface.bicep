param nicName string
param nicLocation string
param subnetId string //"/subscriptions/2f7bd7c9-4d79-45a8-87ee-390e82f6683a/resourceGroups/Default-Networking/providers/Microsoft.Network/virtualNetworks/VNET-MEL0205/subnets/Core"

resource networkInterface 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: nicName
  location: nicLocation
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
}



