$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git не найден. Установите Git for Windows.' }
if (-not (Test-Path '.git')) { git init -b main }
$remote = git remote get-url origin 2>$null
if (-not $remote) { git remote add origin 'https://github.com/kaledindmitrii-oss/universal-openwrt.git' }
git branch -M main
git add .
if (git diff --cached --quiet) { Write-Host 'Изменений для коммита нет.' } else { git commit -m 'Release Universal OpenWrt v30.0.0' }
git push -u origin main
Write-Host ''
Write-Host 'Universal OpenWrt v30.0.0 опубликован в GitHub.'
