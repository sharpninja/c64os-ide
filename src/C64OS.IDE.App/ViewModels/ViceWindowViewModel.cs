using System;
using ReactiveUI;

namespace C64OS.IDE.App.ViewModels;

public class ViceWindowViewModel : ViewModelBase
{
    private string _title = "VICE Emulator";
    private string _statusText = "Starting...";
    private string _viceExecutablePath;

    public ViceWindowViewModel(string viceExecutablePath)
    {
        _viceExecutablePath = viceExecutablePath;
    }

    public string Title
    {
        get => _title;
        set => this.RaiseAndSetIfChanged(ref _title, value);
    }

    public string StatusText
    {
        get => _statusText;
        set => this.RaiseAndSetIfChanged(ref _statusText, value);
    }

    public string ViceExecutablePath => _viceExecutablePath;
}
