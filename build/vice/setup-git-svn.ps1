# setup-git-svn.ps1
#
# Setup git mirror and pull VICE source code from GitHub VICE Team mirror
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
$svnRepo = "https://github.com/VICE-Team/svn-mirror.git"
$gitSvnAuthor = "vice-emu=VICE Emulator Team <info@vice-emu.org>"

# Detect if running as git submodule
$isSubmodule = Test-Path (Join-Path $viceGitDir ".git")
if (Test-Path (Join-Path $viceGitDir ".git")) {
    $gitDir = Get-Content (Join-Path $viceGitDir ".git") -ErrorAction SilentlyContinue
    if ($gitDir -match "^gitdir:") {
        $isSubmodule = $true
    }
}

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
    -Clean      Remove existing git mirror and start fresh
    -Verbose    Show detailed output
    -Help       Show this help message

Description:
    This script sets up a git mirror of the VICE emulator source code
    from the official GitHub VICE Team mirror and applies necessary
    patches for C64OS IDE builds.

    If the mirror already exists, it will be updated using 'git fetch'.
    If -Clean is specified, the existing mirror will be removed and recreated.

Examples:
    # Initial setup (will take a minute or so)
    .\setup-git-svn.ps1

    # Update existing mirror
    .\setup-git-svn.ps1 -Verbose

    # Clean and rebuild mirror
    .\setup-git-svn.ps1 -Clean

"@
    exit 0
}

# Handle git submodule if applicable
if ($isSubmodule) {
    Write-Info "VICE is configured as a git submodule"

    # Check if submodule is already populated
    if ((Test-Path $viceDir) -and (Get-ChildItem $viceDir -ErrorAction SilentlyContinue).Count -gt 0) {
        Write-Info "Submodule already populated (likely by GitHub Actions checkout)"
        Write-Success "VICE submodule content already available"
    } else {
        Write-Info "Submodule not populated, initializing now..."

        Push-Location $projectRoot
        try {
            $ErrorActionPreference = "Continue"
            $status = git submodule status third_party/vice 2>&1
            $ErrorActionPreference = "Stop"

            if ($status -match "^-") {
                Write-Info "Submodule not initialized, initializing now..."
                git submodule update --init --recursive third_party/vice
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "Failed to initialize submodule (exit code: $LASTEXITCODE)"
                    exit 1
                }
            } else {
                Write-Info "Submodule already initialized, updating..."
                git submodule update --recursive third_party/vice
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "Failed to update submodule (exit code: $LASTEXITCODE)"
                    exit 1
                }
            }

            Write-Success "Submodule initialized/updated successfully"
        } catch {
            Write-Error "Failed to manage submodule: $_"
            exit 1
        } finally {
            Pop-Location
        }
    }

    # Apply patches
    Write-Info "Applying VICE patches..."
    $patchScript = Join-Path $patchDir "apply_vice_patches.ps1"
    if (Test-Path $patchScript) {
        try {
            & $patchScript -Verbose
            Write-Success "Patches applied successfully"
        } catch {
            Write-Error "Failed to apply patches: $_"
            exit 1
        }
    }

    Write-Success "VICE submodule setup complete!"
    Write-Info "Source code: $viceDir"
    Write-Info "Next steps: Run the build script"
    Write-Info "  Windows: .\build.cmd BuildVice --Platform Windows"
    Write-Info "  Linux:   ./build.sh BuildVice --Platform Linux"
    exit 0
}

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

# Check if git is available
try {
    $gitVersion = git --version
    Write-Info "Found: $gitVersion"
} catch {
    Write-Error "Git is not installed or not in PATH"
    exit 1
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
    Write-Info "Initializing git mirror from: $svnRepo"
    Write-Info "This may take a few minutes on first run..."

    Push-Location $projectRoot\third_party
    try {
        # Clone from GitHub mirror
        $startTime = Get-Date
        git clone -q $svnRepo vice

        $duration = (Get-Date) - $startTime
        Write-Success "Git mirror cloned successfully"
        Write-Info "Initial clone took: $($duration.TotalMinutes) minutes"
    } catch {
        Write-Error "Failed to initialize git mirror: $_"
        exit 1
    } finally {
        Pop-Location
    }
} else {
    Write-Info "Git mirror already exists at: $viceGitDir"
    Write-Info "Updating from remote..."

    Push-Location $viceGitDir
    try {
        $startTime = Get-Date
        git fetch -q

        $duration = (Get-Date) - $startTime
        Write-Success "Git mirror updated"
        Write-Info "Fetch took: $($duration.TotalSeconds) seconds"
    } catch {
        Write-Error "Failed to update git mirror: $_"
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

Write-Success "VICE git mirror setup complete!"
Write-Info "Source code: $viceDir"
Write-Info "Next steps: Run the build script"
Write-Info "  Windows: .\build.cmd BuildVice --Platform Windows"
Write-Info "  Linux:   ./build.sh BuildVice --Platform Linux"
