# apply_vice_patches.ps1
#
# PowerShell script to apply VICE build patches after pulling from SVN
#
# Usage: .\apply_vice_patches.ps1 [-Verbose] [-TestOnly] [-DryRun]

param(
    [switch]$Verbose,
    [switch]$TestOnly,
    [switch]$DryRun,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# Configuration
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$viceDir = Join-Path $projectRoot "third_party\vice\vice"
$patchDir = $scriptDir

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
    $helpText = @"
VICE Build Patch Manager

Usage: .\apply_vice_patches.ps1 [OPTIONS]

Apply VICE build patches after pulling from SVN repository.

OPTIONS:
    -Verbose      Enable verbose output
    -TestOnly     Only run tests, don't apply patches
    -DryRun       Show what would be done without making changes
    -Help         Show this help message

EXAMPLES:
    # Apply patches
    .\apply_vice_patches.ps1

    # Apply patches with verbose output
    .\apply_vice_patches.ps1 -Verbose

    # Test without applying patches
    .\apply_vice_patches.ps1 -TestOnly

    # See what would be done
    .\apply_vice_patches.ps1 -DryRun
"@
    Write-Host $helpText
}

function Test-PatchFile {
    param([string]$FilePath)
    if (-not (Test-Path $FilePath)) {
        Write-Error "Patch file not found: $FilePath"
        exit 1
    }
}

function Apply-Patch {
    param(
        [string]$PatchFile,
        [string]$TargetDir,
        [string]$Description
    )

    Write-Info "Applying $Description..."

    Push-Location $TargetDir
    try {
        if ($DryRun) {
            Write-Verbose "DRY RUN: Would apply patch $PatchFile"
            # Read patch file to show what would be applied
            $content = Get-Content $PatchFile -Raw
            Write-Verbose "Patch content (first 500 chars):"
            Write-Verbose $content.Substring(0, [Math]::Min(500, $content.Length))
        } else {
            # Apply patch using git if available, otherwise use patch command
            if (Get-Command git -ErrorAction SilentlyContinue) {
                Write-Verbose "Using git apply..."
                & git apply --check $PatchFile 2>$null
                if ($?) {
                    & git apply $PatchFile
                    Write-Success "$Description applied successfully"
                } else {
                    Write-Warning "$Description may already be applied or have conflicts"
                }
            } else {
                Write-Warning "git not found, attempting manual patch..."
                # Fall back to manual verification
                Write-Verbose "Manual application would be needed"
            }
        }
    } finally {
        Pop-Location
    }
}

function Test-Patches {
    Write-Info "Running tests..."
    Write-Host ""

    Write-Info "Test 1: Verifying patches were applied"

    # Test geninfocontrib_h.sh
    $genInfoPath = Join-Path $viceDir "src\buildtools\geninfocontrib_h.sh"
    if (Test-Path $genInfoPath) {
        $content = Get-Content $genInfoPath -Raw
        if ($content -match "test -f coreteam\.tmp &&") {
            Write-Success "✓ geninfocontrib_h.sh contains expected patch"
        } else {
            if ($TestOnly) {
                Write-Warning "✗ geninfocontrib_h.sh patch not detected (expected if not applied)"
            } else {
                Write-Error "✗ geninfocontrib_h.sh patch verification failed"
                return $false
            }
        }
    }

    # Test Makefile
    $makefilePath = Join-Path $viceDir "src\Makefile"
    if (Test-Path $makefilePath) {
        $content = Get-Content $makefilePath -Raw
        if ($content -match '\$\$encoding.*iso-8859-1.*us-ascii') {
            Write-Success "✓ Makefile contains expected patch"
        } else {
            if ($TestOnly) {
                Write-Warning "✗ Makefile patch not detected (expected if not applied)"
            } else {
                Write-Error "✗ Makefile patch verification failed"
                return $false
            }
        }
    }

    return $true
}

# Main script
function Main {
    if ($Help) {
        Show-Help
        exit 0
    }

    Write-Info "VICE Build Patch Manager"
    Write-Info "========================"
    Write-Host ""

    # Check if VICE directory exists
    if (-not (Test-Path $viceDir)) {
        Write-Error "VICE directory not found: $viceDir"
        exit 1
    }
    Write-Success "VICE directory found: $viceDir"

    # Check if patch files exist
    Test-PatchFile (Join-Path $patchDir "geninfocontrib_h.sh.patch")
    Test-PatchFile (Join-Path $patchDir "Makefile.patch")
    Write-Success "All patch files found"
    Write-Host ""

    # Apply patches if not test-only
    if (-not $TestOnly) {
        Apply-Patch `
            -PatchFile (Join-Path $patchDir "geninfocontrib_h.sh.patch") `
            -TargetDir $viceDir `
            -Description "geninfocontrib_h.sh patch"
        Write-Host ""

        Apply-Patch `
            -PatchFile (Join-Path $patchDir "Makefile.patch") `
            -TargetDir $viceDir `
            -Description "Makefile patch"
        Write-Host ""
    }

    # Run tests
    $testPassed = Test-Patches

    # Summary
    Write-Host ""
    Write-Info "Summary"
    Write-Info "========"
    if ($DryRun) {
        Write-Info "Dry run completed - no changes were made"
    } elseif ($TestOnly) {
        Write-Info "Test-only mode - verification completed"
    } else {
        if ($testPassed) {
            Write-Success "Patches applied successfully!"
            Write-Info "The VICE build should now work correctly."
        }
    }
}

# Run main
Main
