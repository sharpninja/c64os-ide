namespace C64OS.IDE.Core
{
    public record CompilationResult(bool Success, string? OutputPath, string[] Diagnostics);

    public interface ICompiler
    {
        CompilationResult Compile(string sourcePath);
    }

    public interface IEmitter
    {
        /// <summary>
        /// Emit TMPx assembly output from IR or intermediate form.
        /// Returns the path to emitted file.
        /// </summary>
        string EmitTMPx(object ir, string outputPath);
    }

    public interface IEmulatorHost
    {
        void Start(string viceExecutablePath, string workingDirectory);
        void Stop();
        void SendMonitorCommand(string command);
    }

    public interface IDebugAdapter
    {
        void SetBreakpoint(string filePath, int line);
        void RemoveBreakpoint(string filePath, int line);
        void StepOver();
        void StepIn();
        void StepOut();
    }
}
