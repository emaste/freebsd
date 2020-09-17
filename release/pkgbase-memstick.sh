#!/bin/sh

set -e

die()
{
	echo "$*" 1>&2
	exit 1
}

: ${SRCTOP:=$(make -V SRCTOP)}
if [ -z "${SRCTOP}" ]; then
	die "Cannot locate top of source tree"
fi
: ${OBJTOP:=$(make -V OBJTOP)}
if [ -z "${OBJTOP}" ]; then
	die "Cannot locate top of object tree"
fi

# Really janky fetch / build pkg
build_pkg()
{
	# Copy pkg to OBJDIR until out-of-tree builds are supported
	# https://github.com/freebsd/pkg/issues/1888
	mkdir -p $OBJTOP/local/
	cp -pr $SRCTOP/local/pkg $OBJTOP/local/

	cd $OBJTOP/local/pkg
	./configure
	make -j $(sysctl -n hw.ncpu)
	cd -
}
build_pkg

# Extract files from desired packages
trim_metalog()
{
	cat $OBJTOP/stage/METALOG |\
	    egrep '/etc/s?pwd.db|/etc/passwd|package=(bootloader|bsdinstall|clibs|libarchive|libbsdxml|libbsm|libbz2|liblzma|libopie|libucl|rc|runtime|utilities|wpa)|type=dir' |\
	    egrep -v 'tags=lib32|,dev|,dbg' | egrep -v '/etc/pkg/FreeBSD.conf'
	cat $OBJTOP/stage/kernel.meta | egrep -v 'usr/lib/debug'
}
trim_metalog > $OBJTOP/stage/installer.meta

create_file()
{
	local contents mode

	contents=
	mode=0755

	while getopts "c:m:" opt; do
		case "$opt" in
		c)
			contents=$OPTARG
			;;
		m)
			mode=$OPTARG
			;;
		esac
	done
	shift $(($OPTIND - 1))

	file=${1#/}
	if [ -z "$contents" ]; then
		contents=$(pwd)/fluffy/$file
		mkdir -p $(dirname $contents)
		cat > $contents
	fi
	size=$(($(cat $contents | wc -c)))
	pwd=$(pwd -P)
	echo "./$file type=file uname=root gname=wheel mode=$mode size=$size contents=$contents" >> $OBJTOP/stage/installer.meta
}

# Installer context config files
# XXX ln -fs /tmp/bsdinstall_etc/resolv.conf ${.TARGET}/etc/resolv.conf
create_file /etc/rc.conf <<EOF
sendmail_enable="NONE"
hostid_enable="NO"
EOF
create_file /etc/sysctl.conf <<EOF
debug.witness.trace=0
EOF
create_file /boot/loader.conf <<EOF
vfs.mountroot.timeout="10"
kernels_autodetect="NO"
EOF
create_file -c $SRCTOP/release/rc.local /etc/rc.local
echo '/dev/ufs/FreeBSD_Install / ufs ro,noatime 1 1' | create_file /etc/fstab
echo 'root_rw_mount="NO"' | create_file /etc/rc.conf.local
create_file -c $SRCTOP/release/FreeBSD-Base.conf /etc/pkg/FreeBSD-base.conf

# Install pkg
mkdir -p $OBJTOP/stage/usr/local/etc
(cd $OBJTOP/local/pkg && make INSTALLFLAGS="-U -M $OBJTOP/stage/installer.meta -D $OBJTOP/stage" DESTDIR=$OBJTOP/stage -C src install)

# Add the repository
ABI=FreeBSD:13:amd64
(cd $OBJTOP/../repo && find $ABI/latest/ -type f) | while read f; do
	create_file -c $OBJTOP/../repo/$f /usr/freebsd-dist/$f
done

cd $OBJTOP/stage
makefs -D -B little -o label=FreeBSD_Install -o version=2 ufs.img installer.meta

#rm ${1}/etc/fstab
#rm ${1}/etc/rc.conf.local

DIR=$OBJTOP/stage

# Make an ESP in a file.
. ${SRCTOP}/tools/boot/install-boot.sh
espfilename=$(mktemp /tmp/efiboot.XXXXXX)
make_esp_file ${espfilename} ${fat32min} $DIR/boot/loader.efi

mkimg -s mbr \
    -b ${DIR}/boot/mbr \
    -p efi:=${espfilename} \
    -p freebsd:-"mkimg -s bsd -b ${DIR}/boot/boot -p freebsd-ufs:=ufs.img" \
    -a 2 \
    -o image
rm ${espfilename}
rm ufs.img
echo $(pwd)/image
