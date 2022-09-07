Import-Module JiraPS

# Variables
$global:Tenant = $null
$global:BakURL = $null
$global:RestoreDBname = $null
$global:RestoreDBServer = $null
$global:RestoreDBname = $null
$global:QueiesExecuted = $false
$global:CICMTicketNo = (Read-Host "`nPlease enter CICM Ticket No")
$global:ServerInstance = 'cpai-peu-sql-01.700bb8e8fb23.database.windows.net'
$global:SQLUsername = 'ContractPodAi'
$global:SQLPassword = 'Ol5LjGlafpDjB2cC'
$global:Database = 'InternalStats'
$global:ServerJSON = @'
{
    "PEU": {
      "ServerInstance": "cpai-peu-sql-01.700bb8e8fb23.database.windows.net",
      "SQLUsername": "ContractPodAi",
      "SQLPassword": "Ol5LjGlafpDjB2cC",
      "Database": "InternalStats"
    },
    "DEV1": {
      "ServerInstance": "cpai-dev-sql-01.39932b3bf5f3.database.windows.net",
      "SQLUsername": "ContractPodAi",
      "SQLPassword": "45S9fSHMm0*vsef"
    },
    "DEV2": {
      "ServerInstance": "cpai-dev-sql-02.12aeca4e0f43.database.windows.net",
      "SQLUsername": "ContractPodAi",
      "SQLPassword": "fSl9F*0iKzwDqRC%"
    },
    "DEV4": {
      "ServerInstance": "cpai-dev-sql-04.7feeef40c74b.database.windows.net",
      "SQLUsername": "ContractPodAi",
      "SQLPassword": "5OcaAS4vVpXMgUec"
    }
}
'@


if (Get-JiraSession) {
    Get-JiraIssue -Key CICM-$global:CICMTicketNo
}
else {
    $credential = Get-Credential -UserName 'shubham.taral@contractpodai.com' -Message "Add Token here 'ayRktmRPwSMjdiINSzLjAECA'" 
    Set-JiraConfigServer 'https://newgalexy.atlassian.net'  # required since version 2.10
    New-JiraSession -Credential $credential

    Get-JiraIssue -Key CICM-$global:CICMTicketNo
}

# Function to Search Tenant
function getTenant {
    # Req Variables

    $TenantName = Read-Host "`nPlease enter tenant url"
    try {
        Write-Host  '==> INFO : Searching tenant DB'
        $SQLFindTenantQuery = "USE $global:Database SELECT * from Tenants where TenantUrl like '$TenantName' "
        $SQLFindTenantQueryOutput = Invoke-Sqlcmd -query $SQLFindTenantQuery -ServerInstance $global:ServerInstance -Username $global:SQLUsername -Password $global:SQLPassword
        if ($SQLFindTenantQueryOutput) {
            Write-Host "==> INFO : Tenant Database Found : $($SQLFindTenantQueryOutput.TenantDatabase) in $($SQLFindTenantQueryOutput.SqlServerId)" -ForegroundColor Green
            $global:Tenant = $SQLFindTenantQueryOutput
        }
        else {
            Write-Host "==> WARN: Please enter correct tenant URL" -ForegroundColor Red
            break
        }
    }
    catch {
        Write-Error "==> ERROR: Failed to find tenant!"
    }   
}

