Add-Type -AssemblyName System.Windows.Forms 
$global:balloon = New-Object System.Windows.Forms.NotifyIcon
$path = (Get-Process -id $pid).Path
$balloon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path) 
$balloon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::None
$balloon.BalloonTipTitle = "$Env:USERNAME" 
$balloon.BalloonTipText = 'Its Time! Lets take a stretch break!'
$balloon.Visible = $true 
$balloon.ShowBalloonTip(1000)