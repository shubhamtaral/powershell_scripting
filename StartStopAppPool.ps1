# Script to Start/Stop Application Pool 
function startStopApplicationPool {
    param (
        [Parameter(Mandatory = $true)][string] $action,
        [Parameter(Mandatory = $true)][string] $applicationPoolName
    )

    $appPoolStatus = (Get-WebAppPoolState -Name $applicationPoolName).Value
    $currentAttempt = 0
    $maxAttempts = 3
    $retryInterval = 30

    # Function to start the App Pool
    function startAppPool {
        try {
            if ($appPoolStatus -ne 'Started') {
                Write-Host ('==>INFO: Starting Application Pool: {0}' -f $applicationPoolName)
                Start-WebAppPool -Name $applicationPoolName 
                $appPoolStatus = (Get-WebAppPoolState -Name $applicationPoolName).Value
                Write-Host ('==>Status: {0} is now {1}!' -f $applicationPoolName, $appPoolStatus)
                return $true
            }
            elseif ($appPoolStatus -eq 'Started') {
                Write-Host ('==>Status: {0} is already in {1} State' -f $applicationPoolName, $appPoolStatus)
                return $true
            }
        }
        catch {
            Write-Output $_.Exception.Message
        }
        
    }

    # Function to stop the App Pool
    function stopAppPool {
        try {
            if ($appPoolStatus -ne 'Stopped') {
                Write-Host ('==>INFO: Stopping Application Pool: {0}' -f $applicationPoolName)
                Stop-WebAppPool -Name $applicationPoolName
                throw 'xyz'
                $appPoolStatus = (Get-WebAppPoolState -Name $applicationPoolName).Value
                Write-Host ('==>Status: {0} is now {1}!' -f $applicationPoolName, $appPoolStatus)
            }
            elseif ($appPoolStatus -eq 'Stopped') {
                Write-Host ('==>Status: {0} is already in {1} State' -f $applicationPoolName, $appPoolStatus)
                throw 'xyz'
            }
        }
        catch {
            Write-Output $_.Exception.Message
        }
    }

    # we can use 'Start' 'Stop' keywards too
    # if (keywards -eq Start){} elseif (keywards -eq Stop)

    # Starts Application Pool when toStart = true
    if ($action -eq "Start") {
        startAppPool
        if ($error){
            while ($currentAttempt -lt $maxAttempts) {
                Write-Host ('==>Current Status: {0} is {1}!' -f $applicationPoolName, $appPoolStatus)
                $currentAttempt++
                Write-Host ('==>INFO: Attempt {0}, Next Attempt after {1} sec...' -f $currentAttempt, $retryInterval)
                Start-Sleep -s $retryInterval
                startAppPools
            }
            Write-Host ('==>INFO: Attempt {0}, Maximum Attempts reached! Exiting now!' -f $currentAttempt)
            break
        }
    }
    # Stops Application Pool when toStop = true
    elseif ($action -eq "Stop") {
        stopAppPool
        if ($error){
            while ($currentAttempt -lt $maxAttempts) {
                Write-Host ('==>Current Status: {0} is {1}!' -f $applicationPoolName, $appPoolStatus)
                $currentAttempt++
                Write-Host ('==>INFO: Attempt {0}, Next Attempt after {1} sec...' -f $currentAttempt, $retryInterval)
                Start-Sleep -s $retryInterval
                stopAppPool
            }
            Write-Host ('==>INFO: Attempt {0}, Maximum Attempts reached! Exiting now!' -f $currentAttempt)
            break
        }
    }
    else {
        Write-Host ('==>INFO: Action is not valid! Please provide "Start" or "Stop" as action...')
    }

}

# Calling Function with params <toStart> <toStop> <AppilicationPoolName>
startStopApplicationPool 'Start' 'DefaultAppPool'