# Create Backup
function createBackup {
    $DatabaseName = $($global:Tenant.TenantDatabase)
    $SqlServerId = $($global:Tenant.SqlServerId)

    Write-Host "==> INFO : Do you want to continue with the backup of" -ForegroundColor Yellow -NoNewline; Write-Host " $($global:Tenant.TenantDatabase)?" -ForegroundColor Green
    Write-Host "Press 'Y' to " -ForegroundColor Yellow -NoNewline; Write-Host "Yes" -ForegroundColor Blue
    Write-Host "Press 'N' to " -ForegroundColor Yellow -NoNewline; Write-Host "No" -ForegroundColor Blue
    $selction = (Read-Host "`nPlease make a selection")

    if ($selction -eq 'Y') {
        # try {
        Write-Host  '==> INFO : Searching tenant Server Details'
        $SQLFindServerDetailsQuery = "USE $global:Database SELECT * from SqlServers where Id = '$SqlServerId' "
        $SQLFindServerDetailsQueryOutput = Invoke-Sqlcmd -query $SQLFindServerDetailsQuery -ServerInstance $global:ServerInstance -Username $global:SQLUsername -Password $global:SQLPassword
        if ($SQLFindServerDetailsQueryOutput) {
            Write-Host "==> INFO : Server Found : $($SQLFindServerDetailsQueryOutput.Id) $($SQLFindServerDetailsQueryOutput.Region)" -ForegroundColor Green
            Write-Host '==> INFO : Starting Database BackUp to AzStorage!'
                
            $ServerInstance = $SQLFindServerDetailsQueryOutput.Host
            $SQLUsername = $SQLFindServerDetailsQueryOutput.Username
            $SQLPassword = $SQLFindServerDetailsQueryOutput.Password
            $SqlCredential = ConvertTo-SecureString $SQLPassword -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential ($SQLUsername, $SqlCredential)
            $backupDBName = $DatabaseName + '_Backup'
            $baseURL = "https://cpaipeustorage.blob.core.windows.net/auto-sqlbackups/"
            $date = $(get-date -f yyyyMMddHHmmss)
            $ext = '.bak'
            $URL = $baseURL + $DatabaseName + '_' + $date + $ext

            # Backing up Database
            Write-Host ("==> INFO : BackingUp DataBase: $DatabaseName as $URL")
            Write-Host "Backup-SqlDatabase -ServerInstance "$ServerInstance" -Database "$DatabaseName" -BackupFile "$URL" -Credential (Get-Credential $credential) -CopyOnly -CompressionOption on"

            Backup-SqlDatabase -ServerInstance "$ServerInstance" -Database "$DatabaseName" -BackupFile "$URL" -Credential (Get-Credential $credential) -CopyOnly -CompressionOption on
            # Deleting the Backup Database if exist
            RemoveBackupDB $ServerInstance $backupDBName $SQLUsername $SQLPassword

            # Check if DB restored
            Write-Host '==> INFO : Checking for Database Existence!'
            $DBCheckQuery1 = " IF (EXISTS (SELECT name FROM master.dbo.sysdatabases WHERE (name = '" + "$DatabaseName" + "'))) BEGIN  Select 1 AS IsDbExist END ELSE BEGIN  Select 0 AS IsDbExist END"   
            $DBCheckQueryOutput1 = Invoke-Sqlcmd -query $DBCheckQuery1 -ServerInstance $ServerInstance -Username $SQLUsername -Password $SQLPassword
            Write-Host "==> INFO : $DatabaseName IsDbExist = $($DBCheckQueryOutput1.IsDbExist) "

            if ($($DBCheckQueryOutput1.IsDbExist) -eq 1) {
                # Restoring Database
                Write-Host '==> INFO : Starting Database Restoration from AzStorage!'
                Write-Host "==> INFO : Restoring DataBase as: $backupDBName from $URL"
                Restore-SqlDatabase -ServerInstance "$ServerInstance" -Database "$backupDBName" -BackupFile "$URL" -Credential (Get-Credential $credential) -ReplaceDatabase
                Write-Host '==> INFO : DataBase Restore Complete!'
            }
                    
            # Check if DB restored
            Write-Host '==> INFO : Checking for Database Existence!'
            $DBCheckQuery2 = " IF (EXISTS (SELECT name FROM master.dbo.sysdatabases WHERE (name = '" + "$backupDBName" + "'))) BEGIN  Select 1 AS IsDbExist END ELSE BEGIN  Select 0 AS IsDbExist END"   
            $DBCheckQueryOutput2 = Invoke-Sqlcmd -query $DBCheckQuery2 -ServerInstance $ServerInstance -Username $SQLUsername -Password $SQLPassword
            Write-Host "==> INFO : $backupDBName IsDbExist = $($DBCheckQueryOutput2.IsDbExist) "
            
            # Run Queries on DB 
            if ($($DBCheckQueryOutput2.IsDbExist) -eq 1) {
                ModifyDb $ServerInstance $backupDBName $SQLUsername $SQLPassword
            }

            # Backing up Database
            if($global:QueiesExecuted){
                $BakURL = $baseURL + $DatabaseName + '_CICM_' + $date + $ext
                Write-Host ("==> INFO : BackingUp DataBase: $backupDBName as $BakURL")
                Backup-SqlDatabase -ServerInstance "$ServerInstance" -Database "$backupDBName" -BackupFile "$BakURL" -Credential (Get-Credential $credential) -CopyOnly -CompressionOption on
                $global:BakURL = $BakURL
            }

            # Deleting the Backup Database if exist
            RemoveBackupDB $ServerInstance $backupDBName $SQLUsername $SQLPassword
        }
        else {
            Write-Host "==> WARN: Please enter correct tenant URL" -ForegroundColor Red
        }
        # }
        # catch {
        #     Write-Error "==> ERROR: Unable to find the DB Server"
        # }
    }
    elseif ($selction -eq 'N') {
        { "Okay! Back to Main Menu" }
    }
    else {
        { "Invavlid Choice!" }
    }

}

