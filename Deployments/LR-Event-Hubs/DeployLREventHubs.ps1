# Install-Module powershell-yaml
$KVLocations = @()
$subscriptions = Get-AzSubscription
foreach ( $subscription in $subscriptions){
    $null = $subscription | set-azcontext
    $kvaults = Get-AzKeyVault
    if ( $kvaults.count -gt 0){
        $KVLocations += $kvaults.location
    }
}
$KVLocations = $KVLocations | Select-Object -Unique

$d = Get-Content ../../defs/logrhythm-eh/event-hub.yaml | ConvertFrom-Yaml

$regions = az account list-locations|ConvertFrom-Json|?{$_.metadata.geographyGroup-ne$null-and$_.name-notlike'*stage'-and$_.name-notlike'*euap'}|sort displayname|select displayname,name,@{n='shortname';e={$w=$_.displayname.replace('Southeast','South East').tolower().split(' ');$x='';if($w.count-eq3){$w|%{$x+=$_[0]}}elseif($w.count-eq2){$x+=$w[0][0];$x+=$w[1][0];$x+=$w[1][1]};$x}}

foreach ( $region in $KVLocations ){
    $regionPrefix = $regions | where name -eq $region

    $d.eh.parameters.name.value = "$($regionPrefix.shortname)-logrhythm-prd"
    $d.eh.parameters.location = @{value = $region}
    $d.eh | ConvertTo-Json -Depth 20 > 'parameters.json'

    @{'$schema'='https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#';contentVersion='1.0.0.0';parameters=@{tags=@{value=$($d.tags)}}} | ConvertTo-Json -Depth 20 > tags.json

    az deployment group create `
            --name "$($d.eh.parameters.name.value)" `
            --subscription "$($d.subscription)" `
            --resource-group "$($d.resourceGroup)" `
            --template-file "..\..\Bicep\event-hub\event-hub.bicep" `
            --parameters '@parameters.json' '@tags.json'

    $saName = $d.eh.parameters.name.value.replace('-','').tolower()
    $saKey = (Get-AzStorageAccountKey -ResourceGroupName $d.resourceGroup -Name $saName )[0].Value
    $ehKey = Get-AzEventHubKey -ResourceGroupName $d.resourceGroup -NamespaceName "$($d.eh.parameters.name.value)" -AuthorizationRuleName $d.eh.parameters.authorisationRuleName.value

    "========================="
    $d.eh.parameters.name.value
    " - Storage"
    "DefaultEndpointsProtocol=https;AccountName=$($saName);AccountKey=$saKey;EndpointSuffix=core.windows.net"
    " - Event Hub"
    "$($ehkey.PrimaryConnectionString);EntityPath=$($d.eh.parameters.name.value),$saName"
    "========================="
}

