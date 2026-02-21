<#
.SYNOPSIS
    CaeliCode WSL — One-line bootstrap installer.

.DESCRIPTION
    Downloads and imports a CaeliCode WSL2 distro image from the latest
    GitHub release. Handles WSL enablement, profile selection, checksum
    verification, and import — all in one command.

.EXAMPLE
    # Interactive (pipe-safe):
    irm https://raw.githubusercontent.com/caelicode/wsl/main/install.ps1 | iex

    # Direct with parameters:
    .\install.ps1 -Profile sre
    .\install.ps1 -Profile dev -InstallDir D:\wsl\caelicode -Force
#>

# ── Wrap in scriptblock for irm | iex safety ─────────────────────────
# In `irm | iex` context, `exit` kills the entire PowerShell host.
# A scriptblock isolates the scope so `return` exits cleanly instead.
& {

# ── irm | iex compatible — no param() block ─────────────────────────
# When run directly, these can be set via: .\install.ps1 -Profile sre
# When piped, the interactive menu handles profile selection.

# Parse args manually for direct invocation compatibility
$CaeliProfile  = $null
$InstallDir    = $null
$DistroName    = $null
$SkipWslCheck  = $false
$Force         = $false

# Pick up args if run as a script (not piped)
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        '-Profile'      { $CaeliProfile = $args[++$i] }
        '-InstallDir'   { $InstallDir   = $args[++$i] }
        '-DistroName'   { $DistroName   = $args[++$i] }
        '-SkipWslCheck' { $SkipWslCheck = $true }
        '-Force'        { $Force        = $true }
    }
}

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # Speeds up Invoke-WebRequest

# ── Constants ───────────────────────────────────────────────────────
$RepoOwner = 'caelicode'
$RepoName  = 'wsl'
$ApiBase   = "https://api.github.com/repos/$RepoOwner/$RepoName"
$ValidProfiles = @('base', 'sre', 'dev', 'data')

$ProfileDescriptions = @{
    base = 'Core tools (git, curl, jq, Python, mise)'
    sre  = 'SRE/Platform (kubectl, helm, terraform, k9s, argocd, trivy)'
    dev  = 'Development (Node.js, Go, Rust, podman, uv)'
    data = 'Data Engineering (Python, dbt, PostgreSQL client, uv)'
}

# ── Helper functions ────────────────────────────────────────────────

function Write-Step {
    param([string]$Message)
    Write-Host "`n  $([char]0x2192) " -ForegroundColor Cyan -NoNewline
    Write-Host $Message
}