# Restore DB
function restoreDB {
    if ($global:BakURL) {
        $DatabaseName = $($global:Tenant.TenantDatabase) + "_CICM$global:CICMTicketNo"
        $ServerObj = ConvertFrom-Json $global:ServerJSON

        Write-Host "==> INFO : Where do you want to restore the backup of" -ForegroundColor Yellow -NoNewline; Write-Host " $DatabaseName?" -ForegroundColor Green
        Write-Host "Press '1' to " -ForegroundColor Yellow -NoNewline; Write-Host "DEV1" -ForegroundColor Blue
        Write-Host "Press '2' to " -ForegroundColor Yellow -NoNewline; Write-Host "DEV2" -ForegroundColor Blue
        Write-Host "Press '4' to " -ForegroundColor Yellow -NoNewline; Write-Host "DEV4" -ForegroundColor Blue

        switch (Read-Host "`nPlease make a selection") {
            '1' {
                $SqlCredential = ConvertTo-SecureString $ServerObj.DEV1.SQLPassword -AsPlainText -Force
                $credential = New-Object System.Management.Automation.PSCredential ($ServerObj.DEV1.SQLUsername, $SqlCredential)

                # Restoring Database
                Write-Host '==> INFO : Starting Database Restoration from AzStorage!'
                Write-Host "==> INFO : Restoring DataBase as: $DatabaseName from $BakURL"
                Restore-SqlDatabase -ServerInstance "$($ServerObj.DEV1.ServerInstance)" -Database "$DatabaseName" -BackupFile "$BakURL" -Credential (Get-Credential $credential) -ReplaceDatabase
                Write-Host '==> INFO : DataBase Restore Complete!'
    
                # Check if DB restored
                Write-Host '==> INFO : Checking for Database Existence!'
                $DBCheckQuery = " IF (EXISTS (SELECT name FROM master.dbo.sysdatabases WHERE (name = '" + "$DatabaseName" + "'))) BEGIN  Select 1 AS IsDbExist END ELSE BEGIN  Select 0 AS IsDbExist END"   
                $DBCheckQueryOutput = Invoke-Sqlcmd -query $DBCheckQuery -ServerInstance $($ServerObj.DEV1.ServerInstance) -Username $($ServerObj.DEV1.SQLUsername) -Password $($ServerObj.DEV1.SQLPassword)
                Write-Host "==> INFO : $DatabaseName IsDbExist = $($DBCheckQueryOutput.IsDbExist) "
                $global:RestoreDBname = $DatabaseName
                $global:RestoreDBServer = "DEV1"
    
            }
            '2' { 
                $SqlCredential = ConvertTo-SecureString $ServerObj.DEV2.SQLPassword -AsPlainText -Force
                $credential = New-Object System.Management.Automation.PSCredential ($ServerObj.DEV2.SQLUsername, $SqlCredential)

                # Restoring Database
                Write-Host '==> INFO : Starting Database Restoration from AzStorage!'
                Write-Host "==> INFO : Restoring DataBase as: $DatabaseName from $BakURL"
                Restore-SqlDatabase -ServerInstance "$($ServerObj.DEV2.ServerInstance)" -Database "$DatabaseName" -BackupFile "$BakURL" -Credential (Get-Credential $credential) -ReplaceDatabase
                Write-Host '==> INFO : DataBase Restore Complete!'
    
                # Check if DB restored
                Write-Host '==> INFO : Checking for Database Existence!'
                $DBCheckQuery = " IF (EXISTS (SELECT name FROM master.dbo.sysdatabases WHERE (name = '" + "$DatabaseName" + "'))) BEGIN  Select 1 AS IsDbExist END ELSE BEGIN  Select 0 AS IsDbExist END"   
                $DBCheckQueryOutput = Invoke-Sqlcmd -query $DBCheckQuery -ServerInstance $($ServerObj.DEV2.ServerInstance) -Username $($ServerObj.DEV2.SQLUsername) -Password $($ServerObj.DEV2.SQLPassword)
                Write-Host "==> INFO : $DatabaseName IsDbExist = $($DBCheckQueryOutput.IsDbExist) "
                $global:RestoreDBname = $DatabaseName
                $global:RestoreDBServer = "DEV2"
            }
            '3' { "Nothing here" }
            '4' { 
                $SqlCredential = ConvertTo-SecureString $ServerObj.DEV4.SQLPassword -AsPlainText -Force
                $credential = New-Object System.Management.Automation.PSCredential ($ServerObj.DEV4.SQLUsername, $SqlCredential)

                # Restoring Database
                Write-Host '==> INFO : Starting Database Restoration from AzStorage!'
                Write-Host "==> INFO : Restoring DataBase as: $DatabaseName from $BakURL"
                Restore-SqlDatabase -ServerInstance "$($ServerObj.DEV4.ServerInstance)" -Database "$DatabaseName" -BackupFile "$BakURL" -Credential (Get-Credential $credential) -ReplaceDatabase
                Write-Host '==> INFO : DataBase Restore Complete!'
    
                # Check if DB restored
                Write-Host '==> INFO : Checking for Database Existence!'
                $DBCheckQuery = " IF (EXISTS (SELECT name FROM master.dbo.sysdatabases WHERE (name = '" + "$DatabaseName" + "'))) BEGIN  Select 1 AS IsDbExist END ELSE BEGIN  Select 0 AS IsDbExist END"   
                $DBCheckQueryOutput = Invoke-Sqlcmd -query $DBCheckQuery -ServerInstance $($ServerObj.DEV4.ServerInstance) -Username $($ServerObj.DEV4.SQLUsername) -Password $($ServerObj.DEV4.SQLPassword)
                Write-Host "==> INFO : $DatabaseName IsDbExist = $($DBCheckQueryOutput.IsDbExist) "
                $global:RestoreDBname = $DatabaseName
                $global:RestoreDBServer = "DEV4" 
            }
            '5' { 'Comming Soon..' }
            'Q' { "Exit" }
            Default {
                "No matches found, Please make right selection "
            }
        }
    }
    else {
        Write-Host "==> WARN: Please create backup first" -ForegroundColor Red
    }
}

