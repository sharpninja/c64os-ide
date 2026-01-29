# Build Targets Reference

## Quick Build Commands

### Standard Build (Restore + Compile Solution)
```bash
./build.cmd
# or
./build.cmd Compile
```

### Build VICE Only (Windows)
```bash
./build.cmd BuildVice --Platform Windows
```

### Build VICE for Both Platforms
```bash
./build.cmd BuildVice --Platform Both
```

### Build VICE for Linux Only
```bash
./build.cmd BuildVice --Platform Linux
```

## **RebuildAll** - Complete Clean Rebuild

The `RebuildAll` target performs a complete clean rebuild of everything:

### What It Does
1. **Cleans entire VICE artifacts** directory
2. **Cleans solution artifacts** (publish & package directories)
3. **Builds VICE for Windows** (MinGW64 with all dependencies and DLLs)
4. **Builds VICE for Linux** (native Linux build via WSL/bash)
5. **Restores** solution dependencies
6. **Builds solution** for Windows (win-x64 runtime)
7. **Builds solution** for Linux (linux-x64 runtime)

### Usage
```bash
./build.cmd RebuildAll
```

### Expected Output
```
========================================
REBUILD ALL - Clean & Full Build
========================================

Cleaning VICE artifacts directory...
✓ Cleaned: E:\github\C64OS_IDE\artifacts\vice

Cleaning solution artifacts directory...
✓ Cleaned: E:\github\C64OS_IDE\artifacts\publish and E:\github\C64OS_IDE\artifacts\package

Building VICE for Windows...
  [VICE Windows build process...]

Building VICE for Linux...
  [VICE Linux build process...]

Restoring solution dependencies...
  [Restore process...]

Building solution for Windows...
  [.NET build for win-x64...]

Building solution for Linux...
  [.NET build for linux-x64...]

========================================
✓ REBUILD ALL COMPLETED SUCCESSFULLY
========================================
```

### Estimated Time
- VICE Windows build: ~40 seconds
- VICE Linux build: ~90 seconds (via WSL)
- Solution restore: ~10 seconds
- Solution Windows build: ~30 seconds
- Solution Linux build: ~30 seconds
- **Total**: ~3-4 minutes

### When to Use RebuildAll

Use `RebuildAll` when:
- Starting a fresh build from scratch
- Making changes to VICE source code
- Updating build scripts or configuration
- Preparing for release/testing
- Ensuring clean state across all platforms
- Resolving build inconsistencies

### Other Targets

| Target | Purpose |
|--------|---------|
| `Restore` | Restore NuGet dependencies |
| `Compile` (default) | Build solution only |
| `Test` | Run unit tests |
| `BuildVice` | Build VICE for specified platform(s) |
| `BuildViceMinGW64` | Build VICE with MinGW64 for Windows |
| `PackWindows` | Create Windows distribution package |
| `PackLinux` | Create Linux distribution package |
| `Pack` | Pack for both platforms |
| `Publish` | Publish packages to release artifacts |

### Build Architecture

**RebuildAll Execution Flow:**
```
RebuildAll
├── Delete artifacts/vice/
├── Delete artifacts/publish/
├── Delete artifacts/package/
├── BuildViceForWindows()
│   ├── build-mingw64.ps1
│   ├── Compile with MinGW64 GCC
│   ├── Copy 11 executables
│   ├── Copy 64 DLL dependencies
│   └── SetupViceWindowsConfig()
│       ├── Copy vicerc to %APPDATA%\vice\
│       ├── Copy ROMs to config directory
│       └── Copy TTF fonts to config directory
├── BuildViceForLinux()
│   ├── build.sh (via WSL)
│   ├── Compile with native GCC
│   └── Create Linux artifacts
├── DotNetRestore()
├── DotNetBuild(win-x64)
└── DotNetBuild(linux-x64)
```

### Output Locations After RebuildAll

**Windows VICE:**
- Executables: `artifacts/vice/win-x64/*.exe` (11 files)
- DLLs: `artifacts/vice/win-x64/*.dll` (64 files)
- ROMs: `artifacts/vice/win-x64/data/{C64,C128,...}/*.bin`
- Fonts: `artifacts/vice/win-x64/data/common/*.ttf`
- Config: `%APPDATA%\vice\` (Windows user directory)

**Linux VICE:**
- Executables: `artifacts/vice/linux-x64/vice/*`
- ROMs: `artifacts/vice/linux-x64/data/{C64,C128,...}/*.bin`
- Config: `~/.config/vice/` (user home directory)

**Solution:**
- Windows: `artifacts/publish/win-x64/`
- Linux: `artifacts/publish/linux-x64/`
- Packages: `artifacts/package/win-x64/*.zip`, `artifacts/package/linux-x64/*.zip`

### Troubleshooting

**Build fails during VICE Windows compilation:**
- Ensure MSYS2/MinGW64 is installed
- Check `C:\msys64\mingw64` exists
- Verify bash and gcc are in PATH

**Build fails during VICE Linux compilation:**
- Ensure bash/WSL is available
- Verify build.sh has proper line endings
- Check WSL has required build tools (gcc, make, etc.)

**Build fails during solution compilation:**
- Run `./build.cmd Restore` first
- Check .NET SDK 9.0+ is installed
- Verify project files are syntactically correct

### Manual Clean (If Needed)
```bash
# Clean only VICE artifacts
Remove-Item -Path artifacts/vice -Recurse -Force

# Clean only solution artifacts
Remove-Item -Path artifacts/publish -Recurse -Force
Remove-Item -Path artifacts/package -Recurse -Force

# Clean everything
Remove-Item -Path artifacts -Recurse -Force
```

### Related Documentation
- [VICE Build System](build/vice/README.md)
- [VICE ROM and Font Setup](VICE_ROM_FONT_SETUP.md)
- [VICE Console Logging](VICE_CONSOLE_LOGGING.md)
- [VICE Default Configuration](VICE_DEFAULT_CONFIG_SETUP.md)
