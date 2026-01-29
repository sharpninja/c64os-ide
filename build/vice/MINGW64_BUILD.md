# VICE MinGW64 Build Setup for Windows

This guide covers building VICE natively on Windows using MinGW64/MSYS2.

## Prerequisites

### 1. Install MSYS2

Download and install MSYS2 from: https://www.msys2.org/

**Default installation path**: `C:\msys64`

### 2. Update MSYS2

Open **MSYS2 MSYS** shell and run:

```bash
pacman -Syu
```

Close the terminal when prompted, then reopen and run again:

```bash
pacman -Syu
```

### 3. Install Build Tools

Open **MSYS2 MinGW64** shell (important: use MinGW64, not MSYS) and run:

```bash
# Essential build tools
pacman -S mingw-w64-x86_64-gcc
pacman -S mingw-w64-x86_64-toolchain
pacman -S autoconf automake libtool make

# GTK3 and dependencies
pacman -S mingw-w64-x86_64-gtk3
pacman -S mingw-w64-x86_64-pkg-config
pacman -S mingw-w64-x86_64-glib2
pacman -S mingw-w64-x86_64-cairo
pacman -S mingw-w64-x86_64-pango

# Additional libraries
pacman -S mingw-w64-x86_64-libpng
pacman -S mingw-w64-x86_64-libjpeg-turbo
pacman -S mingw-w64-x86_64-glew
```

**All-in-one command**:
```bash
pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-toolchain autoconf automake libtool make mingw-w64-x86_64-gtk3 mingw-w64-x86_64-pkg-config mingw-w64-x86_64-glib2 mingw-w64-x86_64-cairo mingw-w64-x86_64-pango mingw-w64-x86_64-libpng mingw-w64-x86_64-libjpeg-turbo mingw-w64-x86_64-glew
```

### 4. Verify Installation

In MSYS2 MinGW64 shell:

```bash
gcc --version
pkg-config --version
autoconf --version
```

All should report their versions successfully.

## Building VICE

### Option 1: Using NUKE Build System

From Windows PowerShell:

```powershell
# Build VICE for Windows
.\build.cmd BuildVice --TargetRid win10-x64
```

The NUKE build system will automatically:
1. Detect and launch MSYS2 MinGW64 environment
2. Run the MinGW64 build script
3. Copy binaries to `artifacts/vice/win-x64/`
4. Include required DLLs

### Option 2: Manual Build (PowerShell)

```powershell
# From repository root
.\build\vice\build-mingw64.ps1 `
    -SourceDir "third_party/vice/vice" `
    -DestDir "artifacts/vice/win-x64" `
    -Jobs 8
