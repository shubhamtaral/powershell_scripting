
    $ServerInstance = "shr-cp-db-qa.04e49d8760a0.database.windows.net"
    $databaseName = 'QA_CL_QA1'
    $SqlCredential = 'ContractPodAi'
    $SqlCredential_pw = 'ContractPod2019!'

    $backupDBName = 'QA_CL_QA1_Backup'
    $baseURL = 'https://backendstorageqa.blob.core.windows.net/backups/'
    $date = $(get-date -f yyyyMMddhhmmss)
    $ext = '.bak'
    $URL = $baseURL + $databaseName + '_' + $date + $ext
    Write-Output $SqlCredential

    Backup-SqlDatabase -ServerInstance "$ServerInstance" -Database "$databaseName" -BackupFile "$URL" -SqlCredential "$SqlCredential" -CopyOnly -CompressionOption on

    Restore-SqlDatabase -ServerInstance "$ServerInstance" -Database "$backupDBName" -BackupFile "$URL" -SqlCredential "$SqlCredential"
