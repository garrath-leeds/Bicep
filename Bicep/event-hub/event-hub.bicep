param name string
param location string
param tags object
param authorisationRuleName string

resource namespace 'Microsoft.EventHub/namespaces@2022-01-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    capacity: 2
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    isAutoInflateEnabled: false
    kafkaEnabled: false
    publicNetworkAccess: 'Enabled'
    zoneRedundant: false
  }
}

resource eventhub 'Microsoft.EventHub/namespaces/eventhubs@2022-01-01-preview' = {
  name: name
  parent: namespace
  properties: {
    messageRetentionInDays: 1
    partitionCount: 4
    status: 'Active'
    captureDescription: {
      destination: {
        name: 'EventHubArchive.AzureBlockBlob'
        properties: {
          archiveNameFormat:'{Namespace}/{EventHub}/{PartitionId}/{Year}/{Month}/{Day}/{Hour}/{Minute}/{Second}'
          blobContainer:'logs'
          storageAccountResourceId: '/subscriptions/cd1224a4-61ac-401e-8af3-ad34f9cd9c94/resourceGroups/DefaultResourceGroup-LogRhythm/providers/Microsoft.Storage/storageAccounts/syd0245infrastucturelr'
        }
      }
      encoding: 'Avro'
      enabled: false
    }
  }
}

// create after due to 
resource authorization 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2022-01-01-preview' = {
  name: authorisationRuleName
  parent: eventhub
  properties: {
    rights: [
      'Listen'
    ]
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: replace(toLower(name),'-','')
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'BlobStorage'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2021-09-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    automaticSnapshotPolicyEnabled: false
    changeFeed: {
      enabled: false
    }
  }
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  name: 'logrhythmconnection'
  parent: blobService
  properties: {
    publicAccess: 'None'
  }
}
