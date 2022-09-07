$file = "_test_"+(get-date).ToString("yyyyMMdd") + ".log"

$logfile = "D:\powershell_scripting\$file"
Set-Content $logfile -Value ("Execution Time : "+ (get-date).ToShortTimeString()+"`r`n")

Function Write-Log {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$False)]
    [ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG")]
    [String]
    $Level = "INFO",

    [Parameter(Mandatory=$True)]
    [string]
    $Message
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp $Message"
    If($logfile) {
        Add-Content $logfile -Value $Line
        Write-Host $Line
    }
    Else {
        Write-Host $Line
    }
}
$StartTime = (get-date)
Write-Log "ERROR" "Error 404"
Write-Log "DEBUG" $file
Write-Log "INFO" "Info 123"
sleep 5s
$EndTime= (get-date)
Write-Log  "INFO" ('Process Completed Duration: {0:mm} min {0:ss} sec' -f ($EndTime-$StartTime))
