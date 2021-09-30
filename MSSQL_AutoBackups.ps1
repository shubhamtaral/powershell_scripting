# Function to Perform one time exec for set SQLPackage Path
function SetSQLPackagePath {
    # Get the path variables details into the variable 
    $PathVariables = $env:Path 
    #Print the path variable
    $PathVariables 
 
    #Check the path existence of the SqlPackage.exe and print its status 
    IF (-not $PathVariables.Contains( "C:\Program Files\Microsoft SQL Server\150\DAC\bin")) { 
        write-host "SQLPackage.exe path is not found, Update the environment variable" 
        $env:Path = $env:Path + ";C:\Program Files\Microsoft SQL Server\150\DAC\bin;"  
    } 
}

# Function to Create a BACPAC
function CreateBACPAC {
    param (
        [Parameter(Mandatory = $true)][string] $SourceServerName,
        [Parameter(Mandatory = $true)][string] $DatabaseName,
        [Parameter(Mandatory = $true)][string] $DatabaseUserName,
        [Parameter(Mandatory = $true)][string] $DatabasePasswd,
        [Parameter(Mandatory = $true)][string] $BackupDirectory,
        [Parameter(Mandatory = $true)][string] $TargetserverName
    )
    
    # Setting sqlPackage 
    SetSQLPackagePath

    # Requried Veriables 
    $dirName = [io.path]::GetDirectoryName($BackupDirectory) 
    $filename = $DatabaseName
    $ext = "bacpac" 
    $TargetFilePath = "$dirName\$filename-$(get-date -f yyyyMMdd).$ext" 

    Write-Host '==> INFO : Taking BACPAC : ' $TargetFilePath 
 
    # Creating BacPac using SqlPackage
    SqlPackage.exe /a:Export /ssn:$SourceServerName /sdn:$DatabaseName /su:$DatabaseUserName /sp:$DatabasePasswd /tf:$TargetFilePath 
 
    # Checking if BacPac File Created
    $NewestBacPacFile = Get-ChildItem -Path $dirName\$filename*.$ext | Sort-Object LastAccessTime -Descending | Select-Object -First 1
    $file = "$NewestBacPacFile"
 
    Write-Host '==> INFO : BACPAC created : ' $file 

    ZipTheBACPACK "$file" "$BackupDirectory" "$DatabaseName"

} 

# Zip the BACPAC
function ZipTheBACPACK {
    param (
        [Parameter(Mandatory = $true)][string] $FilePath,
        [Parameter(Mandatory = $true)][string] $destiationPath,
        [Parameter(Mandatory = $true)][string] $DatabaseName
    )

    $filename = $DatabaseName
    $ext = "zip" 
    $zipname = "$filename-$(get-date -f yyyyMMdd).$ext" 
    $zippath = Join-Path $destiationPath $zipname

    # Zipping the folder
    Write-Host "==> INFO : Backing up $FilePath to $zippath"
    #Compress-Archive -Path $items -DestinationPath $zippath
    & "C:\Program Files\7-Zip\7z" a $zippath $FilePath
}

CreateBACPAC 'shr-cp-db-qa.04e49d8760a0.database.windows.net' 'QA_CL_QA1' 'ContractPodAi' 'ContractPod2019!' 'F:\DBBackups' 'DESKTOP-JOJOSJI'


# https://docs.microsoft.com/en-us/powershell/module/sqlserver/backup-sqldatabase?view=sqlserver-ps#example-11--backup-a-database-to-the-azure-blob-storage-service
# https://docs.microsoft.com/en-us/powershell/module/sqlserver/restore-sqldatabase?view=sqlserver-ps#example-8--restore-a-database-from-the-azure-blob-storage-service
