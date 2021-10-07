# $FreeBSD$

PROG=	ssh-sk-helper
SRCS=	ssh-sk-helper.c ssh-sk.c sk-usbhid.c
MAN=	ssh-sk-helper.8
CFLAGS+=-I${SSHDIR} -include ssh_namespace.h
CFLAGS+=-I${.CURDIR}/../../../contrib/libfido2/src
SRCS+=	ssh_namespace.h

LIBADD=	ssh fido2 cbor crypto z

.include <bsd.prog.mk>

.PATH:	${SSHDIR}