function Write-Success {
    param([string]$Message)
    Write-Host "  $([char]0x2713) " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Fail {
    param([string]$Message)
    Write-Host "  $([char]0x2717) " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Write-Banner {
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════╗" -ForegroundColor DarkCyan
    Write-Host "  ║         CaeliCode WSL Installer           ║" -ForegroundColor DarkCyan
    Write-Host "  ║     Enterprise WSL2 Distro Builder        ║" -ForegroundColor DarkCyan
    Write-Host "  ╚═══════════════════════════════════════════╝" -ForegroundColor DarkCyan
    Write-Host ""
}

# ── 1. Banner ───────────────────────────────────────────────────────
Write-Banner

# ── 2. Check admin privileges ────────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Fail "This installer must be run as Administrator."
    Write-Host ""
    Write-Host "    Right-click PowerShell and select 'Run as Administrator'," -ForegroundColor Yellow
    Write-Host "    then re-run the install command." -ForegroundColor Yellow
    return
}

# ── 3. Check WSL prerequisites ──────────────────────────────────────
if (-not $SkipWslCheck) {
    Write-Step "Checking WSL prerequisites..."

    # Check if WSL is available
    $wslPath = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if (-not $wslPath) {
        Write-Fail "WSL is not installed."
        Write-Host ""
        Write-Host "    Run this in an elevated PowerShell to install WSL:" -ForegroundColor Yellow
        Write-Host "      wsl --install --no-distribution" -ForegroundColor White
        Write-Host ""
        Write-Host "    Then restart your computer and re-run this installer." -ForegroundColor Yellow
        return
    }

    # Check WSL version (need WSL2)
    try {
        $wslStatus = wsl.exe --status 2>&1 | Out-String
        if ($wslStatus -match 'Default Version:\s*1') {
            Write-Fail "WSL default version is 1. CaeliCode requires WSL2."
            Write-Host ""
            Write-Host "    Run: wsl --set-default-version 2" -ForegroundColor Yellow
            return
        }
    } catch {
        # --status may not exist on older builds; continue anyway
    }

    Write-Success "WSL2 is available"
}

# ── 4. Profile selection ────────────────────────────────────────────
if ($CaeliProfile -and $CaeliProfile -notin $ValidProfiles) {
    Write-Fail "Invalid profile '$CaeliProfile'. Must be one of: $($ValidProfiles -join ', ')"
    return
}

if (-not $CaeliProfile) {
    Write-Step "Select a profile:"
    Write-Host ""

    for ($i = 0; $i -lt $ValidProfiles.Count; $i++) {
        $p = $ValidProfiles[$i]
        $desc = $ProfileDescriptions[$p]
        Write-Host "    [$($i + 1)] " -ForegroundColor Cyan -NoNewline
        Write-Host "$p" -ForegroundColor White -NoNewline
        Write-Host " — $desc" -ForegroundColor DarkGray
    }

    Write-Host ""
    do {
        $choice = Read-Host "    Enter choice (1-4)"
    } while ($choice -notmatch '^[1-4]$')

    $CaeliProfile = $ValidProfiles[[int]$choice - 1]
}

Write-Success "Profile: $CaeliProfile — $($ProfileDescriptions[$CaeliProfile])"

# ── 5. Configure paths ──────────────────────────────────────────────
if (-not $InstallDir) {
    $InstallDir = Join-Path $env:LOCALAPPDATA "CaeliCode\wsl\$CaeliProfile"
}

if (-not $DistroName) {
    $DistroName = "caelicode-$CaeliProfile"
}

Write-Step "Install directory: $InstallDir"
Write-Step "Distro name: $DistroName"

# ── 6. Check for existing distro ────────────────────────────────────
$existingDistros = wsl.exe --list --quiet 2>&1 | Out-String
if ($existingDistros -match [regex]::Escape($DistroName)) {
    if ($Force) {
        Write-Step "Removing existing distro '$DistroName'..."
        wsl.exe --unregister $DistroName 2>&1 | Out-Null
        Write-Success "Removed existing distro"
    } else {
        Write-Fail "Distro '$DistroName' already exists."
        Write-Host ""
        Write-Host "    To reinstall, first unregister the existing distro:" -ForegroundColor Yellow
        Write-Host "      wsl --unregister $DistroName" -ForegroundColor White
        Write-Host "    Then re-run this installer." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "    To update in-place instead:" -ForegroundColor Yellow
        Write-Host "      wsl -d $DistroName -- caelicode-update" -ForegroundColor White
        return
    }
}

# ── 7. Fetch latest release info ────────────────────────────────────
Write-Step "Fetching latest release from GitHub..."

try {
    $releaseInfo = Invoke-RestMethod -Uri "$ApiBase/releases/latest" -Headers @{
        'Accept' = 'application/vnd.github+json'
        'User-Agent' = 'CaeliCode-WSL-Installer'
    }
} catch {
    Write-Fail "Failed to fetch release info: $_"
    return
}

$version = $releaseInfo.tag_name
Write-Success "Latest release: $version"

# Find the tar.gz and sha256 assets
$tarAsset = $releaseInfo.assets | Where-Object { $_.name -eq "caelicode-wsl-$CaeliProfile.tar.gz" }
$shaAsset = $releaseInfo.assets | Where-Object { $_.name -eq "caelicode-wsl-$CaeliProfile.sha256" }

if (-not $tarAsset) {
    Write-Fail "Profile '$CaeliProfile' not found in release $version."
    Write-Host "    Available assets:" -ForegroundColor Yellow
    $releaseInfo.assets | ForEach-Object { Write-Host "      - $($_.name)" -ForegroundColor DarkGray }
    return
}

$tarSizeMB = [math]::Round($tarAsset.size / 1MB, 1)
Write-Step "Downloading caelicode-wsl-$CaeliProfile.tar.gz (${tarSizeMB}MB)..."

# ── 8. Download to temp ─────────────────────────────────────────────
$tempDir = Join-Path $env:TEMP "caelicode-wsl-install"
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$tarPath = Join-Path $tempDir $tarAsset.name
$shaPath = Join-Path $tempDir $shaAsset.name

# Download with progress
$webClient = New-Object System.Net.WebClient
$webClient.Headers.Add('User-Agent', 'CaeliCode-WSL-Installer')

# Simple progress via events
$downloadComplete = $false
$lastPercent = 0
Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -Action {
    $pct = $EventArgs.ProgressPercentage
    if ($pct -ge ($script:lastPercent + 10)) {
        $script:lastPercent = $pct
        Write-Host "`r    Downloading... ${pct}%" -NoNewline
    }
} | Out-Null

try {
    $webClient.DownloadFile($tarAsset.browser_download_url, $tarPath)
    Write-Host ""  # newline after progress
    Write-Success "Download complete"
} catch {
    Write-Host ""
    Write-Fail "Download failed: $_"
    return
} finally {
    $webClient.Dispose()
    Get-EventSubscriber | Unregister-Event -Force 2>$null
}

# Download checksum
try {
    Invoke-WebRequest -Uri $shaAsset.browser_download_url -OutFile $shaPath -Headers @{
        'User-Agent' = 'CaeliCode-WSL-Installer'
    }
} catch {
    Write-Fail "Failed to download checksum file: $_"
    return
}

# ── 9. Verify checksum ──────────────────────────────────────────────
Write-Step "Verifying SHA256 checksum..."

$expectedHash = (Get-Content $shaPath -Raw).Trim().Split(' ')[0].ToUpper()
$actualHash = (Get-FileHash -Path $tarPath -Algorithm SHA256).Hash.ToUpper()

if ($expectedHash -ne $actualHash) {
    Write-Fail "Checksum mismatch!"
    Write-Host "    Expected: $expectedHash" -ForegroundColor Red
    Write-Host "    Got:      $actualHash" -ForegroundColor Red
    Write-Host ""
    Write-Host "    The download may be corrupted. Please try again." -ForegroundColor Yellow
    Remove-Item $tempDir -Recurse -Force
    return
}

Write-Success "Checksum verified: $($actualHash.Substring(0, 16))..."

# ── 10. Create install directory and import ──────────────────────────
Write-Step "Importing WSL distro '$DistroName'..."

if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

$importResult = wsl.exe --import $DistroName $InstallDir $tarPath 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Fail "WSL import failed: $importResult"
    Remove-Item $tempDir -Recurse -Force
    return
}

