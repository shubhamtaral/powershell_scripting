$checkoutPath = "$PWD" ##'$(System.DefaultWorkingDirectory)'
$repoUri = "git@bitbucket.org:contractpod/contractpod-cpai-ascential.git" ##'$(repoUri)'
$repoFolder = "contractpod-cpai-ascential" ##'$(repoFolder)'
$branchMatch = "develop_shield_cloud" ##'$(targetBranch)'
$defaultBranch = "develop_cloud" ##'$(sourceBranch)'
$pushChanges = $false ##'$(pushChanges)'
$success = ":check2:"
$failed = ":x-cross:"
$mergeText = "*Merge Successful*"
$conflictsText = "*Found Conflicts*"
$slackApiKey = '12345'
$slackChannel = '#testchannel'

Push-Location
if (!(Test-Path -Path $checkoutPath\$repoFolder)) {
    New-Item -ItemType directory -Path $checkoutPath\$repoFolder
    Write-Host("Folder created")
}
Set-Location $checkoutPath
try {
    if ((Test-Path -Path "$checkoutPath\$repoFolder")) {
        Write-Host("Cloning $repoUri into $checkoutPath\$repoFolder")
        $result = git clone -c $repoUri $repoFolder 2>&1  
        write-host $result
        Write-Host("Cloned")
    }
}
catch {
    Write-Error $_ 
}
Set-Location $repoFolder
$resultList = @{}
$branches = git for-each-ref --format='%(refname:short)' refs/remotes/origin
foreach ($branch in $branches) {
    $branchName = $branch.Substring(7, $branch.Length - 7)
    if ($branchName -like $branchMatch -And !($branchName -eq $defaultBranch)) {
        $branchName
        try {
            git checkout $branchName 2>&1 | write-host
            Write-Host("Checked out $branchName") -ForegroundColor Green
        }
        catch {
            Write-Error $_ 
        }

        # pull any current branch changes
        try {
            git pull origin $branchName 2>&1 | write-host 
        }
        catch {
            Write-Error $_ 
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
                git clean -fdx 2>&1 | write-host
                git reset --hard 2>&1 | write-host
            }
        }
        catch {
            Write-Error $_ 
        }
        # switch off so we can delete the copy we have
        try {
            git checkout $defaultBranch 2>&1 | write-host 
            git branch -D $branchName 2>&1 | write-host 
        }
        catch {
            Write-Error $_ 
        }

        # reset working directory
        try {
            git reset --hard | write-host 
        }
        catch {
            Write-Error $_ 
        }  
    }
}
Write-Host("Finishing process")
Pop-Location
