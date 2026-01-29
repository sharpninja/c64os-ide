# VICE Headless Wrapper

This module provides a C# wrapper for running VICE emulator in headless mode with framebuffer capture support.

## Components

### ViceHeadlessHost
Main class for hosting VICE in headless mode. Manages the emulator process and provides events for frame capture and output.

```csharp
var host = new ViceHeadlessHost();

var options = new ViceHeadlessOptions
{
    DataDirectory = "path/to/vice/data",
    EnableFramebufferCapture = true,
    FramebufferWidth = 384,
    FramebufferHeight = 272,
    SoundDevice = "dummy",
    MonitorPort = 6510
};

// Handle frame events
host.FrameAvailable += (sender, args) =>
{
    // args.FrameData contains BGRA8888 pixel data
    // Update your Avalonia bitmap here
};

await host.StartAsync("path/to/x64sc.exe", "workingDir", options);
```

### ViceFramebufferCapture
Handles framebuffer capture from VICE. Current implementation is a placeholder that needs to be connected to VICE's video output.

**TODO: Implement actual framebuffer capture via:**
1. VICE remote monitor protocol for video data
2. Shared memory interface (platform-specific)
3. Custom VICE patch to expose framebuffer
4. OS-level screen capture APIs

### ViceRemoteMonitor
TCP client for VICE's remote monitor protocol. Allows debugging and control of the emulator.

```csharp
var monitor = new ViceRemoteMonitor("127.0.0.1", 6510);
await monitor.ConnectAsync();

// Set breakpoint
await monitor.SetBreakpointAsync(0x1000);

// Read memory
await monitor.ReadMemoryAsync(0x0400, 256);

// Step through code
await monitor.StepAsync();
await monitor.ContinueAsync();

// Handle responses
monitor.ResponseReceived += (sender, response) =>
{
    Console.WriteLine($"VICE: {response}");
};
```

## VICE Configuration

To use headless mode, VICE must be started with specific command-line arguments:

```bash
# Headless mode with remote monitor
x64sc -remotemonitor -remotemonitoraddress 127.0.0.1:6510 -sounddev dummy

# With GTK3 UI disabled (requires headless build)
x64sc -headless -remotemonitor -remotemonitoraddress 127.0.0.1:6510
```

## Framebuffer Capture Implementation Options

### Option 1: VICE Remote Monitor Extension (Recommended)
Extend VICE's remote monitor protocol to include video frame data:
- Add new monitor command: `frame` to request current framebuffer
- Returns raw pixel data over TCP connection
- Requires minimal VICE modifications

### Option 2: Shared Memory
Use platform-specific shared memory APIs:
- **Windows**: CreateFileMapping / MapViewOfFile
- **Linux**: shm_open / mmap
- Requires VICE patch to write frames to shared memory
- Best performance

### Option 3: Custom Video Driver
Create a custom VICE video output driver:
- Implement in `src/arch/shared/` or `src/arch/gtk3/`
- Expose framebuffer via callback or memory-mapped interface
- Most control but requires significant VICE modifications

### Option 4: Screen Capture (Fallback)
Use OS-level screen capture APIs:
- **Windows**: Windows.Graphics.Capture, BitBlt
- **Linux**: X11 XGetImage, or Wayland screencopy protocol
- Least efficient, requires visible window
- Works without VICE modifications

## Integration with Avalonia

Example Avalonia control to display VICE screen:

```csharp
using Avalonia.Controls;
using Avalonia.Media.Imaging;
using Avalonia.Threading;

public class ViceDisplayControl : UserControl
{
    private WriteableBitmap _bitmap;
    private Image _image;
    private ViceHeadlessHost _viceHost;

    public ViceDisplayControl()
    {
        _bitmap = new WriteableBitmap(
            new PixelSize(384, 272),
            new Vector(96, 96),
            PixelFormat.Bgra8888,
            AlphaFormat.Premul);

        _image = new Image { Source = _bitmap };
        Content = _image;

        _viceHost = new ViceHeadlessHost();
        _viceHost.FrameAvailable += OnFrameAvailable;
    }

    private void OnFrameAvailable(object? sender, ViceFrameEventArgs e)
    {
        Dispatcher.UIThread.Post(() =>
        {
            using (var buffer = _bitmap.Lock())
            {
                Marshal.Copy(e.FrameData, 0, buffer.Address, e.FrameData.Length);
            }
            _image.InvalidateVisual();
        });
    }

    public async Task StartEmulatorAsync(string vicePath, string workingDir)
    {
        var options = new ViceHeadlessOptions
        {
            EnableFramebufferCapture = true,
            FramebufferWidth = 384,
            FramebufferHeight = 272
        };

        await _viceHost.StartAsync(vicePath, workingDir, options);
    }
}
```

## Next Steps

1. **Choose framebuffer capture method** - Recommend Option 1 or 2
2. **Implement capture in ViceFramebufferCapture.cs**
3. **Test with VICE** - Verify remote monitor connectivity
4. **Add keyboard/joystick input forwarding**
5. **Implement audio capture** (if needed)
6. **Create Avalonia sample application**

## VICE Remote Monitor Commands

Common monitor commands for debugging:

- `m <start> <end>` - Display memory
- `d <start> <end>` - Disassemble
- `r` - Show registers
- `break <address>` - Set breakpoint
- `z` - Step one instruction
- `n` - Step over (next)
- `x` - Continue execution
- `reset` - Reset CPU
- `quit` - Quit monitor

## References

- [VICE Manual](https://vice-emu.sourceforge.io/vice_toc.html)
- [VICE Remote Monitor Protocol](https://vice-emu.sourceforge.io/vice_17.html#SEC342)
- [Avalonia Documentation](https://docs.avaloniaui.net/)
