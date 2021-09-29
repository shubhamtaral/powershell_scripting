Install-Module -Name Az 

$StartTime = $(get-date)
$datetime = $(get-date -f yyyy-MM-dd_hh.mm.ss)

$connection_string = 'DefaultEndpointsProtocol=https;AccountName=contractpodwesteurope;AccountKey=QnjhkABO927MlxjPsfnoZVCA3ANYQ70CAfLT3IoLwDJEjqwSAmldkbYQIx1xNv1b7BQhWWHjcZConzLbcTDR6A==;EndpointSuffix=core.windows.net'
$AzureBlobContainerName = 'cl-qa'
 
$destination_path = "D:\CognitiveExitBackup"


If(!(test-path $destination_path))
{
    New-Item -ItemType Directory -Force -Path $destination_path
}
$storage_account = New-AzStorageContext -ConnectionString $connection_string
 
# Download from all containers
#$containers = Get-AzStorageContainer -Context $storage_account
 
# Download from specific container
$containers = Get-AzStorageContainer -Context $storage_account | Where-Object {$_.Name -eq "$AzureBlobContainerName"}
 
$containers
Write-Host 'INFO==> Starting Storage Dump...'
foreach ($container in $containers)
{
    Write-Host -NoNewline 'INFO==> Processing: ' . $container.Name . '...'
    
    $blobs = Get-AzStorageBlob -Container $container.Name -Context $storage_account
    
    $container_path = $destination_path + '\' + $container.Name 
    new-item -ItemType "directory" -Path $container_path
    Write-Host -NoNewline 'INFO==> Downloading files...'   
    foreach ($blob in $blobs)
    {       
        $fileNameCheck = $container_path + '\' + $blob.Name      
        if(!(Test-Path $fileNameCheck ))
        {
            Get-AzStorageBlobContent -Container $container.Name -Blob $blob.Name -Destination $container_path -Context $storage_account
        }           
    } 
    Write-Host 'Done!'
}
Write-Host 'INFO==> Download complete.'

$elapsedTime = $(get-date) - $StartTime

$totalTime = "{0:HH:mm:ss}" -f ([datetime]$elapsedTime.Ticks)

Write-Output "Time Taken:  $totalTime" | Out-String 