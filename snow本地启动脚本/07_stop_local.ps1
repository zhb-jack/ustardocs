param(
  [switch]$IncludeDocker
)

. (Join-Path $PSScriptRoot '_common.ps1')

Write-Step 'Stop frontend controllers'
@('admin-platform', 'website') | ForEach-Object {
  Stop-DetachedCommand -Name $_
}

Write-Step 'Stop Go service controllers'
@('auth-service', 'tenant-api', 'admin-service', 'tenant-admin-service', 'webhook-service') | ForEach-Object {
  Stop-DetachedCommand -Name $_
}

if ($IncludeDocker) {
  Write-Step 'Stop Docker infrastructure'
  $composeFile = Get-PatchedComposePath
  if (-not (Test-Path $composeFile)) {
    $composeFile = New-PatchedComposeFile
  }

  & docker compose -f $composeFile down
  if ($LASTEXITCODE -ne 0) {
    throw 'Docker infrastructure stop failed'
  }
}