```

### Option 3: Direct MSYS2 Build

Open **MSYS2 MinGW64** shell:

```bash
cd /c/github/C64OS_IDE  # Adjust path to your repo
./build/vice/build-mingw64.sh third_party/vice/vice artifacts/vice/win-x64 8
```

## Build Output

### Compiled Binaries

The build produces the following `.exe` files in the destination directory:

- `x64sc.exe` - Commodore 64 emulator
- `x128.exe` - Commodore 128 emulator
- `xvic.exe` - VIC-20 emulator
- `xpet.exe` - PET emulator
- `xplus4.exe` - Plus/4 emulator
- `xcbm2.exe` - CBM-II emulator
- `xcbm5x0.exe` - CBM-II 5x0 series
- `c1541.exe` - Disk image utility
- And more...

### Runtime Dependencies

The build script automatically copies required MinGW64 DLLs:

- **Core runtime**: `libgcc_s_seh-1.dll`, `libstdc++-6.dll`, `libwinpthread-1.dll`
- **GTK3**: `libgtk-3-0.dll`, `libgdk-3-0.dll`, `libcairo-2.dll`, `libpango-1.0-0.dll`
- **Graphics**: `libgdk_pixbuf-2.0-0.dll`, `libpng16-16.dll`, `libjpeg-8.dll`
- **Support libraries**: `libglib-2.0-0.dll`, `libharfbuzz-0.dll`, `libfreetype-6.dll`, etc.

### Data Files

VICE data files (ROMs, palettes, keymap files) are copied to `{DestDir}/data/`.

## Architecture Comparison

### WSL Build (Linux)
- **Environment**: Windows Subsystem for Linux (Ubuntu)
- **Output**: Linux ELF binaries
- **Dependencies**: System GTK3 libraries
- **Use Case**: Linux deployment, WSL integration
- **Build Time**: ~21 minutes

### MinGW64 Build (Windows Native)
- **Environment**: MSYS2 MinGW64 (native Windows)
- **Output**: Windows PE executables (.exe)
- **Dependencies**: Bundled MinGW64 DLLs
- **Use Case**: Native Windows deployment
- **Build Time**: ~18-25 minutes

## Troubleshooting

### "MSYS2 not found"

**Error**: Script cannot locate MSYS2 installation.

**Solution**:
- Ensure MSYS2 is installed in a standard location
- Modify `$msys2Paths` array in `build-mingw64.ps1` to include your path

### "configure: error: no acceptable C compiler found"

**Error**: GCC not installed or not in PATH.

**Solution**:
```bash
pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-toolchain
```

### "Package 'gtk+-3.0' not found"

**Error**: GTK3 development files missing.

**Solution**:
```bash
pacman -S mingw-w64-x86_64-gtk3 mingw-w64-x86_64-pkg-config
```

### "Build failed during make"

**Common causes**:
1. Missing dependencies - rerun package installation
2. Corrupt source files - delete `third_party/vice/vice` and re-checkout
3. Path issues - ensure no spaces in repository path

**Debug steps**:
```bash
# In MSYS2 MinGW64 shell
cd /c/github/C64OS_IDE/third_party/vice/vice
make clean
./configure --enable-gtk3ui --disable-sdl2ui
make -j1  # Single-threaded for better error messages
```

### DLL Dependencies Missing

**Error**: `.exe` files don't run due to missing DLLs.

**Solution**: Use Dependency Walker or `ldd` in MSYS2:
```bash
ldd x64sc.exe | grep "not found"
```

Copy missing DLLs from `/mingw64/bin` to the output directory.

## NUKE Build Integration

The NUKE build system automatically:

1. **Detects build environment**:
   - Windows: Uses `build-mingw64.ps1` → launches MSYS2
   - Linux: Uses `build.sh` → runs natively or via WSL

2. **Mirrors output**:
   - All build output is displayed in real-time
   - Errors are highlighted appropriately

3. **Path conversion**:
   - Automatically converts Windows paths to MSYS2 format
   - Handles `/c/path` and `/mnt/c/path` conversions

## Performance Tips

### Parallel Builds

The `-Jobs` parameter controls parallel compilation:

```powershell
# Use all cores (default)
.\build\vice\build-mingw64.ps1 -Jobs $env:NUMBER_OF_PROCESSORS

# Limit to 4 cores
.\build\vice\build-mingw64.ps1 -Jobs 4
```

### Incremental Builds

After the first build, subsequent builds are much faster:

```bash
# In MSYS2 MinGW64 shell
cd third_party/vice/vice
make -j8  # Only recompiles changed files
```

### Clean Build

Force a complete rebuild:

```bash
cd third_party/vice/vice
make clean
./configure --enable-gtk3ui --disable-sdl2ui
make -j8
```

## Integration with VS Code

### Build Task

Add to `.vscode/tasks.json`:

```json
{
    "label": "build-vice-mingw64",
    "type": "shell",
    "command": "pwsh",
    "args": [
        "-File",
        "${workspaceFolder}/build/vice/build-mingw64.ps1",
        "-SourceDir", "third_party/vice/vice",
        "-DestDir", "artifacts/vice/win-x64"
    ],
    "problemMatcher": [],
    "group": "build"
}
```

### Launch Configuration

The existing VICE debugger configuration works with MinGW64 binaries using `gdb.exe` from MSYS2.

## Comparison: WSL vs MinGW64

| Feature | WSL Build | MinGW64 Build |
|---------|-----------|---------------|
| **Platform** | Linux (Ubuntu in WSL) | Windows Native |
| **Output** | ELF binaries | PE executables (.exe) |
| **Deployment** | Linux, WSL only | Windows (standalone) |
| **Dependencies** | System libraries | Bundled DLLs |
| **Size** | Smaller binaries | Larger (includes DLLs) |
| **Performance** | Native Linux speed | Native Windows speed |
| **Debugging** | GDB via WSL pipe | GDB or MSVC debugger |
| **Distribution** | Requires WSL | Fully portable |

## Recommended Workflow

1. **Development**: Use WSL build for faster iteration
2. **Testing**: Test both WSL and MinGW64 builds
3. **Release**: Use MinGW64 build for Windows distribution
4. **CI/CD**: Build both variants in parallel

## Next Steps

- ✅ MinGW64 build scripts created
- ✅ NUKE integration with output mirroring
- ✅ Automatic DLL bundling
- ⏸️ Code signing for Windows executables
- ⏸️ Create installer (WiX or NSIS)
- ⏸️ Automated testing on Windows native

---

**Last Updated**: January 28, 2026
**VICE Version**: SVN trunk
**MinGW64 Version**: GCC 13.x+
**Status**: Production-ready
