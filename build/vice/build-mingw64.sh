#!/usr/bin/env bash
# VICE MinGW64 Build Script for Windows
# Builds VICE natively on Windows using MinGW64/MSYS2
set -euo pipefail

# Ensure MSYS2 tools are prioritized in PATH
export PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:${PATH}"

SOURCE_DIR=${1:-third_party/vice/vice}
DEST_DIR=${2:-artifacts/vice/win-x64}
JOBS=${3:-$(nproc)}

echo "=========================================="
echo "VICE MinGW64 Build for Windows"
echo "=========================================="
echo "Source: $SOURCE_DIR"
echo "Dest:   $DEST_DIR"
echo "Jobs:   $JOBS"
echo ""

# Fix CRLF line endings (Windows checkout issue)
if [ -d "$SOURCE_DIR" ]; then
    echo "Fixing CRLF line endings in build scripts..."
    # Use full path to MSYS2 find, not Windows find
    /usr/bin/find "$SOURCE_DIR" -name '*.sh' -type f -print0 | xargs -0 -I {} bash -c 'dos2unix "{}" 2>/dev/null || sed -i "s/\r$//" "{}"'
    echo "✓ Line endings fixed"
    echo ""
fi

# Check if running in MSYS2/MinGW64 environment
if [[ ! "$MSYSTEM" =~ MINGW64 ]] && [[ ! "$MSYSTEM" =~ UCRT64 ]]; then
    echo "ERROR: This script must be run in MSYS2 MinGW64 or UCRT64 environment"
    echo "Please launch MSYS2 MinGW64 shell and run this script"
    exit 1
fi

# Verify required tools
echo "Checking build dependencies..."
MISSING_DEPS=()

command -v gcc >/dev/null 2>&1 || MISSING_DEPS+=("gcc")
command -v pkg-config >/dev/null 2>&1 || MISSING_DEPS+=("pkg-config")
command -v autoconf >/dev/null 2>&1 || MISSING_DEPS+=("autoconf")
command -v automake >/dev/null 2>&1 || MISSING_DEPS+=("automake")
command -v libtool >/dev/null 2>&1 || MISSING_DEPS+=("libtool")
command -v make >/dev/null 2>&1 || MISSING_DEPS+=("make")

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo "ERROR: Missing required dependencies: ${MISSING_DEPS[*]}"
    echo "Install with: pacman -S ${MISSING_DEPS[*]/#/mingw-w64-x86_64-}"
    exit 1
fi

echo "✓ All dependencies found"
echo ""

# Navigate to source directory
if [ ! -d "$SOURCE_DIR" ]; then
    echo "ERROR: Source directory not found: $SOURCE_DIR"
    exit 1
fi

cd "$SOURCE_DIR"
echo "Building in: $(pwd)"
echo ""

# Use out-of-source build to avoid mixing Windows and Linux object files
BUILD_DIR="$SOURCE_DIR/build/win-x64"
mkdir -p "$BUILD_DIR"
echo "Out-of-source build directory: $BUILD_DIR"

# Create dummy infocontrib.h to bypass generation issues
# The geninfocontrib_h.sh script has issues with the current vice.texi format
if [ ! -f "src/infocontrib.h" ]; then
    echo "Creating infocontrib.h..."
    mkdir -p src
    cat > src/infocontrib.h << 'EOF'
#ifndef VICE_INFOCONTRIB_H
#define VICE_INFOCONTRIB_H

const char info_contrib_text[] =
"VICE Team";

vice_team_t core_team[] = {
    { NULL, NULL, NULL }
};

vice_team_t ex_team[] = {
    { NULL, NULL, NULL }
};

char *doc_team[] = {
    NULL
};

vice_trans_t trans_team[] = {
    { NULL, NULL, NULL, NULL }
};

#endif
EOF
    echo "✓ infocontrib.h created"
    # Touch the file to a past timestamp so make doesn't try to regenerate it
    touch -d "2020-01-01" src/infocontrib.h
fi

# Fix CRLF in configure scripts if needed
if [ -f "configure" ]; then
    file configure | grep -i crlf >/dev/null && {
        echo "Fixing configure script line endings..."
        dos2unix configure 2>/dev/null || sed -i 's/\r$//' configure
    }
fi

# Clean up any previous in-source configuration to avoid conflicts
if [ -f "Makefile" ]; then
    echo "Cleaning source directory to avoid configuration conflicts..."
    make distclean 2>/dev/null || true
