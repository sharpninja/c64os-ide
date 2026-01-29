# VICE Console Error Logging Configuration

## Overview

VICE has been configured to emit all error and message notifications to console (stdout/stderr) instead of displaying GTK3 dialog boxes. This is useful for:

- Automated/batch processing (CI/CD pipelines, scripts)
- Headless operation (remote servers, containers)
- Log file capture and analysis
- Debugging and troubleshooting

## Changes Made

### Modified File: `src/arch/gtk3/ui.c`

#### Error Handler
**Original behavior:** Displayed errors in GTK3 dialog boxes using `vice_gtk3_message_error()`

**New behavior:** Prints errors directly to stderr
```c
static gboolean ui_error_impl(gpointer user_data)
{
    /* Print error to console/stderr instead of showing dialog */
    fprintf(stderr, "VICE Error: %s\n", (const char*)user_data);
    fflush(stderr);
    lib_free(user_data);
    return G_SOURCE_REMOVE;
}
```

#### Message Handler
**Original behavior:** Displayed messages in GTK3 dialog boxes using `vice_gtk3_message_info()`

**New behavior:** Prints messages directly to stdout
```c
static gboolean ui_message_impl(gpointer user_data)
{
    /* Print message to console/stdout instead of showing dialog */
    fprintf(stdout, "VICE Message: %s\n", (const char *)user_data);
    fflush(stdout);
    lib_free(user_data);
    return G_SOURCE_REMOVE;
}
```

## Usage Examples

### Basic Console Capture

```bash
# Run VICE and see all messages in console
./x64sc.exe 2>&1

# Run VICE with messages only (hide stdout)
./x64sc.exe 2>&1 1>/dev/null

# Run VICE with errors only (hide stdout)
./x64sc.exe 2>/dev/null
```

### Log to File

```bash
# Capture both stdout and stderr to file
./x64sc.exe 2>&1 | tee vice.log

# Capture only errors to file
./x64sc.exe 2> vice_errors.log

# Capture only messages to file
./x64sc.exe > vice_messages.log 2>/dev/null
```

### With Environment Variables

```bash
# Set GSSettings schemas path and run VICE
export GSETTINGS_SCHEMA_DIR=/mingw64/share/glib-2.0/schemas
./x64sc.exe -verbose 2>&1 | tee vice.log
```

### PowerShell Usage

```powershell
# Capture and display output
& ".\x64sc.exe" 2>&1 | Tee-Object -FilePath vice.log

# Capture only errors
& ".\x64sc.exe" 2>&1 1>$null | Tee-Object -FilePath errors.log

# Run with logging
& ".\x64sc.exe" -verbose -logfile verbose.log 2>&1
```

### Batch/Scripting

```bash
#!/bin/bash
# Automated VICE operation with error handling

export GSETTINGS_SCHEMA_DIR=/mingw64/share/glib-2.0/schemas

# Run VICE and capture all output
output=$(./x64sc.exe -logfile vice.log 2>&1)

# Check for errors in output
if echo "$output" | grep -i "error.*couldn't load"; then
    echo "ROM loading failed - cannot run emulator"
    echo "$output" | grep -i "error"
    exit 1
fi

echo "VICE started successfully"
```

## Error/Message Output Format

### Error Messages (to stderr)
```
VICE Error: Couldn't load kernal ROM `kernal-901227-03.bin'
VICE Error: Machine initialization failed
VICE Error: [specific error details]
```

### Info Messages (to stdout)
```
VICE Message: Starting emulator
VICE Message: Configuration loaded
VICE Message: [specific message details]
```

## Common Error Messages

### ROM Loading Errors
```
VICE Error: Couldn't load kernal ROM `kernal-901227-03.bin'.
VICE Error: Couldn't load basic ROM `basic-901226-01.bin'.
VICE Error: Machine initialization failed.
```

**Solution:** Ensure ROM files are in the correct directory or specify with `--romsdir` option.

### Keymap Errors
```
Keymap: Error - Default keymap not found, this should be fixed. Going on anyway...
```

**Note:** These are warnings, not failures. VICE will continue with default keymap.

### GSettings Errors
```
(x64sc.exe:48468): GLib-GIO-ERROR **: No GSettings schemas are installed on the system
```

**Solution:** Set environment variable:
```bash
export GSETTINGS_SCHEMA_DIR=/mingw64/share/glib-2.0/schemas
```

### Resource Data Errors
```
Error - failed to find resource data 'vice.gresource'.
Error - failed to initialize GResource data, don't expect much when it comes to icons, fonts or logos.
```

**Note:** These are warnings. The emulator will function without icons/fonts.

## Logging Levels

VICE supports multiple logging levels via command-line options:

```bash
# Standard logging
./x64sc.exe

