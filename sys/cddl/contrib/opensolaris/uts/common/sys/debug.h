/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "License").
 * You may not use this file except in compliance with the License.
 *
 * You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
 * or http://www.opensolaris.org/os/licensing.
 * See the License for the specific language governing permissions
 * and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the License file at usr/src/OPENSOLARIS.LICENSE.
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 */
/*
 * Copyright 2014 Garrett D'Amore <garrett@damore.org>
 *
 * Copyright 2010 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

/*
 * Copyright (c) 2012, 2017 by Delphix. All rights reserved.
 * Copyright 2013 Saso Kiselkov. All rights reserved.
 */

/*	Copyright (c) 1984, 1986, 1987, 1988, 1989 AT&T	*/
/*	  All Rights Reserved	*/

#ifndef _SYS_DEBUG_H
#define	_SYS_DEBUG_H

#include <sys/types.h>
#include <sys/note.h>

#ifdef	__cplusplus
extern "C" {
#endif

/*
 * Assertion variants sensitive to the compilation data model
 */
#if defined(_LP64)
#define	ASSERT64(x)	ASSERT(x)
#define	ASSERT32(x)
#else
#define	ASSERT64(x)
#define	ASSERT32(x)	ASSERT(x)
#endif

/*
 * IMPLY and EQUIV are assertions of the form:
 *
 *	if (a) then (b)
 * and
 *	if (a) then (b) *AND* if (b) then (a)
 */
#ifdef DEBUG
#define	IMPLY(A, B) \
	((void)(((!(A)) || (B)) || \
	    assfail("(" #A ") implies (" #B ")", __FILE__, __LINE__)))
#define	EQUIV(A, B) \
	((void)((!!(A) == !!(B)) || \
	    assfail("(" #A ") is equivalent to (" #B ")", __FILE__, __LINE__)))
#else
#define	IMPLY(A, B) ((void)0)
#define	EQUIV(A, B) ((void)0)
#endif

/*
 * Compile-time assertion. The condition 'x' must be constant.
 */
#ifndef CTASSERT
#define	CTASSERT(x)		_CTASSERT(x, __LINE__)
#define	_CTASSERT(x, y)		__CTASSERT(x, y)
#define	__CTASSERT(x, y) 	\
	_Static_assert((x), "Static assert failed at " #y)
#endif

#ifdef	_KERNEL

extern void abort_sequence_enter(char *);
extern void debug_enter(char *);

#endif	/* _KERNEL */

#if defined(DEBUG) && !defined(__sun)
/* CSTYLED */
#define	STATIC
#else
/* CSTYLED */
#define	STATIC static
#endif

#ifdef	__cplusplus
}
#endif

#endif	/* _SYS_DEBUG_H */
