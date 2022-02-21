# Script to Start/Stop Application Pool 

# Importing requried modules
Import-Module WebAdministration

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
            }
            $appPoolStatus = (Get-WebAppPoolState -Name $applicationPoolName).Value
            if ($appPoolStatus -eq 'Starting') {
                Write-Error ('==>Status: {0} is in {1} State' -f $applicationPoolName, $appPoolStatus)
                throw
            }
            if ($appPoolStatus -eq 'Started') {
                Write-Host ('==>Status: {0} is already in {1} State' -f $applicationPoolName, $appPoolStatus)
                break
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
                $appPoolStatus = (Get-WebAppPoolState -Name $applicationPoolName).Value
                Write-Host ('==>Status: {0} is now {1}!' -f $applicationPoolName, $appPoolStatus)
            }
            $appPoolStatus = (Get-WebAppPoolState -Name $applicationPoolName).Value
            if ($appPoolStatus -eq 'Stopping') {
                $appPoolStatus = (Get-WebAppPoolState -Name $applicationPoolName).Value
                Write-Error ('==>Status: {0} is in {1} State' -f $applicationPoolName, $appPoolStatus)
                throw
            }
            if ($appPoolStatus -eq 'Stopped') {
                $appPoolStatus = (Get-WebAppPoolState -Name $applicationPoolName).Value
                Write-Host ('==>Status: {0} is already in {1} State' -f $applicationPoolName, $appPoolStatus)
                break
            }
        }
        catch {
            Write-Output $_.Exception.Message
        }
    }

    # Starts Application Pool when $actiom = 'Start'
    if ($action -eq "Start") {
        startAppPool
        if ($error -and $appPoolStatus -ne 'Started'){
            while ($currentAttempt -lt $maxAttempts) {
                Write-Host ('==>Current Status: {0} is {1}!' -f $applicationPoolName, $appPoolStatus)
                $currentAttempt++
                Write-Host ('==>INFO: Attempt {0}, Next Attempt after {1} sec...' -f $currentAttempt, $retryInterval)
                Start-Sleep -s $retryInterval
                startAppPool
            }
            Write-Host ('==>INFO: Attempt {0}, Maximum Attempts reached! Exiting now!' -f $currentAttempt)
            break
        } else {
            $appPoolStatus = (Get-WebAppPoolState -Name $applicationPoolName).Value
            Write-Host ('==>INFO:==>Current Status: {0} is {1}!  Process Completed! Exiting now!' -f $applicationPoolName, $appPoolStatus)
            break
        }
    }
    # Stops Application Pool when $action = 'Stop'
    elseif ($action -eq "Stop") {
        stopAppPool
        if ($error -and $appPoolStatus -eq 'Stoped'){
            while ($currentAttempt -lt $maxAttempts) {
                Write-Host ('==>Current Status: {0} is {1}!' -f $applicationPoolName, $appPoolStatus)
                $currentAttempt++
                Write-Host ('==>INFO: Attempt {0}, Next Attempt after {1} sec...' -f $currentAttempt, $retryInterval)
                Start-Sleep -s $retryInterval
                stopAppPool
            }
            Write-Host ('==>INFO: Attempt {0}, Maximum Attempts reached! Exiting now!' -f $currentAttempt)
            break
        } else {
            $appPoolStatus = (Get-WebAppPoolState -Name $applicationPoolName).Value
            Write-Host ('==>INFO:==>Current Status: {0} is {1}!  Process Completed! Exiting now!' -f $applicationPoolName, $appPoolStatus)
            break
        }
    }
    else {
        Write-Host ('==>INFO: Action is not valid! Please provide "Start" or "Stop" as action...')
    }

}

# Calling Function with params <toStart> <toStop> <AppilicationPoolName>
startStopApplicationPool 'Stop' '$(appname)'