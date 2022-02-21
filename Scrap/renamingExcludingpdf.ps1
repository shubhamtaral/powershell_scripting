Write-Host "INFO: Creating backup Folder as _backupDemo ..."
if (Test-Path -Path $PWD/_backupDemo) {
    "Folder exists!"
} else {
    New-Item -Path $PWD -Name '_backupDemo' -ItemType "directory"
    Write-Host "INFO: Created backup Folder as _backup ..."
}

# Get File Backup
function copyFiles {
    param (
        [Parameter(Mandatory = $true)][string] $File
    )
    $File
    Copy-Item -Path $File -Destination $PWD/_backupDemo 
    Write-Host "Copied $File to /_backupDemo folder ..."
        
}

# Rename the File
function renameFile {
    param (
        [Parameter(Mandatory = $true)][string] $File
    )
    $FileName = (Split-Path $File -leaf)+".pdf"
    Rename-Item -Path $File -NewName $FileName -Force
    Write-Host "INFO: Extension Added ...!"
    Write-Host "Renamed $File"

}

#################################################################################
# Start 
$Files = Get-ChildItem "D:\Renaming\Files" -Recurse -File -Exclude *.pdf 
$Count = 0
ForEach ($File in $Files){
    
    Write-Host "INFO: Coping file before renaming"
    copyFiles $File
    Write-Host "INFO: Renaming File"
    renameFile $File
    $Count++
}
Write-Host "Total Files changed: $Count"