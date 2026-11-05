$ErrorActionPreference = 'Stop'
$base = 'http://127.0.0.1:8000'
$dir  = 'C:\xampp\htdocs\demo-api\evidence'
$resp = Join-Path $dir 'responses'
$bod  = Join-Path $dir 'bodies'
New-Item -ItemType Directory -Path $resp -Force | Out-Null
New-Item -ItemType Directory -Path $bod  -Force | Out-Null

$registerBody = Join-Path $bod 'register.json'
$loginBody    = Join-Path $bod 'login.json'
$badLoginBody = Join-Path $bod 'login-invalid.json'

'{"name":"Juan Dela Cruz","email":"juan@example.com","password":"Student@12345","password_confirmation":"Student@12345"}' |
    Set-Content -Path $registerBody -Encoding ascii -NoNewline
'{"email":"juan@example.com","password":"Student@12345"}' |
    Set-Content -Path $loginBody -Encoding ascii -NoNewline
'{"email":"juan@example.com","password":"wrong-password"}' |
    Set-Content -Path $badLoginBody -Encoding ascii -NoNewline

$results = @()

function Save-Result {
    param($Number, $Name, $Method, $Path, $Status, $Body, $Token)
    $shown = $Body
    if ($Token) { $shown = $shown -replace [regex]::Escape($Token), '<REDACTED_ACCESS_TOKEN>' }
    $record = [pscustomobject]@{
        test = $Number; name = $Name; method = $Method
        url = "$base$Path"; status = [int]$Status; body = $shown
    }
    $record | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $resp ("{0}-{1}.json" -f $Number, $Name)) -Encoding utf8
    $script:results += $record
    Write-Host ("TEST {0} {1,-26} {2,-4} -> {3}" -f $Number, $Name, $Method, $Status)
    return $record
}

function Invoke-Api {
    param($Method, $Path, $BodyFile, $Token)
    $curlArgs = @('-s', '-X', $Method, '-H', 'Accept: application/json', '-w', "`n%{http_code}", "$base$Path")
    if ($BodyFile) { $curlArgs = @('-s', '-X', $Method, '-H', 'Accept: application/json', '-H', 'Content-Type: application/json', '--data-binary', "@$BodyFile", '-w', "`n%{http_code}", "$base$Path") }
    if ($Token)     { $curlArgs += @('-H', "Authorization: Bearer $Token") }
    $raw = & curl.exe @curlArgs
    if ($raw -is [array]) { $raw = $raw -join "`n" }
    $idx = $raw.LastIndexOf("`n")
    $status = $raw.Substring($idx + 1).Trim()
    $body = $raw.Substring(0, $idx).Trim()
    return @{ status = [int]$status; body = $body }
}

$r = Invoke-Api 'GET' '/api/hello' $null $null
Save-Result 1 'public-api' 'GET' '/api/hello' $r.status $r.body $null | Out-Null

$r = Invoke-Api 'POST' '/api/register' $registerBody $null
Save-Result 2 'register' 'POST' '/api/register' $r.status $r.body $null | Out-Null

$r = Invoke-Api 'POST' '/api/login' $loginBody $null
$token = ($r.body | ConvertFrom-Json).access_token
if (-not $token) { throw "Login did not return an access_token: $($r.body)" }
Save-Result 3 'login' 'POST' '/api/login' $r.status $r.body $token | Out-Null

$r = Invoke-Api 'GET' '/api/profile' $null $null
Save-Result 4 'profile-no-token' 'GET' '/api/profile' $r.status $r.body $null | Out-Null

$r = Invoke-Api 'GET' '/api/profile' $null $token
Save-Result 5 'profile-with-token' 'GET' '/api/profile' $r.status $r.body $token | Out-Null

$r = Invoke-Api 'POST' '/api/login' $badLoginBody $null
Save-Result 6 'invalid-login' 'POST' '/api/login' $r.status $r.body $null | Out-Null

$r = Invoke-Api 'POST' '/api/logout' $null $token
Save-Result 7 'logout' 'POST' '/api/logout' $r.status $r.body $token | Out-Null

$r = Invoke-Api 'GET' '/api/profile' $null $token
Save-Result 8 'revoked-token' 'GET' '/api/profile' $r.status $r.body $token | Out-Null

$results | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $dir 'run-results.json') -Encoding utf8

$expected = @{ 1 = 200; 2 = 201; 3 = 200; 4 = 401; 5 = 200; 6 = 422; 7 = 200; 8 = 401 }
$allPass = $true
foreach ($item in $results) {
    if ($item.status -ne $expected[[int]$item.test]) {
        $allPass = $false
        Write-Host ("MISMATCH test {0}: got {1}, expected {2}" -f $item.test, $item.status, $expected[[int]$item.test])
    }
}
Write-Host ("ALL EXPECTED STATUSES MATCHED: {0}" -f $allPass)
