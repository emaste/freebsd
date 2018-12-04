#!/bin/sh
set -e

# Root directory for minimal FreeBSD installation.
ROOTDIR=$(pwd)/fat-root

# Create minimal directory structure.
rm -rf $ROOTDIR/efi/boot/BOOTx64.EFI
for dir in dev bin efi/boot etc lib libexec sbin usr/libexec; do
	mkdir -p $ROOTDIR/$dir
done

# Install kernel, loader and minimal userland.
make -DNO_ROOT DESTDIR=$ROOTDIR \
    MODULES_OVERRIDE= \
    WITHOUT_DEBUG_FILES=yes \
    WITHOUT_KERNEL_SYMBOLS=yes \
    installkernel
for dir in stand \
    lib/libc lib/libedit lib/ncurses \
    libexec/rtld-elf \
    bin/sh sbin/init sbin/shutdown; do
	make -DNO_ROOT DESTDIR=$ROOTDIR INSTALL="install -U" \
	    WITHOUT_MAN= \
	    WITHOUT_PROFILE= \
	    WITHOUT_TESTS= \
	    WITHOUT_TOOLCHAIN= \
	    -C $dir install
done

# Copy loader to standard EFI location.
mv $ROOTDIR/boot/loader.efi $ROOTDIR/efi/boot/BOOTx64.EFI

# Configuration files.
cat > $ROOTDIR/boot/loader.conf <<EOF
vfs.root.mountfrom="msdosfs:/dev/ada0s1"
autoboot_delay=-1
boot_verbose=YES
EOF
cat > $ROOTDIR/etc/rc <<EOF
#!/bin/sh

echo "Hello world."
/sbin/shutdown -p now
EOF

# Remove unnecessary files to keep FAT filesystem size down.
rm -rf $ROOTDIR/METALOG $ROOTDIR/usr/lib


timeout 300 \
    qemu-system-x86_64 -m 256M -bios OVMF.fd \
    -serial stdio -vga none -nographic -monitor none \
    -snapshot -hda fat:$ROOTDIR 2>&1 | tee boot.log
grep -q 'Hello world.' boot.log
echo OK
