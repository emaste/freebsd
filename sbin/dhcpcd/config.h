/* freebsd */
#ifndef	SYSCONFDIR
#define	SYSCONFDIR		"/etc"
#define	SBINDIR			"/sbin"
#define	LIBDIR			"/lib"
#define	LIBEXECDIR		"/libexec"
#define	DBDIR			"/var/db/dhcpcd"
#define	RUNDIR			"/var/run/dhcpcd"
#endif
#include			<net/if.h>
#include			<net/if_var.h>
#ifndef PRIVSEP_USER
#define PRIVSEP_USER		 "_dhcp"
#endif
#define	HAVE_CAPSICUM
#define	HAVE_OPEN_MEMSTREAM
#include			"compat/pidfile.h"
#include			"compat/strtoi.h"
#include			"compat/consttime_memequal.h"
#define	HAVE_SYS_QUEUE_H
#define	RBTEST
#include			"compat/rbtree.h"
#define	HAVE_REALLOCARRAY
#define	HAVE_PPOLL
#define	HAVE_MD5_H
#define	SHA2_H			<sha256.h>
#include			"compat/crypt/hmac.h"
