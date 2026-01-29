# Setup-C64OS-IDE.ps1
#
# Local setup validation script for C64OS IDE
# Checks that all dependencies are installed and operational
# PowerShell 5.0+ compatible
#
# Usage: .\Setup-C64OS-IDE.ps1
#

#Requires -Version 5.0

# Check if running on Windows
$isWindows = if ($IsWindows -ne $null) {
    $IsWindows
} elseif ($PSVersionTable.Platform) {
    $PSVersionTable.Platform -eq "Win32NT"
} else {
    [System.Environment]::OSVersion.Platform -eq "Win32NT"
}

if (-not $isWindows) {
    Write-Host "ERROR: This setup script is designed for Windows only." -ForegroundColor Red
    Write-Host ""
    Write-Host "Detected OS: $($PSVersionTable.Platform)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This script checks for Windows-specific dependencies such as:" -ForegroundColor Yellow
    Write-Host "  - WSL (Windows Subsystem for Linux)" -ForegroundColor Yellow
    Write-Host "  - MSYS2/MinGW64" -ForegroundColor Yellow
    Write-Host "  - Windows-specific build tools" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "If you're running on Linux or macOS, please use the appropriate setup method" -ForegroundColor Yellow
    Write-Host "for your platform instead." -ForegroundColor Yellow
    exit 1
}

$ErrorActionPreference = "Continue"

# Check if running in PowerShell 7+
$isPwsh7 = $PSVersionTable.PSVersion.Major -ge 7

if (-not $isPwsh7) {
    Write-Host "Checking for PowerShell 7..." -ForegroundColor Cyan

    # Check if pwsh is available
    $pwshPath = Get-Command pwsh -ErrorAction SilentlyContinue

    if (-not $pwshPath) {
        Write-Host "PowerShell 7 not found. Installing via winget..." -ForegroundColor Yellow

        # Check if winget is available
        $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
        if (-not $wingetPath) {
            Write-Host "ERROR: winget is not available. Please install PowerShell 7 manually:" -ForegroundColor Red
            Write-Host "  Download from: https://aka.ms/powershell" -ForegroundColor Yellow
            Write-Host "  Or visit: https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Yellow
            exit 1
        }

        # Install PowerShell 7
        Write-Host "Running: winget install Microsoft.PowerShell --silent --accept-package-agreements --accept-source-agreements" -ForegroundColor Cyan
        winget install Microsoft.PowerShell --silent --accept-package-agreements --accept-source-agreements

        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Failed to install PowerShell 7. Please install manually." -ForegroundColor Red
            exit 1
        }

        Write-Host "PowerShell 7 installed successfully!" -ForegroundColor Green

        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        # Verify pwsh is now available
        $pwshPath = Get-Command pwsh -ErrorAction SilentlyContinue
        if (-not $pwshPath) {
            Write-Host "ERROR: PowerShell 7 was installed but pwsh is not in PATH. Please restart your terminal." -ForegroundColor Red
            exit 1
        }
    }

    # Re-execute this script in PowerShell 7
    Write-Host "Relaunching setup script in PowerShell 7..." -ForegroundColor Cyan
    Write-Host ""

    $scriptPath = $MyInvocation.MyCommand.Path
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $scriptPath
    exit $LASTEXITCODE
}

# Now running in PowerShell 7+
Write-Host "Running in PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Green
Write-Host ""

# Check for administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Note: Some operations (like installing packages) require Administrator privileges." -ForegroundColor Yellow
    Write-Host "For full functionality, run this script with 'Run as Administrator'" -ForegroundColor Yellow
    Write-Host ""
}

# Color codes
$colors = @{
    Reset = "`e[0m"
    Green = "`e[32m"
    Red = "`e[31m"
    Yellow = "`e[33m"
    Blue = "`e[34m"
    Cyan = "`e[36m"
}

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host ('=' * 80) -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host ('=' * 80) -ForegroundColor Cyan
    Write-Host ""
}

