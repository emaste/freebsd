/*-
 * Copyright (c) 20XX NAME <foo@bar>
 * All rights reserved.
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
 */
__FBSDID("$FreeBSD$");

#include <unistd.h>
#include <assert.h>

#include <atf-c.h>

#define OFFSET 16
static void
test_brk()
{
  void * origin_brk;
  int i;
  origin_brk = sbrk(0);

  for (i = 0; i < 100; i++) {
    assert(brk(origin_brk + i * OFFSET) == 0);
    assert(sbrk(0) == origin_brk + i * OFFSET);
    assert(brk(origin_brk) == 0);
    assert(sbrk(0) == origin_brk);
  }
}

static void
test_sbrk()
{
  void * origin_brk;
  int i;

  origin_brk = sbrk(0);

  for (i = 0; i < 100; i++) {
    assert(sbrk(i * OFFSET) == origin_brk);
    assert(sbrk(0) == origin_brk + i * OFFSET);
    assert(sbrk(-i * OFFSET) == origin_brk + i * OFFSET);
    assert(sbrk(0) == origin_brk);
  }
}

ATF_TC_WITHOUT_HEAD(brk);
ATF_TC_BODY(brk, tc)
{

  test_brk();
}


ATF_TC_WITHOUT_HEAD(sbrk);
ATF_TC_BODY(sbrk, tc)
{

  test_sbrk();
}

ATF_TP_ADD_TCS(tp)
{

  ATF_TP_ADD_TC(tp,brk);
  ATF_TP_ADD_TC(tp,sbrk);

  return (atf_no_error());
}
