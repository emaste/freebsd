#!/bin/sh
set -e

# Root directory for minimal FreeBSD installation.
ROOTDIR=$(pwd)/fat-root

# Create minimal directory structure.
rm -rf $ROOTDIR/rescue $ROOTDIR/efi/boot/BOOTx64.EFI
for dir in dev efi/boot etc rescue; do
	mkdir -p $ROOTDIR/$dir
done

# Install kernel, loader and rescue.
make -DNO_ROOT DESTDIR=$ROOTDIR \
    MODULES_OVERRIDE= \
    WITHOUT_DEBUG_FILES=yes \
    WITHOUT_KERNEL_SYMBOLS=yes \
    installkernel
for dir in stand rescue; do
	make -DNO_ROOT DESTDIR=$ROOTDIR INSTALL="install -U" \
	    CRUNCH_GENERATE_LINKS=no \
	    WITHOUT_MAN= \
	    WITHOUT_TOOLCHAIN= \
	    -C $dir install
done

# Copy loader to standard EFI location, and rescue to required binaries.
mv $ROOTDIR/boot/loader.efi $ROOTDIR/efi/boot/BOOTx64.EFI
for bin in init sh shutdown; do
	cp $ROOTDIR/rescue/rescue $ROOTDIR/rescue/$bin
done
rm -f $ROOTDIR/rescue/rescue

# Configuration files.
cat > $ROOTDIR/boot/loader.conf <<EOF
vfs.root.mountfrom="msdosfs:/dev/ada0s1"
autoboot_delay=-1
boot_verbose=YES
EOF
cat > $ROOTDIR/etc/rc <<EOF
#!/rescue/sh

echo "Hello world."
/rescue/shutdown -p now
EOF

timeout 300 \
    qemu-system-x86_64 -m 256M -bios OVMF.fd \
    -serial stdio -vga none -nographic -monitor none \
    -snapshot -hda fat:$ROOTDIR 2>&1 | tee boot.log
grep -q 'Hello world.' boot.log
echo OK
