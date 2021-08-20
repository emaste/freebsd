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

#include <sys/cdefs.h>
__FBSDID("$FreeBSD$");

#include <sys/types.h>
#include <sys/param.h>
#include <sys/kernel.h>
#include <sys/malloc.h>
#include <sys/mbuf.h>
#include <sys/socket.h>
#include <sys/socketvar.h>
#include <sys/uio.h>

#include <net/if.h>
#include <net/if_dl.h>
#include <net/if_types.h>
#include <net/if_var.h>
#include <netinet/in.h>
#include <netinet/in_var.h>

#include <dev/vt/ime/vt_ime.h>

#include <teken/teken.h>
#include <teken/teken_wcwidth.h>

static MALLOC_DEFINE(M_VT_IME, "vt_ime", "vt IME");

static int vt_ime_send_message(struct vt_ime *, char *, char *);
static int vt_ime_send_char(struct vt_ime *, int, char *);
static int vt_ime_delete(struct vt_ime *, char *);
static int vt_ime_request_output(struct vt_ime *, char *);
static int vt_ime_check_valid_char(struct vt_ime *, int);

static int vt_ime_convert_utf8_byte(int *, int *, unsigned char);
static void vt_ime_input(struct terminal *, const void *, size_t);

static int
vt_ime_send_message(struct vt_ime *vi, char *message, char *ret)
{
	struct thread *td = curthread;
	struct socket *so;
	struct sockaddr_in server_addr;

	struct uio auio;
	struct iovec iov[1];

	int error = 0;

	error = socreate(PF_INET, &so, SOCK_STREAM, 0, td->td_ucred, td);
	if (error != 0) {
		DPRINTF(10, "%s: socreate, error=%d\n", __func__, error);
		goto out;
	}

	/* initialize the socket */
	server_addr.sin_len = sizeof(struct sockaddr_in);
	server_addr.sin_family = AF_INET;
	server_addr.sin_port = htons(VT_IME_SOCK_PORT);
	bzero(&(server_addr.sin_zero), sizeof(server_addr.sin_zero));

	error = inet_pton(AF_INET, "127.0.0.1", &(server_addr.sin_addr));
	if (error <= 0) {
		DPRINTF(10, "Invalid address/ Address not supported \n");
		goto out;
	}

	error = soconnect(so, (struct sockaddr *)&server_addr, td);
	if (error != 0) {
		DPRINTF(10, "%s: soconnect, error=%d\n", __func__, error);
		goto out;
	}

	/* Wait for so->so_state & SS_ISCONNECTING = 0 */
	while (so->so_state & SS_ISCONNECTING) {
		/*
		 * timeo: sleep timo / hz seconds
		 * On my machine, hz is set to 100 (checked with `sysctl
		 * kern.clockrate`), so it will sleep 1 / 100 = 0.01 secs.
		 */
		pause(NULL, 1);
	}

	/* initialize iovec and uio structure */
	iov[0].iov_base = (void *)message;

	/* don't send '\0' in last byte */
	iov[0].iov_len = strlen(message);

	auio.uio_iov = iov;
	auio.uio_iovcnt = 1;
	auio.uio_segflg = UIO_SYSSPACE;
	auio.uio_rw = UIO_WRITE;
	auio.uio_td = td;
	auio.uio_offset = 0; /* XXX */
	auio.uio_resid = iov[0].iov_len;

	error = sosend(so, (struct sockaddr *)&server_addr, &auio,
	    (struct mbuf *)NULL, (struct mbuf *)NULL, 0, td);
	if (error != 0) {
		DPRINTF(10, "sosend=%d\n", error);
		goto out;
	}

	DPRINTF(10, "Send message \"%s\"!\n", message);

	/* Receive data from the ime server */
	iov[0].iov_base = (void *)ret;
	iov[0].iov_len = VT_IME_MAX_MESSAGE_LEN;

	auio.uio_iov = iov;
	auio.uio_iovcnt = 1;
	auio.uio_segflg = UIO_SYSSPACE;
	auio.uio_rw = UIO_READ;
	auio.uio_td = td;
	auio.uio_offset = 0; /* XXX */
	auio.uio_resid = iov[0].iov_len;

	error = soreceive(so, NULL, &auio, (struct mbuf **)NULL,
	    (struct mbuf **)NULL, 0);
	if (error != 0) {
		DPRINTF(10, "sorecv=%d\n", error);
		goto out;
	}

out:
	soclose(so);
	return (error);
}

static int
vt_ime_send_char(struct vt_ime *vi, int ch, char *ret)
{
	int bufsz;
	char *buf;

	bufsz = snprintf(NULL, 0, "key %d", ch);
	buf = malloc(bufsz + 1, M_VT_IME, M_WAITOK | M_ZERO);
	snprintf(buf, bufsz + 1, "key %d", ch);

	vt_ime_send_message(vi, buf, ret);
	free(buf, M_VT_IME);
	return (0);
}

static int
vt_ime_delete(struct vt_ime *vi, char *ret)
{
	char buf[] = "delete";

	vt_ime_send_message(vi, buf, ret);
	return (0);
}

static int
vt_ime_request_output(struct vt_ime *vi, char *ret)
{
	char buf[] = "output";

	vt_ime_send_message(vi, buf, ret);
	return (0);
}

static int
vt_ime_check_valid_char(struct vt_ime *vi, int ch)
{
	size_t valid_chars_len = strlen(VT_IME_VALID_BOPOMOFO_CHARS);

	for (size_t i = 0; i < valid_chars_len; i++)
		if (ch == VT_IME_VALID_BOPOMOFO_CHARS[i])
			return (1);
	return (0);
}

