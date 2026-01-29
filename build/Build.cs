using System;
using System.IO.Compression;
using Serilog;
using Nuke.Common;
using Nuke.Common.CI.GitHubActions;
using Nuke.Common.ProjectModel;
using Nuke.Common.Tooling;
using Nuke.Common.Tools.DotNet;
using Nuke.Common.IO;
using static Nuke.Common.IO.FileSystemTasks;
using static Nuke.Common.Tools.DotNet.DotNetTasks;

/// <summary>
/// Build platforms for VICE and C64OS IDE
/// </summary>
public enum BuildPlatform
{
    /// <summary>Build for Windows only (default)</summary>
    Windows,
    /// <summary>Build for Linux only</summary>
    Linux,
    /// <summary>Build for both Windows and Linux</summary>
    Both
}

[GitHubActions(
    "ci",
    GitHubActionsImage.UbuntuLatest,
    OnPushBranches = new[] { "main" },
    InvokedTargets = new[] { nameof(Compile) })]
class Build : NukeBuild
{
    public static int Main() => Execute<Build>(x => x.Compile);

    [Parameter("Configuration to build - Default is 'Release'")]
    readonly Configuration Configuration = Configuration.Release;

    [Parameter("Target runtime identifier (win10-x64 or linux-x64)")]
    readonly string TargetRid = "win10-x64";

    [Parameter("Platform to build (Windows, Linux, Both) - Default is Windows")]
    readonly BuildPlatform Platform = BuildPlatform.Windows;

    [Solution]
    readonly Solution Solution;

    AbsolutePath SourceDirectory => RootDirectory / "src";
    AbsolutePath ArtifactsDirectory => RootDirectory / "artifacts";

    Target Restore => _ => _
        .Executes(() =>
        {
            if (Solution != null)
                DotNetRestore(s => s.SetProjectFile(Solution));
            else
                Log.Information("No solution found yet - skip Restore");
        });

    Target Compile => _ => _
        .DependsOn(Restore)
        .Executes(() =>
        {
            if (Solution != null)
                DotNetBuild(s => s.SetProjectFile(Solution).SetConfiguration(Configuration).EnableNoRestore());
            else
                Log.Information("No solution found yet - skip Compile");
        });

    Target Test => _ => _
        .DependsOn(Compile)
        .Executes(() =>
        {
            if (Solution != null)
                DotNetTest(s => s.SetProjectFile(Solution).SetConfiguration(Configuration).EnableNoBuild());
            else
                Log.Information("No solution found yet - skip Test");
        });

    Target BuildVice => _ => _
        .Description("Build VICE for specified platform(s) (use --Platform Windows|Linux|Both)")
        .Executes(() =>
        {
            bool buildWindows = Platform == BuildPlatform.Windows || Platform == BuildPlatform.Both;
            bool buildLinux = Platform == BuildPlatform.Linux || Platform == BuildPlatform.Both;

            Log.Information($"Building VICE for: {Platform}");

            if (buildWindows)
            {
                BuildViceForWindows();
            }

            if (buildLinux)
            {
                BuildViceForLinux();
            }

            if (!buildWindows && !buildLinux)
            {
                Logger.Warn("No platform selected for build");
            }
        });

    void BuildViceForWindows()
    {
        var sourceDir = RootDirectory / "third_party" / "vice" / "vice";
        var destDir = ArtifactsDirectory / "vice" / "win-x64";
        var jobs = Environment.ProcessorCount;
        var script = RootDirectory / "build" / "vice" / "build-mingw64.ps1";

        if (!script.FileExists())
        {
            Logger.Warn("MinGW64 build script not found: " + script);
            return;
        }

        if (!sourceDir.DirectoryExists())
        {
            Logger.Warn("VICE source directory not found: " + sourceDir);
            return;
        }

        // Clean only the Windows x64 artifacts directory
        destDir.CreateOrCleanDirectory();

        // Clean Windows out-of-source build directory
        var winBuildDir = RootDirectory / "third_party" / "vice" / "vice" / "build" / "win-x64";
        if (winBuildDir.DirectoryExists())
            winBuildDir.DeleteDirectory();

        Log.Information("Building VICE with MinGW64 for Windows x64");
        Log.Information($"  Source: {sourceDir}");
        Log.Information($"  Destination: {destDir}");
        Log.Information($"  Parallel jobs: {jobs}");
        Console.WriteLine();
        Console.WriteLine();
        Console.WriteLine("=== Build starting (output below) ===");
        Console.WriteLine();

        // Run PowerShell script directly - it handles MSYS2 properly
        var exitCode = ProcessTasks.StartProcess(
            "pwsh",
            $"-NoProfile -ExecutionPolicy Bypass -Command \"& '{script}' -SourceDir '{sourceDir}' -DestDir '{destDir}' -Jobs {jobs}\"",
            logOutput: true)
            .AssertZeroExitCode()
            .ExitCode;

        Console.WriteLine();
        Log.Information("VICE Windows build completed successfully");

        // Set up default configuration files
        SetupViceWindowsConfig();
    }

