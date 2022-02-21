# Install dependancies 
Install-Module -Name Az 

# Funtion to download files from AzStorage Blob/s
function downloadFromAzStorage {
    param (
        [Parameter(Mandatory = $true)][string] $connection_string,
        [Parameter(Mandatory = $true)][string] $AzureBlobContainerName,
        [Parameter(Mandatory = $true)][string] $destination_path
    )
    
    $StartTime = $(get-date)
    $datetime = $(get-date -f yyyy-MM-dd_hh.mm.ss)

    If (!(test-path $destination_path)) {
        New-Item -ItemType Directory -Force -Path $destination_path
    }
    $storage_account = New-AzStorageContext -ConnectionString $connection_string
 
    # IF we wanna download from all containers
    #$containers = Get-AzStorageContainer -Context $storage_account
 
    # Download from specific container
    $containers = Get-AzStorageContainer -Context $storage_account | Where-Object { $_.Name -eq "$AzureBlobContainerName" }
 
    Write-Host '==> INFO : Containers Found : ' $containers
    Write-Host '==> INFO : Starting Storage Dump...'
    foreach ($container in $containers) {
        Write-Host '==> INFO : Processing: ' . $container.Name . '...'
    
        $blobs = Get-AzStorageBlob -Container $container.Name -Context $storage_account

        # Creating folder as container name
        $container_path = $destination_path + '\' + $container.Name 
        new-item -ItemType "directory" -Path $container_path

        # Downloading files from every every folder
        Write-Host '==> INFO : Downloading files...'
        foreach ($blob in $blobs) { 
            # for specific folders uncomment following
            # if ($blob.name.StartsWith('calendar') -or $blob.name.StartsWith('ocr-input')) { 
                Write-Host '==> INFO : Now Downloading ' $blob.Name 
                $fileNameCheck = $container_path + '\' + $blob.Name 
                if (!(Test-Path $fileNameCheck )) {
                    Get-AzStorageBlobContent -Container $container.Name -Blob $blob.Name -Destination $container_path -Context $storage_account
                } 
            # }
        } 
        Write-Host 'Done!'
    }
    Write-Host '==> INFO : Download complete!'

    $elapsedTime = $(get-date) - $StartTime

    $totalTime = "{0:HH:mm:ss}" -f ([datetime]$elapsedTime.Ticks)

    Write-Output "==> INFO : Time Taken:  $totalTime" | Out-String 
}


downloadFromAzStorage   'DefaultEndpointsProtocol=https;AccountName=contractpodwesteurope;AccountKey=QnjhkABO927MlxjPsfnoZVCA3ANYQ70CAfLT3IoLwDJEjqwSAmldkbYQIx1xNv1b7BQhWWHjcZConzLbcTDR6A==;EndpointSuffix=core.windows.net' `
    'cl-qa' `
    'D:\CognitiveExitBackup'
