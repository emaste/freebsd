/*-
 * Copyright (c) 2018 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jared McNeill <jmcneill@invisible.ca>.
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
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * ARM Server Base System Architecture (SBSA)-compliant generic watchdog
 * driver, as specified in SBSA v3.1:
 *
 * https://static.docs.arm.com/den0029/a/Server_Base_System_Architecture_v3_1_ARM_DEN_0029A.pdf
 */

#include "opt_acpi.h"

#include <sys/cdefs.h>
__FBSDID("$FreeBSD$");

#include <sys/param.h>
#include <sys/eventhandler.h>
#include <sys/bus.h>
#include <sys/kernel.h>
#include <sys/lock.h>
#include <sys/module.h>
#include <sys/rman.h>
#include <sys/watchdog.h>

#include <contrib/dev/acpica/include/acpi.h>
#include <dev/acpica/acpivar.h>

#define	__BIT(x)	((uintmax_t)1 << (uintmax_t)(x))

#define	SBSAWDT_REFRESH_RID	0
#define	SBSAWDT_CONTROL_RID	1

#define	SBSAWDT_REFRESH_SIZE	0x1000
#define	SBSAWDT_CONTROL_SIZE	0x1000

/* Refresh frame registers */
#define	R_WRR_REG		0x000
#define	R_W_IIDR_REG		0xfcc

/* Control frame registers */
#define	C_WCS_REG		0x000
#define	 C_WCS_WS1		__BIT(2)
#define	 C_WCS_WS0		__BIT(1)
#define	 C_WCS_EN		__BIT(0)
#define	C_WOR_REG		0x008
#define	C_WCV_LO_REG		0x010
#define	C_WCV_HI_REG		0x014
#define	C_W_IIDR_REG		0xfcc

struct sbsawdt_acpi_softc {
	device_t		sc_dev;
	struct resource		*ctrl_res;	/* control frame */
	struct resource		*rfrs_res;	/* refresh frame */

	uint32_t		sc_cntfreq;
	uint32_t		sc_max_period;
};

#define	REFRESH_WR4(sc, reg, val)			\
	bus_write_4((sc)->rfrs_res, (reg), (val))

#define	CONTROL_WR4(sc, reg, val)			\
	bus_write_4((sc)->ctrl_res, (reg), (val))

static void sbsawdt_acpi_watchdog_fn(void *, u_int, int *);

static void
sbsawdt_acpi_add_children(ACPI_SUBTABLE_HEADER *entry, void *arg)
{
	ACPI_GTDT_WATCHDOG *wdog;
	device_t dev = arg, child;

	if (entry->Type != ACPI_GTDT_TYPE_WATCHDOG)
		return;

	wdog = (ACPI_GTDT_WATCHDOG *)entry;

	if ((wdog->TimerFlags & ACPI_GTDT_WATCHDOG_SECURE) != 0)
		return;		/* We need a non-secure timer */

	child = BUS_ADD_CHILD(dev, BUS_PASS_TIMER + BUS_PASS_ORDER_LATE,
			"sbsawdt", -1);
	if (child == NULL) {
		device_printf(dev, "add sbsawdt failed\n");
		return;
	}

	BUS_SET_RESOURCE(dev, child, SYS_RES_MEMORY, SBSAWDT_REFRESH_RID,
			wdog->RefreshFrameAddress, SBSAWDT_REFRESH_SIZE);
	BUS_SET_RESOURCE(dev, child, SYS_RES_MEMORY, SBSAWDT_CONTROL_RID,
			wdog->ControlFrameAddress, SBSAWDT_CONTROL_SIZE);
}

static void
sbsawdt_acpi_identify(driver_t *driver, device_t parent)
{
	ACPI_TABLE_GTDT *gtdt;
	vm_paddr_t physaddr;

	physaddr = acpi_find_table(ACPI_SIG_GTDT);
	if (physaddr == 0)
		return;

	gtdt = acpi_map_table(physaddr, ACPI_SIG_GTDT);
	if (gtdt == NULL) {
		device_printf(parent, "sbsawdt: Unable to map the GTDT\n");
		return;
	}

	acpi_walk_subtables(gtdt + 1, (char *)gtdt + gtdt->Header.Length,
	    sbsawdt_acpi_add_children, parent);

	acpi_unmap_table(gtdt);
}