    void SetupViceWindowsConfig()
    {
        try
        {
            // Get AppData directory
            var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            var viceConfigDir = Path.Combine(appData, "vice");
            var sourceDataDir = RootDirectory / "third_party" / "vice" / "vice" / "data";

            Directory.CreateDirectory(viceConfigDir);

            var viceRcPath = Path.Combine(viceConfigDir, "vicerc");
            var defaultViceRcPath = RootDirectory / "build" / "vice" / "default_vicerc";

            if (File.Exists(defaultViceRcPath))
            {
                if (!File.Exists(viceRcPath))
                {
                    File.Copy(defaultViceRcPath, viceRcPath);
                    Log.Information($"Created default vicerc: {viceRcPath}");
                }
                else
                {
                    Log.Information($"vicerc already exists: {viceRcPath}");
                }
            }

            // Copy ROM files to config directory
            if (Directory.Exists(sourceDataDir))
            {
                var romDirs = Directory.GetDirectories(sourceDataDir);
                foreach (var romDir in romDirs)
                {
                    var dirName = Path.GetFileName(romDir);
                    var destRomDir = Path.Combine(viceConfigDir, dirName);
                    Directory.CreateDirectory(destRomDir);

                    // Copy .bin ROM files
                    var binFiles = Directory.GetFiles(romDir, "*.bin");
                    foreach (var binFile in binFiles)
                    {
                        var destFile = Path.Combine(destRomDir, Path.GetFileName(binFile));
                        if (!File.Exists(destFile))
                        {
                            File.Copy(binFile, destFile);
                        }
                    }
                }
                Log.Information($"ROM files copied to: {viceConfigDir}");
            }

            // Copy font files to config directory
            var commonDataDir = sourceDataDir / "common";
            if (Directory.Exists(commonDataDir))
            {
                var destFontDir = Path.Combine(viceConfigDir, "common");
                Directory.CreateDirectory(destFontDir);

                var fontFiles = Directory.GetFiles(commonDataDir, "*.ttf");
                foreach (var fontFile in fontFiles)
                {
                    var destFile = Path.Combine(destFontDir, Path.GetFileName(fontFile));
                    if (!File.Exists(destFile))
                    {
                        File.Copy(fontFile, destFile);
                    }
                }
                Log.Information($"Font files copied to: {destFontDir}");
            }
        }
        catch (Exception ex)
        {
            Logger.Warn($"Failed to set up VICE config: {ex.Message}");
        }
    }

    void BuildViceForLinux()
    {
        var sourceDir = RootDirectory / "third_party" / "vice" / "vice";
        var destDir = ArtifactsDirectory / "vice" / "linux-x64";
        var jobs = Environment.ProcessorCount;
        var script = RootDirectory / "build" / "vice" / "build.sh";

        if (!script.FileExists())
        {
            Logger.Warn("Linux build script not found: " + script);
            return;
        }

        if (!sourceDir.DirectoryExists())
        {
            Logger.Warn("VICE source directory not found: " + sourceDir);
            return;
        }

        // Clean only the Linux x64 artifacts directory
        destDir.CreateOrCleanDirectory();

        // Clean Linux out-of-source build directory
        var linuxBuildDir = RootDirectory / "third_party" / "vice" / "vice" / "build" / "linux-x64";
        if (linuxBuildDir.DirectoryExists())
            linuxBuildDir.DeleteDirectory();

        Log.Information("Building VICE for Linux x64");
        Log.Information($"  Source: {sourceDir}");
        Log.Information($"  Destination: {destDir}");
        Log.Information($"  Parallel jobs: {jobs}");
        Console.WriteLine();
        Console.WriteLine("=== Build output (real-time) ===");
        Console.WriteLine();

        // Convert Windows paths to WSL paths for bash
        string ConvertToWslPath(string windowsPath)
        {
            // E:\github\... -> /mnt/e/github/...
            if (windowsPath.Length >= 2 && windowsPath[1] == ':')
            {
                var drive = char.ToLower(windowsPath[0]);
                var path = windowsPath.Substring(2).Replace('\\', '/');
                return $"/mnt/{drive}{path}";
            }
            return windowsPath.Replace('\\', '/');
        }

        var wslScript = ConvertToWslPath(script);
        var wslSourceDir = ConvertToWslPath(sourceDir);
        var wslDestDir = ConvertToWslPath(destDir);

        // Let bash output directly to console
        var process = ProcessTasks.StartProcess(
            "bash",
            $"{wslScript} {wslSourceDir} {wslDestDir} {jobs}");

        process.AssertZeroExitCode();

        Console.WriteLine();
        Log.Information("VICE Linux build completed successfully");
    }

