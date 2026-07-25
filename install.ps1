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
    .\install.ps1 -Profile sre -Version v0.10.2       # pin a release
    .\install.ps1 -Profile sre -Upgrade               # backup + reinstall
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
$PinVersion    = $null
$SkipWslCheck  = $false
$Force         = $false
$Upgrade       = $false

# Pick up args if run as a script (not piped)
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        '-Profile'      { $CaeliProfile = $args[++$i] }
        '-InstallDir'   { $InstallDir   = $args[++$i] }
        '-DistroName'   { $DistroName   = $args[++$i] }
        '-Version'      { $PinVersion   = $args[++$i] }
        '-SkipWslCheck' { $SkipWslCheck = $true }
        '-Force'        { $Force        = $true }
        '-Upgrade'      { $Upgrade      = $true }
    }
}

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # Speeds up Invoke-WebRequest

# wsl.exe emits UTF-16LE when its output is captured, which turns every
# string comparison on its output into NUL-interleaved garbage. WSL_UTF8
# switches it to UTF-8 (WSL 0.64+); without this, the existing-distro
# and WSL-version checks below can never match.
$env:WSL_UTF8 = '1'

# Windows PowerShell 5.1 may negotiate TLS below 1.2 on older systems;
# GitHub requires TLS 1.2+.
if ($PSVersionTable.PSVersion.Major -le 5) {
    [Net.ServicePointManager]::SecurityProtocol = `
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}

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

# ── 2b. Check CPU architecture ──────────────────────────────────────
# Release images are amd64-only; importing one on ARM64 Windows would
# "succeed" and then fail with an exec format error at first launch.
if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
    Write-Fail "CaeliCode WSL images are x86_64 (amd64) only."
    Write-Host ""
    Write-Host "    This machine is ARM64; the imported distro would not boot." -ForegroundColor Yellow
    Write-Host "    ARM64 images are tracked at: https://github.com/caelicode/wsl/issues" -ForegroundColor Yellow
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
    $attempts = 0
    do {
        if ($attempts -ge 5) {
            Write-Fail "No valid selection after 5 attempts."
            Write-Host "    For scripted installs pass the profile directly:" -ForegroundColor Yellow
            Write-Host "      .\install.ps1 -Profile sre" -ForegroundColor White
            return
        }
        try {
            $choice = Read-Host "    Enter choice (1-4)"
        } catch {
            # Non-interactive host (CI, -NonInteractive): Read-Host throws.
            Write-Fail "Interactive input is unavailable in this session."
            Write-Host "    Pass the profile directly:  .\install.ps1 -Profile sre" -ForegroundColor Yellow
            return
        }
        $attempts++
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
# Exact per-line match (not substring): 'caelicode-base' must not match
# a distro named 'caelicode-base-old'. Requires WSL_UTF8=1 (set above).
$UpgradeBackupPath = $null
$existingList = (wsl.exe --list --quiet 2>&1 | Out-String) -split "`r?`n" |
    ForEach-Object { $_.Trim() } | Where-Object { $_ }
if ($existingList -contains $DistroName) {
    if ($Upgrade) {
        Write-Step "Upgrade requested — backing up '$DistroName' first..."
        $backupDir = Join-Path $env:USERPROFILE 'caelicode-backups'
        if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $UpgradeBackupPath = Join-Path $backupDir "$DistroName-$stamp.tar"
        wsl.exe --terminate $DistroName 2>&1 | Out-Null
        wsl.exe --export $DistroName $UpgradeBackupPath 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $UpgradeBackupPath) -or (Get-Item $UpgradeBackupPath).Length -lt 1MB) {
            Write-Fail "Backup export failed — NOT removing the existing distro."
            Write-Host "    Export manually and retry:  wsl --export $DistroName <path>.tar" -ForegroundColor Yellow
            return
        }
        $backupGB = [math]::Round((Get-Item $UpgradeBackupPath).Length / 1GB, 2)
        Write-Success "Backup saved: $UpgradeBackupPath (${backupGB}GB)"
        Write-Step "Removing existing distro '$DistroName'..."
        wsl.exe --unregister $DistroName 2>&1 | Out-Null
        Write-Success "Removed existing distro"
    } elseif ($Force) {
        Write-Step "Removing existing distro '$DistroName'..."
        wsl.exe --unregister $DistroName 2>&1 | Out-Null
        Write-Success "Removed existing distro"
    } else {
        Write-Fail "Distro '$DistroName' already exists."
        Write-Host ""
        Write-Host "    To update in-place (keeps all your data):" -ForegroundColor Yellow
        Write-Host "      wsl -d $DistroName -- caelicode-update" -ForegroundColor White
        Write-Host ""
        Write-Host "    To reinstall with an automatic backup first:" -ForegroundColor Yellow
        Write-Host "      .\install.ps1 -Profile $CaeliProfile -Upgrade" -ForegroundColor White
        Write-Host ""
        Write-Host "    To overwrite WITHOUT a backup:" -ForegroundColor Yellow
        Write-Host "      .\install.ps1 -Profile $CaeliProfile -Force" -ForegroundColor White
        return
    }
}

# ── 7. Fetch release info ───────────────────────────────────────────
if ($PinVersion) {
    Write-Step "Fetching release $PinVersion from GitHub..."
    $releaseUri = "$ApiBase/releases/tags/$PinVersion"
} else {
    Write-Step "Fetching latest release from GitHub..."
    $releaseUri = "$ApiBase/releases/latest"
}

try {
    $releaseInfo = Invoke-RestMethod -Uri $releaseUri -Headers @{
        'Accept' = 'application/vnd.github+json'
        'User-Agent' = 'CaeliCode-WSL-Installer'
    }
} catch {
    Write-Fail "Failed to fetch release info: $_"
    if ($PinVersion) {
        Write-Host "    Check the tag name against: https://github.com/$RepoOwner/$RepoName/releases" -ForegroundColor Yellow
    }
    return
}

$version = $releaseInfo.tag_name
Write-Success "Release: $version"

# Find the tar.gz and sha256 assets
$tarAsset = $releaseInfo.assets | Where-Object { $_.name -eq "caelicode-wsl-$CaeliProfile.tar.gz" }
$shaAsset = $releaseInfo.assets | Where-Object { $_.name -eq "caelicode-wsl-$CaeliProfile.sha256" }

if (-not $tarAsset -or -not $shaAsset) {
    if (-not $tarAsset) {
        Write-Fail "Profile '$CaeliProfile' not found in release $version."
    } else {
        Write-Fail "Checksum asset for '$CaeliProfile' is missing from release $version — cannot verify a download."
    }
    Write-Host "    Available assets:" -ForegroundColor Yellow
    $releaseInfo.assets | ForEach-Object { Write-Host "      - $($_.name)" -ForegroundColor DarkGray }
    Write-Host ""
    Write-Host "    The release may still be publishing — retry in a few minutes," -ForegroundColor Yellow
    Write-Host "    or pin the previous release:  .\install.ps1 -Profile $CaeliProfile -Version <tag>" -ForegroundColor Yellow
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

# Download with progress. NOTE: WebClient only raises progress events
# for its *Async methods — the synchronous DownloadFile() never fires
# them. Use the task-based download and poll the file size instead.
$webClient = New-Object System.Net.WebClient
$webClient.Headers.Add('User-Agent', 'CaeliCode-WSL-Installer')

try {
    $dlTask = $webClient.DownloadFileTaskAsync($tarAsset.browser_download_url, $tarPath)
    while (-not $dlTask.IsCompleted) {
        Start-Sleep -Milliseconds 500
        if (Test-Path $tarPath) {
            $mb = [math]::Round((Get-Item $tarPath).Length / 1MB, 1)
            Write-Host ("`r    Downloading... {0}MB / {1}MB   " -f $mb, $tarSizeMB) -NoNewline
        }
    }
    if ($dlTask.IsFaulted) { throw $dlTask.Exception.InnerException }
    Write-Host ""  # newline after progress
    Write-Success "Download complete"
} catch {
    Write-Host ""
    Write-Fail "Download failed: $_"
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    return
} finally {
    $webClient.Dispose()
}

