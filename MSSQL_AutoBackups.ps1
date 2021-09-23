﻿# Import requried modules
import-module sqlps

$SQLInstance = "DESKTOP-JOJOSJI"
$DBName = "QA_CL_QA1"
$SharedFolder = "D:\OFFICE\SQLBackups"
$Date = Get-Date -format yyyyMMdd
$BackupFileName = "$DBName-$date.bak"
$BackupDBName = "$($DBName)_backup)"
$DataFile = "D:\Databases\NewDB.mdf"
$LogFile = "D:\Logs\NewDB_log.ldf"

Write-Host "==> INFO: Taking Backup of $DBName..."
Backup-SqlDatabase  -ServerInstance $SQLInstance `
    -Database $DBName `
    -CopyOnly `
    -CompressionOption off `
    -BackupFile "$($SharedFolder)\$BackupFileName" `
    -BackupAction Database `
    -Verbose

Write-Host "==> INFO: $DBName backup completed to $SharedFolder\$BackupFileName"

Write-Host "==> INFO: Restoring $DBName backup From $SharedFolder\$BackupFileName as $BackupDBName"

Restore-SqlDatabase  -ServerInstance $SQLInstance `
    -Database "$BackupDBName" `
    -BackupFile "$($SharedFolder)\$BackupFileName" `
    -verbose

Write-Host "==> INFO: Restoration of $DBName to $BackupDBName is completed ..."

# https://docs.microsoft.com/en-us/powershell/module/sqlserver/backup-sqldatabase?view=sqlserver-ps#example-11--backup-a-database-to-the-azure-blob-storage-service
# https://docs.microsoft.com/en-us/powershell/module/sqlserver/restore-sqldatabase?view=sqlserver-ps#example-8--restore-a-database-from-the-azure-blob-storage-service