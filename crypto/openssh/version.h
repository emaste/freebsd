/* $OpenBSD: version.h,v 1.90 2021/04/16 03:42:00 djm Exp $ */
/* $FreeBSD$ */

#define SSH_VERSION	"OpenSSH_8.6"

#define SSH_PORTABLE	"p1"
#define SSH_RELEASE	SSH_VERSION SSH_PORTABLE

#define SSH_VERSION_FREEBSD	"FreeBSD-20200214"

#ifdef WITH_OPENSSL
#define OPENSSL_VERSION_STRING	OpenSSL_version(OPENSSL_VERSION)
#else
#define OPENSSL_VERSION_STRING	"without OpenSSL"
#endif
