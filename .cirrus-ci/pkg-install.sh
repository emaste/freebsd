#!/bin/sh

PKGS="qemu uefi-edk2-qemu-x86_64 llvm12"

pkg install -y $PKGS && exit 0

cat <<EOF
pkg install failed

dmesg tail:
$(dmesg | tail)

trying again
EOF

pkg install -y $PKGS
