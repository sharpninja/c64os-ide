using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using C64OS.IDE.Core;

namespace C64OS.IDE.EmulatorBridge
{
    /// <summary>
    /// Hosts VICE emulator in headless mode with framebuffer capture support.
    /// </summary>
    public class ViceHeadlessHost : IDisposable
    {
        private Process? _process;
        private ViceFramebufferCapture? _framebuffer;
        private bool _isRunning;
        private readonly SemaphoreSlim _commandLock = new(1, 1);

        public event EventHandler<ViceFrameEventArgs>? FrameAvailable;
        public event EventHandler<string>? OutputReceived;
        public event EventHandler<string>? ErrorReceived;

        public bool IsRunning => _isRunning && _process != null && !_process.HasExited;

        /// <summary>
        /// Starts VICE in headless mode with framebuffer access.
        /// </summary>
        /// <param name="viceExecutablePath">Path to x64sc executable</param>
        /// <param name="workingDirectory">Working directory for the emulator</param>
        /// <param name="options">VICE command-line options</param>
        public async Task StartAsync(string viceExecutablePath, string workingDirectory, ViceHeadlessOptions? options = null)
        {
            if (_isRunning)
                throw new InvalidOperationException("Emulator is already running");

            if (!File.Exists(viceExecutablePath))
                throw new FileNotFoundException("VICE executable not found", viceExecutablePath);

            options ??= new ViceHeadlessOptions();
            
            var effectiveWorkingDir = options.WorkingDirectory ?? workingDirectory;

            var psi = new ProcessStartInfo
            {
                FileName = viceExecutablePath,
                WorkingDirectory = effectiveWorkingDir,
                RedirectStandardInput = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            // Build arguments for headless mode
            foreach (var arg in BuildHeadlessArguments(options))
            {
                psi.ArgumentList.Add(arg);
            }

            _process = new Process { StartInfo = psi, EnableRaisingEvents = true };
            
            _process.OutputDataReceived += (s, e) => 
            {
                if (e.Data != null)
                {
                    OutputReceived?.Invoke(this, e.Data);
                }
            };
            
            _process.ErrorDataReceived += (s, e) => 
            {
                if (e.Data != null)
                {
                    ErrorReceived?.Invoke(this, e.Data);
                }
            };

            _process.Exited += (s, e) =>
            {
                _isRunning = false;
            };

            _process.Start();
            _process.BeginOutputReadLine();
            _process.BeginErrorReadLine();

            _isRunning = true;

            // Initialize framebuffer capture
            if (options.EnableFramebufferCapture)
            {
                _framebuffer = new ViceFramebufferCapture(options.FramebufferWidth, options.FramebufferHeight);
                
                // Initialize capture provider
                var captureMethod = options.CaptureMethod ?? FramebufferCaptureMethod.SharedMemory;
                await _framebuffer.InitializeAsync(captureMethod, _process.Id, "127.0.0.1", options.MonitorPort);
                
                _ = StartFrameCaptureLoop();
            }

            await Task.CompletedTask;
        }

        /// <summary>
        /// Stops the emulator.
        /// </summary>
        public async Task StopAsync()
        {
            _isRunning = false;

            await _commandLock.WaitAsync();
            try
            {
                if (_process != null && !_process.HasExited)
                {
                    _process.Kill(true);
                    await _process.WaitForExitAsync();
                }
            }
            catch { }
            finally
            {
                _process?.Dispose();
                _process = null;
                _commandLock.Release();
            }

            _framebuffer?.Dispose();
            _framebuffer = null;
        }

        /// <summary>
        /// Sends a command to the VICE monitor.
        /// </summary>
        public async Task SendMonitorCommandAsync(string command)
        {
            if (!IsRunning)
                throw new InvalidOperationException("Emulator is not running");

            await _commandLock.WaitAsync();
            try
            {
                await _process!.StandardInput.WriteLineAsync(command);
                await _process.StandardInput.FlushAsync();
            }
            finally
            {
                _commandLock.Release();
            }
        }

        /// <summary>
        /// Sends keyboard input to the emulator.
        /// </summary>
        public async Task SendKeyAsync(ViceKey key, bool pressed)
        {
            // VICE uses monitor commands for keyboard input in headless mode
            // Format: "keybuf 'char'" or specific key codes
            var command = pressed ? $"key down {(int)key}" : $"key up {(int)key}";
            await SendMonitorCommandAsync(command);
        }

        /// <summary>
        /// Loads a program into the emulator.
        /// </summary>
        public async Task LoadProgramAsync(string filePath)
        {
            if (!File.Exists(filePath))
                throw new FileNotFoundException("Program file not found", filePath);

            await SendMonitorCommandAsync($"load \"{filePath}\"");
        }

        /// <summary>
        /// Resets the emulator.
        /// </summary>
        public async Task ResetAsync(bool hard = false)
        {
            var command = hard ? "reset hard" : "reset soft";
            await SendMonitorCommandAsync(command);
        }

        private IEnumerable<string> BuildHeadlessArguments(ViceHeadlessOptions options)
        {
            // Data directory
            if (!string.IsNullOrEmpty(options.DataDirectory))
            {
                yield return "-directory";
                yield return options.DataDirectory;
            }

            // Sound configuration
            yield return "-sound";
            yield return "-sounddev";
            yield return options.SoundDevice ?? "dummy";
            
            if (options.SoundRate.HasValue)
            {
                yield return "-soundrate";
                yield return options.SoundRate.Value.ToString();
            }

            // Video configuration for headless mode
            yield return "-VICIIfilter";
            yield return "0"; // No filtering for faster capture

            // Monitor and control
            yield return "-remotemonitor";
            yield return "-remotemonitoraddress";
            yield return $"127.0.0.1:{options.MonitorPort}";

            // Additional options
            if (options.X64scOptions != null)
            {
                foreach (var arg in options.X64scOptions.GetArguments())
                {
                    yield return arg;
                }
            }

            // Custom arguments
            if (options.AdditionalArguments != null)
            {
                foreach (var arg in options.AdditionalArguments)
                {
                    yield return arg;
                }
            }
        }

        private async Task StartFrameCaptureLoop()
        {
            while (_isRunning && _framebuffer != null)
            {
                try
                {
                    var frameData = await _framebuffer.CaptureFrameAsync();
                    
                    if (frameData != null)
                    {
                        FrameAvailable?.Invoke(this, new ViceFrameEventArgs(frameData));
                    }

                    // Target 60 FPS
                    await Task.Delay(16);
                }
                catch (Exception ex)
                {
                    ErrorReceived?.Invoke(this, $"Frame capture error: {ex.Message}");
                }
            }
        }

        public void Dispose()
        {
            StopAsync().Wait();
            _commandLock.Dispose();
        }
    }

