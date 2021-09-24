function renameFile {
    param (
        [Parameter(Mandatory = $true)][string] $fileFolderPath
    )
    
    $pattern = "[#':><?|%/\\]"
    $global:counter = 0;
    Write-Host "=>INFO: Creating backup Folder @ $fileFolderPath/_backup ..."
    New-Item -Path $fileFolderPath -Name '_backup' -ItemType "directory"

    function copyfiles {
        param (
            [Parameter(Mandatory = $true)][System.Array] $Files
        )
        foreach ($File in $Files) {
            # Use Robocopy, Check for file exsistace
            if (-not(Test-Path -Path $fileFolderPath/_backup  -PathType Leaf)) {
                Copy-Item -Path $File -Destination $fileFolderPath/_backup 
                Write-Host "Copied $File to /_backup folder ..."
                $global:counter++
            }
            else {
                Write-Host "Already Copied $File to /_backup folder ..."
            }
        }    
    }

    # Get BackUp
    Write-Host "=>INFO: Taking Backup of Files from $fileFolderPath Which needs a change..."
    # Copy pdf files which needs renaming
    $pdfFiles = (Get-ChildItem -Exclude _backup, *.xlsx, *.bashrc, *.bash_logout, *.profile, *.docx, *.doc, *.pub, *.pptx, *.zip, *.JEPG $fileFolderPath |
        Where-Object { $_.Name -match $pattern } |
        ForEach-Object { @{Path = $_.fullname } }).Values

    if ($pdfFiles.Count -gt 0) {
        copyfiles $pdfFiles
    }

    # Copy non-pdf files which needs renaming
    $nonpdfFiles = (Get-ChildItem -Exclude _backup, *.pdf, *.xlsx, *.bashrc, *.bash_logout, *.profile, *.docx, *.doc, *.pub, *.pptx, *.zip, *.JEPG  $fileFolderPath |
        ForEach-Object { @{Path = $_.fullname } }).Values

    if ($nonpdfFiles.Count -gt 0) {
        copyfiles $nonpdfFiles 
    }

    # Start Renaming all files (can add -Filter "*.pdf")
    Write-Host "=>INFO: Renaming Files from $fileFolderPath ..."
    Get-ChildItem -Exclude _backup, *.xlsx, *.bashrc, *.bash_logout, *.profile, *.docx, *.doc, *.pub, *.pptx, *.zip, *.JEPG $fileFolderPath | 
    Rename-Item –NewName { $_.name.trim() –replace $pattern , '_' } -Force
    Write-Host "=>INFO: Renaming Files Done! ..."
    
    # Remove spaces to all files ecluding pdfs
    Write-Host "Adding extention to Files from $fileFolderPath ..."
    Get-ChildItem -Exclude _backup, *.xlsx, *.bashrc, *.bash_logout, *.profile, *.docx, *.doc, *.pub, *.pptx, *.zip, *.JEPG $fileFolderPath | 
    Rename-Item –NewName { $_.name.Trim() -replace "\s+.pdf", ".pdf" } -Force
    Write-Host "=>INFO: Spaces removed ...!"

    # Adds ".pdf" ext to all files ecluding pdfs
    Write-Host "Adding extention to Files from $fileFolderPath ..."
    Get-ChildItem -Exclude _backup, *.pdf, *.xlsx, *.bashrc, *.bash_logout, *.profile, *.docx, *.doc, *.pub, *.pptx, *.zip, *.JEPG $fileFolderPath | 
    Rename-Item –NewName { $_.name + ".pdf" } -Force
    Write-Host "=>INFO: Extention Added ...!"

    # Remove Ext double dots to all files ecluding pdfs
    Write-Host "Adding extention to Files from $fileFolderPath ..."
    Get-ChildItem -Exclude _backup, *.xlsx, *.bashrc, *.bash_logout, *.profile, *.docx, *.doc, *.pub, *.pptx, *.zip, *.JEPG $fileFolderPath | 
    Rename-Item –NewName { $_.name.Trim() -replace "..pdf", ".pdf" } -Force
    Write-Host "=>INFO: Ext double dots removed ...!"

    Write-Host "=>INFO: $global:counter files changed (no will apper more than the achual count as some files got override)...."
    
    #Reseting the counter
    $global:counter = 0
}

# Provide Dir path as input to the function
renameFile "D:\powershell_scripting\DemoFiles"