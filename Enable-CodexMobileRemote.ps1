param(
    [switch]$ForceRestart,
    [switch]$NoRestart
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "OK: $Message" -ForegroundColor Green
}

function Write-WarnLine {
    param([string]$Message)
    Write-Host "WARN: $Message" -ForegroundColor Yellow
}

function Find-CodexExe {
    param([switch]$AllowMissing)

    $roots = @(
        (Join-Path $env:LOCALAPPDATA "OpenAI\Codex\bin"),
        (Join-Path $env:USERPROFILE "AppData\Local\OpenAI\Codex\bin")
    ) | Select-Object -Unique

    foreach ($root in $roots) {
        if (Test-Path -LiteralPath $root) {
            $candidate = Get-ChildItem -LiteralPath $root -Recurse -Filter "codex.exe" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
            if ($candidate) {
                return $candidate.FullName
            }
        }
    }

    $cmd = Get-Command "codex.exe" -ErrorAction SilentlyContinue
    if ($cmd) {
        if ($cmd.Source -like "*\WindowsApps\*") {
            return "codex.exe"
        }
        return $cmd.Source
    }

    if ($AllowMissing) {
        return $null
    }

    throw "codex.exe was not found. Install Codex CLI first."
}

function Find-CodexTerminalCommand {
    param([switch]$AllowMissing)

    $cmd = Get-Command "codex.exe" -ErrorAction SilentlyContinue
    if ($cmd) {
        $candidate = $cmd.Source
        if ($cmd.Source -like "*\WindowsApps\*") {
            $candidate = "codex.exe"
        }

        try {
            & $candidate --help *> $null
            if ($LASTEXITCODE -eq 0) {
                return $candidate
            }
        } catch {
            if (!$AllowMissing) {
                throw "codex.exe was found in this terminal but failed to run. Install Codex CLI or fix the terminal PATH."
            }
        }
    }

    if ($AllowMissing) {
        return $null
    }

    throw "codex.exe is not available in this terminal. Install Codex CLI or restart the terminal after installation."
}

function Find-WingetExe {
    $cmd = Get-Command "winget.exe" -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    $candidate = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe"
    if (Test-Path -LiteralPath $candidate) {
        return $candidate
    }

    throw "winget.exe was not found. Install App Installer from Microsoft Store, then rerun this script."
}

function Test-WingetPackageInstalled {
    param(
        [string]$WingetExe,
        [string]$PackageId,
        [string]$Source
    )

    $args = @("list", "--id", $PackageId, "--exact")
    if ($Source) {
        $args += @("--source", $Source)
    }

    $output = & $WingetExe @args 2>&1
    return ($LASTEXITCODE -eq 0 -and ($output -join "`n") -match [regex]::Escape($PackageId))
}

function Install-WingetPackage {
    param(
        [string]$WingetExe,
        [string]$PackageId,
        [string]$Source,
        [switch]$ContinueOnFailure
    )

    $args = @(
        "install",
        "--id", $PackageId,
        "--exact",
        "--accept-package-agreements",
        "--accept-source-agreements"
    )
    if ($Source) {
        $args += @("--source", $Source)
    }

    & $WingetExe @args | Out-Host
    if ($LASTEXITCODE -ne 0) {
        if ($ContinueOnFailure) {
            Write-WarnLine "winget returned exit code $LASTEXITCODE for package '$PackageId'. Continuing and rechecking installation."
            return
        }
        throw "winget install failed for package: $PackageId"
    }
}

function Resolve-CodexFromKnownPath {
    $knownCodexExe = Find-CodexExe -AllowMissing
    if (!$knownCodexExe -or $knownCodexExe -eq "codex.exe") {
        return $null
    }

    $knownCodexDir = Split-Path -Parent $knownCodexExe
    $env:PATH = "$knownCodexDir;$env:PATH"

    $terminalCodexExe = Find-CodexTerminalCommand -AllowMissing
    if ($terminalCodexExe) {
        return $terminalCodexExe
    }

    return $knownCodexExe
}

function Ensure-CodexInstalled {
    Write-Step "Checking codex.exe in terminal"
    $terminalCodexExe = Find-CodexTerminalCommand -AllowMissing
    if ($terminalCodexExe) {
        Write-Ok "Terminal codex.exe found: $terminalCodexExe"
        return $terminalCodexExe
    }

    Write-WarnLine "codex.exe is not available in this terminal. Checking known Codex CLI install paths."
    $knownCodexExe = Resolve-CodexFromKnownPath
    if ($knownCodexExe) {
        Write-Ok "Terminal codex.exe resolved from known install path: $knownCodexExe"
        return $knownCodexExe
    }

    $wingetExe = Find-WingetExe
    $cliPackageId = "OpenAI.Codex"
    Write-Step "Installing Codex CLI"
    Install-WingetPackage -WingetExe $wingetExe -PackageId $cliPackageId -Source "winget" -ContinueOnFailure

    Write-Step "Rechecking codex.exe in terminal"
    $terminalCodexExe = Find-CodexTerminalCommand -AllowMissing
    if ($terminalCodexExe) {
        Write-Ok "Terminal codex.exe found after CLI install: $terminalCodexExe"
        return $terminalCodexExe
    }

    $fallbackCodexExe = Find-CodexExe -AllowMissing
    if ($fallbackCodexExe) {
        if ($fallbackCodexExe -ne "codex.exe") {
            $fallbackDir = Split-Path -Parent $fallbackCodexExe
            $env:PATH = "$fallbackDir;$env:PATH"
        }
        $terminalCodexExe = Find-CodexTerminalCommand -AllowMissing
        if ($terminalCodexExe) {
            Write-Ok "Terminal codex.exe resolved after PATH update: $terminalCodexExe"
            return $terminalCodexExe
        }

        Write-WarnLine "codex.exe is installed at '$fallbackCodexExe', but this terminal cannot run the codex command yet."
        Write-WarnLine "Continuing with the full executable path. Open a new terminal later to confirm 'codex --help' works."
        return $fallbackCodexExe
    }

    throw "Codex CLI installation completed, but codex.exe is still unavailable. Open a new terminal and rerun this script."
}

