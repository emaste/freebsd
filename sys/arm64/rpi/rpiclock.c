#include <sys/cdefs.h>

#include <sys/param.h>
#include <sys/systm.h>
#include <sys/bus.h>
#include <sys/lock.h>
#include <sys/mutex.h>
#include <sys/proc.h>
#include <sys/kernel.h>
#include <sys/malloc.h>
#include <sys/module.h>
#include <sys/rman.h>
#include <sys/endian.h>

#include <dev/ofw/openfirm.h>
#include <dev/ofw/ofw_bus.h>
#include <dev/ofw/ofw_bus_subr.h>
#include <dev/ofw/ofw_pci.h>

#include <dev/fdt/fdt_intr.h>
#include <dev/fdt/simplebus.h>

#include <machine/bus.h>
#include <machine/intr.h>
#include <machine/resource.h>

#include <dev/clk/clk.h>

#include "pic_if.h"

#include "rpiclock.h"

static struct ofw_compat_data compat_data[] = {
	{ "raspberrypi,rp1-clocks",	1 },
	{ NULL,				0 }
};

/*
 * Determine if a given device can be served by the rpiclock driver.
 */
static int
rpiclock_probe(device_t dev)
{
	if (!ofw_bus_status_okay(dev) ||
	    !ofw_bus_search_compatible(dev, compat_data)->ocd_data) {
		return (ENXIO);
	}

	return (BUS_PROBE_DEFAULT);
}

static void
rpiclock_register_clocks(device_t dev)
{
	struct rpiclock_softc *sc;

	sc = device_get_softc(dev);
	sc->clkdom = clkdom_create(dev);
	MPASS(sc->clkdom != NULL);

	rpiclock_init_plls(sc);
	rpiclock_init_periphs(sc);

	clkdom_finit(sc->clkdom);

	if (bootverbose)
		clkdom_dump(sc->clkdom);
}

static int
rpiclock_attach(device_t dev)
{
	struct rpiclock_softc *sc;
	phandle_t xref, node;
	int rid, error;

	sc = device_get_softc(dev);
	mtx_init(&sc->mtx, device_get_nameunit(dev), NULL, MTX_DEF);

	sc->dev = dev;

	rid = 0;
	sc->mem_res = bus_alloc_resource_any(dev, SYS_RES_MEMORY, &rid,
	    RF_ACTIVE);
	if (sc->mem_res == NULL) {
		device_printf(dev, "could not allocate memory resource\n");
		error = ENXIO;
		goto fail;
	}

	rpiclock_register_clocks(dev);

	node = ofw_bus_get_node(dev);
	if (node <= 0)
		panic("%s called on non-OF device\n", __func__);
	xref = OF_xref_from_node(node);
	OF_device_register_xref(xref, dev);

	return (0);

fail:
	if (sc->mem_res != NULL)
		bus_release_resource(dev, sc->mem_res);

	return error;
}

static int
rpiclock_read_4(device_t dev, bus_addr_t base, uint32_t *val)
{
	struct rpiclock_softc *sc;

	sc = device_get_softc(dev);

	*val = bus_read_4(sc->mem_res, base);
	return (0);
}

static int
rpiclock_write_4(device_t dev, bus_addr_t base, uint32_t val)
{
	struct rpiclock_softc *sc;

	sc = device_get_softc(dev);

	bus_write_4(sc->mem_res, base, val);
	return (0);
}

static int
rpiclock_modify_4(device_t dev, bus_addr_t base, uint32_t clr, uint32_t set)
{
	uint32_t val;
	int error;

	if ((error = rpiclock_read_4(dev, base, &val)))
		return error;

	val &= ~clr;
	val |= set;

	if ((error = rpiclock_write_4(dev, base, val)))
		return error;

	return (0);
}

static void
rpiclock_device_lock(device_t dev)
{
	struct rpiclock_softc *sc;

	sc = device_get_softc(dev);
	mtx_lock(&sc->mtx);
}

static void
rpiclock_device_unlock(device_t dev)
{
	struct rpiclock_softc *sc;

	sc = device_get_softc(dev);
	mtx_unlock(&sc->mtx);
}

static device_method_t rpiclock_methods[] = {
	/* Device interface */
	DEVMETHOD(device_probe,		rpiclock_probe),
	DEVMETHOD(device_attach,	rpiclock_attach),

	/* clkdev interface */
	DEVMETHOD(clkdev_write_4,	rpiclock_write_4),
	DEVMETHOD(clkdev_read_4,	rpiclock_read_4),
	DEVMETHOD(clkdev_modify_4,	rpiclock_modify_4),
	DEVMETHOD(clkdev_device_lock,	rpiclock_device_lock),
	DEVMETHOD(clkdev_device_unlock,	rpiclock_device_unlock),

	DEVMETHOD_END
};

static driver_t rpiclock_driver = {
	"rpiclock",
	rpiclock_methods,
	sizeof(struct rpiclock_softc),
};

DRIVER_MODULE(rpiclock, simplebus, rpiclock_driver, NULL, NULL);
