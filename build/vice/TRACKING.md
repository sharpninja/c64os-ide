# VICE Build Changes - Complete Tracking

**Date**: 2026-01-28
**Project**: C64OS IDE
**Target**: VICE Emulator Build Fixes

## Summary

Two critical patches were created to fix VICE emulator build failures when building from the SVN repository.

## Changes Overview

### Change 1: geninfocontrib_h.sh - Handle Missing Team Files

**File Path**: `third_party/vice/vice/src/buildtools/geninfocontrib_h.sh`
**Problem**: Script fails with "No such file or directory" when team member lists are empty
**Root Cause**: Script assumes temporary files exist even if team sections in vice.texi are empty

**Before**:
```bash
cat coreteam.tmp | sed "s/__VICE_CURRENT_YEAR__/$year/g"
cat exteam.tmp | sed "s/__VICE_CURRENT_YEAR__/$year/g"
cat docteam.tmp
cat transteam.tmp | sed "s/__VICE_CURRENT_YEAR__/$year/g"
```

**After**:
```bash
test -f coreteam.tmp && cat coreteam.tmp | sed "s/__VICE_CURRENT_YEAR__/$year/g"
test -f exteam.tmp && cat exteam.tmp | sed "s/__VICE_CURRENT_YEAR__/$year/g"
test -f docteam.tmp && cat docteam.tmp
test -f transteam.tmp && cat transteam.tmp | sed "s/__VICE_CURRENT_YEAR__/$year/g"
```

**Lines Modified**: 302, 308, 314, 320
**Type**: Robustness fix
**Impact**: Allows build to proceed even with empty team sections

### Change 2: Makefile - Flexible Encoding Check

**File Path**: `third_party/vice/vice/src/Makefile`
**Problem**: Build fails with "ERROR: generated infocontrib.h contains content that is not valid iso-8859-x"
**Root Cause**: File encoding check is too strict - expects exactly ISO-8859-1 but ASCII files report as us-ascii

**Before**:
```makefile
@if [ "`file --mime-encoding infocontrib.h`" != "infocontrib.h: iso-8859-1" ]; then \
	echo "ERROR: generated infocontrib.h contains content that is not valid iso-8859-x" >&2; \
	false; \
fi
```

**After**:
```makefile
@encoding=`file --mime-encoding infocontrib.h | cut -d: -f2 | tr -d ' '`; \
if [ "$$encoding" != "iso-8859-1" ] && [ "$$encoding" != "us-ascii" ]; then \
	echo "ERROR: generated infocontrib.h contains content that is not valid iso-8859-x (found: $$encoding)" >&2; \
	false; \
fi
```

**Lines Modified**: 2359-2362
**Type**: Validation fix
**Impact**: Accepts compatible ASCII-only files, provides better error diagnostics

## Deliverables

### Patch Files
1. **geninfocontrib_h.sh.patch** - Standard unified diff format
2. **Makefile.patch** - Standard unified diff format

### Application Scripts
1. **apply_vice_patches.sh** - Bash script (Linux/macOS/WSL)
   - Auto-applies patches
   - Verifies application
   - Tests build
   - Supports dry-run and test-only modes

2. **apply_vice_patches.ps1** - PowerShell script (Windows)
   - Auto-applies patches
   - Verifies application
   - Supports dry-run and test-only modes

### Documentation
1. **VICE_BUILD_PATCHES.md** - Technical details
2. **README.md** - Quick reference and usage guide
3. **TRACKING.md** - This file

## Application Procedure

### Initial Application
After pulling VICE from SVN:

```bash
# Linux/macOS/WSL
cd build/vice
chmod +x apply_vice_patches.sh
./apply_vice_patches.sh

# Windows PowerShell
cd build\vice
.\apply_vice_patches.ps1
```

### Automated Application
The patches can be integrated into the build process:

```csharp
// In build/Build.cs
public class BuildPlan : NukeBuild
{
    Target ApplyVicePatches => _ => _
        .Description("Apply VICE build patches after SVN pull")
        .Executes(() =>
        {
            var script = BuildDirectory / "vice" / "apply_vice_patches.sh";
            ProcessTasks.StartProcess(script, workingDirectory: BuildDirectory / "vice")
                .AssertZeroExitCode();
        });
}
```

## Testing & Verification

### Automated Verification
The scripts verify patches by:
1. Checking for specific strings in modified files
2. Attempting to build infocontrib.h
3. Validating generated file properties

### Manual Verification

```bash
# Check if patches are applied
grep "test -f coreteam.tmp &&" third_party/vice/vice/src/buildtools/geninfocontrib_h.sh
grep 'encoding.*iso-8859-1.*us-ascii' third_party/vice/vice/src/Makefile

# Test build
cd third_party/vice/vice/src
rm -f infocontrib.h
make infocontrib.h
file --mime-encoding infocontrib.h
```

## File Locations

```
build/
└── vice/
    ├── README.md                        (Updated with patch info)
    ├── VICE_BUILD_PATCHES.md            (Detailed technical docs)
    ├── TRACKING.md                      (This file)
    ├── geninfocontrib_h.sh.patch       (Patch 1)
    ├── Makefile.patch                  (Patch 2)
    ├── apply_vice_patches.sh           (Bash script)
    └── apply_vice_patches.ps1          (PowerShell script)
```

## Important Notes

### Patch Dependencies
- Neither patch depends on the other; both must be applied
- Patches are independent and can be applied in any order
- Patches can be safely re-applied if already applied

### SVN Update Procedure
1. Pull from VICE SVN repository
2. Run patch application script immediately after
3. Verify with test-only flag before proceeding
4. Continue with build process

### Integration Points
- Build system should apply patches automatically
- CI/CD should include patch verification step
- Documentation should reference patch directory

## Future Maintenance

### If VICE Updates
- Monitor for changes in `src/buildtools/geninfocontrib_h.sh`
- Monitor for changes in `src/Makefile` (infocontrib.h rule)
- Retest patches against new versions
- Create new patches if needed

### If Patches Fail
1. Check for upstream changes in VICE
2. Review patch application output
3. Apply manually if needed
4. Update patches if structure changed
5. Report to C64OS IDE team

## References

- VICE Homepage: http://vice-emu.sourceforge.net/
- VICE SVN: https://sourceforge.net/p/vice-emu/code/
- Patch Format: https://en.wikipedia.org/wiki/Patch_(Unix)

---

**Created**: January 28, 2026
**Status**: Complete and Tested
**Reviewed**: GitHub Copilot
