/*-
 * SPDX-License-Identifier: BSD-3-Clause and BSD-2-Clause
 *
 * For sys/kern/kern_sig.c:
 *
 * Copyright (c) 1982, 1986, 1989, 1991, 1993
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
 *
 * For sys/kern/imgact_elf.c:
 *
 * Copyright (c) 2017 Dell EMC
 * Copyright (c) 2000-2001, 2003 David O'Brien
 * Copyright (c) 1995-1996 Søren Schmidt
 * Copyright (c) 1996 Peter Wemm
 * All rights reserved.
 *
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
/*-
 * Copyright 2024 Bjoern A. Zeeb
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * The implementation is modelled losely after our normal corefile code.
 * We really should have a user space handler to open the file, pass the
 * file descriptor and then fget() and use that for IO instead of doing all
 * the hustle and magic here.
 * That would likely also solve the entire problem with the hard coded
 * directory prefix and file name.
 */

#include <sys/types.h>
#include <sys/fcntl.h>
#include <sys/mount.h>
#include <sys/namei.h>
#include <sys/proc.h>
#include <sys/vnode.h>
#include <sys/unistd.h>

#include <sys/systm.h>		/* hexdump(9) */

#include <linux/gfp.h>
#include <linux/devcoredump.h>
#include <linux/scatterlist.h>
#include <linux/device.h>

int
lkpi_dev_coredumpsg(void *arg, size_t datalen, struct vnode *vp)
{
	struct scatterlist *table, *iter;
	struct page *p;
	off_t offset;
	size_t left, resid;
	int error, i;

	table = arg;
	left = datalen;
	offset = 0;
	resid = 0;
	for_each_sg(table, iter, sg_nents(table), i) {
		p = sg_page(iter);
		if (p) {
			int len;

			len = MIN(PAGE_SIZE, left);
			//hexdump(linux_page_address(p), len, "DEVCORE: ", 0);
			//printf("%s: seg len %d\n", __func__, len);
			error = vn_rdwr_inchunks(UIO_WRITE, vp, linux_page_address(p), len, offset, UIO_SYSSPACE,
			    IO_UNIT | IO_DIRECT | IO_RANGELOCKED, curthread->td_ucred, curthread->td_ucred, &resid, curthread);
			if (error != 0)
				return (error);

			left -= len;
			offset += len;
		}
	}

	return (0);
}

int
lkpi_dev_coredump(struct device *dev, void *arg, size_t datalen, dev_coredump_cb cb)
{
	struct proc *p;
	struct ucred *cred;
	struct vnode *vp;
	struct nameidata nd;
	struct flock lf;
	struct vattr vattr;
	void *rl_cookie;
	char *name;
	int cmode, error, error1, flags, oflags, locked;

	name = malloc(MAXPATHLEN, M_TEMP, M_WAITOK | M_ZERO);			/* gpf_t ? */

	/* XXX /var/crash hardcoded. */
	snprintf(name, MAXPATHLEN, "/var/crash/%s.%ju",
	    device_get_nameunit(dev->bsddev), (uintmax_t)ticks);

	cmode = S_IRUSR | S_IWUSR;
	oflags = VN_OPEN_NOAUDIT | VN_OPEN_NAMECACHE |
	    ((1 /*capmode_coredump */) ? VN_OPEN_NOCAPCHECK : 0);		/* XXX FIXME */
	flags = O_CREAT | FWRITE | O_NOFOLLOW | O_EXCL;

	NDINIT(&nd, LOOKUP, NOFOLLOW, UIO_SYSSPACE, name);
	error = vn_open_cred(&nd, &flags, cmode, oflags, curthread->td_ucred,
	    NULL);
	if (error != 0)
		goto out;
	vp = nd.ni_vp;
	NDFREE_PNBUF(&nd);

	cred = curthread->td_ucred;

	/*
	 * Don't dump to non-regular files or files with links.
	 * Do not dump into system files. Effective user must own the corefile.
	 */
	if (vp->v_type != VREG || VOP_GETATTR(vp, &vattr, cred) != 0 ||
	    vattr.va_nlink != 1 || (vp->v_vflag & VV_SYSTEM) != 0 ||
	    vattr.va_uid != cred->cr_uid) {
		VOP_UNLOCK(vp);
		error = EFAULT;
		goto out;
	}

	VOP_UNLOCK(vp);

	/* Postpone other writers, including core dumps of other processes. */
	rl_cookie = vn_rangelock_wlock(vp, 0, OFF_MAX);

	p = curthread->td_proc;

	lf.l_whence = SEEK_SET;
	lf.l_start = 0;
	lf.l_len = 0;
	lf.l_type = F_WRLCK;
	locked = (VOP_ADVLOCK(vp, (caddr_t)p, F_SETLK, &lf, F_FLOCK) == 0);

	VATTR_NULL(&vattr);
	vattr.va_size = 0;
	if (1 /*set_core_nodump_flag */)				/* XXX */
		vattr.va_flags = UF_NODUMP;
	vn_lock(vp, LK_EXCLUSIVE | LK_RETRY);
	VOP_SETATTR(vp, &vattr, cred);
	VOP_UNLOCK(vp);

	if (cb != NULL)
		error = cb(arg, datalen, vp);
	else
		error = ENOSYS;

	if (locked) {
		lf.l_type = F_UNLCK;
		VOP_ADVLOCK(vp, (caddr_t)p, F_UNLCK, &lf, F_FLOCK);
	}
	vn_rangelock_unlock(vp, rl_cookie);

	error1 = vn_close(vp, FWRITE, cred, curthread);
	if (error == 0)
		error = error1;

out:
#if 0 && defined(AUDIT)
	audit_devcoredump(dev->bsddev, name, error);
#endif

	/* XXX log possible error */
	free(name, M_TEMP);

	return (error);
}


