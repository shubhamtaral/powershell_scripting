function renameFile {
    param (
        [Parameter(Mandatory = $true)][string] $fileFolderPath

    )
    
    $pattern = "[#':><?|%/\\]"
    $counter = 0;
    Write-Host "=>INFO: Creating backup Folder @ $fileFolderPath/_backup ..."
    New-Item -Path $fileFolderPath -Name '_backup' -ItemType "directory"

    # Get BackUp
    Write-Host "=>INFO: Taking Backup of Files from $fileFolderPath Which needs a change..."
    $Files = (Get-ChildItem -Exclude _backup, *.xlsx, *.bashrc, *.bash_logout, *.profile, *.docx, *.doc, *.pub, *.pptx, *.zip, *.JEPG $fileFolderPath |
        Where-Object { $_.Name -match $pattern} |
        ForEach-Object { @{Path = $_.fullname } }).Values
    foreach ($File in $Files) {
        Copy-Item -Path $File -Destination $fileFolderPath/_backup 
        Write-Host "Copied $File to /_backup folder ..."
        $counter++
    }
    
    # Start Renaming all files (can add -Filter "*.pdf")
    Write-Host "=>INFO: Renaming Files from $fileFolderPath ..."
    Get-ChildItem -Exclude _backup, *.xlsx, *.bashrc, *.bash_logout, *.profile, *.docx, *.doc, *.pub, *.pptx, *.zip, *.JEPG $fileFolderPath | 
    Rename-Item –NewName { $_.name.trim() –replace $pattern , '_' } -Force
    Write-Host "=>INFO: Renaming Files Done! ..."
    
    # Adds ".pdf" ext to all files ecluding pdfs
    Write-Host "Adding extention to Files from $fileFolderPath ..."
    Get-ChildItem -Exclude _backup, *.pdf, *.xlsx, *.bashrc, *.bash_logout, *.profile, *.docx, *.doc, *.pub, *.pptx, *.zip, *.JEPG $fileFolderPath | 
    Rename-Item –NewName { $_.name + ".pdf" } -Force
    Write-Host "=>INFO: Extention Added ...!"

    Write-Host "=>INFO: $counter files Changed...."
}

# Provide Dir path as input to the function
renameFile "D:\powershell_scripting\DemoFiles"
