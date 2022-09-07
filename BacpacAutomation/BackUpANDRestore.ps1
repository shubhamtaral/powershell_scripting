# Import MOdules

# Install-Module -Name SqlServer
# Install-Module -Name Az 
# Import-Module -Name sqlps

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

#To store the generate URL 
$global:URL = $null

# Function to Create the Backup
function BackupDB{
    param (
        [Parameter(Mandatory = $true)][string] $ServerInstance,
        [Parameter(Mandatory = $true)][String] $SqlCredential_Username,
        [Parameter(Mandatory = $true)][String] $SqlCredential_Passwd,
        [Parameter(Mandatory = $true)][string] $databaseName

    )

    Write-Host "==> INFO : Connecting to $ServerInstance for $databaseName"

    Write-Host '==> INFO : Starting Database BackUp to AzStorage!'

    $SqlCredential = $SqlCredential_Username
    $SqlCredential_pw = ConvertTo-SecureString $SqlCredential_passwd -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($SqlCredential, $SqlCredential_Pw)
    $baseURL = 'https://backendstorageqa.blob.core.windows.net/backups/'
    $date = $(get-date -f yyyyMMddhhmmss)
    $ext = '.bak'
    $URL = $baseURL + $databaseName + '_' + $date + $ext
    $global:URL = $URL
    try {
        # Backing up Database
        Write-Host '==> INFO : BackingUp DataBase: ' $databaseName 'as' $URL
        Backup-SqlDatabase -ServerInstance "$ServerInstance" -Database "$databaseName" -BackupFile $URL -Credential (Get-Credential $credential) -CopyOnly -CompressionOption on
        Write-Host '==> INFO : DataBase backup Complete!'
    }
    catch {
        Write-Host '==> INFO : Failed to Backup database!'
        Write-Error $_
    }
}

function RestoreDB{
    param (
        [Parameter(Mandatory = $true)][string] $ServerInstance,
        [Parameter(Mandatory = $true)][String] $SqlCredential_Username,
        [Parameter(Mandatory = $true)][String] $SqlCredential_Passwd,
        [Parameter(Mandatory = $true)][string] $databaseName
    )

    Write-Host "==> INFO : Connecting to $ServerInstance to restore $databaseName" 

    Write-Host '==> INFO : Starting Database Restore from AzStorage!'
        
    $SqlCredential = $SqlCredential_Username
    $SqlCredential_pw = ConvertTo-SecureString $SqlCredential_Passwd -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($SqlCredential,$SqlCredential_pw)

    try {
        # Restoring Database
        Write-Host '==> INFO : Restoring DataBase as: ' $databaseName 'from' $global:URL
        Restore-SqlDatabase -ServerInstance "$ServerInstance" -Database "$databaseName" -BackupFile "$global:URL" -Credential (Get-Credential $credential) -Verbose
        Write-Host '==> INFO : DataBase Restore Complete!'
    }
    catch{
        Write-Host '==> INFO : Failed to Restore database!'
        Write-Error $_
    }

    # try {
    #     # Restore Database
    #     $SQLRestoreQuery = "RESTORE DATABASE $databaseName   
    #     FROM URL = '$global:URL'"
    #     $SQLRestoreQuery
    #     $SQLRestoreQueryOutput = Invoke-Sqlcmd -query $SQLRestoreQuery -ServerInstance $ServerInstance -Username $SqlCredential_Username -Password $SqlCredential_Passwd
    #     Write-Output $SQLRestoreQueryOutput

    # }
    # catch {
    #     Write-Host '==> INFO : Failed to Restore Database!'
    # }
}

###############################################

Write-Host "Starting Program"
$SourceServer = 'cpai-dev-sql-01.39932b3bf5f3.database.windows.net'
$S_SQLUsername = "ContractPodAi"
$S_SQLPassword = "45S9fSHMm0*vsef"
$S_Database = "DEV2_CL_Test"

$TargetServer = "cpai-dev-sql-02.12aeca4e0f43.database.windows.net"
$T_SQLUsername = "ContractPodAi"
$T_SQLPassword = "fSl9F*0iKzwDqRC%"
$T_Database = "DEV2_CL_Test"

BackupDB $TargetServer $T_SQLUsername $T_SQLPassword $T_Database
$global:URL
RestoreDB $SourceServer $S_SQLUsername $S_SQLPassword $S_Database