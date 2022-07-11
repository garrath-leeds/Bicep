Start-Transcript /tmp/pwsh.txt
$azmodule = get-module Az -ListAvailable
if ( -not $azmodule ){
    Get-PSRepository PSGallery | Set-PSRepository -InstallationPolicy Trusted
    Install-Module Az -Force
}
Import-Module Az -Force
Connect-AzAccount -Identity -AccountId 5599f23e-cb79-4596-a3b4-8d5785da98ce
$subscription = "Jan ADS"
$resourceGroupName = "default-storage-australiasoutheast"
$storageAccountName = "mel0204log"
$azcopyLocation = "/tmp/azcopy/azcopy_linux_amd64_10.15.0"
$processBefore =  get-date '2021-04-01' #(get-date).AddDays(-60)
$includeContainers = @() #@("insights-logs-probehealthstatusevents")
$excludeContainers = @("appinsights-continuousexport")


$storageAccount = Get-AzStorageAccount -ResourceGroup $resourceGroupName -StorageAccountName $storageAccountName

$containers = Get-AzStorageContainer -Context $storageAccount.context 

if ( $includeContainers -and $includeContainers.count -gt 0 ) {
    $containers = $containers | Where-Object Name -in $includeContainers
}
if ( $excludeContainers -and $excludeContainers.count -gt 0 ) {
    $containers = $containers | Where-Object Name -notin $excludeContainers
}

foreach ( $container in $containers ){
    "$($container.name)"
    $blobs = get-AzStorageBlob -Container $container.name -Context $storageAccount.Context -Prefix $prefix
    "   Before Filtering: $($blobs.count) blobs..."
    $blobs = $blobs | Where-Object { $_.BlobType -in ("PageBlob","AppendBlob") -and $_.LastModified -lt $processBefore -and $_.AccessTier -in ("Hot",$null) }
    $currentCount = $blobs.count
    "   Processing $currentCount blobs..."

    $tokenExpiry = (Get-Date).AddDays(1)
    $token = $storageAccount | New-AzStorageAccountSASToken -Service Blob,File,Table,Queue -ResourceType Service,Container,Object -Permission racwdlup -ExpiryTime $tokenExpiry

    $global:remove = $false

    $blobSize = $blobs | Group-Object -Property BlobType | ForEach-Object {
        $gb = ( ($_.Group | Measure-Object Length -Sum).Sum / 1gb )

        if ( $gb -gt 5 ){
            $global:remove  = $true
        }

        [PSCustomObject]@{
            Item = $_.Name
            Sum = ("{0:N0} GB" -f $gb)
        }

    }

    $blobSize

    if ( $global:remove ){
        $blobs | ForEach-Object -ThrottleLimit 15 -Parallel {
            function Test-TransferSuccess(){
                param (
                    [Parameter(Mandatory=$true)][string]$Message,
                    [Parameter(Mandatory=$true)][string]$Path,
                    [Parameter(Mandatory=$false)][string]$Destination,
                    [Parameter(Mandatory=$false)][string]$Container,
                    [Parameter(Mandatory=$false)]$StorageAccountContext
                    
                )
                
    
                if ( ( $Message -notlike "*Final Job Status: Failed*" -and $Message -notlike "*Number of Transfers Completed: 0*" -and $Message -notlike "*failed to perform*" ) ) {
                    return $true
                }
                else {
                    if ( $Destination -and $StorageAccountContext ){
                        try{
                            $toObj = Get-AzStorageBlob -Blob $Destination -Container $Container -Context $storageAccountContext -ErrorAction Stop
                            # $fromObj = Get-AzStorageBlob -Blob $Path -Container $Container -Context $storageAccountContext -ErrorAction Stop
                            $migrateCompleted = $true
                        }
                        catch {
                            $migrateCompleted = $false
                        }
                    }
                    if ( !$migrateCompleted ){
                        Write-Error "Error in transferring data"
                        Write-Error $Message
                        Write-Error "Path: $path"
                        return $false
                    }
                    else {
                        return $true
                    }
                    
                }
            
            }
           
            if ( (get-date).AddMinutes(10) -ge $using:tokenExpiry ){
                " Expired token"
            }
            else {
                $blob = $_
                $blob.name
                $newName = $blob.name
    
                $newName = $newName.Insert($blob.name.LastIndexOf('.'),'_')
    
                $copyFrom = "$($($using:storageAccount).PrimaryEndpoints.Blob)$($using:container.name)/$($blob.name)"
                $copyTo = "$($($using:storageAccount).PrimaryEndpoints.Blob)$($using:container.name)/$($newName)"
    
                $output = & "$($using:azcopyLocation)/azcopy" "copy" "$copyFrom$($using:token)" "$copyTo$($using:token)" "--blob-type" "BlockBlob" "--block-blob-tier" "Archive" "--log-level" "ERROR" "--overwrite" "true"

                $testValue = Test-TransferSuccess -Message ($output | out-string) -Path $blob.name -Destination $newName -Container $($using:container.name) -StorageAccountContext $using:storageAccount.context 
                if ( $testValue ){
                    # "Deleting $copyFrom"
                    $output = & "$($using:azcopyLocation)/azcopy" "remove" "$copyFrom$($using:token)" "--log-level" "ERROR"
                }
            }
        }
    }
    else {
        "   Skipping delete as files aren't large enough."
    }
    
}

Stop-Transcript