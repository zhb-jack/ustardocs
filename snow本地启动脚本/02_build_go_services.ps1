param(
  [switch]$ForceRebuild
)

. (Join-Path $PSScriptRoot '_common.ps1')

$backendRoot = Get-BackendRoot
$buildDir = Join-Path (Get-OpsRoot) 'build'
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

$targets = @(
  @{ Name = 'auth-service.exe'; Package = './cmd/services/auth' },
  @{ Name = 'tenant-api.exe'; Package = './cmd/apis/tenant' },
  @{ Name = 'admin-service.exe'; Package = './cmd/services/admin' },
  @{ Name = 'tenant-admin-service.exe'; Package = './cmd/services/tenant-admin' },
  @{ Name = 'webhook-service.exe'; Package = './cmd/workers/webhook' }
)

foreach ($target in $targets) {
  $output = Join-Path $buildDir $target.Name
  if ((-not $ForceRebuild) -and (Test-Path $output)) {
    Write-Info "$($target.Name) already exists, skip"
    continue
  }

  Write-Step "Build $($target.Name)"
  & docker run --rm --entrypoint /bin/sh `
    -v "${backendRoot}:/src" `
    -v "${buildDir}:/out" `
    -w /src `
    golang:1.24 `
    -lc "export PATH=/usr/local/go/bin:/usr/local/bin:/usr/bin:/bin CGO_ENABLED=0 GOOS=windows GOARCH=amd64 && go build -o /out/$($target.Name) $($target.Package)"

  if ($LASTEXITCODE -ne 0) {
    throw "Build failed: $($target.Name)"
  }
}

Write-Step 'Build artifacts'
Get-ChildItem $buildDir *.exe | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
