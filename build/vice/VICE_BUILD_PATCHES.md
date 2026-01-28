# VICE Build Patches

This document tracks all patches applied to the VICE emulator build to make it compatible with the C64OS IDE build system.

## Summary

The VICE emulator requires patches to fix build issues related to:
1. Missing team member files in the contributor info generation
2. Overly strict file encoding checks

## Changes Made

### 1. File: `third_party/vice/vice/src/buildtools/geninfocontrib_h.sh`

**Problem**: The script fails when building team member lists if the team sections in vice.texi are empty.

**Solution**: Add conditional checks before attempting to `cat` temporary team files.

**Lines Modified**: 302-327

**Changes**:
- Line 302: Changed `cat coreteam.tmp` to `test -f coreteam.tmp && cat coreteam.tmp`
- Line 308: Changed `cat exteam.tmp` to `test -f exteam.tmp && cat exteam.tmp`
- Line 314: Changed `cat docteam.tmp` to `test -f docteam.tmp && cat docteam.tmp`
- Line 320: Changed `cat transteam.tmp` to `test -f transteam.tmp && cat transteam.tmp`

### 2. File: `third_party/vice/vice/src/Makefile`

**Problem**: The Makefile checks if generated `infocontrib.h` has encoding `iso-8859-1`, but ASCII-only files are detected as `us-ascii` by the `file` command.

**Solution**: Update the encoding check to accept both `iso-8859-1` and `us-ascii`.

**Lines Modified**: 2359-2362

**Changes**:
- Replaced strict encoding check (expecting exactly "iso-8859-1") with flexible check that accepts both "iso-8859-1" and "us-ascii"
- Added error message showing the actual encoding found

## Patch Files

See the `vice_patches/` directory for:
- `geninfocontrib_h.sh.patch` - Patch for shell script
- `Makefile.patch` - Patch for Makefile
- `apply_vice_patches.sh` - Script to apply patches

## Testing

Run `./build/vice/apply_vice_patches.sh` after pulling from SVN repository to:
1. Apply all patches
2. Verify the patches applied successfully
3. Build `infocontrib.h` to test the fixes
