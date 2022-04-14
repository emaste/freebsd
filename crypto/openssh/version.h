/* $OpenBSD: version.h,v 1.94 2022/04/04 22:45:25 djm Exp $ */
/* $FreeBSD$ */

#define SSH_VERSION	"OpenSSH_9.0"

#define SSH_PORTABLE	"p1"
#define SSH_RELEASE	SSH_VERSION SSH_PORTABLE

#define SSH_VERSION_FREEBSD	"FreeBSD-20220413"

#ifdef WITH_OPENSSL
#define OPENSSL_VERSION_STRING	OpenSSL_version(OPENSSL_VERSION)
#else
#define OPENSSL_VERSION_STRING	"without OpenSSL"
#endif
