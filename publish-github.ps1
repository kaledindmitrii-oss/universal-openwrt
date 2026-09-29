#requires -Version 5.1

$ErrorActionPreference = "Stop"

# ============================================================
# Universal OpenWrt GitHub Publisher
# Version: 30.2.19
# Windows PowerShell 5.1 / PowerShell 7
# ============================================================

$ProjectPath = "C:\universal-openwrt-v30.2.19"
$Repo        = "kaledindmitrii-oss/universal-openwrt"
$Branch      = "main"
$Version     = "30.2.19"
$Tag         = "v30.2.19"

$AssetDir    = "C:\universal-openwrt-v30.2.19-release-assets"
$ReleaseRoot = Join-Path $AssetDir "Universal-OpenWrt-v30.2.19"

$ZipName = "Universal-OpenWrt-v30.2.19-OpenWrt-24.10.8-AWG-3.1-GITHUB.zip"
$TarName = "Universal-OpenWrt-v30.2.19-OpenWrt-24.10.8-AWG-3.1-GITHUB.tar.gz"

$ZipPath = Join-Path $AssetDir $ZipName
$TarPath = Join-Path $AssetDir $TarName

function Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Good {
    param([string]$Message)
    Write-Host "[ OK ] $Message" -ForegroundColor Green
}

function Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Fail {
    param([string]$Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
}

function Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkCyan
    Write-Host " $Title" -ForegroundColor White
    Write-Host "============================================================" -ForegroundColor DarkCyan
}

function Run-Command {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $false)]
        [string[]]$Arguments = @()
    )

    Info ("RUN: " + $Command + " " + ($Arguments -join " "))

    & $Command @Arguments

    $code = $LASTEXITCODE

    if ($code -ne 0) {
        throw "Command failed with exit code $code : $Command"
    }

    return $code
}

function Command-Exists {
    param([string]$Name)

    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-GitTrackedFiles {
    $output = & git -C $ProjectPath ls-files -z

    if ($LASTEXITCODE -ne 0) {
        throw "Unable to read Git tracked files."
    }

    $text = [System.Text.Encoding]::UTF8.GetString(
        [System.Text.Encoding]::Default.GetBytes(($output -join ""))
    )

    return @(
        $text -split "`0" |
        Where-Object { $_ -and $_.Trim() }
    )
}

function Validate-PowerShellFile {
    param([string]$Path)

    Section "PowerShell syntax validation"

    $tokens = $null
    $errors = $null

    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $Path,
        [ref]$tokens,
        [ref]$errors
    )

    if ($errors.Count -gt 0) {
        foreach ($errorItem in $errors) {
            Write-Host $errorItem.ToString() -ForegroundColor Red
        }

        throw "PowerShell parser found syntax errors."
    }

    Good "PowerShell syntax is valid."
}

