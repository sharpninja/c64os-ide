# Build System Platform Flags

The C64OS IDE build system supports building for Windows, Linux, or both platforms using the `--Platform` parameter.

## Usage

### Default (Windows Only)

```bash
# Build VICE for Windows (default)
nuke BuildVice

# Or explicitly
nuke BuildVice --Platform Windows
```

### Linux Only

```bash
# Build VICE for Linux
nuke BuildVice --Platform Linux
```

### Both Platforms

```bash
# Build VICE for both Windows and Linux
nuke BuildVice --Platform Both
```

## Build Targets

### BuildVice

Builds VICE emulator for the specified platform(s).

**Examples:**

```bash
# Windows only (default)
nuke BuildVice
nuke BuildVice --Platform Windows

# Linux only
nuke BuildVice --Platform Linux

# Both platforms
nuke BuildVice --Platform Both
```

**What it does:**
- Windows: Uses `build/vice/build-mingw64.ps1` to build with MinGW64
- Linux: Uses `build/vice/build.sh` to build with native tools
- Both: Executes both build scripts

**Output locations:**
- Windows: `artifacts/vice/win-x64/`
- Linux: `artifacts/vice/linux-x64/`

### Pack

Creates distribution packages for the specified platform(s).

**Examples:**

```bash
# Windows only (default)
nuke Pack
nuke Pack --Platform Windows

# Linux only
nuke Pack --Platform Linux

# Both platforms
nuke Pack --Platform Both
```

**What it does:**
- Calls `PackWindows` if Platform is Windows or Both
- Calls `PackLinux` if Platform is Linux or Both
- Each pack target:
  - Publishes the C# app for the target runtime
  - Copies VICE artifacts if available
  - Creates a ZIP file

**Output locations:**
- Windows: `artifacts/package/win-x64/C64OS.IDE-win-x64.zip`
- Linux: `artifacts/package/linux-x64/C64OS.IDE-linux-x64.zip`

### PackWindows / PackLinux

Individual pack targets that respect the Platform parameter.

**Examples:**

```bash
# Only run if Platform is Windows or Both
nuke PackWindows --Platform Windows

# Only run if Platform is Linux or Both
nuke PackLinux --Platform Linux
```

### Publish

Publishes packages to release artifacts (placeholder for upload logic).

**Examples:**

```bash
nuke Publish --Platform Windows
nuke Publish --Platform Linux
nuke Publish --Platform Both
```

## Platform Parameter Values

| Value | Description | Builds |
|-------|-------------|--------|
| `Windows` | Build for Windows only (default) | MinGW64 build |
| `Linux` | Build for Linux only | Native Linux build |
| `Both` | Build for both platforms | MinGW64 + Linux |

## Command Line Examples

### Full Build Pipeline

```bash
# Build everything for Windows (default)
nuke BuildVice Pack

# Build everything for Linux
nuke BuildVice Pack --Platform Linux

# Build everything for both platforms
nuke BuildVice Pack --Platform Both
```

### Build with Configuration

```bash
# Release build for Windows (default)
nuke BuildVice --Platform Windows --Configuration Release

# Debug build for Linux
nuke BuildVice --Platform Linux --Configuration Debug

# Release build for both
nuke BuildVice --Platform Both --Configuration Release
```

### CI/CD Usage

```bash
# Windows CI pipeline
nuke Restore Compile BuildVice Pack --Platform Windows

# Linux CI pipeline
nuke Restore Compile BuildVice Pack --Platform Linux

# Full cross-platform build
nuke Restore Compile BuildVice Pack --Platform Both
```

## PowerShell Scripts

### Windows (PowerShell)

```powershell
# Build VICE for Windows
.\build.ps1 BuildVice

# Build VICE for both platforms
.\build.ps1 BuildVice --Platform Both

# Full pipeline
.\build.ps1 BuildVice Pack --Platform Windows
```

### Linux (Bash)

```bash
# Build VICE for Linux
./build.sh BuildVice --Platform Linux

# Build VICE for both platforms
./build.sh BuildVice --Platform Both

# Full pipeline
./build.sh BuildVice Pack --Platform Linux
```

## Build Requirements

### Windows

**Required for Windows builds:**
- MSYS2/MinGW64 installed at `C:\msys64`
- PowerShell 7+ (`pwsh`)
- .NET 9 SDK

