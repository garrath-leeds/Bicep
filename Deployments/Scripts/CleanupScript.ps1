$modules = @("Az")
foreach ( $module in $modules ){
    $azmodule = get-module $module -ListAvailable
    if ( -not $azmodule ){
        Install-Module $module -Force
    }
    Import-Module $module
}

Connect-AzAccount -Identity -AccountId 5599f23e-cb79-4596-a3b4-8d5785da98ce

$currentVM = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -NoProxy -Uri http://169.254.169.254/metadata/instance?api-version=2020-09-01

Set-AzContext -Subscription $currentVM.compute.subscriptionId

#untested below
$vm = Get-AzVM -ResourceGroupName $currentVM.compute.resourceGroupName -Name $currentVM.compute.name

if ( $vm.count -eq 1 -and $vm.name -eq $currentVm.compute.name ) { 
    $vm | Remove-AzVm -ForceDeletion $true -Force
}