# Download checksum (with retry — GitHub CDN can be flaky).
# -UseBasicParsing: PS 5.1 IWR otherwise depends on the IE engine,
# which is absent/uninitialized on fresh systems.
$shaDownloaded = $false
for ($retry = 1; $retry -le 3; $retry++) {
    try {
        Invoke-WebRequest -Uri $shaAsset.browser_download_url -OutFile $shaPath -UseBasicParsing -Headers @{
            'User-Agent' = 'CaeliCode-WSL-Installer'
        }
        $shaDownloaded = $true
        break
    } catch {
        if ($retry -lt 3) {
            Write-Host "    Checksum download failed, retrying ($retry/3)..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }
}
if (-not $shaDownloaded) {
    Write-Fail "Failed to download checksum file after 3 attempts."
    Write-Host "    The image was downloaded but cannot be verified." -ForegroundColor Yellow
    Write-Host "    Please try running the installer again." -ForegroundColor Yellow
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
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

# --version 2: guarantee a WSL2 distro even when the machine's default
# is WSL1 (the image's interop features do not work under WSL1).
$importResult = wsl.exe --import $DistroName $InstallDir $tarPath --version 2 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Fail "WSL import failed: $importResult"
    Write-Host "    If this mentions WSL2 or virtualization, enable it first:" -ForegroundColor Yellow
    Write-Host "      wsl --install --no-distribution" -ForegroundColor White
    Write-Host "    then reboot and re-run this installer." -ForegroundColor Yellow
    Remove-Item $tempDir -Recurse -Force
    return
}

Write-Success "Distro imported successfully"

# ── 11. Cleanup temp files ───────────────────────────────────────────
Remove-Item $tempDir -Recurse -Force
Write-Success "Cleaned up temp files"

# ── 12. Install Nerd Font for Starship prompt icons ──────────────────
$fontName = "MesloLGS NF"
$fontInstalled = Test-Path "C:\Windows\Fonts\MesloLGS NF Regular.ttf"
if (-not $fontInstalled) {
    Write-Step "Installing $fontName font for terminal icons..."

    $fontBaseUrl = "https://github.com/romkatv/powerlevel10k-media/raw/master"
    $fonts = @(
        @{ Name = "MesloLGS NF Regular.ttf";      Url = "$fontBaseUrl/MesloLGS%20NF%20Regular.ttf" }
        @{ Name = "MesloLGS NF Bold.ttf";          Url = "$fontBaseUrl/MesloLGS%20NF%20Bold.ttf" }
        @{ Name = "MesloLGS NF Italic.ttf";        Url = "$fontBaseUrl/MesloLGS%20NF%20Italic.ttf" }
        @{ Name = "MesloLGS NF Bold Italic.ttf";   Url = "$fontBaseUrl/MesloLGS%20NF%20Bold%20Italic.ttf" }
    )

    $fontSuccess = $true
    foreach ($font in $fonts) {
        $fontTemp = Join-Path $env:TEMP $font.Name
        try {
            Invoke-WebRequest -Uri $font.Url -OutFile $fontTemp -UseBasicParsing -Headers @{
                'User-Agent' = 'CaeliCode-WSL-Installer'
            }
            Copy-Item $fontTemp "C:\Windows\Fonts\" -Force
            New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" `
                -Name "$($font.Name -replace '\.ttf$', '') (TrueType)" `
                -Value $font.Name -PropertyType String -Force | Out-Null
            Remove-Item $fontTemp -Force 2>$null
        } catch {
            $fontSuccess = $false
        }
    }

    if ($fontSuccess) {
        Write-Success "$fontName installed"
        Write-Host "    Set it in Windows Terminal: Settings > Profiles > Appearance > Font face" -ForegroundColor DarkGray
    } else {
        Write-Host "  ! Font install failed (non-critical) — icons may show as '?'" -ForegroundColor Yellow
        Write-Host "    Download manually from: https://github.com/romkatv/powerlevel10k#fonts" -ForegroundColor DarkGray
    }
} else {
    Write-Success "$fontName already installed"
}

# ── 12b. Configure Windows Terminal to use the font ──────────────
$wtSettingsPath = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$wtPreviewPath  = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"

# Also check for unpackaged (scoop/winget/standalone) install
$wtUnpackagedPath = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json"

$wtPaths = @($wtSettingsPath, $wtPreviewPath, $wtUnpackagedPath) | Where-Object { Test-Path $_ }

if ($wtPaths.Count -gt 0) {
    Write-Step "Configuring Windows Terminal font..."

    $fontConfigured = $false
    foreach ($wtPath in $wtPaths) {
        try {
            # Windows Terminal settings.json is JSONC (// comments), which
            # ConvertFrom-Json cannot parse. Strip single-line comments
            # before parsing. Round-tripping through ConvertTo-Json is
            # inherently lossy (comments/formatting), so: skip the write
            # entirely when the font is already set, and always keep a
            # backup beside the original.
            $rawContent = Get-Content $wtPath -Raw
            $stripped = $rawContent -replace '(?m)^\s*//.*$', '' -replace '(?m)(?<=,)\s*//.*$', ''
            $wtJson = $stripped | ConvertFrom-Json

            # Ensure profiles object exists (legacy array-shaped 'profiles'
            # cannot carry defaults — leave those files alone)
            if (-not $wtJson.profiles -or $wtJson.profiles -is [System.Array]) { continue }

            if ($wtJson.profiles.defaults -and $wtJson.profiles.defaults.font -and
                $wtJson.profiles.defaults.font.face -eq 'MesloLGS NF') {
                $fontConfigured = $true   # already set — nothing to rewrite
                continue
            }

            # Set font in profile defaults so it applies to ALL profiles
            # (including the WSL distro which may not exist in WT yet).
            if (-not $wtJson.profiles.defaults) {
                $wtJson.profiles | Add-Member -NotePropertyName "defaults" -NotePropertyValue @{} -Force
            }
            $defaults = $wtJson.profiles.defaults
            if (-not $defaults.font) {
                $defaults | Add-Member -NotePropertyName "font" -NotePropertyValue @{ face = "MesloLGS NF" } -Force
            } else {
                $defaults.font | Add-Member -NotePropertyName "face" -NotePropertyValue "MesloLGS NF" -Force
            }

            Copy-Item $wtPath "$wtPath.caelicode-bak" -Force
            $wtJson | ConvertTo-Json -Depth 20 | Set-Content $wtPath -Encoding UTF8
            $fontConfigured = $true
            Write-Host "    Note: comments in settings.json cannot survive a rewrite;" -ForegroundColor DarkGray
            Write-Host "    original saved as settings.json.caelicode-bak" -ForegroundColor DarkGray
        } catch {
            # Non-fatal — user can set manually
            Write-Host "    Could not auto-configure $wtPath" -ForegroundColor DarkGray
        }
    }

    if ($fontConfigured) {
        Write-Success "Windows Terminal configured with MesloLGS NF font"
        Write-Host "    Restart Windows Terminal for the change to take effect." -ForegroundColor DarkGray
    } else {
        Write-Host "    Auto-config failed — set the font manually:" -ForegroundColor Yellow
        Write-Host "    Settings (Ctrl+,) > Defaults > Appearance > Font face > 'MesloLGS NF'" -ForegroundColor DarkGray
    }
} else {
    Write-Host "    Windows Terminal settings not found — set font manually:" -ForegroundColor DarkGray
    Write-Host "    Settings (Ctrl+,) > Profiles > Appearance > Font face > 'MesloLGS NF'" -ForegroundColor DarkGray
}

# ── 12c. Configure VS Code integrated terminal font ──────────────
$vscodePaths = @(
    (Join-Path $env:APPDATA "Code\User\settings.json"),
    (Join-Path $env:APPDATA "Code - Insiders\User\settings.json")
) | Where-Object { Test-Path $_ }

if ($vscodePaths.Count -gt 0) {
    Write-Step "Configuring VS Code terminal font..."

    $vscodeConfigured = $false
    foreach ($vscodePath in $vscodePaths) {
        try {
            # VS Code settings.json is JSONC: strip // comments (same as
            # the Windows Terminal path — plain ConvertFrom-Json throws on
            # the comments most real settings files contain), skip if the
            # font is already set, and keep a backup.
            $rawVscode = Get-Content $vscodePath -Raw
            $strippedVscode = $rawVscode -replace '(?m)^\s*//.*$', '' -replace '(?m)(?<=,)\s*//.*$', ''
            $vscodeJson = $strippedVscode | ConvertFrom-Json
            if ($vscodeJson.'terminal.integrated.fontFamily' -eq 'MesloLGS NF') {
                $vscodeConfigured = $true
                continue
            }
            $vscodeJson | Add-Member -NotePropertyName "terminal.integrated.fontFamily" `
                -NotePropertyValue "MesloLGS NF" -Force
            Copy-Item $vscodePath "$vscodePath.caelicode-bak" -Force
            $vscodeJson | ConvertTo-Json -Depth 20 | Set-Content $vscodePath -Encoding UTF8
            $vscodeConfigured = $true
        } catch {
            Write-Host "    Could not auto-configure $vscodePath" -ForegroundColor DarkGray
        }
    }

    if ($vscodeConfigured) {
        Write-Success "VS Code terminal configured with MesloLGS NF font"
        Write-Host "    Original saved as settings.json.caelicode-bak (comments cannot survive a rewrite)" -ForegroundColor DarkGray
    } else {
        Write-Host "    Auto-config failed — set it manually in VS Code:" -ForegroundColor Yellow
        Write-Host "    Settings (Ctrl+,) > search 'terminal font' > set 'MesloLGS NF'" -ForegroundColor DarkGray
    }
} else {
    Write-Host "    VS Code settings not found — if using VS Code, set the font manually:" -ForegroundColor DarkGray
    Write-Host "    Settings (Ctrl+,) > search 'terminal font' > set 'MesloLGS NF'" -ForegroundColor DarkGray
}

# ── 13. First launch info ───────────────────────────────────────────
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
Write-Host "  Default user: " -NoNewline; Write-Host "caelicode" -ForegroundColor Cyan -NoNewline
Write-Host " (sudo enabled, zsh shell)" -ForegroundColor DarkGray
Write-Host "  Rename later: " -ForegroundColor DarkGray -NoNewline
Write-Host "sudo usermod -l yourname caelicode" -ForegroundColor White
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
Write-Host "  Staying up to date:" -ForegroundColor Yellow
Write-Host "    A daily background check notifies you at login when a new" -ForegroundColor DarkGray
Write-Host "    release ships. Apply updates in-place with: caelicode-update" -ForegroundColor DarkGray
Write-Host ""
if ($UpgradeBackupPath) {
    Write-Host "  Your pre-upgrade backup:" -ForegroundColor Yellow
    Write-Host "    $UpgradeBackupPath" -ForegroundColor White
    Write-Host "    Restore files from it any time:" -ForegroundColor DarkGray
    Write-Host "      wsl --import ${DistroName}-old `$env:TEMP\caelicode-old `"$UpgradeBackupPath`"" -ForegroundColor DarkGray
    Write-Host "    Delete it once you've confirmed the new install." -ForegroundColor DarkGray
    Write-Host ""
}

} @args
