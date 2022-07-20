@minLength(3) // @maxLength(24)
param automationName string

@description('Location for the automation')
param location string = resourceGroup().location

@minLength(3)
param logicAppName string

@minLength(3)
param logicAppResourceGroupName string

@description('The Azure resource GUID id of the subscription')
param subscriptionId string = subscription().subscriptionId

@description('The alert settings object used for deploying the automation')
param alertSettings object

param tags object

var automationDescription = 'automation description for subscription {0}'
var scopeDescription = 'automation scope for subscription {0}'

resource automation 'Microsoft.Security/automations@2019-01-01-preview' = {
  name: automationName
  location: location
  tags: tags
  properties: {
    description: format(automationDescription, subscriptionId)
    isEnabled: true
    actions: [
      {
        actionType: 'LogicApp'
        logicAppResourceId: resourceId('Microsoft.Logic/workflows', logicAppName)
        uri: listCallbackURL(resourceId(subscriptionId, logicAppResourceGroupName, 'Microsoft.Logic/workflows/triggers', logicAppName, 'When_an_Azure_Security_Center_Alert_is_created_or_triggered'), '2019-05-01').value
      }
    ]
    scopes: [
      {
        description: format(scopeDescription, subscriptionId)
        scopePath: subscription().id
      }
    ]
    sources: [
      {
        eventSource: 'Alerts'
        ruleSets: [
          {
            rules: [
                {
                  propertyJPath: 'AlertDisplayName' //alertSettings.jpath
                  propertyType: 'String'
                  expectedValue: 'Potential malware uploaded to a storage blob container' //alertSettings.expectedValue
                  operator: 'Equals' //alertSettings.operator
                }
            ]
          }
        ]
      }
    ]
  }
}
