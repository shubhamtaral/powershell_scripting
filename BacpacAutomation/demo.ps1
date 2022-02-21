function DBBackupandRestore{
param (  
    [string]$buildID, #Use the build id can be string or number   
    [string]$dbname ,#Database name  
    [string]$ServerName,# Database server name  
    [string]$DBBackupPath, #Location where backup file will be saved  
    [string]$ExecutionType #Script execution type for Backup-->backup, for Restore-->restor  
 )  
  
  $buildID= get-date -f yyyyMMdd
     
Write-Output "************BuildId************" $($buildID)  
Write-Output "************DB Name************" $($dbname)  
Write-Output "**********Server Name**********" $($ServerName)  
  
  
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")  
  
    Write-Output "************ Start Check Database exists************"  
    $QueryDB=  " IF (EXISTS (SELECT name FROM master.dbo.sysdatabases WHERE (name = '"+"$dbname"+"'))) BEGIN  Select 1 AS IsDbExist END ELSE BEGIN  Select 0 AS IsDbExist END"   
    $CDDBCheck= Invoke-Sqlcmd -Query $QueryDB -ServerInstance $($ServerName)  -Database $($dbname)   
    Write-Output $CDDBCheck  

    $BackupDBName = "$dbname-backup"
  
  
    if ($CDDBCheck.IsDbExist -eq 1)  
    {  
      
        if( $ExecutionType  -eq "backup"){  
            $FileExists = Test-Path $DBBackupPath\$($buildID)
            if($FileExists -eq $False){  
                Write-Output "************Folder with Build Id Created************"  
                New-Item $DBBackupPath\$($buildID) -type directory  
             }  
             Write-Output "************DB Backup Started************"  
             Backup-SqlDatabase -ServerInstance $($ServerName) -Database $($dbname) -BackupFile "$DBBackupPath\$($buildID)\$($dbname).bak"   
             Write-Output "************DB Backup End************"  
         }else{  
             $SQlSvr1 = New-Object Microsoft.SqlServer.Management.Smo.Server "$($ServerName)"  
             $SQlSvr1.KillAllprocesses($($BackupDBName))  
             $_Data = "_Data"
             $_Log = "_Log"
             
             $RelocateData = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($dbname+$_Data, "C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\DATA\$dbname.mdf")
             $RelocateLog = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($dbname+$_Log, "C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\DATA\$dbname.ldf")
             Write-Output "************DB Restore Started************"  
             Write-Output "Restoring File : $DBBackupPath\$($buildID)\$($dbname).bak"
             Write-Output "Data File : C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\DATA\$BackupDBName.mdf"
             Write-Output "Log File : C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\DATA\$BackupDBName.ldf"
             Restore-SqlDatabase -ServerInstance $($ServerName) -Database $($BackupDBName) -BackupFile "$DBBackupPath\$($buildID)\$($BackupDBName).bak" -RelocateFile @($RelocateData,$RelocateLog) -ReplaceDatabase
             Write-Output "************DB Restore End************"  
         }          
  
    }  
    else  
    {  
        Write-Output "************************************************"  
        Write-Output "************Database Server does not exists*****"  
        Write-Output "************************************************"  
    }  
}
#DBBackupandRestore "Demo#" "CMSCentral" "DESKTOP-JOJOSJI" "D:\OFFICE\SQLBackups" "backup"
DBBackupandRestore "Demo1" "CMSCentral" "DESKTOP-JOJOSJI" "D:\OFFICE\SQLBackups" "restor"


