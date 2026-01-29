# C64OS IDE — Architecture & Implementation Plan

Purpose
- Single‑developer IDE for C64OS development: edit, compile (emit TMPx), run and debug within bundled VICE.
- Audience: myself (developer + user). MVP focused on rapid iteration.

MVP Scope
- Editor with syntax highlighting and project files
- Compiler pipeline: LanguageFrontend → IR → TMPxEmitter
- Run in VICE and basic debugging (breakpoints, step, memory inspection)
- ZIP packaging for Windows 10+ and Linux (X11)
- CI builds VICE + solution for both RIDs

Technology Stack
- Runtime/UI: .NET 9 + Avalonia (native desktop)
- Build automation: NUKE (single orchestrator)
- Emulator: VICE (built from source via MSYS2/mingw64 for Windows; native GCC for Linux)
- Packaging: ZIP (MVP); installers deferred

Project Layout (high level)
- src/
  - C64OS.IDE.App (Avalonia UI)
  - C64OS.IDE.Editor
  - C64OS.IDE.Compiler
  - C64OS.IDE.EmulatorBridge
  - C64OS.IDE.Debugger
  - C64OS.IDE.ProjectStore
  - C64OS.IDE.Core (interfaces)
- build/
  - Build.cs (NUKE targets)
  - vice/
    - build.ps1
    - build.sh
    - README.md (MSYS2 packages & commands)
- third_party/vice (submodule or clone)
- artifacts/
  - vice/{rid}/...
  - package/{rid}/...

Core Interfaces (place in `src/C64OS.IDE.Core`)
- ICompiler: Compile(source) → compilation result / TMPx output
- IEmitter: EmitTMPx(IR) → .asm/.prg
- IEmulatorHost: Start/Stop, SendMonitorCommand, Snapshot, Attach
- IDebugAdapter: SetBreakpoint, RemoveBreakpoint, StepIn/Over/Out, InspectMemory/Registers

Build & CI
- NUKE targets (build/Build.cs):
  - Restore, Compile, Test
  - BuildVice(TargetRid) — explicit, parameterized (win10-x64, linux-x64)
  - PackWindows, PackLinux (produce ZIPs under artifacts/package/{rid})
  - Publish
- BuildVice behavior:
  - Clone / update `third_party/vice` to specified revision
  - On Windows: run MSYS2 MinGW64 build (mingw64 toolchain)
  - On Linux: run native build (GCC, X11 libs)
  - Place installed outputs into `artifacts/vice/{rid}` (bin/, lib/, include/)
- CI:
  - GitHub Actions matrix:
    - windows-latest runner → `nuke BuildVice --target=win10-x64` + solution build
    - ubuntu-latest runner → `nuke BuildVice --target=linux-x64` + solution build
  - Cache artifacts/vice and MSYS2 pkg cache where possible

BuildVice (MSYS2 / mingw64) — notes (details live in build/vice/README.md)
- Run from MSYS2 MinGW64 shell; keep pacman updated (`pacman -Syu`)
- Recommended pacman packages (install as needed):
  - base-devel, mingw-w64-x86_64-toolchain
  - mingw-w64-x86_64-autoconf, automake, libtool, pkg-config, cmake
  - mingw-w64-x86_64-SDL2, mingw-w64-x86_64-SDL2_image, mingw-w64-x86_64-SDL2_mixer
  - mingw-w64-x86_64-libpng, mingw-w64-x86_64-libjpeg-turbo, mingw-w64-x86_64-zlib
- Typical build sequence (MSYS2 MinGW64 shell):
  - ./autogen.sh (if present) → ./configure --host=x86_64-w64-mingw32 --prefix=/mingw64
  - make -j$(nproc)
  - make install DESTDIR=/path/to/artifacts/vice/win10-x64

Packaging & Distribution
- MVP: produce ZIP per RID containing app runtime + `artifacts/vice/{rid}` (VICE binaries next to app)
- Post‑MVP: consider MSI/AppImage when installer features are needed

Roadmap (short)
1. Scaffold solution and `C64OS.IDE.Core` interfaces (src/).
2. Add NUKE skeleton `build/Build.cs` with `BuildVice` signature.
3. Add `build/vice/build.ps1`, `build/vice/build.sh`, and `build/vice/README.md` (MSYS2 packages & commands).
4. Create GitHub Actions CI matrix to run `BuildVice` and full solution build.
5. Implement minimal editor → compile → run flow (emit TMPx, run in VICE).
6. Add debugging adapters (monitor protocol), tests, and iterate.

Decisions confirmed
- Native .NET 9 + Avalonia
- NUKE for builds; `BuildVice` is a separate, explicit step
- VICE built from source; Windows build uses MSYS2/mingw64
- Targets: Windows 10+ (win10-x64) and Linux + X11 (linux-x64)
- Packaging: ZIP for MVP
# C64OS IDE — Architecture & Implementation Plan

