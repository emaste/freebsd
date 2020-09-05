#!/bin/sh

make_metalog()
{
    cat /usr/obj/usr/home/emaste/src/freebsd-git/head/amd64.amd64/stage/METALOG |\
	egrep '/etc/s?pwd.db|/etc/passwd|package=(bootloader|bsdinstall|clibs|libbsdxml|libopie|rc|runtime|utilities)|type=dir' |\
	egrep -v 'tags=lib32|,dev|,dbg'
    cat /usr/obj/usr/home/emaste/src/freebsd-git/head/amd64.amd64/stage/kernel.meta |\
	egrep -v 'usr/lib/debug'
#    mkdir -p /usr/obj/usr/home/emaste/src/freebsd-git/head/amd64.amd64/stage/boot/kernel
#    cp /usr/obj/usr/home/emaste/src/freebsd-git/head/amd64.amd64/stage/kernel/boot/kernel/* /usr/obj/usr/home/emaste/src/freebsd-git/head/amd64.amd64/worldstage/boot/kernel/
}

make_metalog > /usr/obj/usr/home/emaste/src/freebsd-git/head/amd64.amd64/stage/bootonly.meta


set -e

scriptdir=$(dirname $(realpath $0))
. ${scriptdir}/../tools/boot/install-boot.sh

PATH=/bin:/usr/bin:/sbin:/usr/sbin
export PATH

#if [ $# -ne 2 ]; then
#        echo "make-memstick.sh /path/to/directory /path/to/image/file"
#        exit 1
#fi
#
#if [ ! -d ${1} ]; then
#        echo "${1} must be a directory"
#        exit 1
#fi
#
#if [ -e ${2} ]; then
#        echo "won't overwrite ${2}"
#        exit 1
#fi

die()
{
	echo "$*" 1>&2
	exit 1
}

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
	echo "./$file type=file uname=root gname=wheel mode=$mode size=$size contents=$contents" >> /usr/obj/usr/home/emaste/src/freebsd-git/head/amd64.amd64/stage/bootonly.meta
}

#        ln -fs /tmp/bsdinstall_etc/resolv.conf ${.TARGET}/etc/resolv.conf
create_file /etc/rc.conf <<EOF
sendmail_enable="NONE"
echo hostid_enable="NO"
EOF
create_file /etc/sysctl.conf <<EOF
debug.witness.trace=0
EOF
create_file /boot/loader.conf <<EOF
vfs.mountroot.timeout="10"
kernels_autodetect="NO"
EOF
create_file -c /usr/home/emaste/src/freebsd-git/head/release/rc.local \
    /etc/rc.local
echo '/dev/ufs/FreeBSD_Install / ufs ro,noatime 1 1' | create_file /etc/fstab
echo 'root_rw_mount="NO"' | create_file /etc/rc.conf.local


# Add the repository
: ${OBJTOP:=$(make -V OBJTOP)}
if [ -z "${OBJTOP}" ]; then
	die "Cannot locate top of object tree"
fi
ABI=FreeBSD:13:amd64
(cd $OBJTOP && find repo/$ABI/latest) | while read f; do
	create_file -c $OBJTOP/$f $f
done

#makefs -B little -o label=FreeBSD_Install -o version=2 ${2}.part ${1}

cd /usr/obj/usr/home/emaste/src/freebsd-git/head/amd64.amd64/stage
makefs -D -B little -o label=FreeBSD_Install -o version=2 ufs.img bootonly.meta

#rm ${1}/etc/fstab
#rm ${1}/etc/rc.conf.local

DIR=/usr/obj/usr/home/emaste/src/freebsd-git/head/amd64.amd64/stage

# Make an ESP in a file.
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