fi

# Configure in out-of-source build directory
SOURCE_ROOT="$(pwd)"
cd "$BUILD_DIR"
if [ ! -f "Makefile" ]; then
    echo "Configuring VICE for MinGW64 (out-of-source)..."
    "$SOURCE_ROOT/configure" \
        --enable-gtk3ui \
        --disable-sdl2ui \
        --without-pulse \
        --disable-pdf-docs \
        --disable-libevdev \
        --prefix=/mingw64 \
        2>&1 | tail -20
    echo ""
fi

# Build VICE
echo "Building VICE with $JOBS parallel jobs..."
echo "=========================================="
START_TIME=$(date +%s)

make -j"$JOBS" 2>&1 | tail -100 || {
    echo "Build failed";
    exit 1;
}

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo ""
echo "=========================================="
echo "Build completed in ${ELAPSED}s"
echo "=========================================="
echo ""

# Create destination directory
mkdir -p "$DEST_DIR"

# Copy binaries
echo "Copying VICE binaries to $DEST_DIR..."
find "$BUILD_DIR/src" -maxdepth 1 -type f -name "*.exe" -exec cp -v {} "$DEST_DIR/" \;

# Copy required DLLs
echo ""
echo "Copying MinGW64 runtime DLLs..."
MINGW_BIN="/mingw64/bin"
if [ -d "$MINGW_BIN" ]; then
    # Core runtime libraries
    for dll in \
        libgcc_s_seh-1.dll \
        libstdc++-6.dll \
        libwinpthread-1.dll \
        ; do
        if [ -f "$MINGW_BIN/$dll" ]; then
            cp -v "$MINGW_BIN/$dll" "$DEST_DIR/" 2>/dev/null || true
        fi
    done

    # GTK3 UI framework
    for dll in \
        libgtk-3-0.dll \
        libgdk-3-0.dll \
        libatk-1.0-0.dll \
        ; do
        if [ -f "$MINGW_BIN/$dll" ]; then
            cp -v "$MINGW_BIN/$dll" "$DEST_DIR/" 2>/dev/null || true
        fi
    done

    # Cairo graphics
    for dll in \
        libcairo-2.dll \
        libcairo-gobject-2.dll \
        libpixman-1-0.dll \
        libepoxy-0.dll \
        ; do
        if [ -f "$MINGW_BIN/$dll" ]; then
            cp -v "$MINGW_BIN/$dll" "$DEST_DIR/" 2>/dev/null || true
        fi
    done

    # Pango text rendering
    for dll in \
        libpango-1.0-0.dll \
        libpangocairo-1.0-0.dll \
        libpangoft2-1.0-0.dll \
        libpangowin32-1.0-0.dll \
        libfribidi-0.dll \
        libthai-0.dll \
        ; do
        if [ -f "$MINGW_BIN/$dll" ]; then
            cp -v "$MINGW_BIN/$dll" "$DEST_DIR/" 2>/dev/null || true
        fi
    done

    # GLib/GObject system
    for dll in \
        libglib-2.0-0.dll \
        libgobject-2.0-0.dll \
        libgio-2.0-0.dll \
        libgmodule-2.0-0.dll \
        libgthread-2.0-0.dll \
        ; do
        if [ -f "$MINGW_BIN/$dll" ]; then
            cp -v "$MINGW_BIN/$dll" "$DEST_DIR/" 2>/dev/null || true
        fi
    done

    # Image support
    for dll in \
        libgdk_pixbuf-2.0-0.dll \
        libpng16-16.dll \
        libjpeg-8.dll \
        libtiff-6.dll \
        libwebp-7.dll \
        libwebpdecoder-3.dll \
        libwebpdemux-2.dll \
        libwebpmux-3.dll \
        libexif-12.dll \
        libjbig-0.dll \
        libLerc.dll \
        libsharpyuv-0.dll \
        ; do
        if [ -f "$MINGW_BIN/$dll" ]; then
            cp -v "$MINGW_BIN/$dll" "$DEST_DIR/" 2>/dev/null || true
        fi
    done

    # Font rendering
    for dll in \
        libharfbuzz-0.dll \
        libgraphite2.dll \
        libfontconfig-1.dll \
        libfreetype-6.dll \
        ; do
        if [ -f "$MINGW_BIN/$dll" ]; then
            cp -v "$MINGW_BIN/$dll" "$DEST_DIR/" 2>/dev/null || true
        fi
    done

    # Networking (libcurl and dependencies)
    for dll in \
        libcurl-4.dll \
        libssl-3-x64.dll \
        libcrypto-3-x64.dll \
        libssh2-1.dll \
        libnghttp2-14.dll \
        libngtcp2-16.dll \
        libngtcp2_crypto_ossl-0.dll \
        libnghttp3-9.dll \
        libpsl-5.dll \
        libidn2-0.dll \
        ; do
        if [ -f "$MINGW_BIN/$dll" ]; then
            cp -v "$MINGW_BIN/$dll" "$DEST_DIR/" 2>/dev/null || true
        fi
    done

    # Compression
    for dll in \
        zlib1.dll \
        libbz2-1.dll \
        libzstd.dll \
        libbrotlidec.dll \
        libbrotlicommon.dll \
        libbrotlienc.dll \
        libdeflate.dll \
        liblzma-5.dll \
        liblzo2-2.dll \
        ; do
        if [ -f "$MINGW_BIN/$dll" ]; then
            cp -v "$MINGW_BIN/$dll" "$DEST_DIR/" 2>/dev/null || true
        fi
    done

    # Utilities
    for dll in \
        libffi-8.dll \
        libpcre2-8-0.dll \
        libexpat-1.dll \
        libintl-8.dll \
        libiconv-2.dll \
        libunistring-5.dll \
        libcharset-1.dll \
        libdatrie-1.dll \
        ; do
        if [ -f "$MINGW_BIN/$dll" ]; then
            cp -v "$MINGW_BIN/$dll" "$DEST_DIR/" 2>/dev/null || true
        fi
    done

    echo "All MinGW64 dependencies copied"
