    # Import MOdules
    Import-Module SqlServer 

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

    # Function to Create the Backup & Restore
    function BackupAndRestoreDB {

        param (
            [Parameter(Mandatory = $true)][string] $ServerInstance,
            [Parameter(Mandatory = $true)][string] $databaseName,
            [Parameter(Mandatory = $true)][string] $BackupDirectory
        )

        Write-Host '==> INFO : Starting Database BackUp to AzStorage!'
        
        $SqlCredential = 'ContractPodAi'
        $SqlCredential_pw = 'ContractPod2019!'
        $backupDBName = $DatabaseName+'_Backup'
        $baseURL = 'https://backendstorageqa.blob.core.windows.net/backups/'
        $date = $(get-date -f yyyyMMddhhmmss)
        $ext = '.bak'
        $URL = $baseURL + $databaseName + '_' + $date + $ext

        #Restoring Database
        Write-Host '==> INFO : BackingUp DataBase: ' $databaseName
        Backup-SqlDatabase -ServerInstance "$ServerInstance" -Database "$databaseName" -BackupFile "$URL" -Credential "$SqlCredential" -CopyOnly -CompressionOption on
        Write-Host '==> INFO : DataBase backup Complete!'
        Start-Sleep 5

        # Check if DB exist before restoring
        Write-Host '==> INFO : Checking for Database Existance!'
        $DBCheckQuery =  " IF (EXISTS (SELECT name FROM master.dbo.sysdatabases WHERE (name = '"+"$backupDBName"+"'))) BEGIN  Select 1 AS IsDbExist END ELSE BEGIN  Select 0 AS IsDbExist END"   
        $DBCheckQueryOutput = Invoke-Sqlcmd -query $DBCheckQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
        Write-Host '==> INFO : '$backupDBName + 'IsDbExist : ' $DBCheckQueryOutput.IsDbExist

        If ($DBCheckQueryOutput.IsDbExist -eq 1){
            Write-Host '==> INFO : Deleting Database ' $backupDBName
            $DBDropQuery = "DROP DATABASE $backupDBName"
            $DBDROPQueryOutput = Invoke-Sqlcmd -query $DBDropQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
            Write-Host '==> INFO : Deleted=>' $DBDROPQueryOutput.count
        }

        # Restoring Database
        Write-Host '==> INFO : Starting Database Restoration from AzStorage!'
        Write-Host '==> INFO : Restoring DataBase as: ' $backupDBName
        Restore-SqlDatabase -ServerInstance "$ServerInstance" -Database "$backupDBName" -BackupFile "$URL" -Credential "$SqlCredential" -ReplaceDatabase
        Write-Host '==> INFO : DataBase Restore Complete!'
        Start-Sleep 5

        # Truncate unwanted tables //WorkflowProcessTransitionHistory
        $SQLTruncateQuery = "USE $backupDBName
        TRUNCATE TABLE [WorkflowProcessTransitionHistory]"
        $SQLTruncateQueryOutput = Invoke-Sqlcmd -query $SQLTruncateQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
        Write-Host '==> INFO : Table truncated =>' $SQLTruncateQueryOutput.count

        Write-Host '==> INFO : Forwarding futher to BACPAC creation!'
        Start-Sleep 5
        CreateBACPAC $ServerInstance $backupDBName $SqlCredential $SqlCredential_pw $BackupDirectory

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
    
        # Creating BacPac using SqlPackage 
        SqlPackage.exe /a:Export /ssn:$SourceServerName /sdn:$DatabaseName /tf:$TargetFilePath  /su:$DatabaseUserName /sp:$DatabasePasswd
    
        # Checking if BacPac File Created
        $NewestBacPacFile = Get-ChildItem -Path $dirName\$filename*.$ext | Sort-Object LastAccessTime -Descending | Select-Object -First 1
        $file = "$NewestBacPacFile"
    
        Write-Host '==> INFO : BACPAC created : ' $FILE 

        Write-Host '==> INFO : Forwarding futher for ZIP creation!'

        Start-Sleep 5

        ZipTheBACPACK "$FILE" "$BackupDirectory" "$DatabaseName"
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

        # Zipping the file
        Write-Host "==> INFO : Zipping up $FilePath to $zippath"
        #Compress-Archive -Path $items -DestinationPath $zippath
        & "C:\Program Files\7-Zip\7z" a $zippath $FilePath

        Write-Host '==> INFO : Zipping Complete!'
    }

    SetSQLPackagePath
    BackupAndRestoreDB 'shr-cp-db-qa.04e49d8760a0.database.windows.net' 'QA_CL_QA1' 'F:\AutoBacpac\backups'

    Write-Host "==> INFO : Process Completed!"