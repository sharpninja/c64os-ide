using System;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Net.Sockets;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace C64OS.IDE.EmulatorBridge
{
    /// <summary>
    /// Handles framebuffer capture from VICE emulator.
    /// Supports both remote monitor protocol and shared memory methods.
    /// </summary>
    public class ViceFramebufferCapture : IDisposable
    {
        private readonly int _width;
        private readonly int _height;
        private readonly int _stride;
        private byte[]? _frameBuffer;
        private bool _isDisposed;
        private IViceFramebufferProvider? _provider;

        public int Width => _width;
        public int Height => _height;
        public int BytesPerPixel => 4; // BGRA8888

        public ViceFramebufferCapture(int width, int height)
        {
            _width = width;
            _height = height;
            _stride = width * BytesPerPixel;
            _frameBuffer = new byte[_stride * height];
        }

        /// <summary>
        /// Initializes framebuffer capture with the specified method.
        /// </summary>
        public async Task<bool> InitializeAsync(FramebufferCaptureMethod method, int processId, string host = "127.0.0.1", int port = 6510)
        {
            _provider = method switch
            {
                FramebufferCaptureMethod.RemoteMonitor => new RemoteMonitorFramebufferProvider(host, port, _width, _height),
                FramebufferCaptureMethod.SharedMemory => new SharedMemoryFramebufferProvider(_width, _height),
                _ => throw new ArgumentException($"Unsupported capture method: {method}")
            };

            return await _provider.InitializeAsync(processId);
        }

        /// <summary>
        /// Captures the current frame from VICE.
        /// </summary>
        public async Task<byte[]?> CaptureFrameAsync()
        {
            if (_isDisposed)
                throw new ObjectDisposedException(nameof(ViceFramebufferCapture));

            if (_provider == null)
                return _frameBuffer; // Return last frame if no provider

            var capturedData = await _provider.CaptureFrameAsync();
            if (capturedData != null && capturedData.Length <= _frameBuffer!.Length)
            {
                Array.Copy(capturedData, _frameBuffer, capturedData.Length);
            }

            return _frameBuffer;
        }

        /// <summary>
        /// Copies raw framebuffer data into the internal buffer.
        /// This method would be called by the actual capture mechanism.
        /// </summary>
        /// <param name="sourceData">Raw pixel data (BGRA8888 format)</param>
        public void UpdateFrameBuffer(IntPtr sourceData, int length)
        {
            if (_isDisposed)
                throw new ObjectDisposedException(nameof(ViceFramebufferCapture));

            if (_frameBuffer == null || length > _frameBuffer.Length)
                throw new ArgumentException("Source data length exceeds framebuffer size");

            Marshal.Copy(sourceData, _frameBuffer, 0, length);
        }

        /// <summary>
        /// Copies raw framebuffer data into the internal buffer.
        /// </summary>
        public void UpdateFrameBuffer(byte[] sourceData)
        {
            if (_isDisposed)
                throw new ObjectDisposedException(nameof(ViceFramebufferCapture));

            if (_frameBuffer == null || sourceData.Length > _frameBuffer.Length)
                throw new ArgumentException("Source data length exceeds framebuffer size");

            Array.Copy(sourceData, _frameBuffer, sourceData.Length);
        }

        public void Dispose()
        {
            if (_isDisposed)
                return;

            _provider?.Dispose();
            _frameBuffer = null;
            _isDisposed = true;
        }
    }

    /// <summary>
    /// Capture method selection.
    /// </summary>
    public enum FramebufferCaptureMethod
    {
        RemoteMonitor,
        SharedMemory
    }

    /// <summary>
    /// Interface for platform-specific framebuffer capture implementations.
    /// </summary>
    public interface IViceFramebufferProvider : IDisposable
    {
        /// <summary>
        /// Initializes the framebuffer provider for a specific VICE process.
        /// </summary>
        Task<bool> InitializeAsync(int processId);

        /// <summary>
        /// Captures the current frame data.
        /// </summary>
        Task<byte[]?> CaptureFrameAsync();

        /// <summary>
        /// Gets the framebuffer dimensions.
        /// </summary>
        (int width, int height) GetDimensions();
    }

    /// <summary>
    /// Framebuffer capture via VICE remote monitor protocol extension.
    /// Requires VICE to be patched with custom "screendata" command.
    /// </summary>
    public class RemoteMonitorFramebufferProvider : IViceFramebufferProvider
    {
        private readonly string _host;
        private readonly int _port;
        private readonly int _width;
        private readonly int _height;
        private TcpClient? _client;
        private NetworkStream? _stream;
        private byte[]? _frameBuffer;
        private bool _isConnected;

        public RemoteMonitorFramebufferProvider(string host, int port, int width, int height)
        {
            _host = host;
            _port = port;
            _width = width;
            _height = height;
            _frameBuffer = new byte[width * height * 4];
        }

        public async Task<bool> InitializeAsync(int processId)
        {
            try
            {
                _client = new TcpClient();
                await _client.ConnectAsync(_host, _port);
                _stream = _client.GetStream();
                _isConnected = true;

                // Wait for VICE monitor prompt
                await Task.Delay(500);

                return true;
            }
            catch
            {
                _isConnected = false;
                return false;
            }
        }

        public async Task<byte[]?> CaptureFrameAsync()
        {
            if (!_isConnected || _stream == null || _frameBuffer == null)
                return null;

            try
            {
                // Send custom "screendata" command to VICE
                // This requires VICE to be patched with this command
                var command = Encoding.ASCII.GetBytes("screendata\n");
                await _stream.WriteAsync(command);
                await _stream.FlushAsync();

                // Read response header (format: "SCREEN:<size>\n")
                var headerBuffer = new byte[256];
                var headerBytesRead = await _stream.ReadAsync(headerBuffer, 0, headerBuffer.Length);
                var header = Encoding.ASCII.GetString(headerBuffer, 0, headerBytesRead);

                if (header.StartsWith("SCREEN:"))
                {
                    // Extract size from header
                    var sizeStr = header.Substring(7, header.IndexOf('\n') - 7);
                    if (int.TryParse(sizeStr, out int expectedSize))
                    {
                        // Read binary frame data
                        int totalRead = 0;
                        int remaining = Math.Min(expectedSize, _frameBuffer.Length);

                        while (totalRead < remaining)
                        {
                            var bytesRead = await _stream.ReadAsync(_frameBuffer, totalRead, remaining - totalRead);
                            if (bytesRead == 0)
                                break;
                            totalRead += bytesRead;
                        }

                        return _frameBuffer;
                    }
                }
            }
            catch
            {
                // Frame capture failed, return last frame
            }

            return _frameBuffer;
        }

        public (int width, int height) GetDimensions()
        {
            return (_width, _height);
        }

        public void Dispose()
        {
            _isConnected = false;
            _stream?.Dispose();
            _client?.Dispose();
        }
    }

    /// <summary>
    /// Framebuffer capture via shared memory.
    /// Uses platform-specific APIs (Windows: CreateFileMapping, Linux: shm_open).
    /// Requires VICE to be patched to write frames to shared memory.
    /// </summary>
    public class SharedMemoryFramebufferProvider : IViceFramebufferProvider
    {
        private readonly int _width;
        private readonly int _height;
        private string? _sharedMemoryName;
        private IntPtr _mappedView;
        private int _bufferSize;
        private bool _isWindows;

        public SharedMemoryFramebufferProvider(int width, int height)
        {
            _width = width;
            _height = height;
            _bufferSize = width * height * 4; // BGRA8888
            _isWindows = RuntimeInformation.IsOSPlatform(OSPlatform.Windows);
        }

        public async Task<bool> InitializeAsync(int processId)
        {
            _sharedMemoryName = $"VICE_Framebuffer_{processId}";

            try
            {
                if (_isWindows)
                {
                    return await InitializeWindowsAsync();
                }
                else
                {
                    return await InitializePosixAsync();
                }
            }
            catch
            {
                return false;
            }
        }

        private async Task<bool> InitializeWindowsAsync()
        {
            // Open existing shared memory created by VICE
            IntPtr hMapFile = NativeMethods.OpenFileMapping(
                NativeMethods.FILE_MAP_READ,
                false,
                _sharedMemoryName!);

            if (hMapFile == IntPtr.Zero)
            {
                // If it doesn't exist yet, wait and retry
                await Task.Delay(1000);
                hMapFile = NativeMethods.OpenFileMapping(
                    NativeMethods.FILE_MAP_READ,
                    false,
                    _sharedMemoryName!);

                if (hMapFile == IntPtr.Zero)
                    return false;
            }

            _mappedView = NativeMethods.MapViewOfFile(
                hMapFile,
                NativeMethods.FILE_MAP_READ,
                0,
                0,
                (UIntPtr)_bufferSize);

            NativeMethods.CloseHandle(hMapFile);

            return _mappedView != IntPtr.Zero;
        }

        private async Task<bool> InitializePosixAsync()
        {
            // Open existing shared memory created by VICE
            int fd = NativeMethods.shm_open(_sharedMemoryName!, NativeMethods.O_RDONLY, 0);
            if (fd == -1)
            {
                await Task.Delay(1000);
                fd = NativeMethods.shm_open(_sharedMemoryName!, NativeMethods.O_RDONLY, 0);
                if (fd == -1)
                    return false;
            }

            _mappedView = NativeMethods.mmap(
                IntPtr.Zero,
                (UIntPtr)_bufferSize,
                NativeMethods.PROT_READ,
                NativeMethods.MAP_SHARED,
                fd,
                0);

            NativeMethods.close(fd);

            return _mappedView != IntPtr.Zero && _mappedView != new IntPtr(-1);
        }

        public Task<byte[]?> CaptureFrameAsync()
        {
            if (_mappedView == IntPtr.Zero)
                return Task.FromResult<byte[]?>(null);

            try
            {
                var buffer = new byte[_bufferSize];
                Marshal.Copy(_mappedView, buffer, 0, _bufferSize);
                return Task.FromResult<byte[]?>(buffer);
            }
            catch
            {
                return Task.FromResult<byte[]?>(null);
            }
        }

        public (int width, int height) GetDimensions()
        {
            return (_width, _height);
        }

        public void Dispose()
        {
            if (_mappedView != IntPtr.Zero)
            {
                if (_isWindows)
                {
                    NativeMethods.UnmapViewOfFile(_mappedView);
                }
                else
                {
                    NativeMethods.munmap(_mappedView, (UIntPtr)_bufferSize);
                }
                _mappedView = IntPtr.Zero;
            }
        }
    }

    /// <summary>
    /// Native methods for shared memory operations.
    /// </summary>
    internal static class NativeMethods
    {
        // Windows APIs
        public const uint FILE_MAP_READ = 0x0004;

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern IntPtr OpenFileMapping(uint dwDesiredAccess, bool bInheritHandle, string lpName);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr MapViewOfFile(IntPtr hFileMappingObject, uint dwDesiredAccess, uint dwFileOffsetHigh, uint dwFileOffsetLow, UIntPtr dwNumberOfBytesToMap);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool UnmapViewOfFile(IntPtr lpBaseAddress);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool CloseHandle(IntPtr hObject);

        // POSIX APIs (Linux/macOS)
        public const int O_RDONLY = 0;
        public const int O_RDWR = 2;
        public const int PROT_READ = 1;
        public const int MAP_SHARED = 1;

        [DllImport("libc", SetLastError = true)]
        public static extern int shm_open(string name, int oflag, uint mode);

        [DllImport("libc", SetLastError = true)]
        public static extern IntPtr mmap(IntPtr addr, UIntPtr length, int prot, int flags, int fd, long offset);

        [DllImport("libc", SetLastError = true)]
        public static extern int munmap(IntPtr addr, UIntPtr length);

        [DllImport("libc", SetLastError = true)]
        public static extern int close(int fd);

        [DllImport("libc", SetLastError = true)]
        public static extern int shm_unlink(string name);
    }
}
