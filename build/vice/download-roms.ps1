# download-roms.ps1
#
# Downloads VICE ROM files from asig/vice-roms GitHub repository
# and places them in the VICE build output directory
#
# Usage: .\download-roms.ps1 [-VicePath <path>] [-Force]

param(
    [string]$VicePath = "$PSScriptRoot\..\..\third_party\vice\vice",
    [switch]$Force,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Show-Help {
    Write-Host @"
VICE ROM Downloader
===================

Downloads VICE ROM files from asig/vice-roms GitHub repository.

Usage:
    .\download-roms.ps1 [-VicePath <path>] [-Force] [-Help]

Parameters:
    -VicePath <path>    Path to VICE source directory (default: ..\..\third_party\vice\vice)
    -Force              Force re-download even if ROMs already exist
    -Help               Show this help message

Examples:
    .\download-roms.ps1
    .\download-roms.ps1 -Force
    .\download-roms.ps1 -VicePath "C:\vice"

ROM Repository: https://github.com/asig/vice-roms
"@
    exit 0
}

if ($Help) {
    Show-Help
}

# Resolve paths
$VicePath = Resolve-Path $VicePath -ErrorAction SilentlyContinue
if (-not $VicePath) {
    Write-Error "VICE path not found. Please specify a valid path with -VicePath"
    exit 1
}

$dataDir = Join-Path $VicePath "data"
$romsDir = Join-Path $dataDir "ROMS"
$tempDir = Join-Path $env:TEMP "vice-roms-download"

Write-Info "VICE ROM Downloader"
Write-Info "==================="
Write-Host ""
Write-Info "VICE path: $VicePath"
Write-Info "Data directory: $dataDir"
Write-Info "ROMs directory: $romsDir"
Write-Host ""

# Check if ROMs already exist
if ((Test-Path $romsDir) -and -not $Force) {
    Write-Info "ROMs directory already exists: $romsDir"
    $romCount = (Get-ChildItem -Path $romsDir -Recurse -File | Measure-Object).Count
    Write-Info "Found $romCount ROM files"
    Write-Warning "Use -Force to re-download"
    exit 0
}

# Create data directory if it doesn't exist
if (-not (Test-Path $dataDir)) {
    Write-Info "Creating data directory: $dataDir"
    New-Item -ItemType Directory -Path $dataDir | Out-Null
}

# Clean up temp directory if it exists
if (Test-Path $tempDir) {
    Write-Info "Cleaning up temporary directory..."
    Remove-Item -Path $tempDir -Recurse -Force
}

# Create temp directory
Write-Info "Creating temporary directory: $tempDir"
New-Item -ItemType Directory -Path $tempDir | Out-Null

try {
    # Download the ROMs repository
    $repoUrl = "https://github.com/asig/vice-roms/archive/refs/heads/master.zip"
    $zipFile = Join-Path $tempDir "vice-roms.zip"
    
    Write-Info "Downloading ROMs from: $repoUrl"
    Write-Host "This may take a moment..."
    
    # Use Invoke-WebRequest to download
    Invoke-WebRequest -Uri $repoUrl -OutFile $zipFile -UseBasicParsing
    
    Write-Success "Download complete"
    Write-Info "File size: $([math]::Round((Get-Item $zipFile).Length / 1MB, 2)) MB"
    
    # Extract the archive
    Write-Info "Extracting archive..."
    Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force
    
    # Find the extracted directory (usually vice-roms-master)
    $extractedDir = Get-ChildItem -Path $tempDir -Directory | Where-Object { $_.Name -like "vice-roms*" } | Select-Object -First 1
    
    if (-not $extractedDir) {
        Write-Error "Could not find extracted ROMs directory"
        exit 1
    }
    
    Write-Info "Extracted to: $($extractedDir.FullName)"
    
    # Copy ROMs to VICE data directory
    Write-Info "Copying ROMs to: $romsDir"
    
    # The repository structure has ROMs in subdirectories
    if (Test-Path $romsDir) {
        if ($Force) {
            Write-Info "Removing existing ROMs directory..."
            Remove-Item -Path $romsDir -Recurse -Force
        }
    }
    
    # Copy the entire directory structure
    Copy-Item -Path $extractedDir.FullName -Destination $romsDir -Recurse -Force
    
    # Count the ROMs
    $romFiles = Get-ChildItem -Path $romsDir -Recurse -File
    $romCount = ($romFiles | Measure-Object).Count
    $totalSize = ($romFiles | Measure-Object -Property Length -Sum).Sum
    
    Write-Success "ROMs installed successfully!"
    Write-Host ""
    Write-Info "Statistics:"
    Write-Host "  Total ROM files: $romCount"
    Write-Host "  Total size: $([math]::Round($totalSize / 1KB, 2)) KB"
    Write-Host ""
    Write-Info "ROM systems available:"
    
    # List ROM directories
    $romDirs = Get-ChildItem -Path $romsDir -Directory
    foreach ($dir in $romDirs) {
        $fileCount = (Get-ChildItem -Path $dir.FullName -File -Recurse | Measure-Object).Count
        Write-Host "  - $($dir.Name): $fileCount files"
    }
    
    Write-Host ""
    Write-Success "Done! VICE emulators can now use these ROMs."
    
}
catch {
    Write-Error "Failed to download or install ROMs: $_"
    exit 1
}
finally {
    # Clean up temp directory
    if (Test-Path $tempDir) {
        Write-Info "Cleaning up temporary files..."
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Info "To use the ROMs with VICE emulators:"
Write-Host "  Run the emulator from: $VicePath\src\"
Write-Host "  Example: wsl $VicePath/src/x64sc"
