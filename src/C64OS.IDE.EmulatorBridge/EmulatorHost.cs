using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using C64OS.IDE.Core;

namespace C64OS.IDE.EmulatorBridge
{
    public class EmulatorHost : IEmulatorHost, IDisposable
    {
        private Process? _process;

        public void Start(string viceExecutablePath, string workingDirectory)
        {
            if (!File.Exists(viceExecutablePath))
                throw new FileNotFoundException("VICE executable not found", viceExecutablePath);

            var psi = new ProcessStartInfo
            {
                FileName = viceExecutablePath,
                WorkingDirectory = workingDirectory,
                RedirectStandardInput = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            _process = new Process { StartInfo = psi, EnableRaisingEvents = true };
            _process.OutputDataReceived += (s, e) => { if (e.Data != null) Console.WriteLine($"[VICE] {e.Data}"); };
            _process.ErrorDataReceived += (s, e) => { if (e.Data != null) Console.Error.WriteLine($"[VICE-ERR] {e.Data}"); };
            _process.Start();
            _process.BeginOutputReadLine();
            _process.BeginErrorReadLine();
        }

        public void Stop()
        {
            try
            {
                if (_process != null && !_process.HasExited)
                {
                    _process.Kill(true);
                    _process.WaitForExit(3000);
                }
            }
            catch { }
            finally
            {
                _process?.Dispose();
                _process = null;
            }
        }

        public void SendMonitorCommand(string command)
        {
            if (_process == null || _process.HasExited)
                throw new InvalidOperationException("Emulator is not running");

            if (!_process.StartInfo.RedirectStandardInput)
                throw new InvalidOperationException("Standard input is not redirected");

            _process.StandardInput.WriteLine(command);
            _process.StandardInput.Flush();
        }

        public void Dispose()
        {
            Stop();
        }
    }
}
