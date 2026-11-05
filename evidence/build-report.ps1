$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$data = Get-Content (Join-Path $dir 'run-results.json') -Raw | ConvertFrom-Json

$titles = @{
    1 = 'Public endpoint'
    2 = 'Register a new user'
    3 = 'Login and obtain an access token'
    4 = 'Protected profile without a token'
    5 = 'Protected profile with a Bearer token'
    6 = 'Login with an incorrect password'
    7 = 'Logout and revoke the token'
    8 = 'Profile request with the revoked token'
}
$expected = @{ 1 = 200; 2 = 201; 3 = 200; 4 = 401; 5 = 200; 6 = 422; 7 = 200; 8 = 401 }

function ConvertTo-HtmlText {
    param([string]$Text)
    return [System.Net.WebUtility]::HtmlEncode($Text)
}

function Format-Json {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    try { return ($Text | ConvertFrom-Json | ConvertTo-Json -Depth 10) } catch { return $Text }
}

$cards = foreach ($item in $data) {
    $statusClass = if ($item.status -eq $expected[[int]$item.test]) { 'ok' } else { 'bad' }
    $auth = if ($item.test -in 5, 7, 8) { '<div class="line"><span class="key">Authorization:</span> Bearer &lt;REDACTED_ACCESS_TOKEN&gt;</div>' } else { '<div class="line"><span class="key">Authorization:</span> No Auth</div>' }
    $body = ConvertTo-HtmlText (Format-Json $item.body)
    $acceptLine = if ($item.method -eq 'POST') { '<div class="line"><span class="key">Accept:</span> application/json &nbsp; <span class="key">Content-Type:</span> application/json</div>' } else { '<div class="line"><span class="key">Accept:</span> application/json</div>' }
    @"
  <section class="card" id="test-$($item.test)">
    <header>
      <span class="num">Test $($item.test)</span>
      <h2>$($titles[[int]$item.test])</h2>
    </header>
    <div class="request">
      <div class="line"><span class="method m-$($item.method.ToLower())">$($item.method)</span> <span class="url">$($item.url)</span></div>
      $acceptLine
      $auth
    </div>
    <div class="response">
      <div class="line"><span class="key">Status:</span> <span class="status $statusClass">$($item.status) $(if ($statusClass -eq 'ok') { 'as expected' } else { 'unexpected' })</span></div>
      <pre>$body</pre>
    </div>
  </section>
"@
}

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Module 5 - Laravel 13 Secure API - live test evidence</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body { margin: 0; padding: 40px; background: #14161a; color: #e6e8eb;
         font-family: "Segoe UI", system-ui, sans-serif; }
  h1 { font-size: 22px; margin: 0 0 6px; }
  .sub { color: #9aa3ad; font-size: 13px; margin-bottom: 28px; }
  .card { width: 960px; background: #1c1f24; border: 1px solid #2b3138;
          border-radius: 10px; padding: 22px 24px; margin-bottom: 28px; }
  .card header { display: flex; align-items: baseline; gap: 14px; margin-bottom: 16px; }
  .card h2 { font-size: 17px; margin: 0; font-weight: 600; }
  .num { font-size: 12px; letter-spacing: .08em; text-transform: uppercase; color: #7d8792; }
  .request, .response { background: #14171c; border: 1px solid #262c33; border-radius: 8px;
                        padding: 14px 16px; margin-bottom: 12px; font-size: 13px; }
  .line { margin: 4px 0; }
  .key { color: #8b96a3; }
  .method { display: inline-block; min-width: 58px; text-align: center; font-weight: 700;
            font-size: 11px; letter-spacing: .06em; padding: 3px 8px; border-radius: 4px; }
  .m-get { background: #123c2a; color: #6ee7a0; }
  .m-post { background: #3a2f0d; color: #f6c445; }
  .url { font-family: Consolas, monospace; color: #cfd6de; }
  .status { font-weight: 700; font-family: Consolas, monospace; }
  .status.ok { color: #6ee7a0; }
  .status.bad { color: #ff7b72; }
  pre { margin: 10px 0 0; font-family: Consolas, monospace; font-size: 12.5px;
        line-height: 1.5; color: #dfe4ea; white-space: pre-wrap; word-break: break-word; }
  footer { color: #7d8792; font-size: 12px; margin-top: 8px; }
</style>
</head>
<body>
<h1>Module 5 - Laravel 13 Secure API - live test evidence</h1>
<div class="sub">Laravel Framework 13.40.0 &middot; Sanctum personal access tokens &middot; MySQL 10.4 (InnoDB) &middot; captured from http://127.0.0.1:8000 &middot; tokens redacted</div>
$($cards -join "`n")
<footer>Responses captured from the running application with curl; the same requests are provided as a Postman collection in /postman.</footer>
</body>
</html>
"@

Set-Content -Path (Join-Path $dir 'report.html') -Value $html -Encoding utf8
Write-Host "Wrote $([System.IO.Path]::Combine($dir,'report.html'))"
