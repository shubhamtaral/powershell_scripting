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
            # can improve if make use of Robocopy and Check for file exsistace
            robocopy -Path $File -Destination $fileFolderPath/_backup 
            Write-Host "Copied $File to /_backup folder ..."
            $global:counter++
        }    
    }

    # Get BackUp
    Write-Host "=>INFO: Taking Backup of Files from $fileFolderPath Which needs a change..."
    # Copy pdf files which needs renaming
    $pdfFiles = (Get-ChildItem -Exclude _backup, *.xlsx, *.bashrc, *.bash_logout, *.profile, *.docx, *.doc, *.pub, *.pptx, *.zip, *.JEPG $fileFolderPath |
        Where-Object { $_.Name -match $pattern } |
        ForEach-Object { @{Path = $_.fullname } }).Values
    copyfiles $pdfFiles 

    # Copy non-pdf files which needs renaming
    $nonpdfFiles = (Get-ChildItem -Exclude _backup, *.pdf, *.xlsx, *.bashrc, *.bash_logout, *.profile, *.docx, *.doc, *.pub, *.pptx, *.zip, *.JEPG  $fileFolderPath |
        ForEach-Object { @{Path = $_.fullname } }).Values
    copyfiles $nonpdfFiles 

    # Start Renaming all files
    Write-Host "=>INFO: Renaming Files from $fileFolderPath ..."
    Get-ChildItem -Exclude _backup, *.xlsx, *.bashrc, *.bash_logout, *.profile, *.docx, *.doc, *.pub, *.pptx, *.zip, *.JEPG $fileFolderPath | 
    Rename-Item -NewName { $_.name.trim() -replace $pattern , '_' } -Force
    Write-Host "=>INFO: Renaming Files Done! ..."
    
    # Adds ".pdf" ext to all files ecluding pdfs
    Write-Host "Adding extention to Files from $fileFolderPath ..."
    Get-ChildItem -Exclude _backup, *.pdf, *.xlsx, *.bashrc, *.bash_logout, *.profile, *.docx, *.doc, *.pub, *.pptx, *.zip, *.JEPG $fileFolderPath | 
    Rename-Item -NewName { $_.name + ".pdf" } -Force
    Write-Host "=>INFO: Extention Added ...!"

    Write-Host "=>INFO: $global:counter files changed (no will apper more than the achual count as some files got override)...."
    
    #Reseting the counter
    $global:counter = 0
}

# Provide Dir path as input to the function
renameFile "D:\powershell_scripting\DemoFiles"
