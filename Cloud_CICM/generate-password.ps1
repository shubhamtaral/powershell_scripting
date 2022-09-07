
$SuperAdminUsername = 'ContractPod'

$symbols = '!@#$%^&*'.ToCharArray()
$characterList = 'a'..'z' + 'A'..'Z' + '0'..'9' + $symbols

function GeneratePassword {
    param(
        [ValidateRange(12, 256)]
        [int] 
        $length = 14
    )

    do {
        $password = -join (0..$length | % { $characterList | Get-Random })
        [int]$hasLowerChar = $password -cmatch '[a-z]'
        [int]$hasUpperChar = $password -cmatch '[A-Z]'
        [int]$hasDigit = $password -match '[0-9]'
        [int]$hasSymbol = $password.IndexOfAny($symbols) -ne -1

    }
    until (($hasLowerChar + $hasUpperChar + $hasDigit + $hasSymbol) -ge 3)

    $password
}

function HashPassword($Password, $Salt) {
    $saltBytes = [System.Convert]::FromBase64String($Salt)
    $passwordBytes = [system.Text.Encoding]::Unicode.GetBytes($Password)
    $saltAndPasswordBytes = $SaltBytes + $passwordBytes
    $hashAlgorithm = [Security.Cryptography.HashAlgorithm]::Create("SHA1")
    $hashBytes = $hashAlgorithm.ComputeHash($saltAndPasswordBytes)
    $hash = [System.Convert]::ToBase64String($hashBytes)
    return $hash
}

$saltBytes = [System.Byte[]]::CreateInstance([System.Byte], 16)
$rngCsp = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
$rngCsp.GetBytes($saltBytes)
$salt = [System.Convert]::ToBase64String($saltBytes)
$plainTextPassword = GeneratePassword 15
$passwordHash = HashPassword -Password $plainTextPassword -Salt $salt
  
# $updateSql = "update aspnet_Membership set Password = '$passwordHash', PasswordSalt = '$salt' " +
# "where UserId = (select UserId from aspnet_Users where UserName = '$SuperAdminUsername')"

# Write-Host $plainTextPassword
# Write-Host $updateSql
return $plainTextPassword