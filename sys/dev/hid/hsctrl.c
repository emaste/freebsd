/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2020 Vladimir Kondratyev <wulf@FreeBSD.org>
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

#include <sys/cdefs.h>
/*
 * General Desktop/System Controls usage page driver
 * https://www.usb.org/sites/default/files/documents/hut1_12v2.pdf
 */

#include <sys/param.h>
#include <sys/bitstring.h>
#include <sys/bus.h>
#include <sys/kernel.h>
#include <sys/module.h>
#include <sys/sysctl.h>

#include <dev/evdev/input.h>
#include <dev/evdev/evdev.h>

#include <dev/hid/hid.h>
#include <dev/hid/hidbus.h>
#include <dev/hid/hidmap.h>

static hidmap_cb_t	hsctrl_radio_cb;

#define	HSCTRL_MAP(usage, code)	\
	{ HIDMAP_KEY(HUP_GENERIC_DESKTOP, HUG_SYSTEM_##usage, code) }

static const struct hidmap_item hsctrl_map[] = {
	HSCTRL_MAP(POWER_DOWN,		KEY_POWER),
	HSCTRL_MAP(SLEEP,		KEY_SLEEP),
	HSCTRL_MAP(WAKEUP,		KEY_WAKEUP),
	HSCTRL_MAP(CONTEXT_MENU,	KEY_CONTEXT_MENU),
	HSCTRL_MAP(MAIN_MENU,		KEY_MENU),
	HSCTRL_MAP(APP_MENU,		KEY_PROG1),
	HSCTRL_MAP(MENU_HELP,		KEY_HELP),
	HSCTRL_MAP(MENU_EXIT,		KEY_EXIT),
	HSCTRL_MAP(MENU_SELECT,		KEY_SELECT),
	HSCTRL_MAP(MENU_RIGHT,		KEY_RIGHT),
	HSCTRL_MAP(MENU_LEFT,		KEY_LEFT),
	HSCTRL_MAP(MENU_UP,		KEY_UP),
	HSCTRL_MAP(MENU_DOWN,		KEY_DOWN),
	HSCTRL_MAP(POWER_UP,		KEY_POWER2),
	HSCTRL_MAP(RESTART,		KEY_RESTART),
	{ HIDMAP_REL_CB(HUP_GENERIC_DESKTOP, HUG_RADIO_BUTTON,
	    &hsctrl_radio_cb) },
};

static const struct hid_device_id hsctrl_devs[] = {
	{ HID_TLC(HUP_GENERIC_DESKTOP, HUG_SYSTEM_CONTROL) },
	{ HID_TLC(HUP_GENERIC_DESKTOP, HUG_RADIO_CONTROL) },
};

/*
 * Synthesize key-down + key-up for the wireless radio button,
 * which only reports a relative pulse (value=1) on press.
 * The firmware latches value=1 and never resets it, so we
 * track the last value via HIDMAP_CB_UDATA64 and only fire
 * on the 0 -> non-zero transition.
 */
static int
hsctrl_radio_cb(HIDMAP_CB_ARGS)
{
	struct evdev_dev *evdev = HIDMAP_CB_GET_EVDEV();
	int32_t last;

	switch (HIDMAP_CB_GET_STATE()) {
	case HIDMAP_CB_IS_ATTACHING:
		evdev_support_event(evdev, EV_KEY);
		evdev_support_key(evdev, KEY_RFKILL);
		HIDMAP_CB_UDATA64 = 0;
		break;
	case HIDMAP_CB_IS_RUNNING:
		last = (int32_t)HIDMAP_CB_UDATA64;
		HIDMAP_CB_UDATA64 = (uint64_t)ctx.data;
		if (ctx.data == 0 || ctx.data == last)
			return (ENOMSG);
		evdev_push_key(evdev, KEY_RFKILL, 1);
		evdev_push_key(evdev, KEY_RFKILL, 0);
		break;
	default:
		break;
	}

	return (0);
}

static int
hsctrl_probe(device_t dev)
{
	return (HIDMAP_PROBE(device_get_softc(dev), dev,
	    hsctrl_devs, hsctrl_map, "System Control"));
}

static int
hsctrl_attach(device_t dev)
{
	return (hidmap_attach(device_get_softc(dev)));
}

static int
hsctrl_detach(device_t dev)
{
	return (hidmap_detach(device_get_softc(dev)));
}

static device_method_t hsctrl_methods[] = {
	DEVMETHOD(device_probe,		hsctrl_probe),
	DEVMETHOD(device_attach,	hsctrl_attach),
	DEVMETHOD(device_detach,	hsctrl_detach),

	DEVMETHOD_END
};

DEFINE_CLASS_0(hsctrl, hsctrl_driver, hsctrl_methods, sizeof(struct hidmap));
DRIVER_MODULE(hsctrl, hidbus, hsctrl_driver, NULL, NULL);
MODULE_DEPEND(hsctrl, hid, 1, 1, 1);
MODULE_DEPEND(hsctrl, hidbus, 1, 1, 1);
MODULE_DEPEND(hsctrl, hidmap, 1, 1, 1);
MODULE_DEPEND(hsctrl, evdev, 1, 1, 1);
MODULE_VERSION(hsctrl, 1);
HID_PNP_INFO(hsctrl_devs);
