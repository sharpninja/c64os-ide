# C64OS IDE Application

Avalonia-based IDE for C64OS development with integrated VICE emulator support.

## Features

- Modern cross-platform UI built with Avalonia
- Integrated VICE emulator display
- Command-line support for launching VICE windows

## Command Line Parameters

### --StartVice

Opens a secondary window with VICE emulator framebuffer output.

**Usage:**

```bash
# With explicit path to VICE executable
C64OS.IDE.App --StartVice "C:\path\to\x64sc.exe"

# Auto-detect VICE (searches common locations)
C64OS.IDE.App --StartVice
```

**Auto-detection searches these locations:**

**Windows:**
- `artifacts/vice/win-x64/x64sc.exe` (from build)
- `C:\Program Files\VICE\x64sc.exe`
- `C:\Program Files (x86)\VICE\x64sc.exe`

**Linux:**
- `/usr/bin/x64sc`
- `/usr/local/bin/x64sc`

**macOS:**
- `/Applications/VICE/x64sc`
- `/usr/local/opt/vice/bin/x64sc`

### Other Parameters

```bash
# Show version
C64OS.IDE.App --version

# Show help
C64OS.IDE.App --help
```

## VICE Display Window

When launched with `--StartVice`, the application opens a secondary window showing:

- **Display Area**: 384x272 pixel C64 screen output (BGRA8888 format)
- **Status Bar**: Real-time status messages and VICE output
- **Black Background**: Retro aesthetic matching C64 appearance

### Window Features

- **Auto-scaling**: Display scales to fit window while maintaining aspect ratio
- **Real-time Updates**: Target 60 FPS frame updates from VICE
- **Status Monitoring**: Shows VICE stdout/stderr messages
- **Clean Shutdown**: Properly stops VICE when window is closed

## Architecture

```
C64OS.IDE.App/
├── Controls/
│   └── ViceDisplayControl.cs      # Avalonia control for VICE framebuffer
├── Services/
│   └── CommandLineService.cs      # Command-line argument processing
├── ViewModels/
│   ├── MainWindowViewModel.cs     # Main IDE window VM
│   └── ViceWindowViewModel.cs     # VICE display window VM
├── Views/
│   ├── MainWindow.axaml           # Main IDE window
│   └── ViceWindow.axaml           # VICE display window
├── App.axaml                      # Application definition
└── Program.cs                     # Entry point
```

## Building

```bash
# Build the application
dotnet build src/C64OS.IDE.App

# Run with VICE
dotnet run --project src/C64OS.IDE.App -- --StartVice "path/to/x64sc.exe"

# Or use the build script
.\build.cmd
```

## Dependencies

- **Avalonia 11.2.2**: Cross-platform UI framework
- **Avalonia.Desktop**: Desktop platform support
- **Avalonia.Themes.Fluent**: Modern Fluent UI theme
- **Avalonia.ReactiveUI**: Reactive MVVM support
- **C64OS.IDE.EmulatorBridge**: VICE headless host wrapper

## Usage Examples

### Example 1: Launch VICE from artifacts directory

```bash
# After building VICE with Nuke
.\build.cmd BuildVice

# Launch IDE with VICE
.\build\bin\Debug\C64OS.IDE.App.exe --StartVice "artifacts\vice\win-x64\x64sc.exe"
```

### Example 2: Auto-detect VICE

```bash
# IDE will search common locations
.\build\bin\Debug\C64OS.IDE.App.exe --StartVice
```

### Example 3: From Visual Studio Code

Add to `.vscode/launch.json`:

```json
{
  "name": "Launch with VICE",
  "type": "coreclr",
  "request": "launch",
  "preLaunchTask": "build",
  "program": "${workspaceFolder}/src/C64OS.IDE.App/bin/Debug/net9.0/C64OS.IDE.App.dll",
  "args": ["--StartVice", "artifacts/vice/win-x64/x64sc.exe"],
  "cwd": "${workspaceFolder}",
  "console": "internalConsole"
}
```

## Implementation Notes

### Framebuffer Capture

The current implementation includes placeholder code for framebuffer capture. To complete the integration, you need to implement one of these approaches:

1. **VICE Remote Monitor Extension** (Recommended)
   - Extend VICE monitor protocol to send frame data
   - Minimal VICE modifications required

2. **Shared Memory**
   - Use platform-specific shared memory APIs
   - Best performance
   - Requires VICE patch

3. **Custom Video Driver**
   - Create custom VICE video output driver
   - Most control
   - Significant VICE modifications

See `src/C64OS.IDE.EmulatorBridge/VICE_HEADLESS_README.md` for implementation details.

### Event Flow

```
1. User runs: C64OS.IDE.App --StartVice
2. Program.Main() captures args
3. App.OnFrameworkInitializationCompleted() called
4. CommandLineService.ProcessCommandLineAsync() processes args
5. ViceWindow created and shown
6. ViceWindow.StartViceAsync() called
7. ViceDisplayControl.StartViceAsync() starts VICE
8. ViceHeadlessHost spawns x64sc process
9. FrameAvailable events fire at ~60 FPS
10. ViceDisplayControl updates WriteableBitmap
11. Avalonia renders updated bitmap
```

## Future Enhancements

- [ ] Add keyboard input forwarding to VICE
- [ ] Add joystick/gamepad support
- [ ] Implement audio capture and playback
- [ ] Add debugging controls (breakpoints, stepping)
- [ ] Support loading .prg/.d64 files via UI
- [ ] Add snapshot/save state functionality
- [ ] Multi-window support (multiple VICE instances)
- [ ] Integration with main IDE (code editor, debugger)

## Troubleshooting

### VICE not found

**Error:** "VICE executable not found"

**Solution:** Specify full path to x64sc:
```bash
C64OS.IDE.App --StartVice "C:\full\path\to\x64sc.exe"
```

### Window shows but no display

**Issue:** VICE window opens but screen is black

**Cause:** Framebuffer capture not yet implemented

**Next Steps:** Implement framebuffer capture (see EmulatorBridge README)

### VICE crashes on startup

**Check:**
1. VICE data files are in correct location
2. Required DLLs are present (GTK3, etc.)
3. VICE is built with headless/remote monitor support

## Contributing

See main repository README for contribution guidelines.

## License

See LICENSE file in repository root.
