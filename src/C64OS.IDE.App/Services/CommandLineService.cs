using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using C64OS.IDE.App.ViewModels;
using C64OS.IDE.App.Views;

namespace C64OS.IDE.App.Services;

/// <summary>
/// Service that processes command-line arguments and opens appropriate windows.
/// </summary>
public static class CommandLineService
{
    /// <summary>
    /// Processes command-line arguments after application startup.
    /// </summary>
    public static async Task ProcessCommandLineAsync(string[] args)
    {
        if (args.Length == 0)
            return;

        for (int i = 0; i < args.Length; i++)
        {
            var arg = args[i];

            if (arg.Equals("--StartVice", StringComparison.OrdinalIgnoreCase) ||
                arg.Equals("-StartVice", StringComparison.OrdinalIgnoreCase))
            {
                // Get the path to VICE executable
                string? vicePath = null;
                
                if (i + 1 < args.Length && !args[i + 1].StartsWith("-"))
                {
                    vicePath = args[i + 1];
                    i++; // Skip next argument
                }
                else
                {
                    // Try to find VICE in common locations
                    vicePath = FindViceExecutable();
                }

                if (!string.IsNullOrEmpty(vicePath))
                {
                    await OpenViceWindowAsync(vicePath);
                }
                else
                {
                    ShowError("VICE executable not found", 
                        "Please specify the path to x64sc executable:\n" +
                        "C64OS.IDE.App --StartVice <path-to-x64sc>");
                }
            }
        }
    }

    /// <summary>
    /// Opens a new window with VICE emulator.
    /// </summary>
    private static async Task OpenViceWindowAsync(string viceExecutablePath)
    {
        if (!File.Exists(viceExecutablePath))
        {
            ShowError("VICE not found", $"VICE executable not found at:\n{viceExecutablePath}");
            return;
        }

        var window = new ViceWindow
        {
            DataContext = new ViceWindowViewModel(viceExecutablePath)
        };

        // Show the window
        if (Application.Current?.ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            window.Show();
            
            // Start VICE after window is shown
            await window.StartViceAsync(viceExecutablePath);
        }
    }

    /// <summary>
    /// Attempts to find VICE executable in common locations.
    /// </summary>
    private static string? FindViceExecutable()
    {
        var isWindows = RuntimeInformation.IsOSPlatform(OSPlatform.Windows);
        var isLinux = RuntimeInformation.IsOSPlatform(OSPlatform.Linux);
        var isMacOS = RuntimeInformation.IsOSPlatform(OSPlatform.OSX);
        
        var possiblePaths = new List<string>();
        
        // Artifacts directory (from build)
        if (isWindows)
        {
            possiblePaths.Add(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "artifacts", "vice", "win-x64", "x64sc.exe"));
            possiblePaths.Add(Path.Combine(AppContext.BaseDirectory, "artifacts", "vice", "win-x64", "x64sc.exe"));
        }
        else if (isLinux)
        {
            possiblePaths.Add(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "artifacts", "vice", "linux-x64", "bin", "x64sc"));
            possiblePaths.Add(Path.Combine(AppContext.BaseDirectory, "artifacts", "vice", "linux-x64", "bin", "x64sc"));
        }
        else if (isMacOS)
        {
            possiblePaths.Add(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "artifacts", "vice", "osx-x64", "bin", "x64sc"));
            possiblePaths.Add(Path.Combine(AppContext.BaseDirectory, "artifacts", "vice", "osx-x64", "bin", "x64sc"));
        }
        
        // Common installation paths on Windows
        if (isWindows)
        {
            possiblePaths.Add(@"C:\Program Files\VICE\x64sc.exe");
            possiblePaths.Add(@"C:\Program Files (x86)\VICE\x64sc.exe");
            possiblePaths.Add(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "VICE", "x64sc.exe"));
        }
        
        // Common installation paths on Linux
        if (isLinux)
        {
            possiblePaths.Add("/usr/bin/x64sc");
            possiblePaths.Add("/usr/local/bin/x64sc");
            possiblePaths.Add("/opt/vice/bin/x64sc");
            possiblePaths.Add(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".local", "bin", "x64sc"));
        }
        
        // macOS
        if (isMacOS)
        {
            possiblePaths.Add("/Applications/VICE/x64sc");
            possiblePaths.Add("/usr/local/opt/vice/bin/x64sc");
            possiblePaths.Add("/opt/homebrew/bin/x64sc");
        }

        foreach (var path in possiblePaths)
        {
            try
            {
                var fullPath = Path.GetFullPath(path);
                if (File.Exists(fullPath))
                {
                    return fullPath;
                }
            }
            catch
            {
                // Ignore invalid paths
            }
        }

        return null;
    }

    /// <summary>
    /// Shows an error message to the user.
    /// </summary>
    private static void ShowError(string title, string message)
    {
        // In a real application, you would show a proper dialog
        // For now, write to console
        Console.Error.WriteLine($"{title}: {message}");
        
        // Try to show a window if possible
        if (Application.Current?.ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop &&
            desktop.MainWindow != null)
        {
            var msgBox = new Window
            {
                Title = title,
                Width = 400,
                Height = 200,
                Content = new TextBlock
                {
                    Text = message,
                    Margin = new Avalonia.Thickness(20),
                    TextWrapping = Avalonia.Media.TextWrapping.Wrap
                }
            };
            msgBox.ShowDialog(desktop.MainWindow);
        }
    }
}