static int
vt_ime_convert_utf8_byte(int *utf8_left, int *utf8_partial, unsigned char c)
{
	/*
	 * UTF-8 handling.
	 */
	if ((c & 0x80) == 0x00) {
		/* One-byte sequence. */
		*utf8_left = 0;
		*utf8_partial = c;
		return (1);
	} else if ((c & 0xe0) == 0xc0) {
		/* Two-byte sequence. */
		*utf8_left = 1;
		*utf8_partial = c & 0x1f;
		return (0);
	} else if ((c & 0xf0) == 0xe0) {
		/* Three-byte sequence. */
		*utf8_left = 2;
		*utf8_partial = c & 0x0f;
		return (0);
	} else if ((c & 0xf8) == 0xf0) {
		/* Four-byte sequence. */
		*utf8_left = 3;
		*utf8_partial = c & 0x07;
		return (0);
	} else if ((c & 0xc0) == 0x80) {
		if (*utf8_left == 0)
			return (-1);
		(*utf8_left)--;
		*utf8_partial = (*utf8_partial << 6) | (c & 0x3f);
		if (*utf8_left == 0) {
			DPRINTF(10, "Got UTF-8 char %x\n", *utf8_partial);
			return (1);
		}
	}
	return (-1);
}

static void
vt_ime_input(struct terminal *term, const void *buf, size_t len)
{
	int ret;
	int utf8_left;
	uint32_t utf8_partial;
	const char *c = buf;

	while (len-- > 0) {
		ret = vt_ime_convert_utf8_byte(&utf8_left, &utf8_partial, *c++);
		if (ret > 0)
			terminal_input_char(term, utf8_partial);
	}
}

int
vt_ime_is_enabled(struct vt_ime *vi)
{
	return vi->vt_ime_state;
}

int
vt_ime_toggle_mode(struct vt_ime *vi)
{
	vt_ime_buf_state ^= 1;
	vi->vt_ime_state ^= 1;

	if (vi->vt_ime_state)
		DPRINTF(10, "Rime mode is enabled!\n");
    else
		DPRINTF(10, "Rime mode is disabled!\n");

	return vi->vt_ime_state;
}

int
vt_ime_process_char(struct terminal *term, struct vt_device *vd,
    struct vt_ime *vi, int ch)
{
	char *status, *output;
	status = output = NULL;

	if (vt_ime_check_valid_char(vi, ch)) {

		status = malloc(VT_IME_MAX_MESSAGE_LEN, M_VT_IME,
		    M_WAITOK | M_ZERO);
		vt_ime_send_char(vi, ch, status);

		output = malloc(VT_IME_MAX_MESSAGE_LEN, M_VT_IME,
		    M_WAITOK | M_ZERO);
		vt_ime_request_output(vi, output);

		vt_ime_draw_status_bar(vd, status);
		vt_ime_input(term, output, strlen(output));
	}

	/* Backspace */
	if (ch == 0x8) {

		status = malloc(VT_IME_MAX_MESSAGE_LEN, M_VT_IME,
		    M_WAITOK | M_ZERO);
		vt_ime_delete(vi, status);

		vt_ime_draw_status_bar(vd, status);
	}

	if (status)
		free(status, M_VT_IME);
	if (output)
		free(output, M_VT_IME);

	return (0);
}

void
vt_ime_draw_status_bar(struct vt_device *vd, char *status)
{
	struct vt_window *vw;
	struct vt_buf *vb;

	const teken_attr_t *a;
	term_char_t ch;
	term_rect_t tarea;

	int ret;
	int len, blen = 0;
	int utf8_left;
	uint32_t utf8_partial;
	const char *c = status;

	vw = vd->vd_curwindow;
	vb = &vw->vw_buf;

	a = teken_get_curattr(&vb->vb_terminal->tm_emulator);
	ch = FG_WHITE | BG_BLUE;

	len = strlen(status);

	while (len-- > 0) {
		ret = vt_ime_convert_utf8_byte(&utf8_left, &utf8_partial, *c++);
		if (ret <= 0)
			continue;

		if (teken_wcwidth(utf8_partial) == 2 &&
		    blen < vb->vb_scr_size.tp_col - 2) {
			vb->vb_ime_buffer[blen++] = utf8_partial | (ch);
			vb->vb_ime_buffer[blen++] = utf8_partial | (ch) |
			    TFORMAT(TF_CJK_RIGHT);
		} else if (blen < vb->vb_scr_size.tp_col - 1) {
			vb->vb_ime_buffer[blen++] = utf8_partial | (ch);
		} else {
			break;
		}
	}

	for (int i = blen; i < vb->vb_scr_size.tp_col; i++) {
		vb->vb_ime_buffer[i] = VTBUF_SPACE_CHAR(ch);
	}

	tarea.tr_begin.tp_row = tarea.tr_begin.tp_col = 0;
	tarea.tr_end.tp_row = 1;
	tarea.tr_end.tp_col = vb->vb_scr_size.tp_col;

	vtbuf_lock(&vw->vw_buf);
	if (vd->vd_driver->vd_invalidate_text)
		vd->vd_driver->vd_invalidate_text(vd, &tarea);
	vtbuf_dirty(&vw->vw_buf, &tarea);
	vtbuf_unlock(&vw->vw_buf);

	/* Rerun timer for screen updates. */
	vt_resume_flush_timer(vd->vd_curwindow, 0);
}
