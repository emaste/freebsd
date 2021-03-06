#!/bin/sh

#
# Copyright (c) 2014 EMC Corp.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#

# Missing wakeup in the bufobj_wwait().

# Snapshot of WiP work.
# http://people.freebsd.org/~pho/stress/log/mmap15.txt
# Not fixed

# panic: invalid size
# http://people.freebsd.org/~pho/stress/log/kostik738.txt
# Fixed in r274878

[ `id -u ` -ne 0 ] && echo "Must be root!" && exit 1

. ../default.cfg

here=`pwd`
cd /tmp
sed '1,/^EOF/d' < $here/$0 > mmap15.c
mycc -o mmap15 -Wall -Wextra -O2 -g mmap15.c -lpthread || exit 1
rm -f mmap15.c

for i in `jot 2`; do
	su $testuser -c /tmp/mmap15 &
done
sleep 300
while pgrep -q mmap15; do
	pkill -9 mmap15
	sleep 2
done
wait

rm -f /tmp/mmap15 /tmp/mmap15.core
exit 0
EOF
#include <sys/types.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/wait.h>

#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <pthread_np.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define LOOPS 2
#define MMSIZE (256 * 1024)
#define N (128 * 1024 / (int)sizeof(u_int32_t))
#define PARALLEL 50

void *p;
u_int32_t r[N];

unsigned long
makearg(void)
{
	unsigned long val;
	unsigned int i;

	val = arc4random();
	i   = arc4random() % 100;
	if (i < 20)
		val = val & 0xff;
	if (i >= 20 && i < 40)
		val = val & 0xffff;
	if (i >= 40 && i < 60)
		val = (unsigned long)(r) | (val & 0xffff);
#if defined(__LP64__)
	if (i >= 60) {
		val = (val << 32) | arc4random();
		if (i > 80)
			val = val & 0x00007fffffffffffUL;
	}
#endif

	return(val);
}

void *
makeptr(void)
{
	unsigned long val;

	if (p != MAP_FAILED && p != NULL)
		val = (unsigned long)p + arc4random();
	else
		val = makearg();
	val = trunc_page(val);

	return ((void *)val);
}

void *
tmmap(void *arg __unused)
{
	size_t len;
	int i, j, fd;

	pthread_set_name_np(pthread_self(), __func__);
	len = MMSIZE;

	if ((fd = open("/dev/zero", O_RDWR)) == -1)
		err(1,"open()");
	for (i = 0, j = 0; i < 100; i++) {
		p = mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_PRIVATE, fd, 0);
		if (p != MAP_FAILED)
			j++;
		p = mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_ANON, -1, 0);
		if (p != MAP_FAILED)
			j++;
	}
	if (j == 0)
		fprintf(stderr, "FAIL: all mmap(2) calls failed.\n");
	close(fd);

	return (NULL);
}

void *
tmlock(void *arg __unused)
{
	size_t len;
	int i, n;

	pthread_set_name_np(pthread_self(), __func__);
	n = 0;
	for (i = 0; i < 200; i++) {
		len = trunc_page(makearg());
		if (mlock(makeptr(), len) == 0)
			n++;
		len = trunc_page(makearg());
		if (arc4random() % 100 < 50)
			if (munlock(makeptr(), len) == 0)
				n++;
	}
	if (n < 10)
		fprintf(stderr, "Note: tmlock() only succeeded %d times.\n",
		    n);

	return (NULL);
}

void
test(void)
{
	pthread_t tid[2];
	int i, rc;

	if ((rc = pthread_create(&tid[0], NULL, tmmap, NULL)) != 0)
		errc(1, rc, "tmmap()");
	if ((rc = pthread_create(&tid[1], NULL, tmlock, NULL)) != 0)
		errc(1, rc, "tmlock()");

	for (i = 0; i < 100; i++) {
		if (fork() == 0) {
			usleep(10000);
			_exit(0);
		}
		wait(NULL);
	}

	raise(SIGSEGV);

	for (i = 0; i < 2; i++)
		if ((rc = pthread_join(tid[i], NULL)) != 0)
			errc(1, rc, "pthread_join(%d)", i);
	_exit(0);
}

int
main(void)
{
	int i, j;

	for (i = 0; i < N; i++)
		r[i] = arc4random();

	for (i = 0; i < LOOPS; i++) {
		for (j = 0; j < PARALLEL; j++) {
			if (fork() == 0)
				test();
		}

		for (j = 0; j < PARALLEL; j++)
			wait(NULL);
	}

	return (0);
}
