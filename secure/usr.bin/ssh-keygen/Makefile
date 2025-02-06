.include <src.opts.mk>
.include "${SRCTOP}/secure/ssh.mk"

PROG=	ssh-keygen
SRCS=	ssh-keygen.c sshsig.c ${SSH_SK_CLIENT}
PACKAGE=	ssh

LIBADD=	ssh

.if ${MK_LDNS} != "no"
CFLAGS+=	-DHAVE_LDNS=1
.endif

LIBADD+=	crypto

.include <bsd.prog.mk>

.PATH:	${SSHDIR}
