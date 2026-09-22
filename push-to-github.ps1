$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$git = Get-Command git.exe -ErrorAction SilentlyContinue
if ($null -eq $git) { Write-Host 'ERROR: Git is not installed or not in PATH.'; exit 10 }
if (-not (Test-Path -LiteralPath '.git')) {
    Write-Host 'Initializing Git repository...'
    & git.exe init -b main
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
$version = (Get-Content -Raw -LiteralPath 'VERSION').Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { Write-Host "ERROR: invalid VERSION: $version"; exit 12 }
$tag = "v$version"
$remote = (& git.exe remote get-url origin 2>$null)
if ([string]::IsNullOrWhiteSpace(($remote -join ''))) {
    & git.exe remote add origin 'https://github.com/kaledindmitrii-oss/universal-openwrt.git'
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} elseif (($remote -join '').TrimEnd('/') -ne 'https://github.com/kaledindmitrii-oss/universal-openwrt.git') {
    Write-Host "ERROR: origin points to an unexpected repository: $($remote -join '')"
    exit 13
}
& git.exe branch -M main; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& git.exe add --all; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& git.exe diff --cached --quiet; $hasChanges = ($LASTEXITCODE -ne 0)
if ($hasChanges) { & git.exe commit -m "Release Universal OpenWrt $tag"; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } }
& git.exe rev-parse -q --verify "refs/tags/$tag" *> $null
if ($LASTEXITCODE -ne 0) {
    & git.exe tag -a $tag -m "Universal OpenWrt $tag"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    $tagCommit = (& git.exe rev-list -n 1 $tag 2>$null)
    $headCommit = (& git.exe rev-parse HEAD 2>$null)
    if (($tagCommit -join '') -ne ($headCommit -join '')) {
        Write-Host "ERROR: local tag $tag already exists on a different commit."
        exit 14
    }
}
& git.exe push --set-upstream origin main; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& git.exe push origin $tag; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "SUCCESS: Universal OpenWrt $tag was pushed to GitHub."
exit 0
