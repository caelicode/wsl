<#
.SYNOPSIS
    CaeliCode WSL — distro backup helper.

.DESCRIPTION
    Exports a CaeliCode WSL distro to a timestamped tar in
    %USERPROFILE%\caelicode-backups and verifies the export is
    non-empty. Used before major upgrades (see: caelicode-update --full)
    and any time you want a restorable snapshot.

.EXAMPLE
    irm https://raw.githubusercontent.com/caelicode/wsl/main/tools/caelicode-backup.ps1 | iex
    .\caelicode-backup.ps1 -DistroName caelicode-sre
#>

& {

$DistroName = $null
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        '-DistroName' { $DistroName = $args[++$i] }
    }
}

$ErrorActionPreference = 'Stop'
$env:WSL_UTF8 = '1'

function Invoke-Native {
    # PS 5.1: 2>&1 on native stderr + EAP 'Stop' throws NativeCommandError.
    param([scriptblock]$Block)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $Block } finally { $ErrorActionPreference = $prev }
}

$allDistros = (Invoke-Native { wsl.exe --list --quiet 2>&1 | Out-String }) -split "`r?`n" |
    ForEach-Object { $_.Trim() } | Where-Object { $_ }
$distros = $allDistros | Where-Object { $_ -like 'caelicode-*' }

# An explicit -DistroName is validated against ALL distros, not just
# caelicode-* — install.ps1 supports custom names via its own
# -DistroName parameter.
if ($DistroName) {
    if ($allDistros -notcontains $DistroName) {
        Write-Host "Distro '$DistroName' not found. Installed distros:" -ForegroundColor Red
        $allDistros | ForEach-Object { Write-Host "  - $_" }
        return
    }
} elseif (-not $distros) {
    Write-Host "No caelicode-* distros found." -ForegroundColor Yellow
    return
}

if (-not $DistroName) {
    if (@($distros).Count -eq 1) {
        $DistroName = @($distros)[0]
    } else {
        Write-Host "Multiple CaeliCode distros found:" -ForegroundColor Cyan
        $idx = 1
        foreach ($d in $distros) { Write-Host "  [$idx] $d"; $idx++ }
        $choice = Read-Host "Select distro to back up (1-$(@($distros).Count))"
        if ($choice -notmatch '^\d+$' -or [int]$choice -lt 1 -or [int]$choice -gt @($distros).Count) {
            Write-Host "Invalid selection." -ForegroundColor Red
            return
        }
        $DistroName = @($distros)[[int]$choice - 1]
    }
}

$backupDir = Join-Path $env:USERPROFILE 'caelicode-backups'
if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupPath = Join-Path $backupDir "$DistroName-$stamp.tar"

Write-Host "Exporting $DistroName → $backupPath" -ForegroundColor Cyan
Write-Host "(the distro is terminated first for a consistent snapshot)" -ForegroundColor DarkGray
Invoke-Native { wsl.exe --terminate $DistroName 2>&1 | Out-Null }
Invoke-Native { wsl.exe --export $DistroName $backupPath }

if ($LASTEXITCODE -ne 0 -or -not (Test-Path $backupPath) -or (Get-Item $backupPath).Length -lt 1MB) {
    Write-Host "Backup FAILED — do not delete or unregister the distro." -ForegroundColor Red
    return
}

$sizeGB = [math]::Round((Get-Item $backupPath).Length / 1GB, 2)
Write-Host "Backup complete: $backupPath (${sizeGB}GB)" -ForegroundColor Green
Write-Host ""
Write-Host "Restore any time with:" -ForegroundColor Yellow
Write-Host "  wsl --import $DistroName-restored `"$env:LOCALAPPDATA\CaeliCode\wsl\restored`" `"$backupPath`""

} @args
