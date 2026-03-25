. (Join-Path $PSScriptRoot '_common.ps1')

Write-Step 'Generate local patched compose file'
$composeFile = New-PatchedComposeFile
Write-Info "patched compose: $composeFile"

Write-Step 'Start Docker infrastructure'
& docker compose -f $composeFile up -d
if ($LASTEXITCODE -ne 0) {
  throw 'Docker infrastructure startup failed'
}

Write-Step 'Infrastructure status'
docker ps --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}" | Select-String 'go-services|kong-' -Context 0,0
