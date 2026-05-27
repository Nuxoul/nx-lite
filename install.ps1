$ErrorActionPreference = "Stop"

try {
    $tls = [Net.SecurityProtocolType]::Tls12
    if ([Enum]::GetNames([Net.SecurityProtocolType]) -contains "Tls13") {
        $tls = $tls -bor [Net.SecurityProtocolType]::Tls13
    }
    [Net.ServicePointManager]::SecurityProtocol = $tls
}
catch {
    # Older PowerShell runtimes may not expose every TLS enum; keep going.
}

$DefaultRawBase = "https://raw.githubusercontent.com/Nuxoul/nx-lite/main"
$RawBase = $env:NX_LITE_RAW_BASE
if ([string]::IsNullOrWhiteSpace($RawBase)) {
    $RawBase = $DefaultRawBase
}

if ($RawBase -like "*YOUR_GITHUB_USERNAME*") {
    throw "Set `$env:NX_LITE_RAW_BASE or edit install.ps1 with the GitHub raw base URL before installing."
}

$HomeDir = [Environment]::GetFolderPath("UserProfile")
$NxHome = if ($env:NX_LITE_HOME) { $env:NX_LITE_HOME } else { Join-Path $HomeDir ".nx-lite" }
$BinDir = if ($env:NX_LITE_BIN_DIR) { $env:NX_LITE_BIN_DIR } else { Join-Path (Join-Path $HomeDir ".local") "bin" }
$CommandsDir = Join-Path $NxHome "commands"
$TemplatesDir = Join-Path $NxHome "templates"
$Entrypoint = Join-Path $BinDir "nx"
$Modules = @("base64-enc", "base64-dec", "json-pretty", "url-enc", "url-dec", "md5")
$DownloadHeaders = @{
    "User-Agent" = "nx-lite-installer"
}

function New-Dir($Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Save-Url($Url, $Path) {
    $tmp = "$Path.tmp.$PID"
    $lastError = $null

    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try {
            if (Test-Path -LiteralPath $tmp) {
                Remove-Item -LiteralPath $tmp -Force
            }

            Invoke-WebRequest -Uri $Url -OutFile $tmp -UseBasicParsing -Headers $DownloadHeaders -TimeoutSec 60

            if (-not (Test-Path -LiteralPath $tmp)) {
                throw "download did not create a file"
            }
            if ((Get-Item -LiteralPath $tmp).Length -le 0) {
                throw "downloaded file is empty"
            }

            Move-Item -LiteralPath $tmp -Destination $Path -Force
            return
        }
        catch {
            $lastError = $_.Exception.Message
            if (Test-Path -LiteralPath $tmp) {
                Remove-Item -LiteralPath $tmp -Force
            }
            if ($attempt -lt 5) {
                Write-Warning "Download failed ($attempt/5): $Url"
                Start-Sleep -Seconds ([Math]::Min(10, $attempt * 2))
            }
        }
    }

    try {
        if (Test-Path -LiteralPath $tmp) {
            Remove-Item -LiteralPath $tmp -Force
        }

        $client = New-Object System.Net.WebClient
        $client.Headers.Add("User-Agent", "nx-lite-installer")
        $client.DownloadFile($Url, $tmp)

        if (-not (Test-Path -LiteralPath $tmp)) {
            throw "download did not create a file"
        }
        if ((Get-Item -LiteralPath $tmp).Length -le 0) {
            throw "downloaded file is empty"
        }

        Move-Item -LiteralPath $tmp -Destination $Path -Force
        return
    }
    catch {
        throw "Failed to download $Url after retries. Last error: $lastError"
    }
    finally {
        if (Test-Path -LiteralPath $tmp) {
            Remove-Item -LiteralPath $tmp -Force
        }
        if ($client) {
            $client.Dispose()
        }
    }
}

function Find-Bash {
    if (-not [string]::IsNullOrWhiteSpace($env:NX_LITE_BASH)) {
        if (Test-Path -LiteralPath $env:NX_LITE_BASH) {
            return $env:NX_LITE_BASH
        }
    }

    $candidates = @(
        "C:\Program Files\Git\bin\bash.exe",
        "C:\Program Files\Git\usr\bin\bash.exe",
        "C:\Program Files (x86)\Git\bin\bash.exe",
        "C:\Program Files (x86)\Git\usr\bin\bash.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    $registryKeys = @(
        "HKCU:\SOFTWARE\GitForWindows",
        "HKLM:\SOFTWARE\GitForWindows",
        "HKLM:\SOFTWARE\WOW6432Node\GitForWindows"
    )

    foreach ($key in $registryKeys) {
        try {
            $installPath = (Get-ItemProperty -LiteralPath $key -ErrorAction Stop).InstallPath
            if (-not [string]::IsNullOrWhiteSpace($installPath)) {
                foreach ($relative in @("bin\bash.exe", "usr\bin\bash.exe")) {
                    $candidate = Join-Path $installPath $relative
                    if (Test-Path -LiteralPath $candidate) {
                        return $candidate
                    }
                }
            }
        }
        catch {
            # Missing registry keys are expected on portable or custom Git installs.
        }
    }

    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($git -and $git.Source) {
        $dir = Split-Path -Parent $git.Source
        for ($i = 0; $i -lt 6 -and -not [string]::IsNullOrWhiteSpace($dir); $i++) {
            foreach ($relative in @("bash.exe", "bin\bash.exe", "usr\bin\bash.exe")) {
                $candidate = Join-Path $dir $relative
                if (Test-Path -LiteralPath $candidate) {
                    return $candidate
                }
            }

            $parent = Split-Path -Parent $dir
            if ($parent -eq $dir) {
                break
            }
            $dir = $parent
        }
    }

    $cmd = Get-Command bash.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        $source = $cmd.Source
        if ($source -notlike "*\Windows\System32\bash.exe" -and $source -notlike "*\WindowsApps\bash.exe") {
            return $source
        }
    }

    return $null
}

