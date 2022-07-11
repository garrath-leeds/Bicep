# Install-Module powershell-yaml

$d = Get-Content ../defs/vm/spot-instance.yaml | ConvertFrom-Yaml

$baseScript = (Get-Content ./scripts/startup.sh -Raw)

$dynamicScript = ""

foreach ( $file in Get-ChildItem './scripts/dynamic'){
    $baseScript += "`necho `"$((((Get-Content $file.fullname) -join '\n').replace('"','\"')).replace('$','\$'))`" > /tmp/$($file.name)"
    
    $dynamicScript += "\n pwsh /tmp/$($file.name) &"
}
$baseScript += "`necho `"$((((Get-Content "./Scripts/CleanupScript.ps1") -join '\n').replace('"','\"')).replace('$','\$'))`" > /tmp/CleanupScript.ps1"

$baseScript += "`n echo `"$dynamicScript \n wait \n pwsh /tmp/CleanupScript.ps1`" > /tmp/dynamic.sh `n chmod +x /tmp/dynamic.sh `n /tmp/dynamic.sh &"

$b = [System.Text.Encoding]::Unicode.GetBytes($baseScript)

$d.vm.parameters.script =@{value=[Convert]::ToBase64String($b)}

$d.vm | ConvertTo-Json -Depth 20 > 'parameters.json'

@{'$schema'='https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#';contentVersion='1.0.0.0';parameters=@{tags=@{value=$($d.tags)}}} | ConvertTo-Json -Depth 20 > tags.json

# ssh-keygen -m PEM -t rsa -b 4096 -C "$($d.vm.parameters.vmName.value)" -f "~/.ssh/$($d.vm.parameters.vmName.value)-priv-key" -N yourpasshphrase

az deployment group create `
          --name "$($d.vm.parameters.vmName.value)" `
          --subscription "$($d.subscription)" `
          --resource-group "$($d.resourceGroup)" `
          --template-file "..\Bicep\vm-resources\spot-instance.bicep" `
          --parameters '@parameters.json' '@tags.json'