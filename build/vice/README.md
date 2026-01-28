# Build VICE (MSYS2 / mingw64) - With Build Fix Patches

This directory contains helper scripts, patches, and notes for building VICE for Windows (mingw64) and Linux.

## VICE Build Patches

After pulling from the SVN repository, you must apply the build fix patches. See **VICE Build Patches** section below.

MSYS2 (Windows - MinGW64) notes
- Run from the "MSYS2 MinGW 64-bit" shell.
- Keep pacman up to date: `pacman -Syu`.
- Recommended pacman packages (install as needed):
  - base-devel, mingw-w64-x86_64-toolchain
  - mingw-w64-x86_64-autoconf, automake, libtool, pkg-config, cmake
  - mingw-w64-x86_64-SDL2, mingw-w64-x86_64-SDL2_image, mingw-w64-x86_64-SDL2_mixer
  - mingw-w64-x86_64-libpng, mingw-w64-x86_64-libjpeg-turbo, mingw-w64-x86_64-zlib

Typical (autotools) build sequence (MSYS2 MinGW64 shell):
```
./autogen.sh        # if present
./configure --host=x86_64-w64-mingw32 --prefix=/mingw64
make -j$(nproc)
make install DESTDIR=/path/to/artifacts/vice/win10-x64
```

Typical (CMake) build sequence:
```
mkdir build && cd build
cmake -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/mingw64 ..
make -j$(nproc)
make install DESTDIR=/path/to/artifacts/vice/win10-x64
```

On CI, `build/Build.cs` NUKE target `BuildVice(win10-x64)` should invoke `build/vice/build.ps1` or `build/vice/build.sh` as appropriate.

SVN vs git-svn
- The VICE source is hosted in an SVN repository. The build scripts prefer `git svn` when available (it clones into a git repository while preserving SVN history), and fall back to `svn checkout`.
- To let the script auto-checkout VICE, ensure `git` with the `git-svn` plugin is installed, or install `svn` (Subversion).

## Applying VICE Build Patches

After pulling from SVN, patches must be applied to fix build issues.

### Quick Start

**Bash (Linux/macOS/WSL):**
```bash
chmod +x apply_vice_patches.sh
./apply_vice_patches.sh
```

**PowerShell (Windows):**
```powershell
.\apply_vice_patches.ps1
```

### Patch Files

1. **geninfocontrib_h.sh.patch** - Fixes missing team member file handling
2. **Makefile.patch** - Fixes file encoding validation

### Issues Fixed

1. **Missing team files**: Adds conditional checks before reading temporary team files
2. **Encoding validation**: Accepts both ISO-8859-1 and US-ASCII encodings

### Script Options

```bash
./apply_vice_patches.sh --verbose       # Detailed output
./apply_vice_patches.sh --test-only     # Test without applying
./apply_vice_patches.sh --dry-run       # Preview changes
```

### Manual Application

```bash
cd ../../third_party/vice/vice
patch -p1 < ../../../build/vice/geninfocontrib_h.sh.patch
patch -p1 < ../../../build/vice/Makefile.patch
```

For detailed documentation, see [VICE_BUILD_PATCHES.md](VICE_BUILD_PATCHES.md).