function Write-Status {
    param([string]$Text, [ValidateSet("Info", "Success", "Warning", "Error")]$Status = "Info")
    $symbol = switch ($Status) {
        "Info" { "[i]" }
        "Success" { "[+]" }
        "Warning" { "[!]" }
        "Error" { "[-]" }
    }

    $color = switch ($Status) {
        "Info" { "Cyan" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
    }

    Write-Host "$symbol " -ForegroundColor $color -NoNewline
    Write-Host $Text
}

function Test-CommandExists {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

function Test-DotnetSdk {
    Write-Status "Checking .NET SDK..." Info

    if (Test-CommandExists "dotnet") {
        $version = dotnet --version 2>&1
        if ($version -match "^[7-9]\.|^1[0-9]\.") {
            Write-Status ".NET SDK $version installed" Success
            return $true
        }
        else {
            Write-Status ".NET SDK $version found (need 7.0+)" Warning
            return $false
        }
    }
    else {
        Write-Status ".NET SDK not found" Error
        Write-Host "  Install from: https://dotnet.microsoft.com/download"
        Write-Host "  Or use: winget install Microsoft.DotNet.SDK.8"
        Write-Host "  Or use: choco install dotnet-sdk"
        return $false
    }
}

function Test-Git {
    Write-Status "Checking Git..." Info

    if (Test-CommandExists "git") {
        $version = git --version 2>&1
        Write-Status $version Success

        # Check if git-svn is available (git-svn is a Git subcommand, not a standalone executable)
        $null = git svn --version 2>&1
        if ($?) {
            Write-Status "  git-svn available" Success
        }
        else {
            Write-Status "  git-svn not found (optional, for SVN integration)" Warning
        }
        return $true
    }
    else {
        Write-Status "Git not found" Error
        Write-Host "  Install from: https://git-scm.com/download/win"
        Write-Host "  Or use: winget install Git.Git"
        Write-Host "  Or use: choco install git"
        return $false
    }
}

function Test-Svn {
    Write-Status "Checking Subversion (SVN)..." Info

    if (Test-CommandExists "svn") {
        $version = svn --version 2>&1 | Select-Object -First 1
        Write-Status $version Success
        return $true
    }
    else {
        Write-Status "SVN not found (git-svn alternative available)" Warning
        Write-Host "  Install from: https://visualsvn.com/downloads/"
        Write-Host "  Or use: winget install Apache.Subversion"
        Write-Host "  Or use: choco install svn"
        return $false
    }
}

function Test-Wsl {
    Write-Status "Checking WSL 2..." Info

    $wsl = Get-Command wsl -ErrorAction SilentlyContinue
    if ($wsl) {
        $version = (wsl --version 2>&1)
        # WSL output may contain UTF-16 null bytes, clean them
        $versionStr = ($version | ForEach-Object { $_.ToString() -replace '\x00', '' }) -join "`n"

        if ($versionStr -match "WSL version") {
            $versionLine = ($versionStr -split "`n")[0].Trim()
            Write-Status $versionLine Success

            # Check default distribution
            $distros = (wsl --list 2>&1) | ForEach-Object { $_.ToString() -replace '\x00', '' }
            $distrosStr = $distros -join " "

            if ($distrosStr -match "Ubuntu|Debian|Alpine") {
                Write-Status "  Linux distribution available" Success
                return $true
            }
            else {
                Write-Status "  No Linux distribution installed" Warning
                Write-Host "  Install with: wsl --install"
                return $false
            }
        }
    }

    Write-Status "WSL 2 not found" Error
    Write-Host "  Install with: wsl --install"
    Write-Host "  Or manually: https://learn.microsoft.com/en-us/windows/wsl/install"
    Write-Host "  (Requires Windows 10 19041+ or Windows 11)"
    return $false
}

function Test-WslBuildTools {
    Write-Status "Checking WSL build tools..." Info

    $tools = @("gcc", "make", "pkg-config")
    $missing = @()

    # Check for command-line tools
    foreach ($tool in $tools) {
        $check = wsl bash -c "which $tool 2>/dev/null" -ErrorAction SilentlyContinue
        if ($check) {
            Write-Host "    [+] $tool" -ForegroundColor Green
        }
        else {
            Write-Host "    [-] $tool" -ForegroundColor Yellow
            $missing += $tool
        }
    }

    # Check for GTK3 development libraries using pkg-config
    $gtkCheck = wsl bash -c "pkg-config --exists gtk+-3.0 && echo 'found' 2>/dev/null" -ErrorAction SilentlyContinue
    if ($gtkCheck -match "found") {
        Write-Host "    [+] GTK 3 development libraries" -ForegroundColor Green
    }
    else {
        Write-Host "    [-] GTK 3 development libraries" -ForegroundColor Yellow
        $missing += "libgtk-3-dev"
    }

    if ($missing.Count -gt 0) {
        Write-Status "Missing build tools in WSL" Warning
        Write-Host "  Install with:"
        Write-Host "    wsl bash -c 'sudo apt-get update && sudo apt-get install -y build-essential pkg-config libgtk-3-dev libusb-1.0-0-dev'"
        return $false
    }

    Write-Status "All WSL build tools available" Success
    return $true
}

function Test-Mingw64 {
    Write-Status "Checking MinGW64/MSYS2..." Info

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
        Write-Status "MSYS2 not found" Warning
        Write-Host "  Install from: https://www.msys2.org/"
        Write-Host "  Or use: winget install MSYS2.MSYS2"
        Write-Host ""
        Write-Host "  After installation, open MSYS2 MinGW64 shell and run:"
        Write-Host "    pacman -Syu"
        Write-Host "    pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-toolchain autoconf automake libtool make"
        Write-Host "    pacman -S mingw-w64-x86_64-gtk3 mingw-w64-x86_64-pkg-config"
        return $false
    }

    Write-Host "    [+] MSYS2 found at: $msys2Root" -ForegroundColor Green

    # Check for MinGW64 tools via MSYS2 shell
    $mingw64Bin = Join-Path $msys2Root "mingw64\bin"
    if (-not (Test-Path $mingw64Bin)) {
        Write-Status "MinGW64 bin directory not found" Warning
        Write-Host "  Install MinGW64 toolchain in MSYS2 MinGW64 shell:"
        Write-Host "    pacman -S mingw-w64-x86_64-toolchain"
        return $false
    }

    # Check for essential tools
    $tools = @(
        @{ Name = "gcc"; Path = "gcc.exe" }
        @{ Name = "pkg-config"; Path = "pkg-config.exe" }
        @{ Name = "make"; Path = "make.exe" }
        @{ Name = "autoconf"; Path = "autoconf.exe" }
        @{ Name = "automake"; Path = "automake.exe" }
        @{ Name = "libtool"; Path = "libtool.exe" }
    )

    $missing = @()
    foreach ($tool in $tools) {
        $toolPath = Join-Path $mingw64Bin $tool.Path
        if (Test-Path $toolPath) {
            Write-Host "    [+] $($tool.Name)" -ForegroundColor Green
        }
        else {
            Write-Host "    [-] $($tool.Name)" -ForegroundColor Yellow
            $missing += $tool.Name
        }
    }

    # Check for GTK3 via pkg-config (if pkg-config is available)
    $gtk3Missing = $false
    if (Test-Path (Join-Path $mingw64Bin "pkg-config.exe")) {
        $msys2Shell = Join-Path $msys2Root "msys2_shell.cmd"
        $gtkCheck = & $msys2Shell -mingw64 -defterm -no-start -c "pkg-config --exists gtk+-3.0 && echo 'found' 2>/dev/null" 2>$null
        if ($gtkCheck -match "found") {
            Write-Host "    [+] GTK3 development libraries" -ForegroundColor Green
        }
        else {
            Write-Host "    [-] GTK3 development libraries" -ForegroundColor Yellow
            $gtk3Missing = $true
        }
    }
    else {
        $gtk3Missing = $true
    }

    if ($missing.Count -gt 0 -or $gtk3Missing) {
        Write-Status "Missing MinGW64 build tools" Warning
        
        # Determine which packages to install
        $packagesToInstall = @()
        
        # Check if we need the full toolchain (includes gcc, make, and other tools)
        $needsToolchain = $missing -contains "gcc" -or 
                         ($missing.Count -gt 1 -and ($missing -contains "make" -or $missing -contains "autoconf" -or $missing -contains "automake" -or $missing -contains "libtool"))
        
        if ($needsToolchain) {
            # Install the full toolchain which includes gcc, make, and other build tools
            $packagesToInstall += "mingw-w64-x86_64-toolchain"
        }
        else {
            # Install individual packages for specific missing tools
            $packageMap = @{
                "gcc" = "mingw-w64-x86_64-gcc"
                "make" = "make"
                "autoconf" = "autoconf"
                "automake" = "automake"
                "libtool" = "libtool"
            }
            
            foreach ($toolName in $missing) {
                if ($packageMap.ContainsKey($toolName) -and -not ($packagesToInstall -contains $packageMap[$toolName])) {
                    $packagesToInstall += $packageMap[$toolName]
                }
            }
        }
        
        # Always add pkg-config if missing (needed for GTK3 check)
        if ($missing -contains "pkg-config" -or $gtk3Missing) {
            if (-not ($packagesToInstall -contains "mingw-w64-x86_64-pkg-config")) {
                $packagesToInstall += "mingw-w64-x86_64-pkg-config"
            }
        }
        
        # Add GTK3 if missing
        if ($gtk3Missing) {
            $packagesToInstall += "mingw-w64-x86_64-gtk3"
        }
        
        # Remove duplicates
        $packagesToInstall = $packagesToInstall | Select-Object -Unique
        
        if ($packagesToInstall.Count -gt 0) {
            Write-Host "  Attempting to install missing packages..." -ForegroundColor Cyan
            Write-Host ""
            
            $msys2Shell = Join-Path $msys2Root "msys2_shell.cmd"
            $packageList = $packagesToInstall -join " "
            
            # Install packages using pacman (non-interactive, assume yes to all prompts)
            # Output from pacman will be streamed directly from the MSYS2 shell.
            Write-Host "  Running in MSYS2 MinGW64 shell:" -ForegroundColor Cyan
            Write-Host "    pacman -S --noconfirm $packageList" -ForegroundColor Cyan
            & $msys2Shell -mingw64 -defterm -no-start -c "pacman -S --noconfirm $packageList"
            $pacmanExitCode = $LASTEXITCODE
            
            if ($pacmanExitCode -eq 0) {
                Write-Status "Packages installed successfully" Success
                Write-Host ""
                
                # Re-check the tools after installation
                Write-Host "  Verifying installation..." -ForegroundColor Cyan
                $allInstalled = $true
                foreach ($tool in $tools) {
                    $toolPath = Join-Path $mingw64Bin $tool.Path
                    if (Test-Path $toolPath) {
                        Write-Host "    [+] $($tool.Name)" -ForegroundColor Green
                    }
                    else {
                        Write-Host "    [-] $($tool.Name)" -ForegroundColor Yellow
                        $allInstalled = $false
                    }
                }
                
                # Re-check GTK3
                if (Test-Path (Join-Path $mingw64Bin "pkg-config.exe")) {
                    $gtkCheck = & $msys2Shell -mingw64 -defterm -no-start -c "pkg-config --exists gtk+-3.0 && echo 'found' 2>/dev/null" 2>$null
                    if ($gtkCheck -match "found") {
                        Write-Host "    [+] GTK3 development libraries" -ForegroundColor Green
                    }
                    else {
                        Write-Host "    [-] GTK3 development libraries" -ForegroundColor Yellow
                        $allInstalled = $false
                    }
                }
                
                if ($allInstalled) {
                    Write-Status "All MinGW64 build tools available" Success
                    return $true
                }
                else {
                    Write-Status "Some packages may still be missing. Please install manually." Warning
                    return $false
                }
            }
            else {
                Write-Status "Failed to install packages automatically" Error
                Write-Host "  Install manually in MSYS2 MinGW64 shell:"
                Write-Host "    pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-toolchain autoconf automake libtool make"
                Write-Host "    pacman -S mingw-w64-x86_64-gtk3 mingw-w64-x86_64-pkg-config"
                return $false
            }
        }
        else {
            Write-Host "  Install in MSYS2 MinGW64 shell:"
            Write-Host "    pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-toolchain autoconf automake libtool make"
            Write-Host "    pacman -S mingw-w64-x86_64-gtk3 mingw-w64-x86_64-pkg-config"
            return $false
        }
    }

    Write-Status "All MinGW64 build tools available" Success
    return $true
}

function Test-VisualStudio {
    Write-Status "Checking Visual Studio or VS Code..." Info

    $vsFound = $false

    # Check for VS Code
    if (Test-CommandExists "code") {
        Write-Status "Visual Studio Code found" Success
        $vsFound = $true
    }

    # Check for Visual Studio
    $vsPath = "C:\Program Files\Microsoft Visual Studio\*\*\Common7\IDE\devenv.exe"
    if (Test-Path $vsPath) {
        Write-Status "Visual Studio found" Success
        $vsFound = $true
    }

    if (-not $vsFound) {
        Write-Status "No IDE found (VS Code recommended)" Warning
        Write-Host "  Install VS Code: https://code.visualstudio.com/download"
        Write-Host "  Or use: winget install Microsoft.VisualStudioCode"
        Write-Host "  Recommended extensions:"
        Write-Host "    - C# (powered by OmniSharp)"
        Write-Host "    - Remote - WSL"
        Write-Host "    - PowerShell"
    }

    return $vsFound
}

function Test-GitConfig {
    Write-Status "Checking Git configuration..." Info

    $userName = git config --global user.name 2>&1
    $userEmail = git config --global user.email 2>&1

    if ($userName -and $userEmail) {
        Write-Status "Git user: $userName ($userEmail)" Success
        return $true
    }
    else {
        Write-Status "Git user not configured" Warning
        Write-Host "  Configure with:"
        Write-Host "    git config --global user.name 'Your Name'"
        Write-Host "    git config --global user.email 'your.email@example.com'"
        return $false
    }
}

function Test-ProjectStructure {
    Write-Status "Checking project structure..." Info

    # Script is in project root, so use PSScriptRoot directly
    $projectRoot = $PSScriptRoot
    $required = @(
        "src\C64OS.IDE.App\C64OS.IDE.App.csproj"
        "src\C64OS.IDE.Core\C64OS.IDE.Core.csproj"
        "build\Build.cs"
        "build\vice"
        ".github\workflows"
    )

    $allFound = $true
    foreach ($path in $required) {
        $fullPath = Join-Path $projectRoot $path
        if (Test-Path $fullPath) {
            Write-Host "    [+] $path" -ForegroundColor Green
        }
        else {
            Write-Host "    [-] $path" -ForegroundColor Red
            $allFound = $false
        }
    }

    if ($allFound) {
        Write-Status "Project structure valid" Success
    }
    else {
        Write-Status "Project structure incomplete" Error
    }

    return $allFound
}

function Show-Summary {
    param([hashtable]$Results)

    Write-Header "DEPENDENCY CHECK SUMMARY"

    $passed = ($Results.Values | Where-Object { $_ -eq $true }).Count
    $failed = ($Results.Values | Where-Object { $_ -eq $false }).Count
    $total = $Results.Count

    Write-Host "Results: " -NoNewline
    Write-Host "$passed/$total" -ForegroundColor Green -NoNewline
    Write-Host " passed"

    if ($failed -gt 0) {
        Write-Host "Failed: " -NoNewline
        Write-Host "$failed" -ForegroundColor Red
        Write-Host ""
        Write-Status "Some dependencies are missing. Install them using the instructions above." Error
        Write-Host ""
        Write-Host "Common installation methods:"
        Write-Host "  - winget (Windows Package Manager): winget install [package]"
        Write-Host "  - chocolatey: choco install [package]"
        Write-Host "  - Direct download from official websites"
        Write-Host ""
        return $false
    }
    else {
        Write-Host ""
        Write-Status "All dependencies are installed and operational!" Success
        Write-Host ""
        Write-Host "Next steps:"
        Write-Host "  1. Review build/vice/README.md for VICE build instructions"
        Write-Host "  2. Pull VICE from SVN: third_party\vice\svn-instructions.txt"
        Write-Host "  3. Run: .\build\vice\apply_vice_patches.sh (in WSL)"
        Write-Host "  4. Build the project: .\build.ps1 or .\build.sh"
        Write-Host ""
        return $true
    }
}

function Main {
    Clear-Host
    Write-Header "C64OS IDE - DEPENDENCY CHECK"

    Write-Host "PowerShell Version: " -NoNewline
    Write-Host $PSVersionTable.PSVersion -ForegroundColor Green
    Write-Host ""

    $results = @{}

    Write-Header "CHECKING CORE DEPENDENCIES"
    $results["Git"] = Test-Git
    $results[".NET SDK"] = Test-DotnetSdk

    Write-Header "CHECKING BUILD TOOLS"
    $results["WSL 2"] = Test-Wsl
    if ($results["WSL 2"]) {
        $results["WSL Build Tools"] = Test-WslBuildTools
    }
    else {
        Write-Status "Skipping WSL build tools check (WSL not installed)" Warning
        $results["WSL Build Tools"] = $false
    }

    $results["MinGW64/MSYS2"] = Test-Mingw64

    $results["Subversion"] = Test-Svn

    Write-Header "CHECKING IDE"
    $results["IDE (VS Code/VS)"] = Test-VisualStudio

    Write-Header "CHECKING CONFIGURATION"
    $results["Git Configuration"] = Test-GitConfig

    Write-Header "CHECKING PROJECT STRUCTURE"
    $results["Project Structure"] = Test-ProjectStructure

    Write-Header "CHECKING OPTIONAL"
    if (Test-CommandExists "code") {
        Write-Status "VS Code extensions recommended:" Info
        Write-Host "  code --install-extension ms-dotnettools.csharp"
        Write-Host "  code --install-extension ms-vscode-remote.remote-wsl"
        Write-Host "  code --install-extension ms-vscode.powershell"
    }

    # Show summary and return status
    $success = Show-Summary -Results $results

    if ($success) {
        exit 0
    }
    else {
        exit 1
    }
}

# Run main function
Main
