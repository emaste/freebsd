# Common Make variables for OpenSSH

.include <src.opts.mk>

SSHDIR=		${SRCTOP}/crypto/openssh

CFLAGS+= -I${SSHDIR} -include ssh_namespace.h
SRCS+=	 ssh_namespace.h

.if ${MK_USB} != "no"
# Built-in security key support
CFLAGS+= -include sk_config.h
.endif

SRCS_BASE+=	sshbuf.c
SRCS_BASE+=	sshbuf-getput-basic.c
SRCS_BASE+=	sshbuf-misc.c
SRCS_BASE+=	ssherr.c
SRCS_BASE+=	log.c
SRCS_BASE+=	xmalloc.c
SRCS_BASE+=	misc.c
SRCS_BASE+=	addr.c
SRCS_BASE+=	addrmatch.c
SRCS_BASE+=	match.c

SRCS_KEX+=	dh.c
SRCS_KEX+=	kexdh.c
SRCS_KEX+=	kexecdh.c
SRCS_KEX+=	kexgex.c
SRCS_KEXC+=	kexgexc.c
SRCS_KEXS+=	kexgexs.c
SRCS_KEX+=	kexc25519.c
SRCS_KEX+=	smult_curve25519_ref.c
SRCS_KEX+=	kexgen.c
SRCS_KEX+=	kexsntrup761x25519.c
SRCS_KEX+=	sntrup761.c
SRCS_PKT+=	kexmlkem768x25519.c

SRCS_KEY+=	sshkey.c
SRCS_KEY+=	cipher.c
SRCS_KEY+=	chacha.c
SRCS_KEY+=	poly1305.c
SRCS_KEY+=	ssh-ecdsa.c
SRCS_KEY+=	ssh-ecdsa-sk.c
SRCS_KEY+=	ssh-rsa.c
SRCS_KEY+=	ssh-dss.c
SRCS_KEY+=	sshbuf-getput-crypto.c
SRCS_KEY+=	digest-openssl.c
SRCS_KEY+=	cipher-chachapoly-libcrypto.c
SRCS_KEY+=	cipher-aesctr.c
SRCS_KEY+=	rijndael.c
SRCS_KEY+=	digest-libc.c
SRCS_KEY+=	cipher-chachapoly.c
SRCS_KEY+=	ssh-ed25519.c
SRCS_KEY+=	ssh-ed25519-sk.c
SRCS_KEY+=	ed25519.c
SRCS_KEY+=	hash.c

SRCS_KEYP+=	authfile.c
SRCS_KEYP+=	sshbuf-io.c
SRCS_KEYP+=	atomicio.c

SRCS_KRL+=	bitmap.c
SRCS_KRL+=	krl.c

SRCS_MAC+=	mac.c
SRCS_MAC+=	hmac.c
SRCS_MAC+=	umac.c
SRCS_MAC+=	umac128.c

SRCS_PKT+=	canohost.c
SRCS_PKT+=	dispatch.c
SRCS_PKT+=	kex.c
SRCS_PKT+=	kex-names.c
SRCS_PKT+=	packet.c

SRCS_PROT+=	channels.c
SRCS_PROT+=	monitor_fdpass.c
SRCS_PROT+=	nchan.c
SRCS_PROT+=	ttymodes.c

SRCS_PKCS11+=		ssh-pkcs11.c
SRCS_PKCS11_CLIENT+=	ssh-pkcs11-client.c
SRCS_MODULI+=		moduli.c

SRCS_SK=		ssh-sk.c
SRCS_SK+=		sk-usbhid.c
SRCS_SK_CLIENT=		ssh-sk-client.c
SRCS_SK_CLIENT+=	msg.c
