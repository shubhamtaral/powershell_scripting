# -----------------------------BACPAC-Automation--------------------------------#
# We can use the following script to automate the bacpac creation               #
# by giving the name of Database                                                #
# and schedule it with a scheduler                                              #
# ------------------------------------------------------------------------------#

# Import Modules
# Install-Module -Name Az

# ----------------------------------------------- Functions ----------------------------------------------- #

# Function to Perform one time exec for set SQLPackage Path (only Once)
function SetSQLPackagePath {
    # Get the path variables details into the variable 
    $PathVariables = $env:Path 
    # Print the path variable
    # $PathVariables 

    #Check the path existence of the SqlPackage.exe and print its status 
    IF (-not $PathVariables.Contains( "C:\Program Files\Microsoft SQL Server\150\DAC\bin")) { 
        Write-Log 'INFO' "SQLPackage.exe path is not found, Update the environment variable" 
        $env:Path = $env:Path + ";C:\Program Files\Microsoft SQL Server\150\DAC\bin;"  
    } 

}

# Function to Create the Backup & Restore
function BackupAndRestoreDB {
    param (
        [Parameter(Mandatory = $true)][string] $ServerInstance,
        [Parameter(Mandatory = $true)][string] $DatabaseName,
        [Parameter(Mandatory = $true)][string] $SQLUserName,
        [Parameter(Mandatory = $true)][string] $SQLPasswd,
        [Parameter(Mandatory = $true)][string] $BackupDirectory
    )

    Write-Log 'INFO' '==> INFO : Starting Database BackUp to AzStorage!'
        
    $SQLUsername = $SQLUserName
    $SQLPassword = $SQLPasswd
    $SqlCredential = $SQLUserName
    $SqlCredential_pw = ConvertTo-SecureString $SQLPasswd -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($SqlCredential, $SqlCredential_pw)
    $backupDBName = $DatabaseName + '_Backup'
    $baseURL = 'https://backendstorageqa.blob.core.windows.net/backups/'
    $date = $(get-date -f yyyyMMddHHmmss)
    $ext = '.bak'
    $URL = $baseURL + $DatabaseName + '_' + $date + $ext

    try {
        # Backing up Database
        Write-Log 'INFO' ("==> INFO : BackingUp DataBase: $DatabaseName as $URL")
        Backup-SqlDatabase -ServerInstance "$ServerInstance" -Database "$DatabaseName" -BackupFile "$URL" -Credential (Get-Credential $credential) -CopyOnly -CompressionOption on | Out-File  $logfile -Encoding ascii -Append -Width 132


        Write-Log 'INFO' '==> INFO : DataBase backup Complete!'
            
        # Deleting the Backup Database if exist
        RemoveBackupDB $ServerInstance $backupDBName $SQLUsername $SQLPassword
    }
    catch {
        Write-Log 'INFO' '==> ERROR : Failed to Backup database!'
        Write-Log 'INFO' "$_"
        Write-Error $_
    }

    try {
        # Restoring Database
        Write-Log 'INFO' '==> INFO : Starting Database Restoration from AzStorage!'
        Write-Log 'INFO' "==> INFO : Restoring DataBase as: $backupDBName from $URL"
        Restore-SqlDatabase -ServerInstance "$ServerInstance" -Database "$backupDBName" -BackupFile "$URL" -Credential (Get-Credential $credential) -ReplaceDatabase | Out-File  $logfile -Encoding ascii -Append -Width 132


        Write-Log 'INFO' '==> INFO : DataBase Restore Complete!'
    
        # Check if DB restored
        Write-Log 'INFO' '==> INFO : Checking for Database Existence!'
        $DBCheckQuery = " IF (EXISTS (SELECT name FROM master.dbo.sysdatabases WHERE (name = '" + "$DatabaseName" + "'))) BEGIN  Select 1 AS IsDbExist END ELSE BEGIN  Select 0 AS IsDbExist END"   
        $DBCheckQueryOutput = Invoke-Sqlcmd -query $DBCheckQuery -ServerInstance $ServerInstance -Username $SQLUsername -Password $SQLPassword
        Write-Log 'INFO' "==> INFO : $DatabaseName IsDbExist = $($DBCheckQueryOutput.IsDbExist) "

        # Run Queries on DB 
        ModifyDb $ServerInstance $backupDBName $SQLUsername $SQLPassword

        # Forwarding further to BACPAC creation!
        Write-Log 'INFO' '==> INFO : Forwarding further to BACPAC creation!'
        CreateBACPAC $ServerInstance $backupDBName $SQLUsername $SQLPassword $BackupDirectory
    }
    catch {
        Write-Log 'INFO' '==> ERROR : Failed to Backup/Restore database!'
    }

    # Last backup on azure
    Write-Log 'INFO' "==> INFO : Last bak file URL :  $URL"
    RemoveBackupDB $ServerInstance $backupDBName $SQLUsername $SQLPassword
}