    Target RebuildAll => _ => _
        .Description("Clean entire solution and all VICE artifacts, then build everything (Windows & Linux)")
        .Executes(() =>
        {
            Log.Information("========================================");
            Log.Information("REBUILD ALL - Clean & Full Build");
            Log.Information("========================================");
            Console.WriteLine();

            // Clean entire VICE artifacts directory
            Log.Information("Cleaning VICE artifacts directory...");
            var viceArtifacts = ArtifactsDirectory / "vice";
            if (viceArtifacts.DirectoryExists())
            {
                viceArtifacts.DeleteDirectory();
                Log.Information($"✓ Cleaned: {viceArtifacts}");
            }

            // Clean VICE out-of-source build directories
            Log.Information("Cleaning VICE build directories...");
            var viceBuildRoot = RootDirectory / "third_party" / "vice" / "vice" / "build";
            var viceWinBuild = viceBuildRoot / "win-x64";
            var viceLinuxBuild = viceBuildRoot / "linux-x64";

            if (viceWinBuild.DirectoryExists())
            {
                viceWinBuild.DeleteDirectory();
                Log.Information($"✓ Cleaned: {viceWinBuild}");
            }
            if (viceLinuxBuild.DirectoryExists())
            {
                viceLinuxBuild.DeleteDirectory();
                Log.Information($"✓ Cleaned: {viceLinuxBuild}");
            }

            // Clean entire solution artifacts directory
            Log.Information("Cleaning solution artifacts directory...");
            if (ArtifactsDirectory.DirectoryExists())
            {
                var publishDir = ArtifactsDirectory / "publish";
                var packageDir = ArtifactsDirectory / "package";

                if (publishDir.DirectoryExists())
                    publishDir.DeleteDirectory();
                if (packageDir.DirectoryExists())
                    packageDir.DeleteDirectory();

                Log.Information($"✓ Cleaned: {publishDir} and {packageDir}");
            }

            Console.WriteLine();
            Log.Information("Building VICE for Windows...");
            BuildViceForWindows();

            Console.WriteLine();
            Log.Information("Building VICE for Linux...");
            BuildViceForLinux();

            Console.WriteLine();
            Log.Information("Restoring solution dependencies...");
            if (Solution != null)
                DotNetRestore(s => s.SetProjectFile(Solution));

            Console.WriteLine();
            Log.Information("Building solution for Windows...");
            if (Solution != null)
                DotNetBuild(s => s
                    .SetProjectFile(Solution)
                    .SetConfiguration(Configuration)
                    .SetRuntime("win-x64")
                    .EnableNoRestore());

            Console.WriteLine();
            Log.Information("Building solution for Linux...");
            if (Solution != null)
                DotNetBuild(s => s
                    .SetProjectFile(Solution)
                    .SetConfiguration(Configuration)
                    .SetRuntime("linux-x64")
                    .EnableNoRestore());

            Console.WriteLine();
            Log.Information("========================================");
            Log.Information("✓ REBUILD ALL COMPLETED SUCCESSFULLY");
            Log.Information("========================================");
        });

