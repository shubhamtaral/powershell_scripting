# Script to Start/Stop Application Pool 
function startStopApplicationPool {
    param (
        [Parameter(Mandatory = $true)][string] $toStart,
        [Parameter(Mandatory = $true)][string] $toStop,
        [Parameter(Mandatory = $true)][string] $applicationPoolName
    )

    $appPoolStatus = (Get-WebAppPoolState -Name $applicationPoolName).Value
    $maxTries = 0
    $retryInterval = 30

    # Function to start the App Pool
    function startAppPool {
        if($appPoolStatus -ne 'Started'){
            Write-Host ('==>INFO: Starting Application Pool: {0}' -f $applicationPoolName)
            Start-WebAppPool -Name $applicationPoolName 
            $appPoolStatus = (Get-WebAppPoolState -Name $applicationPoolName).Value
            Write-Host ('==>Status: {0} is now {1}!' -f $applicationPoolName, $appPoolStatus)
            return $true
        }elseif ($appPoolStatus -eq 'Started') {
            Write-Host ('==>Status: {0} is already in {1} State' -f $applicationPoolName, $appPoolStatus)
            return $true
        }else {
            return $false
        }
    }

    # Function to stop the App Pool
    function stopAppPool {
        if($appPoolStatus -ne 'Stopped'){
            Write-Host ('==>INFO: Stopping Application Pool: {0}' -f $applicationPoolName)
            Stop-WebAppPool -Name $applicationPoolName
            $appPoolStatus = (Get-WebAppPoolState -Name $applicationPoolName).Value
            Write-Host ('==>Status: {0} is now {1}!' -f $applicationPoolName, $appPoolStatus)
            return $true
        }elseif ($appPoolStatus -eq 'Stopped') {
            Write-Host ('==>Status: {0} is already in {1} State' -f $applicationPoolName, $appPoolStatus)
            return $true
        }else {
            return $false
        }
    }

    # Starts Application Pool when toStart = true
    if($toStart -eq $true){
        while ($maxTries -lt 3) {
            $isStarted = startAppPool
            if ($isStarted -eq $false){
                Write-Host ('==>Current Status: {0} is {1}!' -f $applicationPoolName, $appPoolStatus)
                $maxTries++
                Write-Host ('==>INFO: Attempt {0}, Next Attempt after {1} sec...' -f $maxTries, $retryInterval)
                Start-Sleep -s $retryInterval
                startAppPool
            }else {
                Write-Host ('==>INFO: Everythhing is working Fine!')
                break
            }
        }
    }

    # Stops Application Pool when toStop = true
    if($toStop -eq $true){
        while ($maxTries -lt 3) {
            $isStopped = stopAppPool
            if ($isStopped -eq $false){
                Write-Host ('==>Current Status: {0} is {1}!' -f $applicationPoolName, $appPoolStatus)
                $maxTries++
                Write-Host ('==>INFO: Attempt {0}, Next Attempt after {1} sec...' -f $maxTries, $retryInterval)
                Start-Sleep -s $retryInterval
                stopAppPool
            }else {
                Write-Host ('==>INFO: Everythhing is working Fine!')
                break
            }
        }
    }

}

# Calling Function with params <toStart> <toStop> <AppilicationPoolName>
startStopApplicationPool $false $true 'DefaultAppPool'
