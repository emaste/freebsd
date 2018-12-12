#!/bin/sh
#
# $FreeBSD$
#
# Our current approach to dependency tracking cannot cope with certain source
# tree changes, particularly with respect to removing source files and
# replacing generated files.  This script handles these cases in an ad-hoc
# fashion.

# Allow $OBJTOP to be set on the command line or in the environment.
if [ -n "$1" ]; then
	OBJTOP=$1
fi
if [ -z "${OBJTOP}" ]; then
	echo "clean_deps.sh <OBJTOP path>" >&2
	exit 1
fi

check_dep()
{
	if ! [ -e "$OBJTOP/$1" ]; then
		return 1
	fi
	grep -q "$2" "$OBJTOP/$1"
}

# 20181211 r341825 Update Clang/LLVM to 7.0.1.
if check_dep lib/clang/libllvm/.depend.LTO_LTO.o \
    contrib/llvm/include/llvm/Analysis/ObjectUtils.h; then
	echo "Removing LLVM 6 dependencies and objects"
	find $OBJTOP/lib/clang $OBJTOP/tmp/obj-tools/lib/clang \
	    \( -name '.depend*' -o -name '*.o' \) -delete
fi
