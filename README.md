WIPBSD
======
WIPBSD is Ed Maste's work-in-progress FreeBSD tree, including changes
related to the build system and toolchain.

[![CI status](https://api.cirrus-ci.com/github/emaste/freebsd.svg?branch=wipbsd.20200626)](http://cirrus-ci.com/github/emaste/freebsd/wipbsd.20200626)

Default Options
---------------
WIPBSD chooses a different default for a number of options.

Options disabled by default in WIPBSD (enabled in FreeBSD):
    `GDB` `GNU_DIFF` `GNU_GREP` `SENDMAIL` `TCP_WRAPPERS`

Options enabled by default in WIPBSD (disabled in FreeBSD):
   `BSD_GREP` `REPRODUCIBLE_BUILD`

Tool Chains
-----------
WPBSD contains changes in support of FreeBSD's migration to a
[permissively-licensed toolchain](https://wiki.freebsd.org/GPLinBase).
Architectures without in-tree toolchain support are excluded from
`make universe`/`make tinderbox` if the corresponding GCC cross-
toolchain is not installed.

In FreeBSD three GNU binutils are still used: `as`, `ld`, and `objdump`.
In WIPBSD only `as` remains, and is used only on i386 and amd64, for
assembling a small number of files which are not supported by LLVM's
integrated assembler.

| Arch    | Tool Chain   | Status                              |
| ------- | ------------ | --------                            |
| amd64   | Clang + LLD  | Working                             |
| i386    | Clang + LLD  | Working                             |
| arm64   | Clang + LLD  | Working                             |
| armv7   | Clang + LLD  | Working                             |
| armv6   |              |                                     |
| mips64  | Clang + LLD  | Builds (excluding some kernels)     |
| mipsn32 | Clang + LLD  | Buildworld fails                    |
| riscv64 | External GCC | Untested                            |

MIPS64 broken options w/ Clang+LLD:
    `PROFILE` `CLANG` `RESCUE` `LIB32`

For more information and details about stock upstream FreeBSD see the
[FreeBSD README.md](https://github.com/freebsd/freebsd/blob/master/README.md)
