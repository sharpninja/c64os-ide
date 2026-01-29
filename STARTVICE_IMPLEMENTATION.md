# StartVice Command Line Parameter - Implementation Summary

## Overview

Added `--StartVice` command-line parameter to C64OS IDE that opens a secondary window displaying VICE emulator framebuffer output.

## What Was Added

### 1. Avalonia Application Infrastructure

**Files Created:**
- `App.axaml` / `App.axaml.cs` - Main application definition
- `Program.cs` - Updated entry point with Avalonia initialization
- `app.manifest` - Windows application manifest

**Project Updated:**
- `C64OS.IDE.App.csproj` - Added Avalonia packages and dependencies

### 2. Main Window

**Files:**
- `Views/MainWindow.axaml` / `MainWindow.axaml.cs`
- `ViewModels/MainWindowViewModel.cs`
- `ViewModels/ViewModelBase.cs`

**Features:**
- Basic menu structure
- Placeholder content area
- MVVM architecture with ReactiveUI

### 3. VICE Display Window

**Files:**
- `Views/ViceWindow.axaml` / `ViceWindow.axaml.cs`
- `ViewModels/ViceWindowViewModel.cs`

**Features:**
- 768x544 window optimized for C64 display
- Black background with bordered display area
- Status bar showing VICE output and errors
- Proper cleanup on window close

### 4. VICE Display Control

**File:** `Controls/ViceDisplayControl.cs`

**Capabilities:**
- Custom Avalonia UserControl
- WriteableBitmap for frame rendering
- 384x272 BGRA8888 framebuffer
- Event-driven frame updates
- Async start/stop operations
- Proper resource disposal

### 5. Command Line Service

**File:** `Services/CommandLineService.cs`

**Functions:**
- Processes `--StartVice` parameter
- Auto-detects VICE in common locations
- Creates and shows VICE window
- Handles errors gracefully

**Auto-Detection Paths:**
- Windows: Program Files, artifacts directory
- Linux: /usr/bin, /usr/local/bin
- macOS: /Applications, /usr/local/opt

### 6. Documentation

**Files:**
- `src/C64OS.IDE.App/README.md` - Complete usage guide
- `src/C64OS.IDE.EmulatorBridge/VICE_HEADLESS_README.md` - Technical details

## Usage

```bash
# With explicit VICE path
C64OS.IDE.App --StartVice "C:\path\to\x64sc.exe"

# Auto-detect VICE
C64OS.IDE.App --StartVice

# Show help
C64OS.IDE.App --help
```

## Architecture Flow

```
Command Line Args
       ↓
Program.Main() → Stores args in static property
       ↓
Avalonia App Start
       ↓
App.OnFrameworkInitializationCompleted()
       ↓
CommandLineService.ProcessCommandLineAsync()
       ↓
Finds/Validates VICE Path
       ↓
Creates ViceWindow
       ↓
Window.Show()
       ↓
ViceWindow.StartViceAsync()
       ↓
ViceDisplayControl.StartViceAsync()
       ↓
ViceHeadlessHost.StartAsync()
       ↓
Spawns x64sc process
       ↓
FrameAvailable events (60 FPS)
       ↓
Updates WriteableBitmap
       ↓
Avalonia renders to screen
```

## Dependencies Added

### NuGet Packages
- **Avalonia 11.2.2** - UI framework
- **Avalonia.Desktop 11.2.2** - Desktop support
- **Avalonia.Themes.Fluent 11.2.2** - Modern theme
- **Avalonia.Fonts.Inter 11.2.2** - Typography
- **Avalonia.ReactiveUI 11.2.2** - MVVM support

### Project References
- **C64OS.IDE.Core** - Core interfaces
- **C64OS.IDE.EmulatorBridge** - VICE wrapper

## Key Features

✅ **Command-line driven** - Launch VICE from terminal/script
✅ **Auto-detection** - Finds VICE automatically
✅ **Cross-platform** - Windows, Linux, macOS support
✅ **Async/await** - Non-blocking operations
✅ **Event-driven** - Real-time frame updates
✅ **MVVM architecture** - Clean separation of concerns
✅ **Proper cleanup** - Resources disposed correctly
✅ **Error handling** - Graceful error messages

## Testing the Feature

### 1. Build the Application

```bash
cd E:\github\C64OS_IDE
dotnet build src/C64OS.IDE.App
```

### 2. Run with VICE

```bash
# After building VICE
.\build.cmd BuildVice

# Launch IDE with VICE
.\src\C64OS.IDE.App\bin\Debug\net9.0\C64OS.IDE.App.exe --StartVice "artifacts\vice\win-x64\x64sc.exe"
```

### 3. Expected Behavior

1. Main IDE window opens
2. VICE display window opens separately
3. Status bar shows "Starting VICE..."
4. VICE process launches in headless mode
5. (Currently) Black screen displayed (framebuffer capture not yet implemented)
6. Status bar shows VICE output messages
7. Close window → VICE process terminates cleanly

## Current Limitations

⚠️ **Framebuffer capture not implemented** - Screen will be black until you implement one of these:
1. VICE remote monitor protocol extension
2. Shared memory interface
3. Custom VICE video driver
4. OS-level screen capture

See `src/C64OS.IDE.EmulatorBridge/VICE_HEADLESS_README.md` for implementation options.

## Next Steps

### Phase 1: Complete Framebuffer Capture
1. Choose capture method (recommend remote monitor extension)
2. Implement in `ViceFramebufferCapture.cs`
3. Test frame rendering in VICE window

### Phase 2: Add Input Forwarding
1. Implement keyboard event capture in ViceDisplayControl
2. Map Avalonia keys to VICE key codes
3. Send via ViceRemoteMonitor

### Phase 3: Enhanced Features
1. Add menu commands (Load Program, Reset, etc.)
2. Implement debugging controls
3. Add audio capture/playback
4. Support snapshots and save states

### Phase 4: IDE Integration
1. Connect to code editor
2. Implement source-level debugging
3. Add watch windows and memory inspector
4. Create project system

## Code Structure Quality

✅ **Separation of Concerns**
- UI (Views) separate from logic (ViewModels)
- Business logic in Services
- Emulator integration in EmulatorBridge

✅ **Async/Await Throughout**
- No blocking operations on UI thread
- Proper cancellation token support

✅ **Event-Driven**
- Loose coupling via events
- Easy to extend/modify

✅ **Resource Management**
- IDisposable pattern
- Proper cleanup in destructors
- Visual tree detachment handling

✅ **Error Handling**
- Try-catch blocks where appropriate
- User-friendly error messages
- Graceful degradation

## Integration Points

The implementation provides these integration points:

1. **ViceDisplayControl** - Can be embedded in any Avalonia window
2. **ViceHeadlessHost** - Can be used independently for automation
3. **ViceRemoteMonitor** - Direct access to VICE debugging
4. **CommandLineService** - Extensible for more parameters

## Summary

Successfully implemented `--StartVice` command-line parameter with:
- Full Avalonia application setup
- Secondary window for VICE display
- VICE headless host integration
- Event-driven architecture
- Cross-platform support
- Comprehensive documentation

The infrastructure is complete and ready for framebuffer capture implementation to enable actual VICE screen display.
