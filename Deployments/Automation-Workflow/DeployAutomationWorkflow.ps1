# Install-Module powershell-yaml

$d = Get-Content ../../defs/security/automation-workflow.yaml | ConvertFrom-Yaml
$subscriptions = Get-AzSubscription 

$originalAutomationName = $d.workflow.parameters.automationName.value

foreach ( $subscription in ( $subscriptions.name | Select-Object -Unique) ){
# $subscription = 'Jan IT'
    $name = ("$originalAutomationName-$subscription" -replace '[ /]','')
    if ( $name.length -gt 64){
        $name = $name.substring(0,63)
    }
    "Processing $name..."
    $d.workflow.parameters.automationName = @{value = $name}
    # $d.workflow.parameters.name = @{value = $name}

    $d.workflow | ConvertTo-Json -Depth 20 > 'parameters.json'

    @{'$schema'='https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#';contentVersion='1.0.0.0';parameters=@{tags=@{value=$($d.tags)}}} | ConvertTo-Json -Depth 20 > tags.json

    az deployment group create `
            --name "$($d.workflow.parameters.automationName.value)" `
            --subscription "Infrastructure" `
            --resource-group "$($d.resourceGroup)" `
            --template-file "..\..\Bicep\security\automation-workflow.bicep" `
            --parameters '@parameters.json' '@tags.json'

}