function Find-PythonExe {
    $candidates = @(
        (Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python312\python.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python311\python.exe")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    $python = Get-Command "python.exe" -ErrorAction SilentlyContinue
    if ($python) {
        return $python.Source
    }

    $py = Get-Command "py.exe" -ErrorAction SilentlyContinue
    if ($py) {
        return $py.Source
    }

    throw "Python was not found. Install Python or run Codex once so its bundled runtime is installed."
}

function Ensure-RemoteControlConfig {
    $codexHome = Join-Path $env:USERPROFILE ".codex"
    $configPath = Join-Path $codexHome "config.toml"

    if (!(Test-Path -LiteralPath $codexHome)) {
        New-Item -ItemType Directory -Path $codexHome | Out-Null
    }

    if (!(Test-Path -LiteralPath $configPath)) {
        Set-Content -LiteralPath $configPath -Encoding UTF8 -Value "[features]`nremote_control = true`n"
        return $configPath
    }

    $text = Get-Content -LiteralPath $configPath -Raw

    if ($text -match "(?m)^remote_control\s*=\s*true\s*$") {
        return $configPath
    }

    if ($text -match "(?m)^remote_control\s*=") {
        $text = $text -replace "(?m)^remote_control\s*=.*$", "remote_control = true"
    } elseif ($text -match "(?m)^\[features\]\s*$") {
        $text = $text -replace "(?m)^\[features\]\s*$", "[features]`nremote_control = true"
    } else {
        if ($text.Length -gt 0 -and !$text.EndsWith("`n")) {
            $text += "`n"
        }
        $text += "`n[features]`nremote_control = true`n"
    }

    Set-Content -LiteralPath $configPath -Encoding UTF8 -Value $text
    return $configPath
}

function Ensure-RemoteControlDb {
    param([string]$PythonExe)

    $dbPath = Join-Path $env:USERPROFILE ".codex\sqlite\codex-dev.db"
    $dbDir = Split-Path -Parent $dbPath

    if (!(Test-Path -LiteralPath $dbDir)) {
        New-Item -ItemType Directory -Path $dbDir | Out-Null
    }

    $scriptPath = Join-Path $env:TEMP ("codex-remote-control-setup-" + [guid]::NewGuid().ToString("N") + ".py")
    $script = @"
import sqlite3
import time

path = r'''$dbPath'''
con = sqlite3.connect(path)
try:
    con.execute('''
        CREATE TABLE IF NOT EXISTS local_app_server_feature_enablement (
            feature_name TEXT PRIMARY KEY,
            enabled INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        )
    ''')
    con.execute(
        'INSERT OR REPLACE INTO local_app_server_feature_enablement(feature_name, enabled, updated_at) VALUES (?, ?, ?)',
        ('remote_control', 1, int(time.time() * 1000)),
    )
    con.commit()
    print(con.execute(
        'SELECT feature_name, enabled FROM local_app_server_feature_enablement WHERE feature_name = ?',
        ('remote_control',),
    ).fetchone())
finally:
    con.close()
"@

    try {
        Set-Content -LiteralPath $scriptPath -Encoding UTF8 -Value $script
        & $PythonExe $scriptPath
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to update the SQLite state database."
        }
    } finally {
        Remove-Item -LiteralPath $scriptPath -Force -ErrorAction SilentlyContinue
    }

    return $dbPath
}

function Restart-CodexDesktop {
    param([string]$CodexExe)

    if ($NoRestart) {
        Write-WarnLine "Restart skipped. Fully quit and reopen Codex Desktop manually."
        return
    }

    if (!$ForceRestart) {
        Write-Host ""
        $answer = Read-Host "Restart Codex Desktop now? Save active work first. [Y/n]"
        if ($answer -match "^(n|no)$") {
            Write-WarnLine "Restart skipped. Fully quit and reopen Codex Desktop manually."
            return
        }
    }

    Get-Process -ErrorAction SilentlyContinue |
        Where-Object {
            ($_.ProcessName -eq "Codex" -or $_.ProcessName -eq "codex") -and
            $_.Id -ne $PID
        } |
        Stop-Process -Force -ErrorAction SilentlyContinue

    Start-Sleep -Seconds 2

    $workspace = Join-Path $env:USERPROFILE "Documents\Codex"
    if (!(Test-Path -LiteralPath $workspace)) {
        New-Item -ItemType Directory -Path $workspace | Out-Null
    }

    Start-Process -FilePath $CodexExe -ArgumentList @("app", "--enable", "remote_control", $workspace) -WindowStyle Hidden
}

Write-Step "Checking Codex CLI installation"
$codexExe = Ensure-CodexInstalled

Write-Step "Enabling Codex CLI remote_control feature"
& $codexExe features enable remote_control | Out-Host
Write-Ok "CLI feature flag enabled"

Write-Step "Updating config.toml"
$configPath = Ensure-RemoteControlConfig
Write-Ok $configPath

Write-Step "Updating local state database"
$pythonExe = Find-PythonExe
$dbPath = Ensure-RemoteControlDb -PythonExe $pythonExe
Write-Ok $dbPath

Write-Step "Restarting Codex Desktop"
Restart-CodexDesktop -CodexExe $codexExe

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "Open Codex in the ChatGPT mobile app. The approval prompt should appear."
Write-Host "If it does not appear, fully quit Codex Desktop once more and reopen it."