    Target BuildViceMinGW64 => _ => _
        .Description("Build VICE with MinGW64 for Windows x64 (explicit target)")
        .Executes(() =>
        {
            var sourceDir = RootDirectory / "third_party" / "vice" / "vice";
            var destDir = ArtifactsDirectory / "vice" / "win-x64";
            var jobs = Environment.ProcessorCount;
            var script = RootDirectory / "build" / "vice" / "build-mingw64.ps1";

            if (!script.FileExists())
            {
                Logger.Warn("MinGW64 build script not found: " + script.ToString());
                return;
            }

            if (!sourceDir.DirectoryExists())
            {
                Logger.Warn("VICE source directory not found: " + sourceDir.ToString());
                return;
            }

            Log.Information("Building VICE with MinGW64 for Windows x64");
            Log.Information("Source: " + sourceDir.ToString());
            Log.Information("Destination: " + destDir.ToString());
            Log.Information("Parallel jobs: " + jobs);

            ProcessTasks.StartProcess("pwsh",
                "-NoProfile -ExecutionPolicy Bypass -File \"" + script.ToString() + "\" -SourceDir \"" + sourceDir.ToString() + "\" -DestDir \"" + destDir.ToString() + "\" -Jobs " + jobs)
                .AssertZeroExitCode();

            Log.Information("VICE MinGW64 build completed successfully");

            // Verify binaries
            if (destDir.DirectoryExists())
            {
                var binaries = Directory.EnumerateFiles(destDir.ToString(), "*.exe");
                if (binaries.Any())
                {
                    Log.Information("Generated binaries:");
                    foreach (var binary in binaries)
                    {
                        var fileInfo = new FileInfo(binary);
                        var sizeMB = fileInfo.Length / (1024.0 * 1024.0);
                        Log.Information("  " + fileInfo.Name + " (" + sizeMB.ToString("F2") + " MB)");
                    }
                }
                else
                {
                    Logger.Warn("No .exe files found in " + destDir.ToString());
                }
            }
        });

    Target PackWindows => _ => _
        .DependsOn(Compile)
        .Description("Pack Windows ZIP including VICE artifacts")
        .OnlyWhenDynamic(() => Platform == BuildPlatform.Windows || Platform == BuildPlatform.Both)
        .Executes(() =>
        {
            var rid = "win-x64";
            var publishDir = ArtifactsDirectory / "publish" / rid;
            publishDir.CreateOrCleanDirectory();
            Log.Information("Packing application for " + rid);

            var projectPath = Solution != null
                ? Solution.Path
                : SourceDirectory / "C64OS.IDE.App" / "C64OS.IDE.App.csproj";

            DotNetPublish(s => s
                .SetProject(projectPath)
                .SetConfiguration(Configuration)
                .SetFramework("net9.0")
                .SetRuntime(rid)
                .EnableNoRestore()
                .SetOutput(publishDir));

            var viceSrc = ArtifactsDirectory / "vice" / rid;
            if (viceSrc.DirectoryExists())
            {
                viceSrc.Copy(publishDir / "vice", ExistsPolicy.MergeAndOverwrite);
            }

            var zipPath = ArtifactsDirectory / "package" / rid / ("C64OS.IDE-" + rid + ".zip");
            zipPath.Parent.CreateDirectory();
            ZipFile.CreateFromDirectory(publishDir, zipPath);
            Log.Information("Created package: " + zipPath);
        });

    Target PackLinux => _ => _
        .DependsOn(Compile)
        .Description("Pack Linux ZIP including VICE artifacts")
        .OnlyWhenDynamic(() => Platform == BuildPlatform.Linux || Platform == BuildPlatform.Both)
        .Executes(() =>
        {
            var rid = "linux-x64";
            var publishDir = ArtifactsDirectory / "publish" / rid;
            publishDir.CreateOrCleanDirectory();
            Logger.Info("Packing application for " + rid);

            var projectPath = Solution != null
                ? Solution.Path
                : SourceDirectory / "C64OS.IDE.App" / "C64OS.IDE.App.csproj";

            DotNetPublish(s => s
                .SetProject(projectPath)
                .SetConfiguration(Configuration)
                .SetFramework("net9.0")
                .SetRuntime(rid)
                .EnableNoRestore()
                .SetOutput(publishDir));

            var viceSrc = ArtifactsDirectory / "vice" / rid;
            if (viceSrc.DirectoryExists())
            {
                viceSrc.Copy(publishDir / "vice", ExistsPolicy.MergeAndOverwrite);
            }

            var zipPath = ArtifactsDirectory / "package" / rid / ("C64OS.IDE-" + rid + ".zip");
            zipPath.Parent.CreateDirectory();
            ZipFile.CreateFromDirectory(publishDir, zipPath);
            Logger.Info("Created package: " + zipPath);
        });

    Target Pack => _ => _
        .DependsOn(PackWindows, PackLinux)
        .Description("Pack for selected platform(s) (use --Platform Windows|Linux|Both)")
        .Executes(() =>
        {
            Log.Information($"Packaging completed for: {Platform}");
        });

    Target Publish => _ => _
        .DependsOn(Pack)
        .Description("Publish packages to release artifacts")
        .Executes(() =>
        {
            Log.Information($"Publish step for {Platform} - implement upload to release or artifact storage");
        });
}
