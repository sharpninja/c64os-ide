# VICE ROM and Font File Setup

## Overview
This document describes how ROM files and fonts are automatically distributed to both the output directory and the user's configuration directory during the VICE build process.

## Build Date
January 29, 2026

## ROM and Font Distribution Strategy

### Two-Location Distribution
ROMs and fonts are copied to **two locations** to ensure availability in different contexts:

1. **Output Directory** (`artifacts/vice/win-x64/data/`)
   - Location for VICE to find ROMs when running from the build output
   - Used when VICE executable is run directly from build artifacts

2. **User Configuration Directory** (`%APPDATA%\vice/`)
   - Windows: `C:\Users\{username}\AppData\Roaming\vice\`
   - Provides permanent installation after build
   - Makes ROMs/fonts available even if moved outside build artifacts

## Implementation Details

### Build System Changes

**build/Build.cs** - SetupViceWindowsConfig() Method
- Extended to copy ROM files from source `third_party/vice/vice/data/`
- Copies all `.bin` files to config directory maintaining subdirectory structure
- Copies all `.ttf` font files to `config/vice/common/`
- Creates directories as needed

**build/vice/build-mingw64.sh** - Configuration Setup Section
- Added loops to iterate through ROM directories
- Copies ROM files: `find "$rom_dir" -maxdepth 1 -name "*.bin" -type f -exec cp ...`
- Copies font files: `cp data/common/*.ttf "$VICE_CONFIG_DIR/common/"`

## ROM Files

### Source Location
`third_party/vice/vice/data/{MACHINE_NAME}/*.bin`

### Machine Types with ROMs
- **C64** (10 files) - 6502 CPU ROMs, Character ROM, Kernal variations
- **C128** (16 files) - 8502 CPU, Z80 BASIC, extended Kernal variants
- **C64DTV** (4 files) - DTV variant ROMs
- **CBM-II** (8 files) - CBM II series ROMs
- **PET** (28 files) - PET series across multiple hardware versions
- **PLUS4** (8 files) - Plus/4 ROMs
- **SCPU64** (2 files) - Super CPU 64 ROMs
- **VIC20** (6 files) - VIC-20 ROM variants
- **DRIVES** (14 files) - 1541, 1571, 1581, 2000, 4000 drive ROMs
- **PRINTER** (9 files) - Printer device ROMs
- **ROMS** (390 files) - Additional ROM images and cartridge data

**Total ROM Files**: 115 in config directory, 1,121 in output directory (includes additional data files)

### ROM Discovery
VICE on Windows (GTK3) uses `archdep_get_vice_datadir()` which returns:
- Relative path: `../` (parent directory of executable)
- Resolves to: `artifacts/vice/data/` when executable is in `artifacts/vice/win-x64/`
- Fallback: User config directory `%APPDATA%\vice\` if primary location unavailable

## Font Files

### Source Location
`third_party/vice/vice/data/common/*.ttf`

### Available Fonts
| Font Name | Size | Purpose |
|-----------|------|---------|
| C64_Pro_Mono-STYLE.ttf | 28 KB | C64 Professional monospace font |
| PetMe.ttf | 525 KB | Original PET character font |
| PetMe128.ttf | 389 KB | PET 128 variant |
| PetMe1282Y.ttf | 389 KB | PET 128 2Y variant |
| PetMe2X.ttf | 525 KB | PET 2X variant |
| PetMe2Y.ttf | 525 KB | PET 2Y variant |
| PetMe64.ttf | 389 KB | PET 64 variant |
| PetMe642Y.ttf | 389 KB | PET 64 2Y variant |

**Total**: 8 font files (3.75 MB)

### Font Distribution
- Copied to: `%APPDATA%\vice\common\` during build
- Also copied to: `artifacts/vice/win-x64/data/common/`
- Ensures consistent font availability in both execution contexts

## Build Output Summary

### Configuration Directory (`%APPDATA%\vice\`)
```
%APPDATA%\vice\
├── vicerc                          (Configuration file, 1,399 bytes)
├── vice.log                        (Runtime log)
├── C64/                            (10 ROM files)
├── C128/                           (16 ROM files)
├── C64DTV/                         (4 ROM files)
├── CBM-II/                         (8 ROM files)
├── C64DTV/                         (4 ROM files)
├── PET/                            (28 ROM files)
├── PLUS4/                          (8 ROM files)
├── SCPU64/                         (2 ROM files)
├── VIC20/                          (6 ROM files)
├── DRIVES/                         (14 ROM files)
├── PRINTER/                        (9 ROM files)
├── common/                         (8 font files + metadata)
└── ...other directories...

Total: 14 directories, 115 files
```

### Output Directory (`artifacts/vice/win-x64/`)
```
artifacts/vice/win-x64/
├── x64sc.exe                       (Main C64 emulator, 21.26 MB)
├── x128.exe                        (C128 emulator, 22.95 MB)
├── xvic.exe                        (VIC-20 emulator, 17.95 MB)
├── xpet.exe                        (PET emulator, 17.42 MB)
├── xplus4.exe                      (Plus/4 emulator, 17.45 MB)
├── xcbm2.exe                       (CBM-II emulator, 16.95 MB)
├── xcbm5x0.exe                     (CBM-500/600 emulator, 16.86 MB)
├── xscpu64.exe                     (SuperCPU 64 emulator, 21.43 MB)
├── x64dtv.exe                      (C64-DTV emulator, 17.35 MB)
├── vsid.exe                        (SID music player, 13.82 MB)
├── c1541.exe                       (Disk image utility, 2.14 MB)
├── [64 DLL dependencies]
└── data/                           (ROMs and support files)
    ├── C64/                        (93 files)
    ├── C128/                       (69 files)
    ├── C64DTV/                     (57 files)
    ├── CBM-II/                     (52 files)
    ├── PET/                        (68 files)
    ├── PLUS4/                      (32 files)
    ├── SCPU64/                     (82 files)
    ├── VIC20/                      (30 files)
    ├── DRIVES/                     (17 files)
    ├── PRINTER/                    (15 files)
    ├── common/                     (191 files incl. 8 TTF fonts)
    ├── ROMS/                       (390 additional ROM images)
    ├── GLSL/                       (8 shader files)
    ├── hotkeys/                    (14 configuration files)
    └── ...other resources...

Total: 14 directories, 1,121 files in data/
```

## Verification Steps

### Verify ROMs in Config Directory
```powershell
Get-ChildItem -Path "$env:APPDATA\vice" -Recurse -File | Measure-Object
# Should show 115+ files
```

### Verify Fonts in Config Directory
```powershell
Get-ChildItem -Path "$env:APPDATA\vice\common" -Filter "*.ttf"
# Should show 8 font files
```

### Verify ROMs in Output Directory
```powershell
Get-ChildItem -Path "artifacts/vice/win-x64/data" -Recurse -File | Measure-Object
# Should show 1,121+ files
```

### Verify Fonts in Output Directory
```powershell
Get-ChildItem -Path "artifacts/vice/win-x64/data/common" -Filter "*.ttf"
# Should show 8 font files
```

## Build Process Flow

1. **VICE compilation** - Creates 11 emulator executables
2. **Artifact copying** - Copies binaries and DLLs to output directory
3. **Data directory copying** - Copies data/ recursively to output/data/
4. **Windows config setup** - Calls SetupViceWindowsConfig()
   - Creates `%APPDATA%\vice\` directory
   - Copies `vicerc` template
   - **Iterates through ROM directories** - Copies *.bin files
   - **Copies font files** - Copies *.ttf files
5. **Logging** - Reports success/status of each operation

## Build Automation

### Complete Build Command
```bash
./build.cmd BuildVice --Platform Windows
```

### Expected Output
```
[INF] vicerc already exists: C:\Users\{user}\AppData\Roaming\vice\vicerc
[INF] ROM files copied to: C:\Users\{user}\AppData\Roaming\vice
[INF] Font files copied to: C:\Users\{user}\AppData\Roaming\vice\common
```

## Notes

### Directory Preservation
- ROM files maintain their subdirectory structure (C64/, C128/, etc.)
- Fonts collected in `common/` subdirectory
- Enables VICE to locate resources using standard lookup paths

### Idempotent Operations
- Copy operations check for existing files
- Won't overwrite user-modified ROMs or configs
- Safe to re-run build multiple times

### Error Handling
- Missing directories logged as warnings, not errors
- Build continues even if some files can't be copied
- Ensures partial failures don't break build process

### VICE Data Lookup Precedence
1. Check output directory: `../data/` relative to executable
2. Check config directory: `%APPDATA%\vice\`
3. Check system paths (if configured)

## Related Documentation
- [VICE_DEFAULT_CONFIG_SETUP.md](VICE_DEFAULT_CONFIG_SETUP.md) - vicerc configuration
- [VICE_CONSOLE_LOGGING.md](VICE_CONSOLE_LOGGING.md) - Console error output setup
- [VICE Build README](build/vice/README.md) - Build system details
