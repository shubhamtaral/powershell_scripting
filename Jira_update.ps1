Import-Module JiraPS

# authenticate ayRktmRPwSMjdiINSzLjAECA
$credential = Get-Credential -UserName 'shubham.taral@contractpodai.com' -Message "Add Token here"
Set-JiraConfigServer 'https://newgalexy.atlassian.net'  # required since version 2.10
New-JiraSession -Credential $credential

Get-JiraIssue -Key CICM-32

# Add-JiraIssueComment -Comment "Test2 comment from Powershell" -Issue CICM-32 -Confirm
