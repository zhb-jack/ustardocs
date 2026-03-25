. (Join-Path $PSScriptRoot '_common.ps1')

$backendRoot = Get-BackendRoot
$buildDir = Join-Path (Get-OpsRoot) 'build'
$logDir = Get-ToolsLogDir

$services = @(
  @{ Name = 'auth-service'; Exe = (Join-Path $buildDir 'auth-service.exe'); Url = 'http://127.0.0.1:18001/health' },
  @{ Name = 'tenant-api'; Exe = (Join-Path $buildDir 'tenant-api.exe'); Url = 'http://127.0.0.1:18002/health' },
  @{ Name = 'admin-service'; Exe = (Join-Path $buildDir 'admin-service.exe'); Url = 'http://127.0.0.1:18003/health' },
  @{ Name = 'tenant-admin-service'; Exe = (Join-Path $buildDir 'tenant-admin-service.exe'); Url = 'http://127.0.0.1:18004/health' },
  @{ Name = 'webhook-service'; Exe = (Join-Path $buildDir 'webhook-service.exe'); Url = 'http://127.0.0.1:18005/health' }
)

foreach ($service in $services) {
  if (Test-UrlOk -Url $service.Url) {
    Write-Info "$($service.Name) already running, skip"
    continue
  }

  if (-not (Test-Path $service.Exe)) {
    throw "Missing executable: $($service.Exe). Run 02_build_go_services.ps1 first."
  }

  $logFile = Join-Path $logDir ($service.Name + '.log')
  Write-Step "Start $($service.Name)"
  Start-DetachedCommand -Name $service.Name -WorkingDirectory $backendRoot -CommandLine ('"' + $service.Exe + '"') -LogFile $logFile | Out-Null
  Start-Sleep -Seconds 6

  if (-not (Test-UrlOk -Url $service.Url -TimeoutSec 6)) {
    throw "$($service.Name) health check failed. See log: $logFile"
  }
}

Write-Step 'Go services ready'
@('http://127.0.0.1:18001/health','http://127.0.0.1:18002/health','http://127.0.0.1:18003/health','http://127.0.0.1:18004/health','http://127.0.0.1:18005/health') | ForEach-Object {
  Write-Info "$_ => $(if (Test-UrlOk -Url $_) { '200' } else { 'ERROR' })"
}