    /// <summary>
    /// Configuration options for headless VICE emulator.
    /// </summary>
    public class ViceHeadlessOptions
    {
        public string? DataDirectory { get; set; }
        public string? WorkingDirectory { get; set; }
        public string? SoundDevice { get; set; } = "dummy";
        public int? SoundRate { get; set; } = 44100;
        public int MonitorPort { get; set; } = 6510;
        public bool EnableFramebufferCapture { get; set; } = true;
        public FramebufferCaptureMethod? CaptureMethod { get; set; } = FramebufferCaptureMethod.SharedMemory;
        public int FramebufferWidth { get; set; } = 384;
        public int FramebufferHeight { get; set; } = 272;
        public X64scOptions? X64scOptions { get; set; }
        public string[]? AdditionalArguments { get; set; }
    }

    /// <summary>
    /// Event args for frame available events.
    /// </summary>
    public class ViceFrameEventArgs : EventArgs
    {
        public byte[] FrameData { get; }
        public int Width { get; }
        public int Height { get; }
        public DateTime Timestamp { get; }

        public ViceFrameEventArgs(byte[] frameData, int width = 384, int height = 272)
        {
            FrameData = frameData;
            Width = width;
            Height = height;
            Timestamp = DateTime.UtcNow;
        }
    }

    /// <summary>
    /// C64 keyboard key codes for VICE.
    /// </summary>
    public enum ViceKey
    {
        // Letter keys
        A = 10, B = 28, C = 20, D = 18, E = 14, F = 21, G = 26, H = 29,
        I = 33, J = 34, K = 37, L = 42, M = 36, N = 31, O = 38, P = 41,
        Q = 62, R = 17, S = 13, T = 22, U = 30, V = 31, W = 9, X = 23,
        Y = 25, Z = 12,
        
        // Number keys
        Num0 = 35, Num1 = 56, Num2 = 59, Num3 = 8, Num4 = 11, 
        Num5 = 16, Num6 = 19, Num7 = 24, Num8 = 27, Num9 = 32,
        
        // Special keys
        Space = 60,
        Return = 1,
        RunStop = 63,
        Restore = 0,
        F1 = 4,
        F3 = 5,
        F5 = 6,
        F7 = 3,
        CursorUpDown = 7,
        CursorLeftRight = 2,
        Delete = 0,
        Home = 51,
        Pound = 48,
        
        // Shift and control
        LeftShift = 15,
        RightShift = 52,
        Commodore = 61,
        Control = 58
    }
}
