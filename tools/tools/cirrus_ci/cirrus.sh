#!/bin/sh

set -e

cpus=$(sysctl -n hw.ncpu)

# bootstrap and installed toolchains take a long time to build.  We can build
# the bootstrap toolchain within the timeout, so skip only the installed
# toolchain.
cat >/etc/src.conf <<EOF
WITHOUT_TOOLCHAIN=yes
EOF

echo "Building world with -j $cpus"
make -j $cpus buildworld

echo "Building kernel with -j $cpus"
make -j $cpus buildkernel
