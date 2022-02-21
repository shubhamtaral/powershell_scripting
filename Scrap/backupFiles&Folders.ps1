function backupApplications {

    param (
        [Parameter(Mandatory = $true)][string] $sourcePath,
        [Parameter(Mandatory = $true)][string] $destiationPath,
        [Parameter(Mandatory = $true)][string] $exclude,
        [Parameter(Mandatory = $true)][string] $exclude2
    )

    $currentDir = (Get-Location).Path
    $timestamp = Get-Date -format "yyyyMMdd"
    $outputFolder = Join-Path -Path $destiationPath -ChildPath $timestamp

    # Temp Copy files from Source to Dest
    Write-Host "Temp Copy Files from $sourcePath to $destiationPath"
    robocopy $sourcePath $outputFolder /copy:DATSOU /mir /xd $exclude $exclude2
    
    $zipname = "Backup_$timestamp.zip"
    $zippath = Join-Path $destiationPath $zipname

    # Zipping the folder
    Write-Host "Backing up $sourcePath to $zippath"
    #Compress-Archive -Path $items -DestinationPath $zippath
    & "C:\Program Files\7-Zip\7z" a $zippath $outputFolder/*

    # Deleting the copied folder
    Set-Location $destiationPath
    Write-Host "Deleting the temp folder!"
    Remove-Item $destiationPath/$timestamp -Recurse
    Set-Location $currentDir
}

backupApplications "$(SourceFolder)" "$(OutputFolder)" "$(ExcludeFolder1)" "$(ExcludeFolder2)"