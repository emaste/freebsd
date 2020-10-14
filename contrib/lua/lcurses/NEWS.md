# lcurses NEWS - User visible changes

## Noteworthy changes in release ?.? (????-??-??) [?]


## Noteworthy changes in release 9.0.0 (2016-01-10) [stable]

  - This is the first standalone release since lcurses was absorbed into
    luaposix on 2011-09-09.

### Incompatible Changes

  - posix.curses has been split back out into its own separate
    project again!

  - The ncurses-only `KEY_MOUSE` definition has been removed.

### New Features

  - Can now be linked against NetBSD curses, albeit with several functions
    not implemented by that library returning a "not implemented" error as
    a consequence.

  - The curses library now includes reasonably comprehensive LDoc
    documentation (certainly much better than the single wooly web-page in
    previous releases).

  - Install curses.html documentation file correctly.

  - Add `curses.A_COLOR` (where supported by the underlying curses library) for
    extracting color pair assignments from the results of `curses.window.winch`.

  - Add missing `curses.KEY_F31` constant.

  - All APIs now fully and correctly diagnose extraneous and wrong type
    arguments with an error.

  - This release adds wresize to curses.  Several small improvements
    to the documentation were also added.

### Bugs Fixed

  - Links to OpenGroup specs for curses function in section 3x now work.
