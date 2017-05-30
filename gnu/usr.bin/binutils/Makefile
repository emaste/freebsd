# $FreeBSD$

.include <src.opts.mk>

SUBDIR=	libiberty \
	libbfd \
	libopcodes
SUBDIR.${MK_BINUTILS}+=	doc
SUBDIR.${MK_BINUTILS}+=	as
# When we use ld.lld as /usr/bin/ld, do not install the non-ifunc-capable
# GNU binutils 2.17.50 ld.
# Except if we are on powerpc, that needs the ld from binutils to link
# 32-bit binaries.
.if ${MK_LLD_IS_LD} == "no" || ${TARGET} == "powerpc"
SUBDIR.${MK_BINUTILS}+=ld
.endif

SUBDIR_DEPEND_as=libbfd libiberty libopcodes
SUBDIR_DEPEND_ld=libbfd libiberty

.if !make(install)
SUBDIR_PARALLEL=
.endif

.include <bsd.subdir.mk>