function Convert-ToGitBashPath($Path) {
    $full = [System.IO.Path]::GetFullPath($Path).Replace("\", "/")
    if ($full -match "^([A-Za-z]):/(.*)$") {
        return "/$($Matches[1].ToLower())/$($Matches[2])"
    }
    return $full
}

function Write-WindowsLaunchers($BinDir) {
    $ps1Path = Join-Path $BinDir "nx.ps1"
    $cmdPath = Join-Path $BinDir "nx.cmd"

    $ps1 = @'
$ErrorActionPreference = "Stop"

function Find-NxLiteBash {
    if (-not [string]::IsNullOrWhiteSpace($env:NX_LITE_BASH)) {
        if (Test-Path -LiteralPath $env:NX_LITE_BASH) {
            return $env:NX_LITE_BASH
        }
    }

    $candidates = @(
        "C:\Program Files\Git\bin\bash.exe",
        "C:\Program Files\Git\usr\bin\bash.exe",
        "C:\Program Files (x86)\Git\bin\bash.exe",
        "C:\Program Files (x86)\Git\usr\bin\bash.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    $registryKeys = @(
        "HKCU:\SOFTWARE\GitForWindows",
        "HKLM:\SOFTWARE\GitForWindows",
        "HKLM:\SOFTWARE\WOW6432Node\GitForWindows"
    )

    foreach ($key in $registryKeys) {
        try {
            $installPath = (Get-ItemProperty -LiteralPath $key -ErrorAction Stop).InstallPath
            if (-not [string]::IsNullOrWhiteSpace($installPath)) {
                foreach ($relative in @("bin\bash.exe", "usr\bin\bash.exe")) {
                    $candidate = Join-Path $installPath $relative
                    if (Test-Path -LiteralPath $candidate) {
                        return $candidate
                    }
                }
            }
        }
        catch {
            # Missing registry keys are expected on portable or custom Git installs.
        }
    }

    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($git -and $git.Source) {
        $dir = Split-Path -Parent $git.Source
        for ($i = 0; $i -lt 6 -and -not [string]::IsNullOrWhiteSpace($dir); $i++) {
            foreach ($relative in @("bash.exe", "bin\bash.exe", "usr\bin\bash.exe")) {
                $candidate = Join-Path $dir $relative
                if (Test-Path -LiteralPath $candidate) {
                    return $candidate
                }
            }

            $parent = Split-Path -Parent $dir
            if ($parent -eq $dir) {
                break
            }
            $dir = $parent
        }
    }

    $cmd = Get-Command bash.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        $source = $cmd.Source
        if ($source -notlike "*\Windows\System32\bash.exe" -and $source -notlike "*\WindowsApps\bash.exe") {
            return $source
        }
    }

    return $null
}

function Convert-ToGitBashPath($Path) {
    $full = [System.IO.Path]::GetFullPath($Path).Replace("\", "/")
    if ($full -match "^([A-Za-z]):/(.*)$") {
        return "/$($Matches[1].ToLower())/$($Matches[2])"
    }
    return $full
}

$bash = Find-NxLiteBash
if (-not $bash) {
    Write-Error "nx-lite needs Git Bash on Windows PowerShell. Install Git for Windows, add Git to PATH, or set NX_LITE_BASH to bash.exe."
    exit 1
}

$nxScript = Join-Path $PSScriptRoot "nx"
$nxScriptForBash = Convert-ToGitBashPath $nxScript

& $bash --noprofile --norc "$nxScriptForBash" @args
exit $LASTEXITCODE
'@

    $cmd = @'
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0nx.ps1" %*
exit /b %ERRORLEVEL%
'@

    [System.IO.File]::WriteAllText($ps1Path, $ps1, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($cmdPath, $cmd, [System.Text.ASCIIEncoding]::new())
}

New-Dir $BinDir
New-Dir $NxHome
New-Dir $CommandsDir
New-Dir $TemplatesDir

$base = $RawBase.TrimEnd("/")
Save-Url "$base/bin/nx" $Entrypoint
Write-WindowsLaunchers $BinDir

foreach ($name in $Modules) {
    $commandPath = Join-Path $CommandsDir $name
    $templatePath = Join-Path $TemplatesDir $name
    Save-Url "$base/commands/$name" $commandPath
    Copy-Item -LiteralPath $commandPath -Destination $templatePath -Force
}

$bash = Find-Bash
if ($bash) {
    $escapedHome = Convert-ToGitBashPath $NxHome
    $escapedBin = Convert-ToGitBashPath $BinDir
    & $bash --noprofile --norc -lc "chmod +x '$escapedBin/nx' '$escapedHome/commands/'* '$escapedHome/templates/'*" | Out-Null
}

Write-Host "nx-lite installed:"
Write-Host "  entrypoint: $Entrypoint"
Write-Host "  powershell: $(Join-Path $BinDir "nx.cmd")"
Write-Host "  commands:   $CommandsDir"

if ($env:Path -notlike "*$BinDir*") {
    Write-Host ""
    Write-Host "Add this directory to PATH for your POSIX shell:"
    Write-Host "  $BinDir"
}

if (-not $bash) {
    Write-Host ""
    Write-Host "Note: Git Bash was not found. Install Git for Windows, add Git to PATH, or set NX_LITE_BASH to bash.exe."
}
