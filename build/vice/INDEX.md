===============================================================================
VICE BUILD PATCHES - QUICK INDEX
===============================================================================

Location: build/vice/

START HERE:
───────────

1. README.md
   Quick reference guide for applying patches
   ↓ Read this first for a quick overview

2. apply_vice_patches.sh (Linux/macOS/WSL)
   Run this after pulling from SVN: ./apply_vice_patches.sh

3. apply_vice_patches.ps1 (Windows)
   Run this after pulling from SVN: .\apply_vice_patches.ps1

DOCUMENTATION:
───────────────

• README.md - Quick start guide
• VICE_BUILD_PATCHES.md - Technical details of patches
• TRACKING.md - Complete change history
• DEPLOYMENT.md - Integration options
• DELIVERY_REPORT.txt - Complete delivery information
• INDEX.md - This file

PATCHES:
─────────

• geninfocontrib_h.sh.patch - Fixes team file handling
• Makefile.patch - Fixes encoding validation

SCRIPTS:
─────────

• apply_vice_patches.sh - Apply patches (Bash)
• apply_vice_patches.ps1 - Apply patches (PowerShell)
• validate_vice_patches.sh - Validate patch files

===============================================================================
TYPICAL WORKFLOW
===============================================================================

After pulling VICE from SVN:

  $ cd build/vice
  $ ./apply_vice_patches.sh

That's it! The script will:
✓ Apply both patches
✓ Verify they were applied
✓ Test by building infocontrib.h
✓ Report any issues

OPTIONS:

  # Show what would be done (no changes)
  $ ./apply_vice_patches.sh --dry-run

  # Test if patches are already applied
  $ ./apply_vice_patches.sh --test-only

  # Show detailed output
  $ ./apply_vice_patches.sh --verbose

===============================================================================
QUICK REFERENCE
===============================================================================

What patches fix:
  1. Missing team member files (geninfocontrib_h.sh)
  2. File encoding validation (Makefile)

When to apply:
  After pulling from VICE SVN repository

How long it takes:
  ~10-15 seconds

Will it affect my build?
  Yes, positively - allows the build to complete successfully

Can I apply patches multiple times?
  Yes, safe to re-run

Can I undo patches?
  Yes, use: patch -R -p1 < file.patch

Platform support:
  ✓ Linux / WSL
  ✓ macOS
  ✓ Windows (PowerShell)

===============================================================================
DOCUMENTATION MAP
===============================================================================

For different questions, see:

Q: "How do I apply patches after pulling from SVN?"
A: See README.md or run ./apply_vice_patches.sh

Q: "What exactly do these patches fix?"
A: See VICE_BUILD_PATCHES.md or TRACKING.md

Q: "How do I integrate this into my build system?"
A: See DEPLOYMENT.md

Q: "What's the complete delivery information?"
A: See DELIVERY_REPORT.txt

Q: "I need technical details about the changes"
A: See TRACKING.md or VICE_BUILD_PATCHES.md

Q: "How do I verify patches are applied?"
A: Run: ./validate_vice_patches.sh

Q: "How do I troubleshoot issues?"
A: Run with --verbose: ./apply_vice_patches.sh --verbose

===============================================================================
FILE SIZES
===============================================================================

Total size: ~39 KB

Individual files:
  • apply_vice_patches.sh        7.0 KB
  • apply_vice_patches.ps1       6.5 KB
  • TRACKING.md                  6.1 KB
  • DEPLOYMENT.md                5.6 KB
  • validate_vice_patches.sh     5.6 KB
  • README.md                    2.8 KB
  • DELIVERY_REPORT.txt          7.8 KB
  • VICE_BUILD_PATCHES.md        2.0 KB
  • geninfocontrib_h.sh.patch    1.2 KB
  • Makefile.patch               1.3 KB

===============================================================================
VALIDATION STATUS
===============================================================================

All files have been validated:
✓ 9 files present
✓ Patch format correct
✓ Script structure valid
✓ Documentation complete
✓ Cross-platform compatible

Run validation yourself:
  $ ./validate_vice_patches.sh

Expected output:
  [✓] All validations passed!
  [INFO] VICE patch files are ready for deployment.

===============================================================================
GETTING STARTED
===============================================================================

1. Navigate to directory:
   $ cd build/vice

2. Make scripts executable (first time only):
   $ chmod +x *.sh *.ps1

