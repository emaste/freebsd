/*
 * $FreeBSD$
 */
#ifndef _SYS_CK_H_
#define _SYS_CK_H_

#ifdef _KERNEL
#include <ck_epoch.h>
#include <ck_queue.h>
#else
#include <sys/queue.h>
#define CK_STAILQ_HEAD STAILQ_HEAD
#define CK_STAILQ_ENTRY STAILQ_ENTRY
#define CK_LIST_HEAD LIST_HEAD
#define CK_LIST_ENTRY LIST_ENTRY
#endif

#endif /* !_SYS_CK_H_ */
