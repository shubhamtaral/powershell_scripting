$headers = @{
    'Username'= 'IT90'
    'Password'= '#########'
    }

$response = Invoke-RestMethod 'https://contractpod.greythr.com/uas/v1/oauth2/client-token' -Method 'POST' -Headers $headers
$response | ConvertTo-Json