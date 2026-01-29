using System;
using System.Threading.Tasks;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Threading;
using C64OS.IDE.App.Controls;
using C64OS.IDE.EmulatorBridge;

namespace C64OS.IDE.App.Views;

public partial class ViceWindow : Window
{
    public ViceWindow()
    {
        InitializeComponent();
    }

    public async Task StartViceAsync(string viceExecutablePath)
    {
        if (_displayControl == null)
        {
            UpdateStatus("Error: Display control not initialized");
            return;
        }

        try
        {
            UpdateStatus($"Starting VICE from: {viceExecutablePath}");

            var options = new ViceHeadlessOptions
            {
                EnableFramebufferCapture = true,
                FramebufferWidth = 384,
                FramebufferHeight = 272,
                SoundDevice = "dummy",
                MonitorPort = 6510
            };

            _displayControl.ViceOutput += (s, e) =>
            {
                Dispatcher.UIThread.Post(() => UpdateStatus($"VICE: {e}"));
            };

            _displayControl.ViceError += (s, e) =>
            {
                Dispatcher.UIThread.Post(() => UpdateStatus($"ERROR: {e}"));
            };

            await _displayControl.StartViceAsync(viceExecutablePath, null, options);
            UpdateStatus("VICE started successfully");
        }
        catch (Exception ex)
        {
            UpdateStatus($"Failed to start VICE: {ex.Message}");
        }
    }

    private void UpdateStatus(string message)
    {
        if (_statusText != null)
        {
            _statusText.Text = $"{DateTime.Now:HH:mm:ss} - {message}";
        }
    }

    protected override void OnClosed(EventArgs e)
    {
        base.OnClosed(e);
        
        if (_displayControl != null)
        {
            _ = _displayControl.StopViceAsync();
        }
    }
}
