# x64sc Runtime Error Diagnosis

This document summarizes runtime errors when launching the built **x64sc** (VICE C64 emulator) from the source tree and how to fix them.

## Quick fix: run from build tree

From the VICE source tree, run x64sc with the data directory so ROMs, keymaps, shaders, and GTK resources are found:

```bash
cd third_party/vice/vice/src
./x64sc -directory ../data
```

Use an absolute path if running from elsewhere:

```bash
/path/to/third_party/vice/vice/src/x64sc -directory /path/to/third_party/vice/vice/data
```

---

## Error summary and causes

### 1. **Fatal: Couldn't load kernal ROM / Machine initialization failed**

- **Cause:** x64sc looks for C64 ROMs (kernal, basic, chargen) under its *system file search path*. By default that path includes:
  - `~/.local/share/vice`
  - directory of the executable (`src/` when running from build)
  - `VICE_DATADIR` (compile-time, usually `/usr/local/share/vice`)
- **Fix:** Either:
  - Use **`-directory ../data`** (relative to `src/`) so the path includes `data/C64` and `data/DRIVES`, or
  - Copy or symlink `data/C64` and `data/DRIVES` into `src/` (symlinks from `src/` did not resolve correctly in testing on WSL).

### 2. **Keymap: Default keymap not found**

- **Cause:** Keymap files (e.g. `gtk3_sym.vkm`) are under `data/C64/`. If the system path does not include the data tree, they are not found.
- **Fix:** Same as ROMs: **`-directory ../data`** (or install so files are under `VICE_DATADIR`).

### 3. **failed to find resource data 'vice.gresource'**

- **Cause:** The GTK3 UI loads `data/common/vice.gresource` via the same system file path (subpath `common`). If the path does not include the data tree, the file is not found.
- **Fix:** **`-directory ../data`** so the path includes `data/common/`.

### 4. **failed to find resource data 'C64_Pro_Mono-STYLE.ttf' / failed to register CBM font**

- **Cause:** CBM font and other resources are also located using the system path (e.g. under `data/common/`).
- **Fix:** **`-directory ../data`**.

### 5. **Could not open vertex shader: viewport.vert**

- **Cause:** OpenGL shaders under `data/GLSL/` are loaded relative to the same data location (from `archdep_get_vice_datadir()` or equivalent). When the system path is set with `-directory ../data`, the effective data root is the data directory, so shaders are found there.
- **Fix:** **`-directory ../data`** (or install so `VICE_DATADIR` points to the data tree).

### 6. **DriveROM: 2000 / 4000 / CMDHD ROM image not found**

- **Cause:** Optional drive ROMs for 1541-II, 4040, CMD HD, etc. are missing. Standard 1541 emulation does not require them.
- **Fix:** Optional. Ignore unless you need those specific drives, or add the corresponding ROMs under `data/DRIVES/` (see VICE docs for filenames).

### 7. **Gdk-CRITICAL: gdk_frame_clock_idle_end_updating**

- **Cause:** GTK internal assertion; can appear during startup/shutdown.
- **Fix:** Usually harmless. If the window opens and the emulator runs, it can be ignored.

### 8. **glXSwapIntervalMESA(1) failed / scandir() failed on /dev/input**

- **Cause:** VSync or input enumeration issues; on WSL, `/dev/input` often does not exist and sound/joystick may be limited.
- **Fix:** Cosmetic or environment-specific. Emulator can still run; use host sound/input if needed.

### 9. **ALSA: Unknown PCM default**

- **Cause:** No ALSA default sound device (common in WSL or headless environments).
- **Fix:** Use **`-sounddev dummy`** to avoid ALSA entirely, or **`+sound`** to disable sound. Does not block C64 emulation.

### 10. **Requested graphics output driver PNG not found / Invalid or unset autosave screenshot format**

- **Cause:** When running with `-help` or during early init, the screenshot/autosave format may be resolved before all gfx drivers are registered, so "PNG" is not found. Can also appear if the binary was built without PNG support.
- **Fix:** Usually harmless at runtime; screenshots may fall back to another format. For a clean help run, ignore. To force a format: use the Settings UI or a config file to set a format that is built-in (e.g. PPM).

### 11. **scandir() failed on /dev/input**

- **Cause:** The evdev joystick driver enumerates `/dev/input`; on WSL this directory often does not exist.
- **Fix:** Harmless. Joystick support is simply unavailable; keyboard and other input still work.

---

## Reducing runtime noise (WSL / headless)

To avoid ALSA and log spam when debugging or running in WSL:

- **Dummy sound:** `./run-x64sc.sh -sounddev dummy` (or set **`VICE_QUIET=1`** to use dummy sound and reduced logging).
- **Debug logs:** `VICE_DEBUG=1 ./run-x64sc.sh` to pass `-debug`.

---

## Recommended: run script

A small wrapper can standardize “run from build tree”:

Use **`build/vice/run-x64sc.sh`** in this repo (see “Reducing runtime noise” above for `VICE_QUIET` and `VICE_DEBUG`).

---

## Install-based run

For a clean, install-based run (no `-directory` needed):

1. Build and install into a prefix, e.g.  
   `./configure --prefix=/usr && make -j$(nproc) && make install DESTDIR=/tmp/vice-install`
2. Run the installed binary, e.g.  
   `/tmp/vice-install/usr/bin/x64sc`  
   (with ROMs and data under `/tmp/vice-install/usr/share/vice/` as per your `configure`/install layout).

This avoids relying on the build tree and matches the paths baked into the binary (`VICE_DATADIR`).
