using System;
using ReactiveUI;

namespace C64OS.IDE.App.ViewModels;

public class MainWindowViewModel : ViewModelBase
{
    private string _title = "C64OS IDE";

    public string Title
    {
        get => _title;
        set => this.RaiseAndSetIfChanged(ref _title, value);
    }
}
