$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

$git = Get-Command git.exe -ErrorAction SilentlyContinue
if ($null -eq $git) {
    Write-Host 'ERROR: Git is not installed or is not in PATH.'
    Write-Host 'Install Git for Windows, then run this script again.'
    exit 10
}

if (-not (Test-Path -LiteralPath '.git')) {
    Write-Host 'ERROR: .git directory was not found.'
    Write-Host 'Run this script from the extracted project directory.'
    exit 11
}

$remote = (& git.exe remote get-url origin 2>$null)
if ([string]::IsNullOrWhiteSpace(($remote -join ''))) {
    & git.exe remote add origin 'https://github.com/kaledindmitrii-oss/universal-openwrt.git'
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

& git.exe branch -M main
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Checking repository status...'
& git.exe status --short

Write-Host 'Staging files...'
& git.exe add --all
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& git.exe diff --cached --quiet
$hasChanges = ($LASTEXITCODE -ne 0)

if ($hasChanges) {
    Write-Host 'Creating commit...'
    & git.exe commit -m 'Release Universal OpenWrt v30.1.0'
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    Write-Host 'No staged changes.'
}

Write-Host 'Pushing to GitHub...'
& git.exe push --set-upstream origin main
if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host 'ERROR: Git push of main failed.'
    exit $LASTEXITCODE
}

Write-Host 'Pushing release tag v30.1.0...'
& git.exe push origin v30.1.0
if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host 'ERROR: Git push of tag v30.1.0 failed.'
    exit $LASTEXITCODE
}
if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host 'ERROR: Git push failed.'
    Write-Host 'Check GitHub authentication and repository permissions.'
    exit $LASTEXITCODE
}

Write-Host ''
Write-Host 'SUCCESS: Universal OpenWrt v30.0.0 was pushed to GitHub.'
exit 0
