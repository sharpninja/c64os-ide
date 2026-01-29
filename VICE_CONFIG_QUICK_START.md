# VICE Configuration File - Quick Setup Reference

## ✅ Status: AUTOMATICALLY CREATED ON BUILD

After running `./build.cmd BuildVice --Platform Windows`, VICE config is ready at:

```
C:\Users\<your-username>\AppData\Roaming\vice\vicerc
```

## Default Locations by OS

| OS | Path | Notes |
|----|------|-------|
| **Windows** | `%APPDATA%\vice\vicerc` | Auto-created by build |
| **Linux** | `~/.config/vice/vicerc` | XDG standard |
| **macOS** | `~/.config/vice/vicerc` | XDG standard |

## What's In It

The default vicerc includes:
- ✅ GTK3 UI enabled
- ✅ Sound volume: 100%
- ✅ Joystick/input config
- ✅ Drive settings (1541 by default)
- ✅ Logging enabled

## Editing Configuration

1. Open vicerc with any text editor
2. Modify settings (format: `Name=Value`)
3. Save file
4. Run VICE - changes apply automatically

## Example: Disable Fullscreen

```ini
[GLOBAL]
FullscreenEnable=0  # Change 1 to 0
```

## Example: Increase Audio

```ini
SoundVolume=200  # Increase from 100
```

## Example: Different Disk Drive Type

```ini
Drive8Type=1571   # Use 1571 instead of 1541
```

## Reset to Defaults

Delete the vicerc file and rebuild:
```bash
rm $env:APPDATA\vice\vicerc
./build.cmd BuildVice --Platform Windows
```

## Accessing Configuration

The build process automatically:
1. ✅ Creates `%APPDATA%\vice` directory
2. ✅ Copies default vicerc template
3. ✅ Loads on next VICE run

**No manual steps required!**

## Quick Paths

Open vicerc quickly (PowerShell):
```powershell
notepad $env:APPDATA\vice\vicerc
```

View vicerc location:
```powershell
echo $env:APPDATA\vice
```

See all config files:
```powershell
dir $env:APPDATA\vice
```

## Build Output

You'll see in build log:
```
[INF] Created default vicerc: C:\Users\<user>\AppData\Roaming\vice\vicerc
```

This confirms configuration was set up successfully.

## Files Involved

| File | Purpose |
|------|---------|
| `build/vice/default_vicerc` | Configuration template |
| `build/vice/build-mingw64.sh` | Shell script to copy config |
| `build/Build.cs` | .NET build orchestration |

## Support

- See [VICE_DEFAULT_CONFIG_SETUP.md](VICE_DEFAULT_CONFIG_SETUP.md) for full details
- See [VICE_CONSOLE_LOGGING_QUICK_REF.md](VICE_CONSOLE_LOGGING_QUICK_REF.md) for console output info