static int
sbsawdt_acpi_probe(device_t dev)
{

	device_set_desc(dev, "ARM SBSA Generic Watchdog");
	return (BUS_PROBE_NOWILDCARD);
}

static int
sbsawdt_acpi_attach(device_t dev)
{
	struct sbsawdt_acpi_softc *sc = device_get_softc(dev);
	int rid;

	sc->sc_dev = dev;
	sc->sc_cntfreq = READ_SPECIALREG(cntfrq_el0);
	sc->sc_max_period = howmany((uint64_t)UINT32_MAX, sc->sc_cntfreq);

	rid = SBSAWDT_REFRESH_RID;
	sc->rfrs_res = bus_alloc_resource(dev, SYS_RES_MEMORY, &rid, 0ul, ~0ul, SBSAWDT_REFRESH_SIZE, RF_ACTIVE);
	if (sc->rfrs_res == NULL) {
		device_printf(dev, "failed to map refresh frame\n");
		return (ENXIO);
	}

	rid = SBSAWDT_CONTROL_RID;
	sc->ctrl_res = bus_alloc_resource(dev, SYS_RES_MEMORY, &rid, 0ul, ~0ul, SBSAWDT_CONTROL_SIZE, RF_ACTIVE);
	if (sc->ctrl_res == NULL) {
		device_printf(dev, "failed to map control frame\n");
		goto out_rfrs;
	}

	device_printf(dev, "default watchdog period is %u seconds\n",
			sc->sc_max_period);

	EVENTHANDLER_REGISTER(watchdog_list, sbsawdt_acpi_watchdog_fn, sc, 0);

	return (0);

out_rfrs:
	bus_release_resource(dev, SYS_RES_MEMORY, SBSAWDT_REFRESH_RID, sc->rfrs_res);

	return (ENXIO);
}


static void
sbsawdt_acpi_watchdog_fn(void *private, u_int cmd, int *error)
{
	struct sbsawdt_acpi_softc *sc = private;
	uint64_t sec;

	cmd &= WD_INTERVAL;

	if (cmd > 0) {
		sec = ((uint64_t)1 << (cmd & WD_INTERVAL)) / 1000000000;

		if (sec > sc->sc_max_period) {
			device_printf(sc->sc_dev,
				"Can't arm, timeout is more than %d sec\n", sc->sc_max_period);
			CONTROL_WR4(sc, C_WCS_REG, 0);
			return;
		}

		CONTROL_WR4(sc, C_WCS_REG, 0);
		CONTROL_WR4(sc, C_WOR_REG, sec * sc->sc_cntfreq / 2);
		CONTROL_WR4(sc, C_WCS_REG, C_WCS_EN);
		REFRESH_WR4(sc, R_WRR_REG, 0);
	} else {
		CONTROL_WR4(sc, C_WCS_REG, 0);
	}

	*error = 0;
}

static device_method_t sbsawdt_acpi_methods[] = {
	DEVMETHOD(device_identify,	sbsawdt_acpi_identify),
	DEVMETHOD(device_probe,		sbsawdt_acpi_probe),
	DEVMETHOD(device_attach,	sbsawdt_acpi_attach),

	DEVMETHOD_END
};

static driver_t sbsawdt_acpi_driver = {
	"sbsawdt",
	sbsawdt_acpi_methods,
	sizeof(struct sbsawdt_acpi_softc),
};

static devclass_t sbsawdt_acpi_devclass;

EARLY_DRIVER_MODULE(sbsawdt, acpi, sbsawdt_acpi_driver, sbsawdt_acpi_devclass,
    0, 0, BUS_PASS_TIMER + BUS_PASS_ORDER_LATE);
