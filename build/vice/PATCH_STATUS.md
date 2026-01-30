# VICE Patch Status

**Last Updated**: 2026-01-29  
**VICE Commit**: `5ca7ce898bca1a3696dbc9e444207026eabd58d5`  
**Status**: ✅ All patches obsolete - fixes applied upstream

## Overview

The C64OS IDE previously required two patches to build VICE successfully:
1. `geninfocontrib_h.sh.patch` - File existence checks
2. `Makefile.patch` - Encoding validation improvements

As of VICE commit `5ca7ce898b`, both issues have been resolved upstream with equivalent or better solutions. **No patches are currently needed.**

## Patch History

### 1. geninfocontrib_h.sh Patch (OBSOLETE)

**Original Issue**: The script would fail when trying to `cat` non-existent temp files.

**Our Fix**: Added `test -f file && cat file` checks before each `cat` operation.

**Upstream Solution**: 
- Uses `if [ -f file ]; then cat file; fi` pattern
- More readable and maintainable
- Applied during 2025-2026 codebase refactoring
- See lines 302-337 in `src/buildtools/geninfocontrib_h.sh`

**Status**: ✅ OBSOLETE - Upstream fix is superior

---

### 2. Makefile Patch (OBSOLETE)

**Original Issue**: Encoding validation would fail on `us-ascii` encoded files, only accepting `iso-8859-1`.

**Our Fix**: Modified encoding check to accept both `iso-8859-1` and `us-ascii`:
```bash
encoding=`file --mime-encoding infocontrib.h | cut -d: -f2 | tr -d ' '`
if [ "$encoding" != "iso-8859-1" ] && [ "$encoding" != "us-ascii" ]; then
    echo "ERROR: generated infocontrib.h contains content that is not valid iso-8859-x (found: $encoding)" >&2
    false
fi
```

**Upstream Solution**:
- Completely replaced encoding validation with error handling
- Uses `command 2>/dev/null || { fallback }` pattern
- Provides minimal `infocontrib.h` on generation failure
- More robust approach that handles multiple failure modes
- See lines 499-509 in `src/Makefile.am`

**Current Upstream Code**:
```make
infocontrib.h: $(srcdir)/buildtools/geninfocontrib_h.sh $(top_srcdir)/doc/vice.texi $(srcdir)/buildtools/infocontrib.sed
	@echo "generating infocontrib.h"
	@$(SHELL) $(srcdir)/buildtools/geninfocontrib_h.sh infocontrib.h <$(top_srcdir)/doc/vice.texi [...] 2>/dev/null || { \
		echo "WARNING: Could not generate infocontrib.h, using minimal version"; \
		rm -f infocontrib.h; \
		printf '#ifndef VICE_INFOCONTRIB_H\n#define VICE_INFOCONTRIB_H\n[...]\n' > infocontrib.h; \
	}
```

**Status**: ✅ OBSOLETE - Upstream solution handles more cases

---

## Submodule Configuration

The VICE submodule is pinned to a specific commit for reproducible builds:

```
Commit: 5ca7ce898bca1a3696dbc9e444207026eabd58d5
Branch: main (merge commit)
Date: 2026-01-29
Message: Merge branch 'clean' into main
```

This commit includes:
- r45962: Improved BASIC tokenizer/detokenizer handling
- r45960: Enhanced literal handling in tokenization
- r45959: Version update preparations
- r45957: CIA SDR IRC fix for old CIAs
- r45955: Explicit iconv installation for MSYS

### Updating the Pinned Commit

To update to a newer VICE commit:

```powershell
# 1. Update the submodule to latest
cd third_party/vice
git fetch origin
git checkout origin/main

# 2. Test the build
cd ../..
.\build\vice\apply_vice_patches.ps1 -Verbose

# 3. If successful, commit the submodule update
git add third_party/vice
git commit -m "Update VICE to commit $(cd third_party/vice; git rev-parse --short HEAD)"
git push

# 4. Update this document with the new commit hash
```

## Patch Management Scripts

### apply_vice_patches.ps1 / .sh

**Behavior**: 
- Automatically detects if patches are marked as `# OBSOLETE` in first line
- If obsolete: Displays info message and skips application
- If not obsolete: Applies patches as before
- Provides commit information for troubleshooting

**Exit Codes**:
- `0`: Success (patches applied or not needed)
- `1`: Error (missing files, application failure)

**Usage**:
```powershell
# Check patch status
.\build\vice\apply_vice_patches.ps1 -Verbose

# Test patches without applying
.\build\vice\apply_vice_patches.ps1 -TestOnly

# Dry run
.\build\vice\apply_vice_patches.ps1 -DryRun
```

## CI/CD Pipeline

The GitHub Actions workflow:
1. Checks out repository with `submodules: 'true'`
2. Submodule is automatically initialized to pinned commit
3. Runs `setup-git-svn.ps1` which detects populated submodule
4. Runs `apply_vice_patches.ps1` which detects obsolete patches
5. Proceeds directly to build without applying any patches

## Future Considerations

### When to Apply Patches Again

If you need to apply patches in the future:

1. Update the patch file content (remove `# OBSOLETE` marker)
2. Test locally with `apply_vice_patches.ps1 -DryRun`
3. Verify patches apply cleanly
4. Update this document

### When to Remove Patch Files

Consider removing patch files entirely when:
- VICE has been stable for 6+ months without needing patches
- Multiple VICE versions have been tested successfully
- No regression risks from upstream changes

For now, keeping the patch files as `OBSOLETE` provides:
- Historical documentation
- Quick recovery if upstream introduces regressions
- Examples for future patch creation if needed

## References

- VICE SVN Mirror: https://github.com/VICE-Team/svn-mirror
- VICE Official: https://sourceforge.net/projects/vice-emu/
- Submodule Documentation: `.gitmodules`
- Patch Files: 
  - `geninfocontrib_h.sh.patch` (obsolete)
  - `Makefile.patch` (obsolete)
