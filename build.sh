#!/bin/sh

dashj="-j$(sysctl -n hw.ncpu)"
datestr=$(date +%Y%m%d_%H%M%S)
log=build.$datestr.log
stagedir=$(pwd)/stage

ln -fs $log build.log

make_args="TARGET=arm64 PKG_FORMAT=tar"

do_build()
{
	make $dashj -DNO_CLEAN $make_args buildworld buildkernel 2>&1 | tee -a $log
}

do_stage()
{
	mkdir -p $stagedir
	make $make_args -DNO_ROOT DESTDIR=$stagedir installworld installkernel distribution
}


stage_file()
{
	mode=0444
	if [ $1 = "-m" ]; then
		mode=$2
		shift
		shift
	fi

	path=${1#/}

	size=$(stat -f %z config/$path)
	cp config/$path $stagedir/$path
	
	egrep -v "^\./$path " $stagedir/METALOG > $stagedir/METALOG.edit
	echo "./$path type=file uname=root gname=wheel mode=$mode size=$size" >> $stagedir/METALOG.edit
	mv $stagedir/METALOG.edit $stagedir/METALOG
}

do_stage_files()
{
	stage_file /boot/loader.conf
	stage_file /etc/fstab
	stage_file /etc/rc.conf
	stage_file -m 0544 /etc/rc.d/oci-setup
}


ufs_size=10g

do_ufs_part()
{
	cd $stagedir
	makefs -D -B little -o label=FreeBSD_root -o version=2 -s $ufs_size ufs.part METALOG 2>&1 | tee -a $log
	cd - 
}

do_efi_part()
{
	mkdir -p $stagedir/EFI/BOOT
	efibootname=BOOTAA64.EFI
	cp $stagedir/boot/loader.efi $stagedir/EFI/BOOT/$efibootname
	size=$(stat -f %z $stagedir/EFI/BOOT/$efibootname)
	echo "./EFI/BOOT/$efibootname type=file uname=root gname=wheel mode=0555 size=$size" > $stagedir/METALOG.efi
	cd $stagedir
	makefs -t msdos -o fat_type=32 -o sectors_per_cluster=1 \
	    -o volume_label=EFISYS -s 200m efi.part METALOG.efi
	cd ..
}

image_format=qcow2
image_file=freebsd.$image_format

do_image()
{
	mkimg -s gpt -f $image_format \
	  -p efi:=$stagedir/efi.part \
	  -p freebsd-ufs:=$stagedir/ufs.part \
	  -p freebsd-swap::4G \
	  -o $image_file
}

set -e
do_build
do_stage
do_stage_files
do_ufs_part
do_efi_part
do_image

qemulog=qemu.$datestr.log
qemucfg="-cpu cortex-a57 -M virt -bios edk2-aarch64-code.fd -m 256M -nodefaults -serial stdio -vga none -nographic -monitor none -netdev user,id=n1 -device virtio-net-pci,netdev=n1"
# boot in qemu to install packages
qemu-system-aarch64 $qemucfg -hda $image_file 2>&1 | tee $qemulog
if ! grep -q 'OK Packages Installed' $qemulog; then
	echo 'Pkg install failed' >&2
	exit 1
fi

echo "qemu-system-aarch64 $qemucfg -snapshot -hda $image_file"