3. Apply patches:
   $ ./apply_vice_patches.sh

4. That's it! Patches are now applied and tested.

For Windows:
  > .\apply_vice_patches.ps1

===============================================================================
ADVANCED USAGE
===============================================================================

For developers and build engineers:

Manual patch application:
  $ cd ../../../third_party/vice/vice
  $ patch -p1 < ../../../build/vice/geninfocontrib_h.sh.patch
  $ patch -p1 < ../../../build/vice/Makefile.patch

Verify patches applied:
  $ grep "test -f coreteam.tmp &&" src/buildtools/geninfocontrib_h.sh
  $ grep 'encoding.*iso-8859-1.*us-ascii' src/Makefile

Manual build test:
  $ cd src
  $ rm -f infocontrib.h
  $ make infocontrib.h

Undo patches:
  $ patch -R -p1 < ../../../build/vice/geninfocontrib_h.sh.patch
  $ patch -R -p1 < ../../../build/vice/Makefile.patch

===============================================================================
INTEGRATION EXAMPLES
===============================================================================

For Build System (build/Build.cs):

  Target ApplyVicePatches => _ => _
      .Description("Apply VICE build patches")
      .Executes(() =>
      {
          var script = BuildDirectory / "vice" / "apply_vice_patches.sh";
          ProcessTasks.StartProcess(script, workingDirectory: ...).AssertZeroExitCode();
      });

For GitHub Actions:

  - name: Apply VICE Patches
    run: |
      cd build/vice
      bash apply_vice_patches.sh

For Makefile:

  apply-patches:
      bash build/vice/apply_vice_patches.sh

For Shell Script:

  bash build/vice/apply_vice_patches.sh --verbose

===============================================================================
TROUBLESHOOTING
===============================================================================

If script fails:
  1. Run with --verbose: ./apply_vice_patches.sh --verbose
  2. Check README.md for usage details
  3. Read VICE_BUILD_PATCHES.md for patch details
  4. Run validate_vice_patches.sh to check files
  5. See DEPLOYMENT.md for integration help

If patches don't apply:
  1. Check VICE hasn't changed (unlikely)
  2. Try: ./apply_vice_patches.sh --test-only
  3. If already applied, that's ok - no harm
  4. Verify with: grep "test -f" src/buildtools/geninfocontrib_h.sh

If build still fails:
  1. Ensure patches were applied
  2. Run: make clean; make
  3. Check for other build issues
  4. Review VICE_BUILD_PATCHES.md

If you need help:
  • Read all documentation in this directory
  • Run validate_vice_patches.sh
  • Use --verbose flag
  • Check DELIVERY_REPORT.txt

===============================================================================
SUPPORT & MAINTENANCE
===============================================================================

Last Updated: January 28, 2026
Status: Production Ready
Version: 1.0
Platform: Linux, macOS, Windows

For latest information:
  • See README.md
  • See TRACKING.md
  • Run validation script
  • Check DEPLOYMENT.md

Reporting issues:
  • Provide output from: ./apply_vice_patches.sh --verbose
  • Include OS and version
  • Include VICE revision number
  • Include complete error message

===============================================================================
QUICK COMMANDS
===============================================================================

Apply patches:           ./apply_vice_patches.sh
Apply (with details):    ./apply_vice_patches.sh --verbose
Test without applying:   ./apply_vice_patches.sh --test-only
Preview changes:         ./apply_vice_patches.sh --dry-run
Validate files:          ./validate_vice_patches.sh
Get help:               ./apply_vice_patches.sh --help
View documentation:      cat README.md
View technical details:  cat VICE_BUILD_PATCHES.md
View changes made:       cat TRACKING.md

===============================================================================
NEED MORE INFO?
===============================================================================

File                           Purpose
──────────────────────────     ──────────────────────────────
README.md                      Quick start guide
VICE_BUILD_PATCHES.md          Technical patch details
TRACKING.md                    What was changed and why
DEPLOYMENT.md                  How to integrate into build system
DELIVERY_REPORT.txt            Complete delivery information
INDEX.md                       This file

Read README.md first, then pick the document that answers your question.

===============================================================================
END OF INDEX
===============================================================================

For questions, start with README.md or DELIVERY_REPORT.txt
For technical details, see TRACKING.md or VICE_BUILD_PATCHES.md
For integration, see DEPLOYMENT.md

All documentation is in this directory (build/vice/)
