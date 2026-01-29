#!/usr/bin/env bash
set -euxo pipefail

SOURCE_DIR=${1:-third_party/vice}
DEST_DIR=${2:-artifacts/vice/linux-x64}
JOBS=${3:-$(nproc)}
VICE_REPO=${4:-https://svn.code.sf.net/p/vice-emu/code/trunk}
VICE_REV=${5:-}

echo "Build VICE"
echo "Source: $SOURCE_DIR"
echo "Dest:   $DEST_DIR"

if [ ! -d "$SOURCE_DIR" ]; then
	echo "Source directory not found: $SOURCE_DIR"
	# Prefer git-svn if available
	if command -v git >/dev/null 2>&1 && git svn --version >/dev/null 2>&1; then
		echo "Using git-svn to clone VICE"
		if [ -n "$VICE_REV" ]; then
			git svn clone -r "$VICE_REV" "$VICE_REPO" "$SOURCE_DIR"
		else
			git svn clone "$VICE_REPO" "$SOURCE_DIR"
		fi
	else
		if ! command -v svn >/dev/null 2>&1; then
			echo "svn is not installed. Please install subversion or git/git-svn to auto-checkout VICE." >&2
			exit 2
		fi
		echo "Checking out VICE from $VICE_REPO"
		if [ -n "$VICE_REV" ]; then
			svn checkout -r "$VICE_REV" "$VICE_REPO" "$SOURCE_DIR"
		else
			svn checkout "$VICE_REPO" "$SOURCE_DIR"
		fi
	fi
fi

mkdir -p "$DEST_DIR"

# Use out-of-source build to avoid mixing Windows and Linux object files
BUILD_DIR="$SOURCE_DIR/build/linux-x64"
mkdir -p "$BUILD_DIR"

echo "Out-of-source build directory: $BUILD_DIR"

pushd "$SOURCE_DIR"

echo "Listing contents of $PWD before build:"
ls -lA | head -20

# Prefer autotools if present
if [ -f ./configure ] || [ -f ./autogen.sh ]; then
	echo "Autotools build detected."

	# Clean up any previous Windows build configuration in source tree
	echo "Cleaning source directory to avoid configuration conflicts..."
	if [ -f Makefile ]; then
		make distclean 2>/dev/null || true
	fi

	if [ -f ./autogen.sh ]; then
		echo "Running autogen.sh..."
		./autogen.sh || { echo "autogen.sh failed"; exit 2; }
	fi

	# Detect build type using config.guess if available, else fallback
	BUILD_TYPE=""
	if [ -x ./config.guess ]; then
		BUILD_TYPE=$(./config.guess 2>/dev/null || true)
		echo "Detected build type from config.guess: '$BUILD_TYPE'"
	fi
	if [ -z "$BUILD_TYPE" ]; then
		BUILD_TYPE="x86_64-pc-linux-gnu"
		echo "Falling back to hardcoded build type: '$BUILD_TYPE'"
	fi

	# Change to build directory for out-of-source build
	cd "$BUILD_DIR"
	SOURCE_ROOT="$(pwd)/../.."
	echo "Configuring from out-of-source build directory..."
	echo "Running: $SOURCE_ROOT/configure --prefix=/usr --build=\"$BUILD_TYPE\" --enable-gtk3ui --with-pulse"
	"$SOURCE_ROOT/configure" --prefix=/usr --build="$BUILD_TYPE" --enable-gtk3ui --with-pulse || { echo "configure failed"; exit 3; }

	echo "Running make from build directory..."
	make -j"$JOBS" || { echo "make failed"; exit 4; }

	if make -q install 2>/dev/null; then
		echo "Running make install..."
		make install DESTDIR="$DEST_DIR" || { echo "make install failed"; exit 5; }
	else
		echo "No install target, copying VICE binaries manually..."
		mkdir -p "$DEST_DIR"
		find ./src -maxdepth 1 -type f -executable -exec cp {} "$DEST_DIR" \; 2>/dev/null || true
	fi
else
	echo "CMake build fallback."
	cd "$BUILD_DIR"
	SOURCE_ROOT="$(pwd)/../.."
	echo "Running cmake..."
	cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr "$SOURCE_ROOT" || { echo "cmake failed"; exit 6; }
	echo "Running make (cmake)..."
	make -j"$JOBS" || { echo "make (cmake) failed"; exit 7; }
	echo "Running make install (cmake)..."
	make install DESTDIR="$DEST_DIR" || { echo "make install (cmake) failed"; exit 8; }
fi

echo "Listing contents of $DEST_DIR after build:"
ls -lA "$DEST_DIR" 2>/dev/null | head -20

popd

echo "VICE build completed; installed into $DEST_DIR"
exit 0
