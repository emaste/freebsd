PROG=	fwcontrol
SRCS=	fwcontrol.c fwcrom.c fwdv.c fwmpegts.c
MAN=	fwcontrol.8
WARNS?=	3

.PATH:	${SRCTOP}/sys/dev/firewire

SDIR= ${SRCTOP}/sys
CFLAGS+=-I${.CURDIR} -I${SDIR}
CWARNFLAGS+=	${NO_WZERO_LENGTH_BOUNDS}

.include <bsd.prog.mk>
