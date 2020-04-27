#! $FreeBSD$

LUASRC?=	${SRCTOP}/contrib/lua/src
LCURSESSRC?=	${SRCTOP}/contrib/lua/lcurses/ext
.PATH: ${LCURSESSRC}

SHLIB_NAME=	curses_c.so
WARNS?=	2
LIBDIR=	/usr/lib/flua

SRCS=	curses.c

LDFLAGS=	-Wl,-E

CFLAGS+=	-I${.CURDIR} -I${LCURSESSRC} -I${LCURSESSRC}/include -I${LUASRC}
CFLAGS+=	-I${SRCTOP}/lib/liblua

.include <bsd.lib.mk>
