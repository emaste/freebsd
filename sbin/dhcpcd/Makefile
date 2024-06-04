# $FreeBSD$

# Derived from DragonFly BSD's Makefile for dhcpcd,
# which was derived from NetBSD's Makefile for dhcpcd

.include <src.opts.mk>

DISTDIR=	${.CURDIR}/../../contrib/dhcpcd

PACKAGE=	dhcpcd
PROG=		dhcpcd

WARNS?=		0

SRCDIR=		${DISTDIR}/src
.PATH:		${SRCDIR}
CFLAGS+=	-DHAVE_CONFIG_H -I${.CURDIR} -I${SRCDIR} -I${DISTDIR}
CFLAGS+=	-I${.OBJDIR}
SRCS=		common.c control.c dhcpcd.c duid.c eloop.c logerr.c
SRCS+=		if.c if-options.c route.c sa.c script.c
SRCS+=		dhcp-common.c dhcpcd-embedded.c
SRCS+=		if-bsd.c

CFLAGS+=	-DAUTH
SRCS+=		auth.c

CFLAGS+=	-DPRIVSEP -DPRIVSEP_USER='"_dhcp"'
SRCS+=		privsep.c privsep-root.c privsep-inet.c privsep-control.c
SRCS+=		privsep-bsd.c

.if ${MK_INET_SUPPORT} != "no"
CFLAGS+=	-DINET
SRCS+=		bpf.c dhcp.c ipv4.c
SRCS+=		privsep-bpf.c
CFLAGS+=	-DARP -DARPING
SRCS+=		arp.c
CFLAGS+=	-DIPV4LL
SRCS+=		ipv4ll.c
.endif

.if ${MK_INET6_SUPPORT} != "no"
CFLAGS+=	-DINET6
SRCS+=		ipv6.c ipv6nd.c
CFLAGS+=	-DDHCP6
SRCS+=		dhcp6.c
.endif

.PATH:		${DISTDIR}/compat
SRCS+=		pidfile.c rb.c strtoi.c strtou.c
.PATH:		${DISTDIR}/compat/crypt
CFLAGS+=	-lmd
SRCS+=		hmac.c

_LIBEXECDIR=	/libexec
_DATADIR=	/usr/share/examples
_HOOKDIR=	${_LIBEXECDIR}/dhcpcd-hooks
MAN=		dhcpcd.conf.5 dhcpcd.8
CONFS=		dhcpcd.conf
CONFDIR=	/etc
CONFMODE=	644

#
# Hooks
#

HOOKSRC=	${DISTDIR}/hooks
.PATH:		${HOOKSRC}

SCRIPTS=	dhcpcd-run-hooks
SCRIPTSDIR=	${_LIBEXECDIR}
MAN+=		dhcpcd-run-hooks.8

FILES=		01-test 20-resolv.conf 30-hostname
FILESDIR=	${_HOOKDIR}

# Example hooks that should not be installed by default
.for f in 10-wpa_supplicant 15-timezone 29-lookup-hostname 50-ypbind
FILES+=		${f}
FILESDIR_${f}=	${_DATADIR}/dhcpcd/hooks
.endfor

###
CLEANFILES+=	dhcpcd-embedded.h dhcpcd-embedded.c

dhcpcd-embedded.h: dhcpcd-embedded.h.in
	(cd ${DISTDIR}/src && sh ${DISTDIR}/src/genembedh ${.ALLSRC}) > ${.TARGET}

dhcpcd-embedded.c: dhcpcd-embedded.c.in
	(cd ${DISTDIR}/src && sh ${DISTDIR}/src/genembedc ${.ALLSRC}) > ${.TARGET}

if-options.c: dhcpcd-embedded.h

###

.include <bsd.prog.mk>