# Function to create SQL User
function createSQLUser {
    $ServerObj = ConvertFrom-Json $global:ServerJSON

    Write-Host "==> INFO : Do you want to continue user creation of" -ForegroundColor Yellow -NoNewline; Write-Host " $($global:RestoreDBname) in $($global:RestoreDBServer) ?" -ForegroundColor Green
    Write-Host "Press 'Y' to " -ForegroundColor Yellow -NoNewline; Write-Host "Yes" -ForegroundColor Blue
    Write-Host "Press 'N' to " -ForegroundColor Yellow -NoNewline; Write-Host "Create for another DB" -ForegroundColor Blue

    switch (Read-Host "`nPlease make a selection") {
        'Y' { 
            $password = & "$PSScriptRoot\generate-password.ps1"
            $Username = "cicm$global:CICMTicketNo"
    
            $CreateUserLoginQuery = "create login $username with password = '$password'
                                    create user $username for login $username
                                    EXEC sp_addrolemember N'db_owner', N'$username'"
    
            $CreateUserLoginQueryOutput = Invoke-Sqlcmd -query $CreateUserLoginQuery -ServerInstance $($($ServerObj.$($global:RestoreDBServer)).ServerInstance) -Username $($($ServerObj.$($global:RestoreDBServer)).SQLUsername) -Password $($($ServerObj.$($global:RestoreDBServer)).SQLPassword) 
            $CreateUserLoginQueryOutput
            Write-Host "Username : $Username `nPassword: $password"
        }
        'N' {             
            $password = & "$PSScriptRoot\generate-password.ps1"
            $Username = (Read-Host "`nPlease enter username")
            Write-Host "Username : $Username `nPassword: $password" 
        }
        Default {
            "No matches found, Please make right selection "
        }
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
        Write-Host '==> INFO : Checking for Database Existence!'
        $DBCheckQuery = " IF (EXISTS (SELECT name FROM master.dbo.sysdatabases WHERE (name = '" + "$DatabaseName" + "'))) BEGIN  Select 1 AS IsDbExist END ELSE BEGIN  Select 0 AS IsDbExist END"   
        $DBCheckQueryOutput = Invoke-Sqlcmd -query $DBCheckQuery -ServerInstance $ServerInstance -Username $SQLUsername -Password $SQLPassword
        Write-Host "==> INFO : $DatabaseName IsDbExist = $($DBCheckQueryOutput.IsDbExist) "

        If ($DBCheckQueryOutput.IsDbExist -eq 1) {
            Write-Host "==> INFO : Deleting Database: $DatabaseName"
            $DBDropQuery = "DROP DATABASE $DatabaseName"
            $DBDROPQueryOutput = Invoke-Sqlcmd -query $DBDropQuery -ServerInstance $ServerInstance -Username $SQLUsername -Password $SQLPassword
            $DBDROPQueryOutput
            Write-Host '==> INFO : Database Deleted!'
        }
    }
    catch {
        Write-Error "==> ERROR: Failed to remove/delete DB"
    }
}

