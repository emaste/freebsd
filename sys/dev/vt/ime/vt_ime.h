/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2021 Fan Chung
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
 * $FreeBSD$
 */

#include <sys/terminal.h>

#include <dev/vt/vt.h>

struct vt_ime {

#define VT_IME_KEY RCTR /* right control key */
#define VT_IME_SOCK_PORT 2133
#define VT_IME_VALID_BOPOMOFO_CHARS \
	"abcdefghijklmnopqrstuvwxyz0123456789 ,.;-=/"
#define VT_IME_MAX_MESSAGE_LEN 1024
#define VT_IME_STATUS_BAR_HEIGHT 1

	int vt_ime_state; /* IME state */
};

int vt_ime_toggle_mode(struct vt_ime *vi);
int vt_ime_is_enabled(struct vt_ime *vi);
int vt_ime_process_char(struct terminal *terminal, struct vt_device *vd,
    struct vt_ime *vi, int ch);
void vt_ime_draw_status_bar(struct vt_device *vd, char *status);
