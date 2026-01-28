using System;
using Nuke.Common;
using Nuke.Common.CI.GitHubActions;
using Nuke.Common.ProjectModel;
using Nuke.Common.Tooling;
using Nuke.Common.Tools.DotNet;
using Nuke.Common.IO;
using static Nuke.Common.IO.FileSystemTasks;
using static Nuke.Common.Tools.DotNet.DotNetTasks;

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

    [Parameter("VICE source repository url")]
    readonly string ViceSource = "https://git.code.sf.net/p/vice-emu/code";

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
                Logger.Info("No solution found yet - skip Restore");
        });

    Target Compile => _ => _
        .DependsOn(Restore)
        .Executes(() =>
        {
            if (Solution != null)
                DotNetBuild(s => s.SetProjectFile(Solution).SetConfiguration(Configuration).EnableNoRestore());
            else
                Logger.Info("No solution found yet - skip Compile");
        });

    Target Test => _ => _
        .DependsOn(Compile)
        .Executes(() =>
        {
            if (Solution != null)
                DotNetTest(s => s.SetConfiguration(Configuration).EnableNoBuild());
            else
                Logger.Info("No solution found yet - skip Test");
        });

    Target BuildVice => _ => _
        .Description("Build VICE for the provided TargetRid using build/vice scripts")
        .OnlyWhenDynamic(() => !string.IsNullOrWhiteSpace(TargetRid))
        .Executes(() =>
        {
            var script = (TargetRid.StartsWith("win")) ? RootDirectory / "build" / "vice" / "build.ps1" : RootDirectory / "build" / "vice" / "build.sh";
            if (!FileExists(script))
            {
                Logger.Warn($"VICE build script not found: {script}");
                return;
            }

            var sourceDir = RootDirectory / "third_party" / "vice";
            var destDir = ArtifactsDirectory / "vice" / (TargetRid.StartsWith("win") ? "win-x64" : "linux-x64");
            var jobs = Environment.ProcessorCount;

            if (TargetRid.StartsWith("win"))
            {
                // Invoke PowerShell script with explicit arguments
                var args = new[] {
                    "-ExecutionPolicy", "Bypass",
                    "-File", script.ToString(),
                    "-SourceDir", sourceDir.ToString(),
                    "-DestDir", destDir.ToString(),
                    "-Jobs", jobs.ToString()
                };
                ProcessTasks.StartProcess("powershell", args).AssertZeroExitCode();
            }
            else
            {
                // Invoke bash script: script <source> <dest> <jobs>
                var args = new[] { script.ToString(), sourceDir.ToString(), destDir.ToString(), jobs.ToString() };
                ProcessTasks.StartProcess("bash", args).AssertZeroExitCode();
            }
        });

    Target PackWindows => _ => _
        .DependsOn(Compile)
        .Description("Pack Windows ZIP including VICE artifacts (expected in artifacts/vice/win10-x64)")
        .Executes(() =>
        {
            var rid = "win-x64";
            var dest = ArtifactsDirectory / "package" / rid;
            EnsureCleanDirectory(dest);
            Logger.Info($"Packing application for {rid} into {dest}");

            // Publish the .NET app for the target RID
            var publishDir = ArtifactsDirectory / "publish" / rid;
            EnsureCleanDirectory(publishDir);
            var projectToPublish = Solution != null ? (AbsolutePath?)Solution : SourceDirectory / "C64OS.IDE.App" / "C64OS.IDE.App.csproj";
            DotNetPublish(s => s
                .SetProjectFile(projectToPublish?.ToString() ?? string.Empty)
                .SetConfiguration(Configuration)
                .SetFramework("net9.0")
                .SetRuntime("win-x64")
                .EnableNoRestore()
                .SetOutput(publishDir));

            // Copy VICE artifacts if present
            var viceSrc = ArtifactsDirectory / "vice" / rid;
            if (Directory.Exists(viceSrc))
            {
                CopyDirectoryRecursively(viceSrc, publishDir / "vice", FileExistsPolicy.Overwrite);
            }

            // Create ZIP
            var zipPath = ArtifactsDirectory / "package" / rid / ($"C64OS.IDE-{rid}.zip");
            EnsureExistingDirectory(zipPath.Parent!);
            CompressionTasks.Zip(publishDir, zipPath);
            Logger.Info($"Created package: {zipPath}");
        });

    Target PackLinux => _ => _
        .DependsOn(Compile)
        .Description("Pack Linux ZIP including VICE artifacts (expected in artifacts/vice/linux-x64)")
        .Executes(() =>
        {
            var rid = "linux-x64";
            var dest = ArtifactsDirectory / "package" / rid;
            EnsureCleanDirectory(dest);
            Logger.Info($"Packing application for {rid} into {dest}");

            var publishDir = ArtifactsDirectory / "publish" / rid;
            EnsureCleanDirectory(publishDir);
            DotNetPublish(s => s
                .SetProjectFile(projectToPublish?.ToString() ?? string.Empty)
                .SetConfiguration(Configuration)
                .SetFramework("net9.0")
                .SetRuntime("linux-x64")
                .EnableNoRestore()
                .SetOutput(publishDir));

            var viceSrc = ArtifactsDirectory / "vice" / rid;
            if (Directory.Exists(viceSrc))
            {
                CopyDirectoryRecursively(viceSrc, publishDir / "vice", FileExistsPolicy.Overwrite);
            }

            var zipPath = ArtifactsDirectory / "package" / rid / ($"C64OS.IDE-{rid}.zip");
            EnsureExistingDirectory(zipPath.Parent!);
            CompressionTasks.Zip(publishDir, zipPath);
            Logger.Info($"Created package: {zipPath}");
        });

    Target Publish => _ => _
        .DependsOn(PackWindows, PackLinux)
        .Description("Publish packages to release artifacts")
        .Executes(() =>
        {
            Logger.Info("Publish step - implement upload to release or artifact storage");
        });
}
