WIPBSD
======
WIPBSD is Ed Maste's work-in-progress FreeBSD tree, including changes
related to the build system and toolchain.

[![CI status](https://api.cirrus-ci.com/github/emaste/freebsd.svg?branch=wipbsd)](http://cirrus-ci.com/github/emaste/freebsd/wipbsd)

Default Options
---------------
WIPBSD chooses a different default for a number of options.

Options disabled by default in WIPBSD (enabled in FreeBSD):
- `CLEAN`
- `GNU_DIFF`
- `SENDMAIL`
- `TCP_WRAPPERS`

Options enabled by default in WIPBSD (disabled in FreeBSD):
- `BIND_NOW`
- `CLANG_EXTRAS`
- `INIT_ALL_ZERO`
- `KERNEL_RETPOLINE`
- `LLVM_BINUTILS`
- `REPRODUCIBLE_BUILD`
- `RETPOLINE`

For more information and details about stock upstream FreeBSD see the
[FreeBSD README.md](https://github.com/freebsd/freebsd/blob/master/README.md)
