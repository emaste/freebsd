#!/bin/sh

# Concurrency
DASHJ=-j6
#DASHJ=-j$(nproc)

# Skip 2x toolchain build
#ARGS="$ARGS CROSS_TOOLCHAIN=llvm19"
# Reduce build verbosity
ARGS="$ARGS -s"
ARGS="$ARGS PORTSDIR=/home/emaste/src/freebsd-ports"
ARGS="$ARGS -DNO_ROOT -DWITHOUT_QEMU"

LOG=$(pwd)/build.$(date +%Y%m%d_%H%M%S).log
ln -fs $LOG build.log

set -e

build()
{
	time make $ARGS buildworld buildkernel $DASHJ
	echo
	time make $ARGS $DASHJ BUILD_WITH_STRICT_TMPPATH=0 PKG_FORMAT=tzst PKG_LEVEL=1 packages
	echo
	cd release
	rm -rf obj/pkgbase-repo* obj/disc1* obj/dvd1*
	export PKG_LEVEL=1
	time make $ARGS BUILD_WITH_STRICT_TMPPATH=0 disc1.iso
	#time make $ARGS dvd1.iso
}

build_dvd()
{
	cd release
	export PKG_LEVEL=1
	time make $ARGS dvd1.iso
}

build 2>&1 | tee $LOG
#build_dvd 2>&1 | tee $LOG
