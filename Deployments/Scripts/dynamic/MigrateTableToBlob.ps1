Start-Transcript /tmp/pwsh-table.txt
if ( -not ( $HOME) ){
    "Setting Home variable: current $HOME"
    Set-Variable HOME '/root' -Force
    "New home variable: $HOME"
}
else {
    "apparently home has a value"
}

$modules = @("Az", "AzTable")
foreach ( $module in $modules ){
    $azmodule = get-module $module -ListAvailable
    if ( -not $azmodule ){
        Install-Module $module -Force
    }
    Import-Module $module
}

Connect-AzAccount -Identity -AccountId 5599f23e-cb79-4596-a3b4-8d5785da98ce

$subscription = "Jan ADS"
$resourceGroupName = "default-storage-australiasoutheast"
$storageAccountName = "mel0204log"
$output = "/tmp/tables"
if ( !(test-path $output ) ){
    New-Item $output -ItemType Directory
}
$archiveContainer = "tablelogsarchive"
$processBefore = get-date '2021-04-01'
$storageAccount = Get-AzStorageAccount -ResourceGroup $resourceGroupName -StorageAccountName $storageAccountName
$rowTables = 10000
$tables = Get-AzStorageTable -Context $storageAccount.Context
$tables = $tables | where Name -ne "SchemasTable"
function Get-StepTime(){
    "   Time $(get-date)"
    if ( $global:start ){
        $time = (get-date) - $global:start
        if ( $time.TotalSeconds -gt 60 ){
            $elapsedTime = "$($time.TotalMinutes) minutes"
        }
        else {
            $elapsedTime = "$($time.TotalSeconds) seconds"
        }

        "   Run time: $elapsedTime"
    }

    $global:start = get-date

}

foreach ( $table in $tables ) {
    Get-StepTime
    $table.name
    $time = get-date
    "   Getting rows..."
    $rows = Get-AzTableRow -Table $table.CloudTable -Top $rowTables
    "       Retrieved $($rows.count) rows..."
    Get-StepTime
    if ( $($rows.count) -gt 0 ){
        $fileName = "$($table.name)-$((get-date).toString('yyyy-MM-dd-HH.mm')).json"
        $fullFilename = "$output/$fileName"
        "   Exporting to JSON file $fullFilename..."
        $rows | ConvertTo-Json -Compress | out-file $fullFilename
        "       Export size: $((get-item $fullFilename).size / 1gb) gb"
        Get-StepTime
        "   Uploading to archive..."

        $Blob2HT = @{
            File             = $fullFilename
            Container        = $archiveContainer
            Blob             = "$($table.name)/$fileName"
            Context          = $storageAccount.Context
            StandardBlobTier = 'Archive'
        }
        $upload = Set-AzStorageBlobContent @Blob2HT
        "       Name: $($upload.name)"
        "       Upload size: $($upload.length / 1gb) gb"
        Get-StepTime
        "   Deleting rows..."
        if ( $upload ){
            $delete = $rows | ForEach-Object -ThrottleLimit 20 -Parallel {
                if ( -not ( $HOME) ){
                    "Setting Home variable: current $HOME"
                    Set-Variable HOME '/root' -Force
                    "New home variable: $HOME"
                }
                else {
                    "apparently home has a value"
                }
                $modules = @("Az", "AzTable")
                foreach ( $module in $modules ){
                    $azmodule = get-module $module -ListAvailable
                    if ( -not $azmodule ){
                        "installing $module" | out-file /tmp/imtest.txt -Append
                        Install-Module $module -Force
                    }
                    "importing $module" | out-file /tmp/imtest.txt -Append
                    Import-Module $module
                }
                $_ | Remove-AzTableRow -Table $using:table.CloudTable
            }
        }
        else {
            "   skipping deleting from table as file not uploaded"
        }
        
        Get-StepTime
        # Remove-Item $fullFilename
    }
    else {
        "   skipping empty table..."
    }
}

Stop-Transcript