# Function to Create a BACPAC
function CreateBACPAC {
    param (
        [Parameter(Mandatory = $true)][string] $SourceServerName,
        [Parameter(Mandatory = $true)][string] $DatabaseName,
        [Parameter(Mandatory = $true)][string] $SQLUserName,
        [Parameter(Mandatory = $true)][string] $SQLPasswd,
        [Parameter(Mandatory = $true)][string] $BackupDirectory
    )
        
    # Requried Veriables 
    $dirName = [io.path]::GetDirectoryName($BackupDirectory) 
    if ($DatabaseName -like "*_Backup") {
        $filename = ($DatabaseName -replace "_Backup", "")
    }
    else {
        $filename = $DatabaseName
    }
    $ext = "bacpac" 
    $TargetFilePath = "$dirName\$filename-$(get-date -f yyyyMMdd).$ext" 

    Write-Log 'INFO' ("==> INFO : Taking BACPAC @ : $TargetFilePath ")
    try {
        # Creating BacPac using SqlPackage 
        SqlPackage.exe /a:Export /ssn:$SourceServerName /sdn:$DatabaseName /tf:$TargetFilePath  /su:$SQLUserName /sp:$SQLPasswd | Out-File  $logfile -Encoding ascii -Append -Width 132


        
        # Checking if BacPac File Created
        $NewestBacPacFile = Get-ChildItem -Path $dirName\$filename*.$ext | Sort-Object LastAccessTime -Descending | Select-Object -First 1
        $file = "$NewestBacPacFile"
        Write-Log 'INFO' "==> INFO : BACPAC created : $FILE "
        Write-Log 'INFO' '==> INFO : Forwarding further for ZIP creation!'
        if ($FILE){
            ZipTheBACPAC "$FILE" "$BackupDirectory" "$DatabaseName"
        }

    }
    catch {
        Write-Log 'INFO' '==> ERROR : BACPAC creation failed!'
        Write-Log 'INFO' "$_"
        Write-Error $_
    }
    
} 

# Zip the BACPAC
function ZipTheBACPAC {
    param (
        [Parameter(Mandatory = $true)][string] $FilePath,
        [Parameter(Mandatory = $true)][string] $destinationPath,
        [Parameter(Mandatory = $true)][string] $DatabaseName
    )

    if ($DatabaseName -like "*_Backup") {
        $filename = ($DatabaseName -replace "_Backup", "")
    }
    else {
        $filename = $DatabaseName
    }
    $ext = "zip" 
    $zipname = "QA_$filename-$(get-date -f yyyyMMdd)-$(get-date -f HHmm).$ext" 
    $zippath = Join-Path $destinationPath $zipname

    Write-Log 'INFO' '==> INFO : Starting Zipping the BACPAC File!'
    try {
        # Zipping the file
        Write-Log 'INFO' "==> INFO : Zipping up $FilePath to $zippath"
        #Compress-Archive -Path $items -DestinationPath $zippath
        & "C:\Program Files\7-Zip\7z" a $zippath $FilePath | Out-File  $logfile -Encoding ascii -Append -Width 132


        Write-Log 'INFO' '==> INFO : Zipping Complete!'
        Write-Log 'INFO' "==> INFO : Deleting $FilePath.."
        Remove-Item $FilePath
        Write-Log 'INFO' '==> INFO : Forwarding further for ZIP upload!'
        UploadToAzBlob $zipname $zippath
    }
    catch {
        Write-Log 'INFO' '==> INFO : Zipping Failed!'
        Write-Error $_
    }

    Write-Log 'INFO' '==> INFO : Forwarding further for files deletion!'
    DeleteOldFileFromDisk $destinationPath

}

