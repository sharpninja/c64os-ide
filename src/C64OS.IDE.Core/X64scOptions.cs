namespace C64OS.IDE.Core
{
    /// <summary>Common x64sc option names for use with <see cref="X64scOptions.Options"/>.</summary>
    public static class X64scOptionNames
    {
        public const string Directory = "directory";
        public const string Config = "config";
        public const string LogFile = "logfile";
        public const string LogLimit = "loglimit";
        public const string Silent = "silent";
        public const string Verbose = "verbose";
        public const string Debug = "debug";
        public const string Sound = "sound";
        public const string SoundDevice = "sounddev";
        public const string SoundRate = "soundrate";
        public const string SoundVolume = "soundvolume";
        public const string Autostart = "autostart";
        public const string Autoload = "autoload";
        public const string LimitCycles = "limitcycles";
        public const string Seed = "seed";
        public const string Chdir = "chdir";
        public const string TapeImage = "1";
        public const string DiskImage8 = "8";
        public const string DiskImage9 = "9";
        public const string DiskImage10 = "10";
        public const string DiskImage11 = "11";
    }

    /// <summary>
    /// Options object for all VICE x64sc command-line options.
    /// Use <see cref="Directory"/> and <see cref="WorkingDirectory"/> for paths;
    /// use <see cref="Options"/> for any -option / -option value / +option, or
    /// <see cref="Arguments"/> for raw argv.
    /// </summary>
    public sealed class X64scOptions
    {
        /// <summary>Data directory for ROMs, keymaps, shaders, etc. Emitted as -directory &lt;path&gt;.</summary>
        public string? Directory { get; set; }

        /// <summary>Working directory for the emulator process (not passed to x64sc).</summary>
        public string? WorkingDirectory { get; set; }

        /// <summary>
        /// Structured options: key = option name without leading -/+ (e.g. "sound", "sounddev", "silent").
        /// Value: string/int/long → -key value; true → -key; false → +key; null = omit.
        /// Covers all VICE options (e.g. sounddev, sound, silent, verbose, config, autostart, etc.).
        /// </summary>
        public IReadOnlyDictionary<string, object?>? Options { get; set; }

        /// <summary>
        /// Raw argument list appended after Directory and Options (e.g. "-sounddev", "dummy", "-silent").
        /// Use for options not expressed via <see cref="Options"/> or for exact ordering.
        /// </summary>
        public IReadOnlyList<string>? Arguments { get; set; }

        /// <summary>
        /// Builds the full sequence of command-line arguments for x64sc (excluding the executable path).
        /// Order: -directory (if set), then Options entries, then Arguments.
        /// </summary>
        public IEnumerable<string> GetArguments()
        {
            if (!string.IsNullOrEmpty(Directory))
            {
                yield return "-directory";
                yield return Directory;
            }

            if (Options != null)
            {
                foreach (var kv in Options)
                {
                    if (kv.Value == null) continue;
                    var key = kv.Key.TrimStart('-', '+');
                    if (string.IsNullOrEmpty(key)) continue;

                    if (kv.Value is bool b)
                    {
                        yield return b ? "-" + key : "+" + key;
                    }
                    else
                    {
                        yield return "-" + key;
                        yield return kv.Value.ToString() ?? "";
                    }
                }
            }

            if (Arguments != null)
            {
                foreach (var a in Arguments)
                    yield return a;
            }
        }
    }
}
