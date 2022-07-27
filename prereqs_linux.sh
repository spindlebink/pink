#!/bin/sh

RELEASE_MODE=true
WGPU_COMMIT="1b0900009f8f39ff722bf1115e7d46e32b2a79ed"

DIR="$(cd "$(dirname "$0")" && pwd)"

has_command() {
	echo `command -v "$1" &> /dev/null`
}

#####

if [ "$(uname)" != "Linux" ]; then
	echo "OS doesn't seem to be Linux: uname returned $OS"
	exit 1
fi

case "$1" in
	clean)
		rm -rf "$DIR/build/wgpu-native"
		rm -rf "$DIR/build/fontdue-native"
		rm -rf "$DIR/build/physfs"
		exit 0
	;;
	*help*)
		echo "A script for setting up Pink's prerequisites on Linux."
		echo "* '$0' to execute normally"
		echo "* '$0 clean' to wipe results from a previous run"
		echo "* '$0 help' to show this message"
		exit 0
	;;
esac

# Actual script if no short-circuiting cases

its_all_good=true
if [ ! `has_command git` ]; then
	echo "Git not found--install from git-scm.com/downloads or via your package manager"
	its_all_good=false
fi
if [ ! `has_command cargo` ]; then
	echo "Rust toolchain not found--install from rust-lang.org/tools/install or via your package manager"
	echo "Rust is necessary for building WGPU and Fontdue."
	its_all_good=false
fi
if [ ! `has_command cmake` ]; then
	echo "CMake not found--install from cmake.org/download or via your package manager"
	echo "CMake is necessary for building PhysFS."
	its_all_good=false
fi
if [ ! `has_command make` ]; then
	echo "Make not found--install via your package manager"
	echo "Make is necessary for building PhysFS."
	its_all_good=false
fi

if [ "$its_all_good" != true ]; then
	echo "Failed to build prerequisites for Linux."
	exit 1
fi

mkdir -p "$DIR/build"
cd "$DIR/build" && {
	
	#
	# WGPU
	#

	echo "Building wgpu-native..."
	if [ ! -d wgpu-native ]; then
		git clone https://github.com/gfx-rs/wgpu-native
	fi
	cd wgpu-native && {
		git submodule update --init --recursive
		if [ "$WGPU_COMMIT" != "" ]; then
			git checkout "$WGPU_COMMIT" 2>/dev/null
		fi
		cargo clean
		if [ "$RELEASE_MODE" = true ]; then
			cargo build --release
		else
			cargo build
		fi
		cd ..
	}
	
	echo

	#
	# Fontdue
	#

	echo "Building fontdue-native..."
	if [ ! -d fontdue-native ]; then
		git clone https://codeberg.org/spindlebink/fontdue-native
	fi
	cd fontdue-native && {
		cargo clean
		if [ "$RELEASE_MODE" = true ]; then
			cargo build --release
		else
			cargo build
		fi
		cd ..
	}
	
	echo

	#
	# PhysFS
	#

	echo "Setting up physfs..."
	if [ ! -d physfs ]; then
		git clone https://github.com/icculus/physfs
	fi
	cd physfs && {
		rm -rf build
		mkdir -p build
		cd build && {
			cmake ../
			make
			cd ..
		}
		cd ..
	}

	echo
	echo "Done building; copying libraries...."

	rs_target_dir="debug"
	if [ "$RELEASE_MODE" = true ]; then
		rs_target_dir="release"
	fi

	cp wgpu-native/target/$rs_target_dir/libwgpu_native.a "$DIR/pink/render/wgpu/libwgpu_native.a"
	cp fontdue-native/target/$rs_target_dir/libfontdue_native.a "$DIR/pink/text/fontdue/libfontdue_native.a"
	cp physfs/build/libphysfs.a "$DIR/pink/fs/physfs/libphysfs.a"

	cd ..
}