# Modify Backup Database 
function ModifyDb {
    param (
        [Parameter(Mandatory = $true)][string] $ServerInstance,
        [Parameter(Mandatory = $true)][string] $backupDBName,
        [Parameter(Mandatory = $true)][string] $SQLUsername,
        [Parameter(Mandatory = $true)][string] $SQLPassword
    )

    try {
        Write-Host '==> INFO : Executing Query on Database'

        $EncryptionOffQuery = "Alter database $backupDBName set encryption Off"

        $SQLDumpQuery = "USE $backupDBName
                        TRUNCATE TABLE ContractRequest_ht
                        TRUNCATE TABLE WorkflowProcessTransitionHistory
                        "

        $CheckEncryptionStatus = "Select d.name, dek.encryption_state_desc
                                from sys.databases d
                                left join sys.dm_database_encryption_keys dek on dek.database_id = d.database_id
                                where --d.name not in ('master', 'model', 'msdb') and 
                                d.name like '%$backupDBName%'
                                order by d.name
                                "
        $MaskingQuery = "USE $backupDBName
                        update Client set ClientName = Concat('ClientName', ClientId) where ClientName is not NULL;
                        update ClientAddressDetails set Address = Concat('Address', ClientAddressdetailId) where Address is not NULL;
                        update ClientEmaildetails set EmailID = Concat('test', ClientEmaildetailId ,'@test.com', ClientEmaildetailId) where EmailID is not NULL;
                        update ClientContactDetails set ContactNumber = Concat('ContactNumber', ClientContactdetailId) where ContactNumber is not NULL;
                        update ContractRequest set ClientName = Concat('ClientName', ClientId) where ClientName is not NULL;
                        delete from ScheduledReports
                        update MstUsers set UserName = Concat('UserName', UsersId) where UserName is not NULL and UserName <> 'ContractPod';
                        update MstUsers set FirstName = Concat('FirstName', UsersId) where FirstName is not NULL;
                        update MstUsers set LastName = Concat('LastName', UsersId) where LastName is not NULL;
                        update MstUsers set FullName = Concat('FullName', UsersId) where FullName is not NULL;
                        update aspNet_Membership set Email = Concat('Email', UserId,'@test.com') where Email is not NULL;
                        update aspNet_Membership set LoweredEmail = Concat('Email', UserId,'@test.com') where LoweredEmail is not NULL;
                        update aspnet_Users set UserName = Concat('Email', UserId,'@test.com') where UserName is not NULL and UserName <> 'ContractPod';
                        update aspnet_Users set LoweredUserName = Concat('Email', UserId,'@test.com')
                        where LoweredUserName is not NULL and UserName <> 'ContractPod';
                        "


        $SQLDumpQueryOutput = Invoke-Sqlcmd -query $SQLDumpQuery -ServerInstance $ServerInstance -Username $SQLUsername -Password $SQLPassword
        $SQLDumpQueryOutput

        $EncryptionOffQueryOutput = Invoke-Sqlcmd -query $EncryptionOffQuery -ServerInstance $ServerInstance -Username $SQLUsername -Password $SQLPassword
        $EncryptionOffQueryOutput

        do {
            $CheckEncryptionStatusOutput = Invoke-Sqlcmd -query $CheckEncryptionStatus -ServerInstance $ServerInstance -Username $SQLUsername -Password $SQLPassword
            Write-Host "==> INFO : Checking Encryption Status, Current Status: $($CheckEncryptionStatusOutput.encryption_state_desc)"
            if ($($CheckEncryptionStatusOutput.encryption_state_desc) -eq 'UNENCRYPTED') {
                break
            }
            else {
                Start-Sleep -s 60
            }
        }
        while ($true)

        if ($($CheckEncryptionStatusOutput.encryption_state_desc) -eq 'UNENCRYPTED') {
            $DropEncryptionKeyQuery = "USE $backupDBName DROP DATABASE ENCRYPTION KEY"
            $DropEncryptionKeyQueryOutput = Invoke-Sqlcmd -query $DropEncryptionKeyQuery -ServerInstance $ServerInstance -Username $SQLUsername -Password $SQLPassword
            $DropEncryptionKeyQueryOutput  
        }

        $MaskingQueryOutput = Invoke-Sqlcmd -query $MaskingQuery -ServerInstance $ServerInstance -Username $SQLUsername -Password $SQLPassword
        $MaskingQueryOutput

        $global:QueiesExecuted = $true
        Write-Host '==> INFO : Queries executed!'

    }
    catch {
        Write-Error "==> ERROR: Failed to execute query on DB"
    }
}

