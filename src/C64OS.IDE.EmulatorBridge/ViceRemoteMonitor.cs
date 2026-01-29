using System;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace C64OS.IDE.EmulatorBridge
{
    /// <summary>
    /// Client for VICE remote monitor protocol.
    /// Allows sending commands and receiving responses from VICE over TCP.
    /// </summary>
    public class ViceRemoteMonitor : IDisposable
    {
        private TcpClient? _client;
        private NetworkStream? _stream;
        private readonly string _host;
        private readonly int _port;
        private bool _isConnected;
        private readonly SemaphoreSlim _sendLock = new(1, 1);

        public event EventHandler<string>? ResponseReceived;
        public event EventHandler? Disconnected;

        public bool IsConnected => _isConnected && _client?.Connected == true;

        public ViceRemoteMonitor(string host = "127.0.0.1", int port = 6510)
        {
            _host = host;
            _port = port;
        }

        /// <summary>
        /// Connects to the VICE remote monitor.
        /// </summary>
        public async Task<bool> ConnectAsync(CancellationToken cancellationToken = default)
        {
            if (_isConnected)
                return true;

            try
            {
                _client = new TcpClient();
                await _client.ConnectAsync(_host, _port, cancellationToken);
                _stream = _client.GetStream();
                _isConnected = true;

                // Start listening for responses
                _ = Task.Run(() => ListenForResponses(cancellationToken), cancellationToken);

                return true;
            }
            catch
            {
                await DisconnectAsync();
                return false;
            }
        }

        /// <summary>
        /// Sends a command to VICE monitor.
        /// </summary>
        public async Task<bool> SendCommandAsync(string command, CancellationToken cancellationToken = default)
        {
            if (!IsConnected || _stream == null)
                return false;

            await _sendLock.WaitAsync(cancellationToken);
            try
            {
                var data = Encoding.ASCII.GetBytes(command + "\n");
                await _stream.WriteAsync(data, cancellationToken);
                await _stream.FlushAsync(cancellationToken);
                return true;
            }
            catch
            {
                await DisconnectAsync();
                return false;
            }
            finally
            {
                _sendLock.Release();
            }
        }

        /// <summary>
        /// Sets a breakpoint at a specific address.
        /// </summary>
        public Task<bool> SetBreakpointAsync(ushort address, CancellationToken cancellationToken = default)
        {
            return SendCommandAsync($"break ${address:X4}", cancellationToken);
        }

        /// <summary>
        /// Removes a breakpoint at a specific address.
        /// </summary>
        public Task<bool> RemoveBreakpointAsync(ushort address, CancellationToken cancellationToken = default)
        {
            return SendCommandAsync($"delete ${address:X4}", cancellationToken);
        }

        /// <summary>
        /// Reads memory at a specific address.
        /// </summary>
        public Task<bool> ReadMemoryAsync(ushort address, ushort length, CancellationToken cancellationToken = default)
        {
            return SendCommandAsync($"m ${address:X4} ${(address + length):X4}", cancellationToken);
        }

        /// <summary>
        /// Writes a byte to memory.
        /// </summary>
        public Task<bool> WriteMemoryAsync(ushort address, byte value, CancellationToken cancellationToken = default)
        {
            return SendCommandAsync($"> ${address:X4} {value:X2}", cancellationToken);
        }

        /// <summary>
        /// Disassembles code at a specific address.
        /// </summary>
        public Task<bool> DisassembleAsync(ushort address, ushort length, CancellationToken cancellationToken = default)
        {
            return SendCommandAsync($"d ${address:X4} ${(address + length):X4}", cancellationToken);
        }

        /// <summary>
        /// Steps one instruction (step into).
        /// </summary>
        public Task<bool> StepAsync(CancellationToken cancellationToken = default)
        {
            return SendCommandAsync("z", cancellationToken);
        }

        /// <summary>
        /// Steps over a subroutine call.
        /// </summary>
        public Task<bool> StepOverAsync(CancellationToken cancellationToken = default)
        {
            return SendCommandAsync("n", cancellationToken);
        }

        /// <summary>
        /// Returns from current subroutine.
        /// </summary>
        public Task<bool> StepOutAsync(CancellationToken cancellationToken = default)
        {
            return SendCommandAsync("ret", cancellationToken);
        }

        /// <summary>
        /// Continues execution until breakpoint.
        /// </summary>
        public Task<bool> ContinueAsync(CancellationToken cancellationToken = default)
        {
            return SendCommandAsync("x", cancellationToken);
        }

        /// <summary>
        /// Gets the current register values.
        /// </summary>
        public Task<bool> GetRegistersAsync(CancellationToken cancellationToken = default)
        {
            return SendCommandAsync("r", cancellationToken);
        }

        /// <summary>
        /// Resets the CPU.
        /// </summary>
        public Task<bool> ResetAsync(CancellationToken cancellationToken = default)
        {
            return SendCommandAsync("reset", cancellationToken);
        }

        /// <summary>
        /// Quits the monitor (returns to emulation).
        /// </summary>
        public Task<bool> QuitMonitorAsync(CancellationToken cancellationToken = default)
        {
            return SendCommandAsync("x", cancellationToken);
        }

        private async Task ListenForResponses(CancellationToken cancellationToken)
        {
            if (_stream == null)
                return;

            var buffer = new byte[4096];
            var messageBuilder = new StringBuilder();

            try
            {
                while (_isConnected && !cancellationToken.IsCancellationRequested)
                {
                    var bytesRead = await _stream.ReadAsync(buffer, cancellationToken);
                    
                    if (bytesRead == 0)
                    {
                        // Connection closed
                        break;
                    }

                    var text = Encoding.ASCII.GetString(buffer, 0, bytesRead);
                    messageBuilder.Append(text);

                    // Process complete lines
                    var message = messageBuilder.ToString();
                    var lines = message.Split('\n');
                    
                    for (int i = 0; i < lines.Length - 1; i++)
                    {
                        if (!string.IsNullOrWhiteSpace(lines[i]))
                        {
                            ResponseReceived?.Invoke(this, lines[i]);
                        }
                    }

                    // Keep the last incomplete line
                    messageBuilder.Clear();
                    if (lines.Length > 0)
                    {
                        messageBuilder.Append(lines[^1]);
                    }
                }
            }
            catch (OperationCanceledException)
            {
                // Normal cancellation
            }
            catch
            {
                // Connection error
            }
            finally
            {
                await DisconnectAsync();
            }
        }

        /// <summary>
        /// Disconnects from the VICE monitor.
        /// </summary>
        public async Task DisconnectAsync()
        {
            _isConnected = false;

            if (_stream != null)
            {
                await _stream.DisposeAsync();
                _stream = null;
            }

            _client?.Dispose();
            _client = null;

            Disconnected?.Invoke(this, EventArgs.Empty);
        }

        public void Dispose()
        {
            DisconnectAsync().Wait();
            _sendLock.Dispose();
        }
    }
}
