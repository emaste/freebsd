# $FreeBSD$

PROG=	decryptcore

LIBADD=	crypto pjdlog

MAN=	decryptcore.8

CFLAGS+=-I${SRCTOP}/lib/libpjdlog
CFLAGS+=-DOPENSSL_API_COMPAT=0x10100000L

.include <bsd.prog.mk>
