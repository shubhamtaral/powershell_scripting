# Import MOdules
Import-Module -Name SqlServer
Install-Module -Name Az 

# Function to Perform one time exec for set SQLPackage Path
function SetSQLPackagePath {
    # Get the path variables details into the variable 
    $PathVariables = $env:Path 
    # Print the path variable
    # $PathVariables 

    
    #Check the path existence of the SqlPackage.exe and print its status 
    IF (-not $PathVariables.Contains( "C:\Program Files\Microsoft SQL Server\150\DAC\bin")) { 
        write-host "SQLPackage.exe path is not found, Update the environment variable" 
        $env:Path = $env:Path + ";C:\Program Files\Microsoft SQL Server\150\DAC\bin;"  
    } 

}

# Function to Create the Backup & Restore
function BackupAndRestoreDB {
    param (
        [Parameter(Mandatory = $true)][string] $ServerInstance,
        [Parameter(Mandatory = $true)][string] $databaseName,
        [Parameter(Mandatory = $true)][string] $BackupDirectory
    )

    Write-Host '==> INFO : Starting Database BackUp to AzStorage!'
        
    $SQLUsername = "ContractPodAi"
    $SQLPassword = "ContractPod2019!"
    $SqlCredential = 'ContractPodAi'
    $SqlCredential_pw = ConvertTo-SecureString 'ContractPod2019!' -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($SqlCredential, $SqlCredential_pw)
    $backupDBName = $DatabaseName + '_Backup'
    $baseURL = 'https://backendstorageqa.blob.core.windows.net/backups/'
    $date = $(get-date -f yyyyMMddhhmmss)
    $ext = '.bak'
    $URL = $baseURL + $databaseName + '_' + $date + $ext

    try {
        # Backing up Database
        Write-Host '==> INFO : BackingUp DataBase: ' $databaseName 'as' $URL
        Backup-SqlDatabase -ServerInstance "$ServerInstance" -Database "$databaseName" -BackupFile "$URL" -Credential (Get-Credential $credential) -CopyOnly -CompressionOption on
        Write-Host '==> INFO : DataBase backup Complete!'
    }
    catch {
        Write-Host '==> INFO : Failed to Backup database!'
    }

    # Deletiong the Backedup Database if exist
    RemoveBackupDB $ServerInstance $backupDBName

    try {
        # Restoring Database
        Write-Host '==> INFO : Starting Database Restoration from AzStorage!'
        Write-Host '==> INFO : Restoring DataBase as: ' $backupDBName 'from' $URL
        Restore-SqlDatabase -ServerInstance "$ServerInstance" -Database "$backupDBName" -BackupFile "$URL" -Credential (Get-Credential $credential) -ReplaceDatabase
        Write-Host '==> INFO : DataBase Restore Complete!'
    }
    catch {
        Write-Host '==> INFO : Failed to Restore database!'
    }
    
    try {
        # Truncate unwanted tables //WorkflowProcessTransitionHistory
        $SQLTruncateQuery = "USE $backupDBName
                            TRUNCATE TABLE [WorkflowProcessTransitionHistory]"
    
        $SQLTruncateQueryOutput = Invoke-Sqlcmd -query $SQLTruncateQuery -ServerInstance $ServerInstance -Username $SQLUsername -Password $SQLPassword
        $SQLTruncateQueryOutput
        Write-Host '==> INFO : Table truncated!'
    }
    catch {
        Write-Host '==> INFO : Failed to Truncate table!'
    }

    # Forwarding futher to BACPAC creation!
    Write-Host '==> INFO : Forwarding futher to BACPAC creation!'
    CreateBACPAC $ServerInstance $backupDBName $SQLUsername $SQLPassword $BackupDirectory

    # Last backup on azure
    Write-Host '==> INFO : Last bak file URL : ' $URL
}

# Delete Backup Database 
function RemoveBackupDB {
    param (
        [Parameter(Mandatory = $true)][string] $ServerInstance,
        [Parameter(Mandatory = $true)][string] $databaseName
    )

    $SQLUsername = "ContractPodAi"
    $SQLPassword = "ContractPod2019!"
    try{
        # Check if DB exist before restoring
        Write-Host '==> INFO : Checking for Database Existance!'
        $DBCheckQuery = " IF (EXISTS (SELECT name FROM master.dbo.sysdatabases WHERE (name = '" + "$databaseName" + "'))) BEGIN  Select 1 AS IsDbExist END ELSE BEGIN  Select 0 AS IsDbExist END"   
        $DBCheckQueryOutput = Invoke-Sqlcmd -query $DBCheckQuery -ServerInstance $ServerInstance -Username $SQLUsername -Password $SQLPassword
        Write-Host "==> INFO : $databaseName IsDbExist = $($DBCheckQueryOutput.IsDbExist) "

        If ($DBCheckQueryOutput.IsDbExist -eq 1) {
            Write-Host '==> INFO : Deleting Database ' $databaseName
            $DBDropQuery = "DROP DATABASE $databaseName"
            $DBDROPQueryOutput = Invoke-Sqlcmd -query $DBDropQuery -ServerInstance $ServerInstance -Username $SQLUsername -Password $SQLPassword
            $DBDROPQueryOutput
            Write-Host '==> INFO : Database Deleted!' 
        }
    }catch{
        Write-Host '==> INFO : Failed to Delete Database!'
    }   
}

