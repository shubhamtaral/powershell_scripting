function FindInFile {
    param (
        [Parameter(Mandatory = $true)][string] $FilePath
    )

    #$File = Get-Content $FilePath 
    $lines = Get-Content $FilePath 
    $counter = 0;
    $lastremovedline = 0
    foreach ($line in $lines) {

        $counter++
        # $ifPresent = $line.Contains("DynamicTbl") #| select-string "DynamicTbl" -CaseSensitive -SimpleMatch
        $ifPresent = $line | select-string "DynamicTbl" | select-string "Alter" -SimpleMatch
        if ($ifPresent) {
            $RemoveFrom = $counter
        }
        $findGO = $line.Contains("GO") #| select-string "GO" -CaseSensitive -SimpleMatch
        if ($findGO) {
            $RemoveTill = $counter
            if ($RemoveFrom -and $RemoveTill -and ($RemoveTill -gt $RemoveFrom)) {
                
                if ($lastremovedline -ine $RemoveFrom) {
                    Write-Host "$RemoveFrom to $RemoveTill" 
                    try {
                        $content = Get-Content $FilePath
                        $content | 
                        ForEach-Object { 
                            if ($_.ReadCount -ge $RemoveFrom - 1 -and $_.ReadCount -le $RemoveTill - 1) { 
                                $_ -replace '.', ' ' 
                            }
                            else { 
                                $_ 
                            } 
                        } | 
                        Set-Content $FilePath
                    }
                    catch {
                        $_
                    }
                }
                $lastremovedline = $RemoveFrom
            }
        } 
    }
}

$StartTime = (Get-Date)
$funcDef = ${function:FindInFile}.ToString()
1..6 | ForEach-Object -Parallel {
    ${function:FindInFile} = $using:funcDef
    FindInFile "D:\powershell_scripting\QA_CL_QA$_.sql" 
}

$EndTime = (Get-Date)
Write-Host 'INFO' ('==> INFO : Process Completed Duration: {0:mm} min {0:ss} sec' -f ($EndTime - $StartTime))