# updates CICM's status and add comment
function updateCICMTicket {
    # authenticate ayRktmRPwSMjdiINSzLjAECA
    Write-Host "==> INFO: Checking existing session" -ForegroundColor Green
    # Get-JiraSession

    Write-Host "==> INFO: CICM Ticket found" -ForegroundColor Green
    # Get-JiraIssue -Key CICM-$global:CICMTicketNo

    Write-Host "==> INFO: Commenting on CICM Ticket" -ForegroundColor Green
    Add-JiraIssueComment -Comment "Restored to $global:RestoreDBServer. Please check CICM$global:CICMTicketNo in LastPass for more details." -Issue CICM-$global:CICMTicketNo -Confirm

    # Invoke-JiraIssueTransition -Issue "CICM-$global:CICMTicketNo" -Transition 22 -Comment "Transition done thru powershell"
}

# Clear CICM
function clearCICM {
    Write-Host "Comming Soon.."
}

:menuLoop while ($true) {
    Write-Host "`n============= Cloud CICM Menu =============`n" -ForegroundColor Yellow
    Write-Host "Press '1' to " -ForegroundColor Yellow -NoNewline; Write-Host "Create Backup for CICM-$global:CICMTicketNo" -ForegroundColor Blue
    Write-Host "Press '2' to " -ForegroundColor Yellow -NoNewline; Write-Host "Restore Backup for CICM-$global:CICMTicketNo" -ForegroundColor Blue
    Write-Host "Press '3' to " -ForegroundColor Yellow -NoNewline; Write-Host "Create SQL User " -ForegroundColor Blue
    Write-Host "Press '4' to " -ForegroundColor Yellow -NoNewline; Write-Host "Update CICM-$global:CICMTicketNo Ticket" -ForegroundColor Blue
    Write-Host "Press '5' to " -ForegroundColor Yellow -NoNewline; Write-Host "Delete Backup for CICM-$global:CICMTicketNo" -ForegroundColor Blue
    Write-Host "Press 'Q' to " -ForegroundColor Yellow -NoNewline; Write-Host "Quit" -ForegroundColor Red

    switch (Read-Host "`nPlease make a selection") {
        '1' { (getTenant), (createBackup) }
        '2' { (restoreDB) }
        '3' { (createSQLUser) }
        '4' { (updateCICMTicket) }
        '5' { (clearCICM) }
        'Q' { break menuLoop }
        Default {
            "No matches found, Please make right selection "
        }
    }
}