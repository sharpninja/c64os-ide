#!/usr/bin/env pwsh
# VICE MinGW64 Build Script for Windows
# Wrapper that launches MSYS2 MinGW64 environment and runs the build

param(
    [string]$SourceDir = "third_party/vice/vice",
    [string]$DestDir = "artifacts/vice/win-x64",
    [int]$Jobs = $env:NUMBER_OF_PROCESSORS
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VICE MinGW64 Build for Windows" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Source: $SourceDir"
Write-Host "Dest:   $DestDir"
Write-Host "Jobs:   $Jobs"
Write-Host ""

# Find MSYS2 installation
$msys2Paths = @(
    "C:\msys64",
    "C:\tools\msys64",
    "$env:USERPROFILE\msys64",
    "C:\Program Files\msys64"
)

$msys2Root = $null
foreach ($path in $msys2Paths) {
    if (Test-Path "$path\msys2_shell.cmd") {
        $msys2Root = $path
        break
    }
}

if (-not $msys2Root) {
    Write-Host "ERROR: MSYS2 not found in common locations" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install MSYS2 from: https://www.msys2.org/" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "Found MSYS2 at: $msys2Root" -ForegroundColor Green
Write-Host ""

# Convert paths to MSYS2 format
$scriptDir = $PSScriptRoot
$buildScript = Join-Path $scriptDir "build-mingw64.sh"

# Convert Windows paths to MSYS2 paths
function ConvertTo-Msys2Path {
    param([string]$WindowsPath)

    $fullPath = (Resolve-Path -Path $WindowsPath -ErrorAction SilentlyContinue)?.Path
    if (-not $fullPath) {
        $fullPath = $WindowsPath
    }

    # Convert C:\path to /c/path
    if ($fullPath -match '^([A-Z]):(.*)$') {
        $drive = $matches[1].ToLower()
        $path = $matches[2] -replace '\\', '/'
        return "/$drive$path"
    }
    return $fullPath -replace '\\', '/'
}

$msys2SourceDir = ConvertTo-Msys2Path $SourceDir
$msys2DestDir = ConvertTo-Msys2Path $DestDir
$msys2BuildScript = ConvertTo-Msys2Path $buildScript

Write-Host "Converted paths for MSYS2:" -ForegroundColor Cyan
Write-Host "  Script: $msys2BuildScript"
Write-Host "  Source: $msys2SourceDir"
Write-Host "  Dest:   $msys2DestDir"
Write-Host ""

# Launch MSYS2 MinGW64 shell with build command
$msys2Shell = Join-Path $msys2Root "msys2_shell.cmd"
$msys2Cmd = "bash '$msys2BuildScript' '$msys2SourceDir' '$msys2DestDir' $Jobs"

Write-Host "Launching MSYS2 MinGW64 build..." -ForegroundColor Cyan
Write-Host "Command: $msys2Cmd" -ForegroundColor Gray
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# When streams are redirected, -c doesn't work properly with msys2_shell.cmd
# Instead, call bash.exe directly with the MINGW64 environment
$bashExe = Join-Path $msys2Root "usr\bin\bash.exe"

# Build the bash command - source the MINGW64 profile first
$bashCmd = "source /etc/profile && [[ -f ~/.bashrc ]] && source ~/.bashrc; $msys2BuildScript '$msys2SourceDir' '$msys2DestDir' $Jobs"

Write-Host "Executing with bash directly to handle stream redirection..." -ForegroundColor Yellow

# Execute bash directly with proper environment
$processInfo = New-Object System.Diagnostics.ProcessStartInfo
$processInfo.FileName = $bashExe
$processInfo.Arguments = "-l -c `"$bashCmd`""
$processInfo.UseShellExecute = $false
$processInfo.RedirectStandardOutput = $false
$processInfo.RedirectStandardError = $false

# Set MINGW64 environment before bash starts
$processInfo.EnvironmentVariables["MSYSTEM"] = "MINGW64"
$processInfo.EnvironmentVariables["MSYS2_PATH_TYPE"] = "inherit"
$processInfo.EnvironmentVariables["CHERE_INVOKING"] = "1"

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $processInfo
$null = $process.Start()
$process.WaitForExit()

if ($process.ExitCode -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Build failed with exit code $($process.ExitCode)" -ForegroundColor Red
    exit $process.ExitCode
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Build completed successfully!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Verify binaries
$binaries = Get-ChildItem -Path $DestDir -Filter "*.exe" -ErrorAction SilentlyContinue
if ($binaries) {
    Write-Host "Generated binaries:" -ForegroundColor Green
    foreach ($bin in $binaries) {
        $sizeMB = [math]::Round($bin.Length / 1MB, 2)
        Write-Host "  $($bin.Name) ($sizeMB MB)"
    }
} else {
    Write-Host "WARNING: No .exe files found in $DestDir" -ForegroundColor Yellow
}

Write-Host ""
exit 0