**Check:**
```powershell
# Verify MSYS2
Test-Path C:\msys64\mingw64\bin\gcc.exe

# Verify PowerShell 7+
pwsh --version

# Verify .NET
dotnet --version
```

### Linux

**Required for Linux builds:**
- GCC/G++ (build-essential)
- Autotools (autoconf, automake, libtool)
- GTK3 development libraries
- PulseAudio development libraries
- .NET 9 SDK

**Check:**
```bash
# Verify GCC
gcc --version

# Verify autotools
autoconf --version

# Verify GTK3
pkg-config --modversion gtk+-3.0

# Verify .NET
dotnet --version
```

### Cross-Platform (Both)

**Required for building both:**
- All Windows requirements (on Windows host)
- WSL2 with all Linux requirements (for Linux build on Windows)
- Or: Separate Windows and Linux build machines

## Output Structure

After building with `--Platform Both`:

```
artifacts/
├── vice/
│   ├── win-x64/          # Windows VICE build
│   │   ├── x64sc.exe
│   │   ├── *.dll
│   │   └── data/
│   └── linux-x64/        # Linux VICE build
│       └── usr/
│           ├── bin/
│           │   └── x64sc
│           └── share/
│               └── vice/
├── publish/
│   ├── win-x64/          # Windows app publish
│   └── linux-x64/        # Linux app publish
└── package/
    ├── win-x64/
    │   └── C64OS.IDE-win-x64.zip
    └── linux-x64/
        └── C64OS.IDE-linux-x64.zip
```

## Troubleshooting

### Platform Not Building

**Problem:** Platform doesn't build when using `--Platform Both`

**Solution:** Check build requirements for that platform are met

### VICE Source Not Found

**Problem:** `VICE source directory not found: third_party/vice/vice`

**Solution:** 
```bash
# The build scripts will auto-checkout VICE from SVN
# But you can manually checkout:
cd third_party
mkdir -p vice
cd vice
svn checkout https://svn.code.sf.net/p/vice-emu/code/trunk vice
```

### Build Script Not Found

**Problem:** `MinGW64 build script not found` or `Linux build script not found`

**Solution:** Verify scripts exist:
- Windows: `build/vice/build-mingw64.ps1`
- Linux: `build/vice/build.sh`

### Wrong Platform Selected

**Problem:** Built for wrong platform

**Solution:** Explicitly specify `--Platform`:
```bash
nuke BuildVice --Platform Linux  # Force Linux
nuke BuildVice --Platform Windows # Force Windows
```

## Advanced Usage

### Skip Specific Platforms

If you want to run the full pipeline but skip one platform:

```bash
# Build both, but only pack Windows
nuke BuildVice --Platform Both
nuke PackWindows
```

### Override Build Script

If you need custom build behavior, modify the build scripts:
- Windows: Edit `build/vice/build-mingw64.ps1`
- Linux: Edit `build/vice/build.sh`

### Custom Parallel Jobs

The build system uses all CPU cores by default. To override:

Edit `Build.cs` and change:
```csharp
var jobs = Environment.ProcessorCount;  // Default
// to
var jobs = 8;  // Fixed number
```

## Quick Reference

| Task | Command |
|------|---------|
| Build VICE (Windows) | `nuke BuildVice` |
| Build VICE (Linux) | `nuke BuildVice --Platform Linux` |
| Build VICE (Both) | `nuke BuildVice --Platform Both` |
| Pack (Windows) | `nuke Pack` |
| Pack (Linux) | `nuke Pack --Platform Linux` |
| Pack (Both) | `nuke Pack --Platform Both` |
| Full Pipeline (Windows) | `nuke BuildVice Pack` |
| Full Pipeline (Linux) | `nuke BuildVice Pack --Platform Linux` |
| Full Pipeline (Both) | `nuke BuildVice Pack --Platform Both` |

## Summary

- ✅ **Default Platform:** Windows (no flag needed)
- ✅ **Linux Support:** Use `--Platform Linux`
- ✅ **Cross-Platform:** Use `--Platform Both`
- ✅ **Smart Filtering:** Pack targets only run for selected platforms
- ✅ **CI-Friendly:** Easy to specify platform in pipeline scripts

The build system is designed to make cross-platform builds easy while defaulting to Windows for compatibility with most development environments.

---

**Last Updated:** 2026-01-28  
**Version:** 1.0.0
