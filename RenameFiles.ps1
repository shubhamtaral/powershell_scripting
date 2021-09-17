function renameFile {
    param (
        [Parameter(Mandatory = $true)][string] $fileFolderPath

    )
    
    $pattern = "[#':><?|%/\\]"
    Write-Host "Creating backup Folder @ $fileFolderPath/_backup ..."
    New-Item -Path $fileFolderPath -Name '_backup' -ItemType "directory"

    # Get BackUp
    $Files = (Get-ChildItem -Exclude _backup, *.xlsx, *.bashrc, *.bash_logout, *.profile, *.docx, *.doc, *.pub, *.pptx, *.zip, *.JEPG $fileFolderPath | 
        ForEach-Object { @{Path = $_.fullname } }).Values
    foreach ($File in $Files) {
        Copy-Item -Path $File -Destination $fileFolderPath/_backup 
        Write-Host "Copied $File to /_backup folder ..."
    }
    
    # Start Renaming all files (can add -Filter "*.pdf")
    Write-Host "Renaming Files from $fileFolderPath ..."
    Get-ChildItem -Exclude _backup, *.xlsx, *.bashrc, *.bash_logout, *.profile, *.docx, *.doc, *.pub, *.pptx, *.zip, *.JEPG $fileFolderPath | 
    Rename-Item –NewName { $_.name.trim() –replace $pattern , '_' } -Force
    Write-Host "Renaming Files Done! ..."
    
    # Adds ".pdf" ext to all files ecluding pdfs
    Write-Host "Adding extention to Files from $fileFolderPath ..."
    Get-ChildItem -Exclude _backup, *.pdf, *.xlsx, *.bashrc, *.bash_logout, *.profile, *.docx, *.doc, *.pub, *.pptx, *.zip, *.JEPG $fileFolderPath | 
    Rename-Item –NewName { $_.name + ".pdf" } -Force
    Write-Host "Extention Added ...!"
}

# Provide Dir path as input to the function
renameFile "D:\powershell_scripting\DemoFiles"
