$checkoutPath = "D:" #'$(System.DefaultWorkingDirectory)'
$repoUri = 'Shubham_Taral@bitbucket.org:Shubham_Taral/azurefunctiondemo.git' #'$(repoUri)'
$repoFolder = 'azurefunctiondemo' #'$(repoFolder)'
$branchMatch = 'sit' #'$(targetBranch)'
$defaultBranch = 'master' #'$(sourceBranch)'
$pushChanges = $false #'$(pushChanges)'
$success = ":check2:"
$failed = ":x-cross:"
$mergeText = "*Merge Successful*"
$conflictsText = "*Found Conflicts*"
$slackApiKey = '12345'
$slackChannel = '#testchannel'

try {
    # Push-Location

    # if (!(Test-Path -Path $checkoutPath\$repoFolder)) {
    #     New-Item -ItemType directory -Path $checkoutPath\$repoFolder
    #     Write-Host("Folder created")
    # }else{
    #     Write-Host ("Folder exist!")
    # }
    
    # Set-Location -Path $checkoutPath
    # Get-ChildItem
    # try {
    #     if (Test-Path -Path "$checkoutPath\$repoFolder") {
    #         Write-Host("Cloning $repoUri into $checkoutPath\$repoFolder")
    #         $result = git clone -c $repoUri $checkoutPath 2>&1  
    #         write-host $result
    #         Write-Host("Cloned")
    #     }else{
    #         Write-Warning ("Folder does not exits!")
    #     }
    # }
    # catch {
    #     Write-Warning $_ 
    # }

    # Set-Location $checkoutPath\$repoFolder
    # Write-Host ("Inside $repoFolder")
    # Get-ChildItem
    $resultList = @{}
    $branches = git for-each-ref --format='%(refname:short)' refs/remotes/origin
    $branches
    foreach ($branch in $branches) {
        $branchName = $branch.Substring(7, $branch.Length - 7)
        if ($branchName -like $branchMatch -And !($branchName -eq $defaultBranch)) {
    
            try {
                git checkout $branchName 2>&1 | write-host
                Write-Host("Checked out $branchName") -ForegroundColor Green
            }
            catch {
                Write-Warning $_ 
            }
    
            # pull any current branch changes
            try {
                git pull origin $branchName 2>&1 | write-host 
                git log -n 2 2>&1 | write-host
            }
            catch {
                Write-Warning $_ 
            }
    
            # merge in remote
            try {
                git pull origin $defaultBranch 2>&1 | write-host 
                $workingDirectory = git status --porcelain
                if ($workingDirectory -eq $null) {
                    # tree is clean
                    if ($pushChanges) {
                        git push 2>&1 | write-host
                    }
                    $resultList.add($branchName, $success)
                    Write-Host("$branchName successfully updated with changes from $DefaultBranch") -ForegroundColor Green
                }
                else {
                    # not clean
                    $resultList.add($branchName, $failed )
                    Write-Warning("Pull failed. Found conflicts.")
                    git status 2>&1 | write-host
                    git clean -fdx 2>&1 | write-host
                    git reset --hard 2>&1 | write-host
                }
            }
            catch {
                Write-Warning $_ 
            }
            # switch off so we can delete the copy we have
            try {
                git checkout $defaultBranch 2>&1 | write-host 
                git branch -D $branchName 2>&1 | write-host 
            }
            catch {
                Write-Warning $_ 
            }
    
            # reset working directory
            try {
                git reset --hard 2>&1 | write-host 
            }
            catch {
                Write-Warning $_ 
            }  
        }
    }
}
catch {
    Write-Warning $_
}
finally {
    Write-Host("Finishing process")
    Pop-Location
    #Remove-Item -Path $checkoutPath\$repoFolder
}