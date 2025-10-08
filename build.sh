#!/bin/sh

# Concurrency
#DASHJ=-j6
DASHJ=-j$(nproc)

# Skip 2x toolchain build
ARGS="$ARGS WITHOUT_TOOLCHAIN= CROSS_TOOLCHAIN=llvm19"
# Reduce build verbosity
ARGS="$ARGS -s"
ARGS="$ARGS PORTSDIR=/home/emaste/src/freebsd-ports"

LOG=$(pwd)/build.$(date +%Y%m%d_%H%M%S).log
ln -fs $LOG build.log

set -e

build()
{
	time make $ARGS buildworld buildkernel $DASHJ
	echo
	time make $ARGS $DASHJ PKG_FORMAT=tzst PKG_LEVEL=1 packages
	echo
	cd release
	rm -rf obj/pkgbase-repo* obj/disc1*
	export PKG_LEVEL=1
	time make $ARGS disc1.iso
}

build 2>&1 | tee $LOG
