# VICE Console Logging - Quick Reference

## What Changed?

VICE error and message dialogs now print to console instead of showing GUI dialog boxes.

- **Errors** → printed to stderr (red in terminals)
- **Messages** → printed to stdout (normal console)

## Quick Examples

### Capture All Output
```bash
./x64sc.exe 2>&1
```

### Capture to Log File
```bash
./x64sc.exe 2>&1 | tee vice.log
```

### Errors Only
```bash
./x64sc.exe 2>&1 1>/dev/null
```

### Messages Only
```bash
./x64sc.exe 2>/dev/null
```

## With Environment Setup (Recommended)

```bash
export GSETTINGS_SCHEMA_DIR=/mingw64/share/glib-2.0/schemas
./x64sc.exe -verbose 2>&1 | tee vice_run.log
```

## PowerShell

```powershell
& ".\x64sc.exe" 2>&1 | Tee-Object -FilePath vice.log
```

## What You'll See

```
*** VICE Version 3.10 ***

This is the condensed log, for the full log use --verbose or --debug.
Main:  random seed was: 0x697bbd65
C64MEM: Error - Couldn't load kernal ROM `kernal-901227-03.bin'.
VICE Error: Machine initialization failed.
```

## Common Errors

| Error | Meaning | Solution |
|-------|---------|----------|
| `Couldn't load kernal ROM` | ROM file missing | Place ROM files in data directory |
| `Default keymap not found` | Keymap config missing | Non-critical, will use default |
| `No GSettings schemas` | Missing GTK config | `export GSETTINGS_SCHEMA_DIR=/mingw64/share/glib-2.0/schemas` |
| `failed to find resource data` | Missing data files | Non-critical, GUI will be minimal |

## Modified Files

- `third_party/vice/vice/src/arch/gtk3/ui.c`
  - Lines 2547-2551: `ui_error_impl()` - changed to fprintf(stderr)
  - Lines 2581-2585: `ui_message_impl()` - changed to fprintf(stdout)

## Benefits

✅ No popup dialogs blocking execution
✅ Perfect for automated/batch processing
✅ Easy log capture for debugging
✅ Works in headless/remote environments
✅ Faster startup (no GTK3 dialog overhead)

## Full Documentation

See [VICE_CONSOLE_LOGGING.md](VICE_CONSOLE_LOGGING.md) for comprehensive guide.
