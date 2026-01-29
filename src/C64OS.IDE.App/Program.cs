using System;
using C64OS.IDE.Core;

Console.WriteLine("C64OS IDE - minimal runner stub");

// This minimal runner is a placeholder for the Avalonia app.
// It demonstrates that the build/publish flow works and references core interfaces.

if (args.Length > 0 && args[0] == "--version")
{
    Console.WriteLine("C64OS IDE (stub) v0.1");
    return;
}

Console.WriteLine("No UI yet. Implement Avalonia App in src/C64OS.IDE.App later.");
