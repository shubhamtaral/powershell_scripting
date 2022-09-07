# Delete Older file/s using powershell

Get-ChildItem -Path "C:\Windows\Temp" -Recurse | Where-Object { ($_.LastWriteTime -lt (Get-Date).AddDays(-90)) } | Remove-Item

# We can you the args following way 
# By this meathod we can delete files from multiple paths at 1 go!
# For Eg

foreach ($i in $args)
{
    Write-Host 'INFO: Deleting files from:' $i
    Get-ChildItem -Path $i -Recurse | Where-Object { ($_.LastWriteTime -lt (Get-Date).AddDays(-90)) } | Remove-Item
}

# To execute: ./delete_older.ps1 <path1> <path2> 