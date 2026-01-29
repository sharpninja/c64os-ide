using System;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Media.Imaging;
using Avalonia.Platform;
using Avalonia.Threading;
using C64OS.IDE.EmulatorBridge;

namespace C64OS.IDE.App.Controls;

/// <summary>
/// Avalonia control that displays VICE emulator framebuffer output.
/// </summary>
public class ViceDisplayControl : UserControl
{
    private WriteableBitmap? _bitmap;
    private Image? _image;
    private ViceHeadlessHost? _viceHost;
    private bool _isRunning;

    public event EventHandler<string>? ViceOutput;
    public event EventHandler<string>? ViceError;

    public ViceDisplayControl()
    {
        InitializeControl();
    }

    private void InitializeControl()
    {
        // Create bitmap for C64 display (384x272 is VICE default)
        _bitmap = new WriteableBitmap(
            new PixelSize(384, 272),
            new Vector(96, 96),
            PixelFormat.Bgra8888,
            AlphaFormat.Premul);

        _image = new Image
        {
            Source = _bitmap,
            Stretch = Avalonia.Media.Stretch.Uniform
        };

        Content = _image;

        // Set background to black
        Background = Avalonia.Media.Brushes.Black;
    }

    /// <summary>
    /// Starts the VICE emulator and begins displaying output.
    /// </summary>
    public async Task StartViceAsync(string viceExecutablePath, string? workingDirectory = null, ViceHeadlessOptions? options = null)
    {
        if (_isRunning)
        {
            throw new InvalidOperationException("VICE is already running");
        }

        workingDirectory ??= System.IO.Path.GetDirectoryName(viceExecutablePath) ?? Environment.CurrentDirectory;

        _viceHost = new ViceHeadlessHost();
        
        // Wire up events
        _viceHost.FrameAvailable += OnFrameAvailable;
        _viceHost.OutputReceived += (s, e) => ViceOutput?.Invoke(this, e);
        _viceHost.ErrorReceived += (s, e) => ViceError?.Invoke(this, e);

        await _viceHost.StartAsync(viceExecutablePath, workingDirectory, options);
        _isRunning = true;
    }

    /// <summary>
    /// Stops the VICE emulator.
    /// </summary>
    public async Task StopViceAsync()
    {
        if (!_isRunning || _viceHost == null)
            return;

        _isRunning = false;
        await _viceHost.StopAsync();
        _viceHost = null;
    }

    private void OnFrameAvailable(object? sender, ViceFrameEventArgs e)
    {
        if (_bitmap == null)
            return;

        // Update on UI thread
        Dispatcher.UIThread.Post(() =>
        {
            try
            {
                using (var buffer = _bitmap.Lock())
                {
                    // Copy frame data to bitmap
                    Marshal.Copy(e.FrameData, 0, buffer.Address, Math.Min(e.FrameData.Length, buffer.Size.Width * buffer.Size.Height * 4));
                }
                
                // Force redraw
                _image?.InvalidateVisual();
            }
            catch (Exception ex)
            {
                ViceError?.Invoke(this, $"Frame update error: {ex.Message}");
            }
        });
    }

    protected override void OnDetachedFromVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnDetachedFromVisualTree(e);
        
        // Clean up VICE when control is removed
        if (_isRunning)
        {
            _ = StopViceAsync();
        }
    }
}