# Function to download files from AzStorage Blob/s
function UploadToAzBlob {
    param (
        [Parameter(Mandatory = $true)][string] $FileName,
        [Parameter(Mandatory = $true)][string] $FilePath
    )

    $AzureBlobContainerName = 'bacpacs'
    $connection_string = 'DefaultEndpointsProtocol=https;AccountName=cpaidevstorageaccount;AccountKey=SQcHtBxKMfq0Ul2wXZAPgqYdJ/tJEgWv5GSKQ185DnRljE8Dv62Zwc8uYokJzw6MDgRG2L906nOZp8xQ8aBaRw==;EndpointSuffix=core.windows.net'

    # Connecting to storageAccount
    $storage_account = New-AzStorageContext -ConnectionString $connection_string

    Write-Log 'INFO' "==> INFO : Uploading: $FileName..."
    try {
        Set-AzStorageBlobContent -Container "$AzureBlobContainerName" -File "$FilePath" -Context $storage_account -Force | Out-File  $logfile -Encoding ascii -Append -Width 132


        Write-Log 'INFO' '==> INFO : Upload complete!'

        # Delete 30 day older files form AzureStorage
        Write-Log 'INFO' '==> INFO : Looking for 30 Day older files!'
        $Count = (Get-AzStorageBlob -Container $AzureBlobContainerName -Context $storage_account | Where-Object { ($_.LastModified -lt (Get-Date).AddDays(-30)) } | Measure-Object).Count 
        Write-Log 'INFO' "==> INFO : $Count 30 Day older file/s found!"
        Get-AzStorageBlob -Container $AzureBlobContainerName -Context $storage_account | Where-Object { ($_.LastModified -lt (Get-Date).AddDays(-30)) } | Remove-AzStorageBlob
        Write-Log 'INFO' "==> INFO : Deletion complete!"

        Write-Log 'INFO' "==> INFO : Find the file ==> https://cpaidevstorageaccount.blob.core.windows.net/qabacpac/$Filename"

    }
    catch {
        Write-Log 'INFO' '==> INFO : Upload Failed!'
        Write-Error $_
    }

}

# Delete Backup Database 
function RemoveBackupDB {
    param (
        [Parameter(Mandatory = $true)][string] $ServerInstance,
        [Parameter(Mandatory = $true)][string] $DatabaseName,
        [Parameter(Mandatory = $true)][string] $SQLUsername,
        [Parameter(Mandatory = $true)][string] $SQLPassword

    )

    try {
        # Check if DB exist before restoring
        Write-Log 'INFO' '==> INFO : Checking for Database Existence!'
        $DBCheckQuery = " IF (EXISTS (SELECT name FROM master.dbo.sysdatabases WHERE (name = '" + "$DatabaseName" + "'))) BEGIN  Select 1 AS IsDbExist END ELSE BEGIN  Select 0 AS IsDbExist END"   
        $DBCheckQueryOutput = Invoke-Sqlcmd -query $DBCheckQuery -ServerInstance $ServerInstance -Username $SQLUsername -Password $SQLPassword
        Write-Log 'INFO' "==> INFO : $DatabaseName IsDbExist = $($DBCheckQueryOutput.IsDbExist) "

        If ($DBCheckQueryOutput.IsDbExist -eq 1) {
            Write-Log 'INFO' "==> INFO : Deleting Database: $DatabaseName"
            $DBDropQuery = "DROP DATABASE $DatabaseName"
            $DBDROPQueryOutput = Invoke-Sqlcmd -query $DBDropQuery -ServerInstance $ServerInstance -Username $SQLUsername -Password $SQLPassword
            $DBDROPQueryOutput
            Write-Log 'INFO' '==> INFO : Database Deleted!'
        }
    }
    catch {
        Write-Log 'INFO' '==> ERROR : Failed to Delete Database!'
        Write-Error $_
    }   
}

# Truncate unwanted tables //WorkflowProcessTransitionHistory
function ModifyDb {
    param (
        [Parameter(Mandatory = $true)][string] $ServerInstance,
        [Parameter(Mandatory = $true)][string] $backupDBName,
        [Parameter(Mandatory = $true)][string] $SQLUsername,
        [Parameter(Mandatory = $true)][string] $SQLPassword
    )
    if ($backupDBName.Contains("CMSCentral")) {
        try {
            Write-Log 'INFO' '==> INFO : Executing Query on Database'

            $SQLQuery = "USE $backupDBName
                            update subscribers set DbConnectionString = '(REMOVED)'
                            "

            $SQLQueryOutput = Invoke-Sqlcmd -query $SQLQuery -ServerInstance $ServerInstance -Username $SQLUsername -Password $SQLPassword

            Write-Log 'INFO' "==> INFO : $SQLQuery"
            $SQLQueryOutput
            Write-Log 'INFO' '==> INFO : Query executed!'
        }
        catch {
            Write-Log 'INFO' '==> ERROR : Failed to Update DB!'
            Write-Error $_
        }
    }
    else {
        try {
            Write-Log 'INFO' '==> INFO : Executing Query on Database'

            $SQLDumpQuery = "USE $backupDBName
                            TRUNCATE TABLE ContractRequest_ht
                            TRUNCATE TABLE WorkflowProcessTransitionHistory
                            drop security policy FilterPolicyOnMstDepartment
                            drop security policy FilterPolicyOnMstContractingParty
                            drop security policy FilterPolicyOnMstApplication
                            drop security policy FilterPolicyOnContractRequest
                            drop security policy FilterPolicyOnMstApplicationType
                            drop function fnContractingParty
                            "
            $SQLDumpQueryOutput = Invoke-Sqlcmd -query $SQLDumpQuery -ServerInstance $ServerInstance -Username $SQLUsername -Password $SQLPassword
            Write-Log 'INFO' "==> INFO : $SQLDumpQuery"
            $SQLDumpQueryOutput
        
            Write-Log 'INFO' '==> INFO : Query executed!'

        }
        catch {
            Write-Log 'INFO' '==> ERROR : Failed to Update DB!'
            Write-Error $_
        }
    }
    
}

