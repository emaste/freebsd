WIPBSD
======
WIPBSD is Ed Maste's work-in-progress FreeBSD tree, including changes
related to the build system and toolchain.

[![CI status](https://api.cirrus-ci.com/github/emaste/freebsd.svg?branch=wipbsd.20200727)](http://cirrus-ci.com/github/emaste/freebsd/wipbsd.20200727)

Default Options
---------------
WIPBSD chooses a different default for a number of options.

Options disabled by default in WIPBSD (enabled in FreeBSD):
    `GDB` `GNU_DIFF` `GNU_GREP` `SENDMAIL` `TCP_WRAPPERS`

Options enabled by default in WIPBSD (disabled in FreeBSD):
   `BSD_GREP` `REPRODUCIBLE_BUILD`

For more information and details about stock upstream FreeBSD see the
[FreeBSD README.md](https://github.com/freebsd/freebsd/blob/master/README.md)
