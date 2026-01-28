using System;
using System.IO;
using System.Diagnostics;

var argsList = args.Length > 0 ? args : new[] { "pack-windows" };
var target = argsList[0].ToLowerInvariant();

string Root() => Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", ".."));
var root = Root();

void Run(string exe, string arguments)
{
    Console.WriteLine($"Running: {exe} {arguments}");
    var psi = new ProcessStartInfo(exe, arguments)
    {
        WorkingDirectory = root,
        RedirectStandardOutput = true,
        RedirectStandardError = true,
        UseShellExecute = false
    };
    var p = Process.Start(psi)!;
    p.OutputDataReceived += (s, e) => { if (e.Data != null) Console.WriteLine(e.Data); };
    p.ErrorDataReceived += (s, e) => { if (e.Data != null) Console.Error.WriteLine(e.Data); };
    p.BeginOutputReadLine();
    p.BeginErrorReadLine();
    p.WaitForExit();
    if (p.ExitCode != 0) throw new Exception($"Command failed: {exe} {arguments}");
}

try
{
    switch (target)
    {
        case "buildvice":
        case "build-vice":
            Run("powershell", $"-ExecutionPolicy Bypass -File build\\vice\\build.ps1 -SourceDir third_party/vice -DestDir artifacts/vice/win-x64 -Jobs {Environment.ProcessorCount}");
            break;
        case "pack-windows":
            // publish
            var projectPath = Path.Combine(root, "src", "C64OS.IDE.App", "C64OS.IDE.App.csproj");
            Console.WriteLine($"[DEBUG] Computed root: {root}");
            Console.WriteLine($"[DEBUG] Computed projectPath: {projectPath}");
            if (!File.Exists(projectPath))
            {
                Console.Error.WriteLine($"Project not found at expected location: {projectPath}");
                // Fallback: search for the project file recursively from root
                var found = Directory.GetFiles(root, "C64OS.IDE.App.csproj", SearchOption.AllDirectories);
                if (found.Length > 0)
                {
                    projectPath = found[0];
                    Console.WriteLine($"[DEBUG] Found project at: {projectPath}");
                }
                else
                {
                    Console.Error.WriteLine($"Project file C64OS.IDE.App.csproj not found anywhere under {root}");
                    Environment.Exit(1);
                }
            }
            var winPublishDir = Path.Combine(root, "artifacts", "publish", "win-x64");
            var winViceDir = Path.Combine(root, "artifacts", "vice", "win-x64");
            var winViceSource = Path.Combine(root, "third_party", "vice", "vice");
            var winPsScript = Path.Combine(root, "build", "vice", "build.ps1");
            Run("dotnet", $"publish \"{projectPath}\" -c Release -r win-x64 -o \"{winPublishDir}\"");
            Run("powershell", $"-ExecutionPolicy Bypass -File {winPsScript} {winViceSource} {winViceDir} {Environment.ProcessorCount}");
            // package
            var publishDir = Path.Combine(root, "artifacts", "publish", "win-x64");
            var viceDir = Path.Combine(root, "artifacts", "vice", "win-x64");
            var packageDir = Path.Combine(root, "artifacts", "package", "win-x64");
            if (Directory.Exists(packageDir)) Directory.Delete(packageDir, true);
            Directory.CreateDirectory(packageDir);
            Directory.CreateDirectory(Path.Combine(packageDir, "app"));
            if (Directory.Exists(publishDir)) CopyDir(publishDir, Path.Combine(packageDir, "app"));
            if (Directory.Exists(viceDir)) CopyDir(viceDir, Path.Combine(packageDir, "app", "vice"));
            var zipPath = Path.Combine(packageDir, "C64OS.IDE-win-x64.zip");
            if (File.Exists(zipPath)) File.Delete(zipPath);
            System.IO.Compression.ZipFile.CreateFromDirectory(Path.Combine(packageDir, "app"), zipPath);
            Console.WriteLine($"Created package: {zipPath}");
            break;
        case "pack-linux":
            // publish for linux-x64
            var projectPathLinux = Path.Combine(root, "src", "C64OS.IDE.App", "C64OS.IDE.App.csproj");
            Console.WriteLine($"[DEBUG] Computed root: {root}");
            Console.WriteLine($"[DEBUG] Computed projectPath: {projectPathLinux}");
            if (!File.Exists(projectPathLinux))
            {
                Console.Error.WriteLine($"Project not found at expected location: {projectPathLinux}");
                // Fallback: search for the project file recursively from root
                var found = Directory.GetFiles(root, "C64OS.IDE.App.csproj", SearchOption.AllDirectories);
                if (found.Length > 0)
                {
                    projectPathLinux = found[0];
                    Console.WriteLine($"[DEBUG] Found project at: {projectPathLinux}");
                }
                else
                {
                    Console.Error.WriteLine($"Project file C64OS.IDE.App.csproj not found anywhere under {root}");
                    Environment.Exit(1);
                }
            }
            var linuxPublishDir = Path.Combine(root, "artifacts", "publish", "linux-x64");
            var linuxViceDir = Path.Combine(root, "artifacts", "vice", "linux-x64");
            var linuxViceSource = Path.Combine(root, "third_party", "vice", "vice");
            var linuxShScript = Path.Combine(root, "build", "vice", "build.sh");
            Run("dotnet", $"publish \"{projectPathLinux}\" -c Release -r linux-x64 -o \"{linuxPublishDir}\"");
            Run("bash", $"{linuxShScript} {linuxViceSource} {linuxViceDir} {Environment.ProcessorCount}");
            // package
            var publishDirLinux = Path.Combine(root, "artifacts", "publish", "linux-x64");
            var viceDirLinux = Path.Combine(root, "artifacts", "vice", "linux-x64");
            var packageDirLinux = Path.Combine(root, "artifacts", "package", "linux-x64");
            if (Directory.Exists(packageDirLinux)) Directory.Delete(packageDirLinux, true);
            Directory.CreateDirectory(packageDirLinux);
            Directory.CreateDirectory(Path.Combine(packageDirLinux, "app"));
            if (Directory.Exists(publishDirLinux)) CopyDir(publishDirLinux, Path.Combine(packageDirLinux, "app"));
            if (Directory.Exists(viceDirLinux)) CopyDir(viceDirLinux, Path.Combine(packageDirLinux, "app", "vice"));
            var zipPathLinux = Path.Combine(packageDirLinux, "C64OS.IDE-linux-x64.zip");
            if (File.Exists(zipPathLinux)) File.Delete(zipPathLinux);
            System.IO.Compression.ZipFile.CreateFromDirectory(Path.Combine(packageDirLinux, "app"), zipPathLinux);
            Console.WriteLine($"Created package: {zipPathLinux}");
            break;
        default:
            Console.WriteLine($"Unknown target: {target}");
            break;
    }
}
catch (Exception ex)
{
    Console.Error.WriteLine(ex.Message);
    Environment.Exit(1);
}

static void CopyDir(string src, string dst)
{
    foreach (var dir in Directory.GetDirectories(src, "*", SearchOption.AllDirectories))
    {
        Directory.CreateDirectory(dir.Replace(src, dst));
    }
    foreach (var file in Directory.GetFiles(src, "*.*", SearchOption.AllDirectories))
    {
        File.Copy(file, file.Replace(src, dst), true);
    }
}
