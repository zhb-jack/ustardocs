Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-SnowRoot {
  return Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

function Get-BackendRoot {
  return Join-Path (Get-SnowRoot) 'ustarpay-backend-go'
}

function Get-OpsRoot {
  return Join-Path (Get-SnowRoot) 'ustarpay-ops'
}

function Get-AdminFrontendRoot {
  return Join-Path (Join-Path (Get-SnowRoot) 'ustarpay-frontend-admin') 'admin-platform'
}

function Get-WebsiteRoot {
  return Join-Path (Get-SnowRoot) 'ustarpay-website'
}

function Get-ToolsStateDir {
  $dir = Join-Path $PSScriptRoot 'state'
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  return $dir
}

function Get-ToolsLogDir {
  $dir = Join-Path $PSScriptRoot 'logs'
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  return $dir
}

function Get-ToolsTempDir {
  $dir = Join-Path $PSScriptRoot 'tmp'
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  return $dir
}

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Info([string]$Message) {
  Write-Host "    $Message" -ForegroundColor Gray
}

function Get-PatchedComposePath {
  return Join-Path (Get-ToolsTempDir) 'docker-compose.local.patched.yml'
}

function New-PatchedComposeFile {
  $source = Join-Path (Get-BackendRoot) 'docker-compose.local.yml'
  $target = Get-PatchedComposePath
  $content = Get-Content $source -Raw
  $content = $content -replace "(?m)^\s*-\s+\./config/init\.sql:/docker-entrypoint-initdb\.d/init\.sql\r?\n", ''
  $content = $content -replace "(?m)^\s*-\s+""--max_memory_store=1GB""\r?\n", ''
  $content = $content -replace "(?m)^\s*-\s+""--max_file_store=10GB""\r?\n", ''
  $content = $content -replace 'test: \["CMD", "curl", "-f", "http://localhost:8222"\]', 'test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8222/healthz"]'
  Set-Content -Path $target -Value $content -Encoding UTF8
  return $target
}

function Test-UrlOk {
  param(
    [Parameter(Mandatory = $true)][string]$Url,
    [int]$TimeoutSec = 5
  )

  try {
    $null = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec
    return $true
  } catch {
    return $false
  }
}

function Get-PidFilePath([string]$Name) {
  return Join-Path (Get-ToolsStateDir) ($Name + '.pid')
}

function Save-ControllerPid([string]$Name, [int]$ControllerPid) {
  Set-Content -Path (Get-PidFilePath $Name) -Value $ControllerPid -Encoding ASCII
}

function Get-ControllerPid([string]$Name) {
  $file = Get-PidFilePath $Name
  if (-not (Test-Path $file)) {
    return $null
  }

  $value = (Get-Content $file -Raw).Trim()
  if ([string]::IsNullOrWhiteSpace($value)) {
    return $null
  }

  return [int]$value
}

function Remove-ControllerPid([string]$Name) {
  $file = Get-PidFilePath $Name
  if (Test-Path $file) {
    Remove-Item $file -Force
  }
}

function Start-DetachedCommand {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory,
    [Parameter(Mandatory = $true)][string]$CommandLine,
    [Parameter(Mandatory = $true)][string]$LogFile
  )

  $fullCommand = "cd /d `"$WorkingDirectory`" && $CommandLine >> `"$LogFile`" 2>&1"
  $proc = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $fullCommand -WindowStyle Hidden -PassThru
  Save-ControllerPid -Name $Name -ControllerPid $proc.Id
  Write-Info "$Name started, controller PID=$($proc.Id)"
  return $proc.Id
}

function Stop-DetachedCommand {
  param(
    [Parameter(Mandatory = $true)][string]$Name
  )

  $controllerPid = Get-ControllerPid -Name $Name
  if ($null -eq $controllerPid) {
    Write-Info "$Name has no recorded controller PID, skip"
    return
  }

  cmd /c "taskkill /PID $controllerPid /T /F" | Out-Null
  Remove-ControllerPid -Name $Name
  Write-Info "$Name stopped"
}

function Ensure-KongService {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Url
  )

  $serviceUrl = "http://127.0.0.1:8001/services/$Name"
  try {
    Invoke-RestMethod -Uri $serviceUrl -Method Get -TimeoutSec 5 | Out-Null
    Write-Info "Kong service exists: $Name"
  } catch {
    Invoke-RestMethod -Uri 'http://127.0.0.1:8001/services' -Method Post -Body @{
      name = $Name
      url  = $Url
    } -TimeoutSec 10 | Out-Null
    Write-Info "Kong service created: $Name -> $Url"
  }
}

function Ensure-KongRoute {
  param(
    [Parameter(Mandatory = $true)][string]$ServiceName,
    [Parameter(Mandatory = $true)][string]$RouteName,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $routeUrl = "http://127.0.0.1:8001/routes/$RouteName"
  try {
    Invoke-RestMethod -Uri $routeUrl -Method Get -TimeoutSec 5 | Out-Null
    Invoke-WebRequest -Uri $routeUrl -Method Patch -ContentType 'application/x-www-form-urlencoded' -Body 'strip_path=false' -UseBasicParsing -TimeoutSec 10 | Out-Null
    Write-Info "Kong route exists and strip_path=false: $RouteName"
  } catch {
    Invoke-RestMethod -Uri ("http://127.0.0.1:8001/services/{0}/routes" -f $ServiceName) -Method Post -Body @{
      name       = $RouteName
      paths      = $Path
      strip_path = 'false'
    } -TimeoutSec 10 | Out-Null
    Write-Info "Kong route created: $RouteName -> $Path"
  }
}
