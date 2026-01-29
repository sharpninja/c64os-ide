using Avalonia;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml;
using C64OS.IDE.App.Services;
using C64OS.IDE.App.ViewModels;
using C64OS.IDE.App.Views;

namespace C64OS.IDE.App;

public partial class App : Application
{
    public override void Initialize()
    {
        AvaloniaXamlLoader.Load(this);
    }

    public override async void OnFrameworkInitializationCompleted()
    {
        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            desktop.MainWindow = new MainWindow
            {
                DataContext = new MainWindowViewModel(),
            };

            // Process command-line arguments after window is created
            await CommandLineService.ProcessCommandLineAsync(Program.CommandLineArgs);
        }

        base.OnFrameworkInitializationCompleted();
    }
}
