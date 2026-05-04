

// Driver for the Microchip LAN8760/1/2 PHY

#include <sys/cdefs.h>
#include <sys/param.h>
#include <sys/bus.h>
#include <sys/module.h>
#include <sys/socket.h>

#include <net/if.h>
#include <net/if_media.h>

#include <dev/mii/miivar.h>
#include "miidevs.h"
#include "miibus_if.h"

struct conf {
	uint16_t addr;
	uint16_t value;
};

// AN1699 2. Revision D0 Configuration Process

struct conf lan867x_config_d0[] = {
	{ 0x0037, 0x0800 },
	{ 0x008a, 0xbfc0 },
	{ 0x0118, 0x029c },
	{ 0x00d6, 0x1001 },
	{ 0x0082, 0x001c },
	{ 0x00fd, 0x0c0b }, // Per AN1699, both values need to be written
	{ 0x00fd, 0x8c07 }, // to 0x00fd.
	{ 0x0091, 0x9660 },
};
//	{ 0x0012, (LSCTL) 0xXXXX }


static int lan867x_probe(device_t);
static int lan867x_attach(device_t);

static int lan867xphy_service(struct mii_softc *, struct mii_data *, int);
static void lan867xphy_status(struct mii_softc *);

static device_method_t lan867x_methods[] = {
	DEVMETHOD(device_probe, lan867x_probe),
	DEVMETHOD(device_attach, lan867x_attach),
	DEVMETHOD(device_detach, mii_phy_detach),
	DEVMETHOD(device_shutdown, bus_generic_shutdown),
	DEVMETHOD_END
};

static driver_t lan867x_driver = {
	"lan867xphy",
	lan867x_methods,
	sizeof(struct mii_softc)
};

DRIVER_MODULE(lan867xphy, miibus, lan867x_driver, 0, 0);

static const struct mii_phydesc lan867xphys[] = {
//	MII_PHY_DESC();
	MII_PHY_END
};

static const struct mii_phy_funcs lan867xphy_funcs = {
	lan867xphy_service,
	lan867xphy_status,
	mii_phy_reset,
};

static int
lan867x_probe(device_t dev)
{
	return (mii_phy_dev_probe(dev, lan867xphys, BUS_PROBE_DEFAULT));
}

static int
lan867x_attach(device_t dev)
{
	struct mii_softc *sc;
	const struct mii_phy_funcs *mpf;

	sc = device_get_softc(dev);
	mpf = &lan867xphy_funcs;
	// XXX flags
	// XXX just pass lan867xphy_funcs w/o temp variable
	mii_phy_dev_attach(dev, MIIF_NOISOLATE | MIIF_NOMANPAUSE, mpf, 1);
	mii_phy_setmedia(sc);

	return (0);
}

static int
lan867xphy_service(struct mii_softc *sc, struct mii_data *mii, int cmd)
{
//	struct ifmedia_entry *ife;
//	int reg;
//
//	ife = mii->mii_media.ifm_cur;

	switch (cmd) {
	case MII_POLLSTAT:
		break;

	case MII_MEDIACHG:
		break;

	case MII_TICK:
		break;
	}

	mii_phy_update(sc, cmd);
	return (0);
}

static void
lan867xphy_status(struct mii_softc *sc)
{
	
}
