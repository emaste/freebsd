FreeBSD makefs update / sync with NetBSD
========================================

FreeBSD and NetBSD both have a copy of makefs(8) in the base system,
a tool for creating filesystem images from a directory or manifset
file as an unprivileged user.

NetBSD's version can be considered "upstream," but the copy in FreeBSD
was not considered vendor source and diverged from NetBSD's. As a result
I have been following an iterative approach bringing in groups of
changes from NetBSD. In addition I have found some bugs in NetBSD
changes that are not yet in FreeBSD, so reviewing the changes as they
are brought over is a valuable exercise.

This TODO file documents the work remaining in the update process.

TODO
----

### implement -O (offset) option

```
commit 358ec754d3943312f154294516783ab20d9fc062
Author: christos <christos>
Date:   Sun Feb 3 03:21:21 2013 +0000

    - more changes to make -O work
    - fix err* calls.

commit c64f300739477e5f41349de5841c99320e7d0283
Author: christos <christos>
Date:   Sat Feb 2 20:42:02 2013 +0000

    add and document offset.
```

```
NetBSD revs:
ffs.c		1.60
makefs.8	1.44
makefs.c	1.48
makefs.h	1.33
ffs/buf.c	1.20
ffs/mkfs.c	1.27
```

### implement -r (replace) option

```
commit 852bbfc6c27da1d3e2479b3e2288622e2fb1502d
Author: christos <christos>
Date:   Sun Feb 3 06:16:53 2013 +0000

    add a replace flag so we can overlay exiting files when we merge directories.
```

```
NetBSD revs:
makefs.8	1.45
makefs.c	1.49
makefs.h	1.34
walk.c		1.28
```


### Clean up warnings

```
commit 51abbbaeefabf089c687147988ea6357c46c5b5b
Author:	christos <christos>
Date:	Thu Apr 19 17:28:25 2012 +0000

    WARNS=5

commit 9cacfb1a1d4eac4c15334db8388ddc85ca2f75e3
Author: joerg <joerg>
Date:   Sun Apr 29 13:32:21 2012 +0000

    usage is dead. name_len should be read as unsigned byte.

commit 67d44fc1c3519f7a07afa31d0940fa3edde6d928
Author: christos <christos>
Date:   Sat Oct 19 17:16:37 2013 +0000

    fix unused variable warnings.
```

```
NetBSD revs:
cd9660.c			1.45
ffs.c				1.47
makefs.c			1.34
walk.c				1.26
cd9660/cd9660_debug.c		1.13
cd9660/cd9660_eltorito.c	1.19
cd9660/cd9660_write.c		1.17
ffs/ffs_alloc.c			1.19
ffs/mkfs.c			1.23 1.24
```


### Clean up UFS/FFS namespace

```
commit 267e29a24be249273f70b203729d251bc78d92ad
Author: dholland <dholland>
Date:   Sun Jun 23 22:03:34 2013 +0000

    Stick ffs_ in front of the following macros:
       fragstoblks()
       blkstofrags()
       fragnum()
       blknum()

    to finish the job of distinguishing them from the lfs versions, which
    Christos renamed the other day.

    I believe this is the last of the overtly ambiguous exported symbols
    from ffs... or at least, the last of the ones that conflicted with lfs.
    ffs still pollutes the C namespace very broadly (as does ufs) and this
    needs quite a bit more cleanup.

    XXX: boo on macros with lowercase names. But I'm not tackling that just yet.

commit 9badf91cd57540919df5c412af725a04576c49ae
Author: dholland <dholland>
Date:   Sun Jun 23 07:28:36 2013 +0000

    Stick ffs_, ext2_, chfs_, filecore_, cd9660_, or mfs_ in front of
    the following symbols so as to disambiguate fully. (Christos already
    did the lfs ones.)

       lblkno
       lblktosize
       lfragtosize
       numfrags
       blkroundup
       fragroundup

commit 789bb5a53492e9181712650f7a2425d362c2984a
Author: dholland <dholland>
Date:   Sun Jun 23 02:06:04 2013 +0000

    fsbtodb() -> FFS_FSBTODB(), EXT2_FSBTODB(), or MFS_FSBTODB()
    dbtofsb() -> FFS_DBTOFSB() or EXT2_DBTOFSB()

    (Christos already did the lfs ones a few days back)

commit ca3acdf6ec1717f237fa9de40857f4694440bff6
Author: dholland <dholland>
Date:   Wed Jun 19 17:51:25 2013 +0000

    Rename ambiguous macros:
       MAXDIRSIZE -> UFS_MAXDIRSIZE or LFS_MAXDIRSIZE
       NINDIR -> FFS_NINDIR, EXT2_NINDIR, LFS_NINDIR, or MFS_NINDIR
       INOPB -> FFS_INOPB, LFS_INOPB
       INOPF -> FFS_INOPF, LFS_INOPF
       blksize -> ffs_blksize, ext2_blksize, or lfs_blksize
       sblksize -> ffs_blksize

    These are not the only ambiguously defined filesystem macros, of
    course, there's a pile more. I may not have found all the ambiguous
    definitions of blksize(), too, as there are a lot of other things
    called 'blksize' in the system.

commit 20187151caea088a69474faae80e131f3123290c
Author: dholland <dholland>
Date:   Sun Jun 9 17:57:08 2013 +0000

    Stick UFS_ in front of these symbols:
       DIRBLKSIZ
       DIRECTSIZ
       DIRSIZ
       OLDDIRFMT
       NEWDIRFMT

    Part of PR 47909.
```

### Review and apply ffs-specific improvements from NetBSD

### Review and apply cd9660-specific improvements from NetBSD

NetBSD supports ISO Level 3 in addition to 1 & 2 in FreeBSD.

### Add msdos support

### Investigate other filesystems
NetBSD also has chfs, udf, v7fs. Decide if we want to bring these over.

### migrate to libmtree

See https://github.com/mratajsky/freebsd/tree/libmtree-makefs

### Fix makefs.8 man page

Incorporate updates from NetBSD.
Document newly added filesystems (msdos).
Add documentation NetBSD's missing (fs-specific single-letter options).
Note that they incorrectly changed 'filesystem' to 'file system'.

### Submit patches to NetBSD

After updating compare the NetBSD and FreeBSD copies of makefs. Submit
patches to NetBSD where we have whitespace fixes, bug fixes, or new
functionality.

NetBSD git log
--------------
netbsd-git-makefs.log contains a partial 'git log' of NetBSD's
usr.sbin/makefs.

On Nov 7 2010 cognet@ sync'd with NetBSD. The last NetBSD commit prior
to that was:

```
commit 29d74a517fe40cbc99df3b95d4618d58e9c05df7
Author: christos <christos>
Date:   Wed Oct 27 18:51:34 2010 +0000

    Handle > 2GB images. Thanks to Greg Troxel for testing!
```

Commit log entries for later NetBSD changes that already exist in
FreeBSD have also been removed.

Note that the NetBSD git hashes change will regularly change on successive
runs of the cvs-git conversion.
