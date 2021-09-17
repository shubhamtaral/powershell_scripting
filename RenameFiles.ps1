function renameFile {
    param (
        [Parameter(Mandatory = $true)][string] $fileFolderPath

    )
    
    $pattern = "[#':><?|%/\\]"
    $backup = $fileFolderPath + '_Backup'

    # Get BackUp
    Write-Host "Backup Copy Files from $fileFolderPath to $backup ..."
    Copy-Item -Path $fileFolderPath -Destination $backup -Recurse
    
    
    # Start Renaming all files (can add -Filter "*.pdf")
    Write-Host "Renaming Files from $fileFolderPath ..."
    Get-ChildItem -File $fileFolderPath | 
    Rename-Item –NewName { $_.name.trim() –replace $pattern ,'_' } -Force

    # Adds ".pdf" ext to all files ecluding pdfs
    Write-Host "Adding extention to Files from $fileFolderPath ..."
    Get-ChildItem -Exclude "*.pdf" $fileFolderPath | 
    Rename-Item –NewName { $_.name +".pdf" } -Force
}

# Provide Dir path as input to the function
renameFile "D:\powershell_scripting\DemoFiles"
