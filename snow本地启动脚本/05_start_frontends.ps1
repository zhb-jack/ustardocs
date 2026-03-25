. (Join-Path $PSScriptRoot '_common.ps1')

$logDir = Get-ToolsLogDir
$adminRoot = Get-AdminFrontendRoot
$websiteRoot = Get-WebsiteRoot

Write-Step 'Check admin frontend dependencies'
if (-not (Test-Path (Join-Path $adminRoot 'node_modules'))) {
  Push-Location $adminRoot
  try {
    corepack pnpm install
    corepack pnpm rebuild esbuild
  } finally {
    Pop-Location
  }
}

Write-Step 'Check website dependencies'
if (-not (Test-Path (Join-Path $websiteRoot 'node_modules'))) {
  Push-Location $websiteRoot
  try {
    npm install
  } finally {
    Pop-Location
  }
}

if (-not (Test-UrlOk -Url 'http://127.0.0.1:3000')) {
  Write-Step 'Start admin-platform'
  Start-DetachedCommand `
    -Name 'admin-platform' `
    -WorkingDirectory $adminRoot `
    -CommandLine 'corepack pnpm dev --host 0.0.0.0' `
    -LogFile (Join-Path $logDir 'admin-platform.log') | Out-Null
  Start-Sleep -Seconds 8
} else {
  Write-Info 'admin-platform already running, skip'
}

if (-not (Test-UrlOk -Url 'http://127.0.0.1:3001')) {
  Write-Step 'Start website'
  Start-DetachedCommand `
    -Name 'website' `
    -WorkingDirectory $websiteRoot `
    -CommandLine 'npm run dev -- --host 0.0.0.0 --port 3001' `
    -LogFile (Join-Path $logDir 'website.log') | Out-Null
  Start-Sleep -Seconds 8
} else {
  Write-Info 'website already running, skip'
}

Write-Step 'Frontend URLs'
Write-Info 'Admin frontend: http://localhost:3000'
Write-Info 'Website: http://localhost:3001'