# Verbose logging (more detail)
./x64sc.exe -verbose

# Debug logging (maximum detail)
./x64sc.exe -debug

# Log to specific file
./x64sc.exe -logfile verbose.log -verbose

# Log to specific file with debug
./x64sc.exe -logfile debug.log -debug
```

## Integration with Logging Systems

### Redirecting to System Logs

```bash
# Send to syslog (Linux/Unix)
./x64sc.exe 2>&1 | logger -t vice

# Send to Windows Event Log (Windows PowerShell)
& ".\x64sc.exe" 2>&1 | ForEach-Object { Write-EventLog -LogName "Application" -EventId 1 -Source "VICE" -Message $_ }
```

### Log Rotation

```bash
#!/bin/bash
# Rotate VICE logs

LOG_DIR="/var/log/vice"
LOG_FILE="$LOG_DIR/vice.log"

# Create log directory if needed
mkdir -p "$LOG_DIR"

# Rotate logs if size exceeds 10MB
if [ -f "$LOG_FILE" ]; then
    size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null)
    if [ $size -gt 10485760 ]; then
        mv "$LOG_FILE" "$LOG_FILE.$(date +%s)"
        gzip "$LOG_FILE".*
    fi
fi

# Run VICE with logging
export GSETTINGS_SCHEMA_DIR=/mingw64/share/glib-2.0/schemas
./x64sc.exe 2>&1 | tee -a "$LOG_FILE"
```

## Automated Testing

### Example Test Script

```bash
#!/bin/bash

# Test VICE startup and initialization

set -e

VICE_DIR="/e/github/C64OS_IDE/artifacts/vice/win-x64"
export GSETTINGS_SCHEMA_DIR=/mingw64/share/glib-2.0/schemas

test_vice() {
    local timeout=$1
    local expected_error=$2

    output=$($VICE_DIR/x64sc.exe 2>&1 | head -50)

    if echo "$output" | grep -q "$expected_error"; then
        echo "✓ Expected error found: $expected_error"
        return 0
    else
        echo "✗ Expected error NOT found: $expected_error"
        return 1
    fi
}

# Test ROM loading error handling
test_vice 2 "Couldn't load kernal ROM"

# Test successful startup with ROMs in place
# (would require ROMs to be present)

echo "All tests completed"
```

## Performance Notes

- **Faster execution**: Eliminating GTK3 dialog creation and rendering improves startup time
- **Lower overhead**: Console output has less overhead than GUI dialogs
- **Batch processing**: Much more efficient for headless/automated operations

## Debugging Output Capture

To capture debug information for troubleshooting:

```bash
#!/bin/bash

export GSETTINGS_SCHEMA_DIR=/mingw64/share/glib-2.0/schemas

# Capture all output with timestamps
./x64sc.exe -debug 2>&1 | \
    sed "s/^/[$(date +'%Y-%m-%d %H:%M:%S')] /" | \
    tee vice_debug_$(date +%s).log
```

## Build Information

- **Build Date**: 2026-01-29
- **VICE Version**: 3.10
- **Modified File**: `src/arch/gtk3/ui.c`
- **Changes**: Error/message handlers modified to use fprintf/stdout/stderr
- **Platform**: Windows x64 (MinGW64 build)

## Reverting Changes

To restore dialog-based error handling, rebuild the original VICE:

```bash
cd third_party/vice/vice
git checkout src/arch/gtk3/ui.c
cd ../../..
./build.cmd BuildVice --Platform Windows
```

This will restore the original GTK3 dialog behavior.