Write-Success "Distro imported successfully"

# ── 11. Cleanup temp files ───────────────────────────────────────────
Remove-Item $tempDir -Recurse -Force
Write-Success "Cleaned up temp files"

# ── 12. First launch info ───────────────────────────────────────────
Write-Host ""
Write-Host "  ╔═══════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║       Installation Complete!               ║" -ForegroundColor Green
Write-Host "  ╚═══════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Profile:  " -NoNewline; Write-Host $CaeliProfile -ForegroundColor Cyan
Write-Host "  Version:  " -NoNewline; Write-Host $version -ForegroundColor Cyan
Write-Host "  Distro:   " -NoNewline; Write-Host $DistroName -ForegroundColor Cyan
Write-Host "  Location: " -NoNewline; Write-Host $InstallDir -ForegroundColor Cyan
Write-Host ""
Write-Host "  Launch your distro:" -ForegroundColor Yellow
Write-Host "    wsl -d $DistroName" -ForegroundColor White
Write-Host ""
Write-Host "  On first launch, CaeliCode will:" -ForegroundColor DarkGray
Write-Host "    - Detect your Windows username" -ForegroundColor DarkGray
Write-Host "    - Create a matching Linux user with sudo" -ForegroundColor DarkGray
Write-Host "    - Configure DNS from your Windows settings" -ForegroundColor DarkGray
Write-Host "    - Set the default user for future launches" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Set as default distro:" -ForegroundColor Yellow
Write-Host "    wsl --set-default $DistroName" -ForegroundColor White
Write-Host ""
Write-Host "  Run health check (inside WSL):" -ForegroundColor Yellow
Write-Host "    wsl -d $DistroName -- caelicode-health" -ForegroundColor White
Write-Host ""
Write-Host "  Open in VS Code (requires VS Code on Windows):" -ForegroundColor Yellow
Write-Host "    wsl -d $DistroName -- code ." -ForegroundColor White
Write-Host ""

} @args
