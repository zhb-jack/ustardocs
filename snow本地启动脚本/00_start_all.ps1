param(
  [switch]$ForceRebuild
)

. (Join-Path $PSScriptRoot '_common.ps1')

Write-Step 'Start all local services'
& (Join-Path $PSScriptRoot '01_start_infra.ps1')
& (Join-Path $PSScriptRoot '02_build_go_services.ps1') @PSBoundParameters
& (Join-Path $PSScriptRoot '03_init_kong_and_nats.ps1')
& (Join-Path $PSScriptRoot '04_start_go_services.ps1')
& (Join-Path $PSScriptRoot '05_start_frontends.ps1')
& (Join-Path $PSScriptRoot '06_health_check.ps1')

Write-Step 'Local startup finished'
Write-Info 'Admin frontend: http://localhost:3000'
Write-Info 'Website: http://localhost:3001'
Write-Info 'Kong Proxy: http://localhost:8000'
Write-Info 'Kong Admin API: http://localhost:8001'
Write-Info 'Kong Manager UI: http://localhost:8002'
