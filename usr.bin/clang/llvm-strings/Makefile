# $FreeBSD$

.include <src.opts.mk>

PROG_CXX=	llvm-strings

SRCDIR=		llvm/tools/llvm-strings
SRCS+=		llvm-strings.cpp

.if ${MK_LLVM_BINUTILS} != "no"
LINKS=		${BINDIR}/llvm-strings ${BINDIR}/strings
MLINKS=		llvm-strings.1 strings.1
.endif

.include "../llvm.prog.mk"