fi

# Copy data files
echo ""
echo "Copying VICE data files..."
if [ -d "data" ]; then
    mkdir -p "$DEST_DIR/data"
    cp -r data/* "$DEST_DIR/data/" 2>/dev/null || true
fi

# Create default vicerc in user's AppData directory (Windows)
echo ""
echo "Setting up default configuration..."
if command -v cygpath >/dev/null 2>&1; then
    # Running under Windows/MSYS2
    APPDATA=$(cygpath -w "$APPDATA" 2>/dev/null || echo "$APPDATA")
    if [ -n "$APPDATA" ] && [ -d "$APPDATA" ]; then
        VICE_CONFIG_DIR="$APPDATA/vice"
        mkdir -p "$VICE_CONFIG_DIR"

        # Copy default vicerc if it doesn't exist
        if [ ! -f "$VICE_CONFIG_DIR/vicerc" ]; then
            if [ -f "../../build/vice/default_vicerc" ]; then
                cp "../../build/vice/default_vicerc" "$VICE_CONFIG_DIR/vicerc"
                echo "✓ Created default vicerc: $VICE_CONFIG_DIR/vicerc"
            fi
        else
            echo "✓ vicerc already exists: $VICE_CONFIG_DIR/vicerc"
        fi

        # Copy ROM files to config directory if they don't exist
        if [ -d "data" ]; then
            for rom_dir in data/*/; do
                if [ -d "$rom_dir" ]; then
                    rom_name=$(basename "$rom_dir")
                    mkdir -p "$VICE_CONFIG_DIR/$rom_name"
                    # Copy .bin ROM files
                    find "$rom_dir" -maxdepth 1 -name "*.bin" -type f -exec cp {} "$VICE_CONFIG_DIR/$rom_name/" \; 2>/dev/null || true
                fi
            done
            echo "✓ ROM files copied to: $VICE_CONFIG_DIR"

            # Copy font files to config directory
            if [ -d "data/common" ]; then
                mkdir -p "$VICE_CONFIG_DIR/common"
                cp data/common/*.ttf "$VICE_CONFIG_DIR/common/" 2>/dev/null || true
                echo "✓ Font files copied to: $VICE_CONFIG_DIR/common"
            fi
        fi
    fi
fi

echo ""
echo "=========================================="
echo "VICE MinGW64 build completed!"
echo "=========================================="
echo "Binaries: $DEST_DIR"
ls -lh "$DEST_DIR"/*.exe 2>/dev/null || echo "No .exe files found"
echo ""
