.include <src.opts.mk>
.include "${SRCTOP}/secure/ssh.mk"

LIB=	ssh
PRIVATELIB=	true
SHLIB_MAJOR=	5
SRCS=	ssh_api.c
SRCS+=	authfd.c \
	cipher-aes.c \
	cleanup.c \
	compat.c fatal.c hostfile.c \
	dns.c entropy.c \
	readpass.c \
	utf8.c \
	sftp-realpath.c platform-pledge.c platform-tracing.c platform-misc.c
SRCS+=	${SRCS_BASE}
SRCS+=	${SRCS_KEX} ${SRCS_KEXC} ${SRCS_KEXS}
SRCS+=	${SRCS_KEY}
SRCS+=	${SRCS_KEYP}
SRCS+=	${SRCS_KRL}
SRCS+=	${SRCS_MAC}
SRCS+=	${SRCS_PKT}
SRCS+=	${SRCS_PROT}
SRCS+=	${SRCS_PKCS11}
SRCS+=	${SRCS_MODULI}
SRCS+=	${SRCS_SK_CLIENT}

PACKAGE=	ssh

# gss-genr.c should be in $SRCS but causes linking problems, so it is
# compiled directly into sshd instead.

# Portability layer
SRCS+=	bcrypt_pbkdf.c blowfish.c bsd-misc.c bsd-signal.c explicit_bzero.c \
	fmt_scaled.c freezero.c glob.c \
	libressl-api-compat.c \
	mktemp.c \
	openssl-compat.c port-net.c \
	recallocarray.c strtonum.c timingsafe_bcmp.c vis.c xcrypt.c

.if ${MK_LDNS} == "no"
SRCS+=	getrrsetbyname.c
.else
LDNSDIR=	${SRCTOP}/contrib/ldns
CFLAGS+=	-DHAVE_LDNS=1 -I${LDNSDIR}
SRCS+=	getrrsetbyname-ldns.c
LIBADD+=	ldns
.endif

.if ${MK_GSSAPI} != "no" && ${MK_KERBEROS_SUPPORT} != "no"
CFLAGS+= -include krb5_config.h
SRCS+=	 krb5_config.h
.endif

.if defined(LOCALBASE)
CFLAGS+= -D_PATH_SSH_ASKPASS_DEFAULT='"${LOCALBASE}/bin/ssh-askpass"'
.endif

NO_LINT=

LIBADD+=	crypto crypt z

.include <bsd.lib.mk>

.PATH: ${SSHDIR} ${SSHDIR}/openbsd-compat
