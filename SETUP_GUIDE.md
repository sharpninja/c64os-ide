# Local Setup Guide - C64OS IDE

## Quick Start

Run the setup validation script to check all dependencies:

```powershell
# From the project root (with explicit flags for consistency)
powershell -NoProfile -ExecutionPolicy Bypass -File .\Setup-C64OS-IDE.ps1
```

Or simply:
```powershell
.\Setup-C64OS-IDE.ps1
```

**Note:** The script will automatically check for PowerShell 7 and install it via winget if missing. It will then relaunch itself in PowerShell 7 to complete the setup validation.

The script requires Administrator privileges for installing PowerShell 7 (if needed) and will check for:
- Core dependencies (.NET SDK, Git)
- Build tools (WSL 2, compilers, build utilities)
- IDE setup (Visual Studio Code or Visual Studio)
- Project structure integrity

## System Requirements

### Minimum
- Windows 10 (version 19041 or later) or Windows 11
- PowerShell 5.0+
- 4 GB RAM
- 20 GB free disk space

### Recommended
- Windows 11
- PowerShell 7.0+ (Core)
- 8+ GB RAM
- 50 GB free disk space for VICE build artifacts

## Required Dependencies

### 1. .NET SDK 7.0+ (Required)
Used for building C# projects (IDE application)

**Check Installation:**
```powershell
dotnet --version
```

**Installation:**
- Windows Package Manager: `winget install Microsoft.DotNet.SDK.8`
- Chocolatey: `choco install dotnet-sdk`
- Direct: https://dotnet.microsoft.com/download

**Verify:**
```powershell
dotnet --version  # Should show 7.0 or higher
```

### 2. Git (Required)
Version control system

**Check Installation:**
```powershell
git --version
```

**Installation:**
- Windows Package Manager: `winget install Git.Git`
- Chocolatey: `choco install git`
- Direct: https://git-scm.com/download/win

**Configure:**
```powershell
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### 3. WSL 2 (Required for VICE build)
Windows Subsystem for Linux - provides Linux build environment

**Check Installation:**
```powershell
wsl --version
wsl --list
```

**Installation:**
```powershell
wsl --install
# Then restart your computer
```

**Detailed Instructions:**
https://learn.microsoft.com/en-us/windows/wsl/install

**Verify Linux Distribution:**
```powershell
wsl bash -c "uname -a"
```

### 4. WSL Build Tools (Required for VICE compilation)
GCC, Make, pkg-config, and GTK3 development libraries

**Install in WSL:**
```bash
wsl bash -c "sudo apt-get update && sudo apt-get install -y build-essential pkg-config libgtk-3-dev libusb-1.0-0-dev"
```

**Verify Installation:**
```bash
wsl bash -c "which gcc make pkg-config"
```

### 5. Subversion/Git-SVN (Required for VICE source)
Version control for VICE emulator source code from SourceForge

**Option A: Git-SVN (via Git)**
Usually included with Git installation:
```powershell
git svn --version
```

**Option B: Subversion (standalone)**
- Windows Package Manager: `winget install Apache.Subversion`
- Chocolatey: `choco install svn`
- Direct: https://visualsvn.com/downloads/

**Check Installation:**
```powershell
svn --version
```

## Optional But Recommended

### Visual Studio Code
IDE for editing code and managing WSL development

**Installation:**
- Windows Package Manager: `winget install Microsoft.VisualStudioCode`
- Direct: https://code.visualstudio.com/download

**Recommended Extensions:**
```powershell
code --install-extension ms-dotnettools.csharp
code --install-extension ms-vscode-remote.remote-wsl
code --install-extension ms-vscode.powershell
code --install-extension ms-vscode.makefile-tools
```

### Visual Studio 2022 (Community Edition Free)
Full IDE for C# development

**Installation:**
- Direct: https://visualstudio.microsoft.com/downloads/
- Winget: `winget install Microsoft.VisualStudio.2022.Community`

**Install these workloads:**
- .NET desktop development
- Desktop development with C++
- Linux development with C++

## Installation Methods

### Windows Package Manager (Recommended)
```powershell
# Install multiple packages
winget install Microsoft.DotNet.SDK.8
winget install Git.Git
winget install Microsoft.VisualStudioCode
winget install Apache.Subversion
```

### Chocolatey
```powershell
choco install dotnet-sdk git vscode svn
```

### Manual Installation
Download installers from official websites and run them.

## Verification Steps

### 1. Verify .NET SDK
```powershell
dotnet --version
dotnet --info
```

### 2. Verify Git
```powershell
git --version
git config --list  # Should show user.name and user.email
```

### 3. Verify WSL 2
```powershell
wsl --version
wsl bash -c "uname -a"
```

### 4. Verify Build Tools
```powershell
# In WSL
wsl bash -c "gcc --version"
wsl bash -c "make --version"
wsl bash -c "pkg-config --version"
wsl bash -c "dpkg -l | grep libgtk-3"
```

### 5. Verify VICE Prerequisites
```powershell
wsl bash -c "which autoconf automake libtool"
```

## Troubleshooting

### Issue: WSL Installation Fails
**Solution:**
1. Ensure Windows is up to date: `winget upgrade`
2. Enable Virtual Machine Platform: Press Win+R, type `OptionalFeatures`, enable "Virtual Machine Platform"
3. Run PowerShell as Administrator
4. Try again: `wsl --install`

### Issue: .NET SDK Not Found
**Solution:**
1. Close all PowerShell windows
2. Reinstall: `winget install Microsoft.DotNet.SDK.8`
3. Restart computer
4. Verify: `dotnet --version`

### Issue: Git Not Recognized
**Solution:**
1. Restart PowerShell after Git installation
2. Check PATH: `$env:Path`
3. Manually add if needed: `[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Program Files\Git\cmd", "User")`

### Issue: WSL Linux Tools Missing
**Solution:**
```bash
wsl bash -c "sudo apt-get update"
wsl bash -c "sudo apt-get install -y build-essential pkg-config libgtk-3-dev"
```

### Issue: Permission Denied in WSL
**Solution:**
```bash
wsl bash -c "sudo chown -R $USER:$USER /mnt/e/github/C64OS_IDE"
```

## Next Steps After Setup

1. **Pull VICE Source:**
   ```bash
   cd third_party/vice
   cat svn-instructions.txt  # For detailed instructions
   ```

2. **Apply VICE Patches:**
   ```bash
   cd build/vice
   ./apply_vice_patches.sh
   ```

3. **Build VICE:**
   ```bash
   ./build.sh  # From WSL
   ```

4. **Build IDE:**
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
   ```

   Or simply:
   ```powershell
   .\build.ps1
   ```

## Additional Resources

- [C64OS IDE Documentation](./README.md)
- [VICE Build Patches](./build/vice/README.md)
- [VICE Homepage](http://vice-emu.sourceforge.net/)
- [WSL Documentation](https://learn.microsoft.com/en-us/windows/wsl/)
- [.NET Documentation](https://learn.microsoft.com/en-us/dotnet/)

## Getting Help

If you encounter issues:

1. Run `.\Setup-C64OS-IDE.ps1` with error details
2. Check [VICE_PATCHES_SUMMARY.md](./VICE_PATCHES_SUMMARY.md)
3. Review build logs in build.log
4. Check [GITHUB_SETUP.md](./GITHUB_SETUP.md) for repository issues

## Summary

All dependencies should be installed before attempting to build. Run the setup script regularly to catch any missing or outdated components.