try {

    Section "Universal OpenWrt GitHub Publisher"

    Info "Project: $ProjectPath"
    Info "Repository: $Repo"
    Info "Branch: $Branch"
    Info "Version: $Version"
    Info "Tag: $Tag"

    if (-not (Test-Path $ProjectPath -PathType Container)) {
        throw "Project directory does not exist: $ProjectPath"
    }

    Set-Location $ProjectPath

    # --------------------------------------------------------
    # Tools
    # --------------------------------------------------------

    Section "Checking required tools"

    if (-not (Command-Exists "git")) {
        throw "git.exe was not found in PATH."
    }

    Good "Git found."

    if (-not (Command-Exists "gh")) {
        throw "GitHub CLI 'gh' was not found in PATH."
    }

    Good "GitHub CLI found."

    # --------------------------------------------------------
    # Self validation
    # --------------------------------------------------------

    $scriptPath = $MyInvocation.MyCommand.Path

    if ($scriptPath -and (Test-Path $scriptPath)) {
        Validate-PowerShellFile $scriptPath
    }

    # --------------------------------------------------------
    # Git repository
    # --------------------------------------------------------

    Section "Checking Git repository"

    if (-not (Test-Path (Join-Path $ProjectPath ".git"))) {
        throw "This directory is not a Git repository."
    }

    Good "Git repository detected."

    $origin = (& git remote get-url origin 2>$null).Trim()

    if (-not $origin) {
        throw "Git remote 'origin' is not configured."
    }

    Info "Origin: $origin"

    if ($origin -notmatch "github\.com[:/]kaledindmitrii-oss/universal-openwrt(\.git)?$") {
        throw "Origin points to an unexpected repository: $origin"
    }

    Good "Origin repository is correct."

    # --------------------------------------------------------
    # GitHub authentication
    # --------------------------------------------------------

    Section "Checking GitHub authentication"

    & gh auth status

    if ($LASTEXITCODE -ne 0) {
        throw "GitHub CLI is not authenticated. Run: gh auth login"
    }

    Good "GitHub authentication is available."

    # --------------------------------------------------------
    # VERSION
    # --------------------------------------------------------

    Section "Checking project version"

    $versionFile = Join-Path $ProjectPath "VERSION"

    if (-not (Test-Path $versionFile)) {
        throw "VERSION file is missing."
    }

    $localVersion = (Get-Content $versionFile -Raw).Trim()

    Info "VERSION file: $localVersion"

    if ($localVersion -ne $Version) {
        throw "VERSION mismatch. Expected $Version, got $localVersion."
    }

    Good "VERSION is correct."

    # --------------------------------------------------------
    # Cleanup
    # --------------------------------------------------------

    Section "Cleaning generated Python cache"

    Get-ChildItem `
        -Path $ProjectPath `
        -Recurse `
        -Force `
        -Directory `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq "__pycache__" } |
        ForEach-Object {
            Info ("Removing " + $_.FullName)
            Remove-Item $_.FullName -Recurse -Force
        }

    Get-ChildItem `
        -Path $ProjectPath `
        -Recurse `
        -Force `
        -File `
        -Filter "*.pyc" `
        -ErrorAction SilentlyContinue |
        ForEach-Object {
            Info ("Removing " + $_.FullName)
            Remove-Item $_.FullName -Force
        }

    Good "Python cache cleanup complete."

    # --------------------------------------------------------
    # Git status
    # --------------------------------------------------------

    Section "Git status"

    & git status --short

    # --------------------------------------------------------
    # Commit
    # --------------------------------------------------------

    Section "Preparing commit"

    & git add -A

    $statusAfterAdd = & git status --porcelain

    if ($statusAfterAdd) {

        Info "Changes detected."

        & git commit -m "Release v$Version"

        if ($LASTEXITCODE -ne 0) {
            throw "Git commit failed."
        }

        Good "Commit created."
    }
    else {
        Good "Working tree is clean. No new commit required."
    }

    # --------------------------------------------------------
    # Current HEAD
    # --------------------------------------------------------

    $head = (& git rev-parse HEAD).Trim()

    if (-not $head) {
        throw "Unable to determine current Git HEAD."
    }

    Info "Current HEAD: $head"

    # --------------------------------------------------------
    # Push
    # --------------------------------------------------------

    Section "Pushing main branch"

    & git push origin $Branch

    if ($LASTEXITCODE -ne 0) {
        throw "Git push failed."
    }

    Good "Branch pushed successfully."

    # --------------------------------------------------------
    # Tag
    # --------------------------------------------------------

    Section "Checking release tag"

    $remoteTag = (& git ls-remote --tags origin "refs/tags/$Tag" 2>$null)

    if ($remoteTag) {

        $remoteSha = ($remoteTag -split "`t")[0]

        Info "Remote tag $Tag exists."
        Info "Remote tag SHA: $remoteSha"

        if ($remoteSha -ne $head) {
            throw "Remote tag $Tag points to another commit. Aborting to prevent overwrite."
        }

        Good "Existing tag points to current HEAD."

    }
    else {

        Info "Creating annotated tag $Tag"

        & git tag -a $Tag -m "Universal OpenWrt v$Version"

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create Git tag."
        }

        & git push origin $Tag

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to push Git tag."
        }

        Good "Tag $Tag created and pushed."
    }

    # --------------------------------------------------------
    # Release assets
    # --------------------------------------------------------

    Section "Building release assets"

    if (Test-Path $AssetDir) {
        Remove-Item $AssetDir -Recurse -Force
    }

    New-Item `
        -ItemType Directory `
        -Path $AssetDir `
        -Force |
        Out-Null

    $Stage = Join-Path $AssetDir "stage"

    New-Item `
        -ItemType Directory `
        -Path $Stage `
        -Force |
        Out-Null

    $tracked = @(
        & git ls-files
    )

    if ($LASTEXITCODE -ne 0) {
        throw "Unable to enumerate tracked files."
    }

    if ($tracked.Count -eq 0) {
        throw "Git repository contains no tracked files."
    }

    Info ("Tracked files: " + $tracked.Count)

    foreach ($relative in $tracked) {

        if ([string]::IsNullOrWhiteSpace($relative)) {
            continue
        }

        $source = Join-Path $ProjectPath $relative
        $target = Join-Path $Stage $relative

        if (Test-Path $source -PathType Leaf) {

            $parent = Split-Path $target -Parent

            if (-not (Test-Path $parent)) {
                New-Item `
                    -ItemType Directory `
                    -Path $parent `
                    -Force |
                    Out-Null
            }

            Copy-Item `
                $source `
                $target `
                -Force
        }
    }

    New-Item `
        -ItemType Directory `
        -Path $ReleaseRoot `
        -Force |
        Out-Null

    Copy-Item `
        "$Stage\*" `
        $ReleaseRoot `
        -Recurse `
        -Force

    Info "Creating ZIP..."

    Compress-Archive `
        -Path "$ReleaseRoot\*" `
        -DestinationPath $ZipPath `
        -CompressionLevel Optimal `
        -Force

    if (-not (Test-Path $ZipPath -PathType Leaf)) {
        throw "ZIP archive was not created."
    }

    Good "ZIP created: $ZipPath"

    # --------------------------------------------------------
    # TAR.GZ
    # --------------------------------------------------------

    if (Command-Exists "tar") {

        Info "Creating TAR.GZ..."

        Push-Location $AssetDir

        try {

            & tar `
                -czf `
                $TarPath `
                "Universal-OpenWrt-v30.2.19"

            if ($LASTEXITCODE -ne 0) {
                throw "tar.exe failed."
            }
        }
        finally {
            Pop-Location
        }

        Good "TAR.GZ created: $TarPath"
    }
    else {
        Warn "tar.exe not found. TAR.GZ will not be created."
    }

    # --------------------------------------------------------
    # SHA256
    # --------------------------------------------------------

    Section "Calculating SHA256"

    $zipHash = (Get-FileHash $ZipPath -Algorithm SHA256).Hash.ToLower()

    Info "ZIP SHA256:"
    Write-Host $zipHash -ForegroundColor White

    if (Test-Path $TarPath -PathType Leaf) {

        $tarHash = (Get-FileHash $TarPath -Algorithm SHA256).Hash.ToLower()

        Info "TAR.GZ SHA256:"
        Write-Host $tarHash -ForegroundColor White
    }

    # --------------------------------------------------------
    # Release
    # --------------------------------------------------------

    Section "Checking GitHub release"

    $releaseExists = $false

    & gh release view $Tag --repo $Repo *> $null

    if ($LASTEXITCODE -eq 0) {
        $releaseExists = $true
    }

    if (-not $releaseExists) {

        Info "Creating GitHub release $Tag"

        $releaseArgs = @(
            "release",
            "create",
            $Tag,
            "--repo",
            $Repo,
            "--title",
            "Universal OpenWrt v$Version",
            "--notes",
            "Universal OpenWrt v$Version - OpenWrt 24.10.8 / AmneziaWG 3.1",
            "--latest"
        )

        if (Test-Path $ZipPath) {
            $releaseArgs += $ZipPath
        }

        if (Test-Path $TarPath) {
            $releaseArgs += $TarPath
        }

        & gh @releaseArgs

        if ($LASTEXITCODE -ne 0) {
            throw "GitHub release creation failed."
        }

        Good "GitHub release created."
    }
    else {

        Info "GitHub release already exists."

        Info "Uploading/updating release assets..."

        & gh release upload `
            $Tag `
            $ZipPath `
            --repo $Repo `
            --clobber

        if ($LASTEXITCODE -ne 0) {
            throw "ZIP upload failed."
        }

        if (Test-Path $TarPath -PathType Leaf) {

            & gh release upload `
                $Tag `
                $TarPath `
                --repo $Repo `
                --clobber

            if ($LASTEXITCODE -ne 0) {
                throw "TAR.GZ upload failed."
            }
        }

        Good "Release assets uploaded."
    }

    # --------------------------------------------------------
    # Final verification
    # --------------------------------------------------------

    Section "Final GitHub verification"

    & gh release view $Tag `
        --repo $Repo

    if ($LASTEXITCODE -ne 0) {
        throw "Unable to verify GitHub release."
    }

    Section "PUBLISH COMPLETE"

    Good "Repository: https://github.com/$Repo"
    Good "Tag: $Tag"
    Good "Version: $Version"
    Good "ZIP SHA256: $zipHash"

    if (Test-Path $TarPath -PathType Leaf) {
        Good "TAR.GZ SHA256: $tarHash"
    }

    Write-Host ""
    Write-Host "Release successfully published." -ForegroundColor Green
}
catch {

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host " PUBLISH FAILED" -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""

    if (Test-Path $ProjectPath) {
        Write-Host "Git status:" -ForegroundColor Yellow
        try {
            & git -C $ProjectPath status --short
        }
        catch {
            Write-Host "Unable to read Git status." -ForegroundColor Red
        }
    }
}
finally {

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkCyan
    Write-Host " Script finished. Window will remain open." -ForegroundColor White
    Write-Host "============================================================" -ForegroundColor DarkCyan
    Read-Host "Press ENTER to exit"
}