# $FreeBSD$

.include <src.opts.mk>

SUBDIR=	libiberty \
	libbfd \
	libopcodes
SUBDIR.${MK_BINUTILS}+=	doc
SUBDIR.${MK_BINUTILS}+=	as
# All archs except powerpc either use lld or require external toolchain.
# powerpc still needs binutils ld to link 32-bit binaries.
.if ${TARGET} == "powerpc"
SUBDIR.${MK_BINUTILS}+=ld
.endif

SUBDIR_DEPEND_as=libbfd libiberty libopcodes
SUBDIR_DEPEND_ld=libbfd libiberty

.if !make(install)
SUBDIR_PARALLEL=
.endif

.include <bsd.subdir.mk>
