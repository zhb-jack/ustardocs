. (Join-Path $PSScriptRoot '_common.ps1')

$checks = @(
  @{ Url = 'http://127.0.0.1:3000'; Method = 'GET'; Body = $null; ContentType = $null },
  @{ Url = 'http://127.0.0.1:3001'; Method = 'GET'; Body = $null; ContentType = $null },
  @{ Url = 'http://127.0.0.1:8000/auth/v1/login'; Method = 'POST'; Body = '{}'; ContentType = 'application/json' },
  @{ Url = 'http://127.0.0.1:18001/health'; Method = 'GET'; Body = $null; ContentType = $null },
  @{ Url = 'http://127.0.0.1:18002/health'; Method = 'GET'; Body = $null; ContentType = $null },
  @{ Url = 'http://127.0.0.1:18003/health'; Method = 'GET'; Body = $null; ContentType = $null },
  @{ Url = 'http://127.0.0.1:18004/health'; Method = 'GET'; Body = $null; ContentType = $null },
  @{ Url = 'http://127.0.0.1:18005/health'; Method = 'GET'; Body = $null; ContentType = $null }
)

Write-Step 'Run health checks'
foreach ($check in $checks) {
  try {
    if ($check.Method -eq 'POST') {
      $response = Invoke-WebRequest -Uri $check.Url -Method Post -Body $check.Body -ContentType $check.ContentType -UseBasicParsing -TimeoutSec 8
    } else {
      $response = Invoke-WebRequest -Uri $check.Url -UseBasicParsing -TimeoutSec 8
    }
    Write-Host "$($check.Url) => $($response.StatusCode)"
  } catch {
    if ($_.Exception.Response) {
      Write-Host "$($check.Url) => $([int]$_.Exception.Response.StatusCode)"
    } else {
      Write-Host "$($check.Url) => ERROR: $($_.Exception.Message)"
    }
  }
}