Purpose
- Single‑developer IDE for C64OS development: edit, compile (emit TMPx), run and debug within bundled VICE.
- Audience: myself (developer + user). MVP focused on rapid iteration.

MVP Scope
- Editor with syntax highlighting and project files
- Compiler pipeline: LanguageFrontend → IR → TMPxEmitter
- Run in VICE and basic debugging (breakpoints, step, memory inspection)
- ZIP packaging for Windows 10+ and Linux (X11)
- CI builds VICE + solution for both RIDs

Technology Stack
- Runtime/UI: .NET 9 + Avalonia (native desktop)
- Build automation: NUKE (single orchestrator)
- Emulator: VICE (built from source via MSYS2/mingw64 for Windows; native GCC for Linux)
- Packaging: ZIP (MVP); installers deferred

Project Layout (high level)
- src/
  - C64OS.IDE.App (Avalonia UI)
  - C64OS.IDE.Editor
  - C64OS.IDE.Compiler
  - C64OS.IDE.EmulatorBridge
  - C64OS.IDE.Debugger
  - C64OS.IDE.ProjectStore
  - C64OS.IDE.Core (interfaces)
- build/
  - Build.cs (NUKE targets)
  - vice/
    - build.ps1
    - build.sh
    - README.md (MSYS2 packages & commands)
- third_party/vice (submodule or clone)
- artifacts/
  - vice/{rid}/...
  - package/{rid}/...

Core Interfaces (place in `src/C64OS.IDE.Core`)
- ICompiler: Compile(source) → compilation result / TMPx output
- IEmitter: EmitTMPx(IR) → .asm/.prg
- IEmulatorHost: Start/Stop, SendMonitorCommand, Snapshot, Attach
- IDebugAdapter: SetBreakpoint, RemoveBreakpoint, StepIn/Over/Out, InspectMemory/Registers

Build & CI
- NUKE targets (build/Build.cs):
  - Restore, Compile, Test
  - BuildVice(TargetRid) — explicit, parameterized (win10-x64, linux-x64)
  - PackWindows, PackLinux (produce ZIPs under artifacts/package/{rid})
  - Publish
- BuildVice behavior:
  - Clone / update `third_party/vice` to specified revision
  - On Windows: run MSYS2 MinGW64 build (mingw64 toolchain)
  - On Linux: run native build (GCC, X11 libs)
  - Place installed outputs into `artifacts/vice/{rid}` (bin/, lib/, include/)
- CI:
  - GitHub Actions matrix:
    - windows-latest runner → `nuke BuildVice --target=win10-x64` + solution build
    - ubuntu-latest runner → `nuke BuildVice --target=linux-x64` + solution build
  - Cache artifacts/vice and MSYS2 pkg cache where possible

BuildVice (MSYS2 / mingw64) — notes (details live in build/vice/README.md)
- Run from MSYS2 MinGW64 shell; keep pacman updated (`pacman -Syu`)
- Recommended pacman packages (install as needed):
  - base-devel, mingw-w64-x86_64-toolchain
  - mingw-w64-x86_64-autoconf, automake, libtool, pkg-config, cmake
  - mingw-w64-x86_64-SDL2, mingw-w64-x86_64-SDL2_image, mingw-w64-x86_64-SDL2_mixer
  - mingw-w64-x86_64-libpng, mingw-w64-x86_64-libjpeg-turbo, mingw-w64-x86_64-zlib
- Typical build sequence (MSYS2 MinGW64 shell):
  - ./autogen.sh (if present) → ./configure --host=x86_64-w64-mingw32 --prefix=/mingw64
  - make -j$(nproc)
  - make install DESTDIR=/path/to/artifacts/vice/win10-x64

Packaging & Distribution
- MVP: produce ZIP per RID containing app runtime + `artifacts/vice/{rid}` (VICE binaries next to app)
- Post‑MVP: consider MSI/AppImage when installer features are needed

Roadmap (short)
1. Scaffold solution and `C64OS.IDE.Core` interfaces (src/).
2. Add NUKE skeleton `build/Build.cs` with `BuildVice` signature.
3. Add `build/vice/build.ps1`, `build/vice/build.sh`, and `build/vice/README.md` (MSYS2 packages & commands).
4. Create GitHub Actions CI matrix to run `BuildVice` and full solution build.
5. Implement minimal editor → compile → run flow (emit TMPx, run in VICE).
6. Add debugging adapters (monitor protocol), tests, and iterate.

Decisions confirmed
- Native .NET 9 + Avalonia
- NUKE for builds; `BuildVice` is a separate, explicit step
- VICE built from source; Windows build uses MSYS2/mingw64
- Targets: Windows 10+ (win10-x64) and Linux + X11 (linux-x64)
- Packaging: ZIP for MVP