# Function to Create a BACPAC
function CreateBACPAC {
    param (
        [Parameter(Mandatory = $true)][string] $SourceServerName,
        [Parameter(Mandatory = $true)][string] $DatabaseName,
        [Parameter(Mandatory = $true)][string] $DatabaseUserName,
        [Parameter(Mandatory = $true)][string] $DatabasePasswd,
        [Parameter(Mandatory = $true)][string] $BackupDirectory
    )
        
    # Requried Veriables 
    $dirName = [io.path]::GetDirectoryName($BackupDirectory) 
    $filename = $DatabaseName
    $ext = "bacpac" 
    $TargetFilePath = "$dirName\$filename-$(get-date -f yyyyMMdd).$ext" 

    Write-Host '==> INFO : Taking BACPAC @ : ' $TargetFilePath 
    try{
        # Creating BacPac using SqlPackage 
        SqlPackage.exe /a:Export /ssn:$SourceServerName /sdn:$DatabaseName /tf:$TargetFilePath  /su:$DatabaseUserName /sp:$DatabasePasswd
        
        # Checking if BacPac File Created
        $NewestBacPacFile = Get-ChildItem -Path $dirName\$filename*.$ext | Sort-Object LastAccessTime -Descending | Select-Object -First 1
        $file = "$NewestBacPacFile"
        
        Write-Host '==> INFO : BACPAC created : ' $FILE 

        Write-Host '==> INFO : Forwarding futher for ZIP creation!'

        ZipTheBACPACK "$FILE" "$BackupDirectory" "$DatabaseName"

    }catch{
        Write-Host '==> INFO : BACPAC creation failed!'
    }
    
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

    Write-Host '==> INFO : Starting Zipping the BACPAC File!'
    try {
        # Zipping the file
        Write-Host "==> INFO : Zipping up $FilePath to $zippath"
        #Compress-Archive -Path $items -DestinationPath $zippath
        & "C:\Program Files\7-Zip\7z" a $zippath $FilePath
        Write-Host '==> INFO : Zipping Complete!'
        Write-Host '==> INFO : Forwarding futher for ZIP creation!'
        UploadToAzBlob $zipname $zippath
    }catch{
        Write-Host '==> INFO : Zipping Failed!'
    }
}

# Funtion to download files from AzStorage Blob/s
function UploadToAzBlob {
    param (
        [Parameter(Mandatory = $true)][string] $FileName,
        [Parameter(Mandatory = $true)][string] $FilePath
    )

    $AzureBlobContainerName = 'qabacpac'
    $connection_string = 'DefaultEndpointsProtocol=https;AccountName=cpaidevstorageaccount;AccountKey=SQcHtBxKMfq0Ul2wXZAPgqYdJ/tJEgWv5GSKQ185DnRljE8Dv62Zwc8uYokJzw6MDgRG2L906nOZp8xQ8aBaRw==;EndpointSuffix=core.windows.net'

    # Connecting to storageAccount
    $storage_account = New-AzStorageContext -ConnectionString $connection_string

    Write-Host '==> INFO : Uploading: ' $FileName '...'
    try {
        Set-AzStorageBlobContent -Container "$AzureBlobContainerName" -File "$FilePath" -Context $storage_account -Force
        Write-Host '==> INFO : Upload complete!'
        Write-Host "==> INFO : Find the file ==> https://cpaidevstorageaccount.blob.core.windows.net/qabacpac/$Filename"
    }
    catch{
        Write-Host '==> INFO : Upload Failed!'
    }
}

$StartTime = (Get-Date).Millisecond
SetSQLPackagePath
BackupAndRestoreDB 'shr-cp-db-qa.04e49d8760a0.database.windows.net' 'QA_CL_QA1' 'F:\AutoBacpac\backups'
$EndTime = (Get-Date).Millisecond
$TotalTime = ($StartTime - $EndTime)/60000
Write-Host "==> INFO : Process Completed in $($TotalTime) Minutes!"