# Function to delete 30days old file/s from Disk
function DeleteOldFileFromDisk {
    Write-Log 'INFO' '==> INFO : Deleting Old files!'
    try {
        foreach ($i in $args) {
            Write-Log 'INFO' "==> INFO : Checking files for deletion in : $i"
            $Count = (Get-ChildItem -Path $i -Recurse | Where-Object { ($_.LastWriteTime -lt (Get-Date).AddDays(-30)) } | Measure-Object).Count
            Write-Log 'INFO' "==> INFO : $Count files found in $i"
            Get-ChildItem -Path $i -Recurse | Where-Object { ($_.LastWriteTime -lt (Get-Date).AddDays(-30)) } | Remove-Item
            Write-Log 'INFO' "==> INFO : Deletion complete!"
        }
    }
    catch {
        Write-Log 'INFO' '==> ERROR : Failed deleting Old files!'
        Write-Error $_
    }
}

# Custom log writer
Function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False)]
        [ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG")]
        [String]
        $Level = "INFO",

        [Parameter(Mandatory = $True)]
        [string]
        $Message
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp $Message" # We are not using Level add this script  
    If ($logfile) {
        Add-Content $logfile -Value $Line
        Write-Host $Line
    }
    Else {
        Write-Host $Line
    }
}

# ----------------------------------------------- Input Values Here ----------------------------------------------- #

# Req Variables
$Server = 'cpai-uat-sql-09.8b98e47e8d53.database.windows.net'
$DBName = 'CMSCentral'
$SQLUser = 'ContractPodAi'
$SQLPasswd = 'wDGE0D8!MVpzdel5'  
$LocalFilePath = 'F:\AutoBacpac\backups\' # (This path is specific to mgnt server)

$DirectBacpac = $false

$ifConnected = $false

#LogFile
$file = 'QA_' + $DBName + '_' + (get-date).ToString("yyyyMMdd") + ".log"
$logfile = "F:\AutoBacpac\Logs\$file"  # (*Given path specific to mgnt specific)
Set-Content $logfile -Value ("Execution Start Time : " + (get-date).ToString() + "`r`n")

$StartTime = (Get-Date)
SetSQLPackagePath

# ----------------------------------------------- Test Connection ----------------------------------------------- #

try {
    Write-Log 'INFO' "==> INFO : Trying to connect DataBase server"
    $connectionString = 'Data Source={0};database={1};User ID={2};Password={3}' -f $Server, $DBName, $SQLUser, $SQLPasswd
    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
    $sqlConnection.Open()
    $ifConnected = $true
    Write-Log 'INFO' "==> INFO : Database Connected"
}
catch {
    Write-Log 'INFO' "$_"
    $ifConnected = $false
}
finally {
    $sqlConnection.Close()
}

# ----------------------------------------------- Start ----------------------------------------------- #

if ($DirectBacpac -eq $true -and $ifConnected) {
    # if you are looking for bacpac without any changes in the current DB
    CreateBACPAC $Server $DBName $SQLUser $SQLPasswd $LocalFilePath
}

if ($DirectBacpac -eq $false -and $ifConnected) {
    # if you are looking for bacpac with changes in the current DB eg (Removing sensitive data)
    BackupAndRestoreDB $Server $DBName $SQLUser $SQLPasswd $LocalFilePath
}

$EndTime = (Get-Date)
Write-Log 'INFO' ('==> INFO : Process Completed Duration: {0:mm} min {0:ss} sec' -f ($EndTime - $StartTime))

