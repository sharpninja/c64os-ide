# setup-git-svn.ps1
#
# Setup git-svn mirror and pull VICE source code from SourceForge SVN
# Applies patches after successful checkout
#
# Usage: .\setup-git-svn.ps1 [-Clean] [-Verbose]

param(
    [switch]$Clean,
    [switch]$Verbose,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# Configuration
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$viceGitDir = Join-Path $projectRoot "third_party\vice"
$viceDir = Join-Path $viceGitDir "vice"
$patchDir = $scriptDir
$svnRepo = "https://svn.code.sf.net/p/vice-emu/code/trunk"
$gitSvnAuthor = "vice-emu=VICE Emulator Team <info@vice-emu.org>"

# Helper functions
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

function Write-Verbose {
    param([string]$Message)
    if ($Verbose) {
        Write-Host "[VERBOSE] $Message" -ForegroundColor Gray
    }
}

function Show-Help {
    @"
Usage: .\setup-git-svn.ps1 [OPTIONS]

Options:
    -Clean      Remove existing git-svn mirror and start fresh
    -Verbose    Show detailed output
    -Help       Show this help message

Description:
    This script sets up a git-svn mirror of the VICE emulator source code
    from SourceForge and applies necessary patches for C64OS IDE builds.

    If the mirror already exists, it will be updated using 'git svn fetch'.
    If -Clean is specified, the existing mirror will be removed and recreated.

Examples:
    # Initial setup (will take several minutes)
    .\setup-git-svn.ps1

    # Update existing mirror
    .\setup-git-svn.ps1 -Verbose

    # Clean and rebuild mirror
    .\setup-git-svn.ps1 -Clean

"@
    exit 0
}

if ($Help) { Show-Help }

Write-Info "VICE git-svn Setup Script"
Write-Info "Project Root: $projectRoot"

# Check if git is available
try {
    $gitVersion = git --version
    Write-Info "Found: $gitVersion"
} catch {
    Write-Error "Git is not installed or not in PATH"
    exit 1
}

# Check if git-svn perl module is available (Windows may require manual setup)
Write-Info "Checking for git-svn support..."
$gitSvnTest = & git svn --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning "git-svn may not be fully configured on this system"
    Write-Warning "On Windows, you may need to install Git with perl support"
}

# Create third_party directory if needed
if (-not (Test-Path $projectRoot\third_party)) {
    Write-Info "Creating third_party directory..."
    New-Item -ItemType Directory -Path $projectRoot\third_party | Out-Null
}

# Handle --clean flag
if ($Clean) {
    if (Test-Path $viceGitDir) {
        Write-Warning "Removing existing git-svn mirror at: $viceGitDir"
        Remove-Item -Path $viceGitDir -Recurse -Force
        Write-Success "Removed existing mirror"
    }
}

# Initialize or update git-svn mirror
if (-not (Test-Path $viceGitDir)) {
    Write-Info "Initializing git-svn mirror from: $svnRepo"
    Write-Info "This may take several minutes on first run..."

    Push-Location $projectRoot\third_party
    try {
        # Clone from SVN with git-svn
        # Note: Only pull trunk to avoid excessive download
        $startTime = Get-Date
        git svn clone -s `
            -A $gitSvnAuthor `
            -q `
            $svnRepo `
            vice

        $duration = (Get-Date) - $startTime
        Write-Success "Git-SVN mirror initialized successfully"
        Write-Info "Initial clone took: $($duration.TotalMinutes) minutes"
    } catch {
        Write-Error "Failed to initialize git-svn mirror: $_"
        exit 1
    } finally {
        Pop-Location
    }
} else {
    Write-Info "Git-SVN mirror already exists at: $viceGitDir"
    Write-Info "Updating from SVN..."

    Push-Location $viceGitDir
    try {
        $startTime = Get-Date
        git svn fetch -q

        $duration = (Get-Date) - $startTime
        Write-Success "Git-SVN update completed"
        Write-Info "Fetch took: $($duration.TotalSeconds) seconds"
    } catch {
        Write-Error "Failed to update git-svn mirror: $_"
        exit 1
    } finally {
        Pop-Location
    }
}

# Verify VICE directory exists
if (-not (Test-Path $viceDir)) {
    Write-Error "VICE source directory not found at: $viceDir"
    exit 1
}

Write-Success "VICE source available at: $viceDir"

# Apply patches
Write-Info "Applying VICE patches..."

$patchScript = Join-Path $patchDir "apply_vice_patches.ps1"
if (-not (Test-Path $patchScript)) {
    Write-Error "Patch application script not found: $patchScript"
    exit 1
}

try {
    & $patchScript -Verbose
    Write-Success "Patches applied successfully"
} catch {
    Write-Error "Failed to apply patches: $_"
    exit 1
}

Write-Success "VICE git-svn setup complete!"
Write-Info "Source code: $viceDir"
Write-Info "Next steps: Run the build script"
Write-Info "  Windows: .\build.cmd BuildVice --Platform Windows"
Write-Info "  Linux:   ./build.sh BuildVice --Platform Linux"
