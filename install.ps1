$ErrorActionPreference = "Stop"

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

function New-Dir($Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Save-Url($Url, $Path) {
    $tmp = "$Path.tmp.$PID"
    try {
        Invoke-WebRequest -Uri $Url -OutFile $tmp -UseBasicParsing
        Move-Item -LiteralPath $tmp -Destination $Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $tmp) {
            Remove-Item -LiteralPath $tmp -Force
        }
    }
}

function Find-Bash {
    $cmd = Get-Command bash.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    $candidates = @(
        "C:\Program Files\Git\bin\bash.exe",
        "C:\Program Files\Git\usr\bin\bash.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $null
}

New-Dir $BinDir
New-Dir $NxHome
New-Dir $CommandsDir
New-Dir $TemplatesDir

$base = $RawBase.TrimEnd("/")
Save-Url "$base/bin/nx" $Entrypoint

foreach ($name in $Modules) {
    Save-Url "$base/commands/$name" (Join-Path $CommandsDir $name)
    Save-Url "$base/templates/$name" (Join-Path $TemplatesDir $name)
}

$bash = Find-Bash
if ($bash) {
    $escapedHome = $NxHome.Replace("\", "/").Replace("C:", "/c").Replace("D:", "/d")
    $escapedBin = $BinDir.Replace("\", "/").Replace("C:", "/c").Replace("D:", "/d")
    & $bash --noprofile --norc -lc "chmod +x '$escapedBin/nx' '$escapedHome/commands/'* '$escapedHome/templates/'*" | Out-Null
}

Write-Host "nx-lite installed:"
Write-Host "  entrypoint: $Entrypoint"
Write-Host "  commands:   $CommandsDir"

if ($env:Path -notlike "*$BinDir*") {
    Write-Host ""
    Write-Host "Add this directory to PATH for your POSIX shell:"
    Write-Host "  $BinDir"
}

if (-not $bash) {
    Write-Host ""
    Write-Host "Note: bash/sh was not found. nx-lite is a POSIX shell tool; use it from WSL, Git Bash, Linux, or macOS."
}
