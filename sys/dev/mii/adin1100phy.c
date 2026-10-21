/* SPDX-License-Identifier: BSD-2-Clause */

/*
 * Analog Devices ADIN1100 PHY driver.
 */

#include <sys/cdefs.h>
#include <sys/param.h>
#include <sys/bus.h>
#include <sys/module.h>
#include <sys/socket.h>

#include <net/if.h>
#include <net/if_media.h>

#include <dev/mii/mii.h>
#include <dev/mii/miivar.h>
#include "miidevs.h"
#include "miibus_if.h"

static const struct mii_phydesc adin_phys[] = {
	MII_PHY_DESC(ADI, ADIN1100),
	MII_PHY_END
};

static int
adin1100phy_service(struct mii_softc *sc, struct mii_data *mii, int cmd)
{
	PHY_STATUS(sc);
	mii_phy_update(sc, cmd);
	return (0);
}

static void
adin1100phy_status(struct mii_softc *sc)
{
	struct mii_data *mii = sc->mii_pdata;

	mii->mii_media_status = IFM_AVALID | IFM_ACTIVE;
	mii->mii_media_active = IFM_ETHER | IFM_10_T1L | IFM_FDX;
}

static void
adin1100phy_reset(struct mii_softc *sc)
{
	mii_phy_reset(sc);
}

static const struct mii_phy_funcs adin1100phy_funcs = {
	adin1100phy_service,
	adin1100phy_status,
	adin1100phy_reset,
};

static int
adin_probe(device_t dev)
{
	return (mii_phy_dev_probe(dev, adin_phys, BUS_PROBE_DEFAULT));
}

static int
adin_attach(device_t dev)
{
	struct mii_softc *sc = device_get_softc(dev);
	int media;

	mii_phy_dev_attach(dev, MIIF_NOISOLATE | MIIF_NOMANPAUSE,
	    &adin1100phy_funcs, 0);

	PHY_RESET(sc);

	/* XXX Hardcode 10BASE-T1L FDX for now. */
	media = IFM_MAKEWORD(IFM_ETHER, IFM_10_T1L, IFM_FDX, sc->mii_inst);
	ifmedia_add(&sc->mii_pdata->mii_media, media, 0, NULL);
	ifmedia_set(&sc->mii_pdata->mii_media, media);

	return (0);
}

static device_method_t adin_methods[] = {
	DEVMETHOD(device_probe, adin_probe),
	DEVMETHOD(device_attach, adin_attach),
	DEVMETHOD(device_detach, mii_phy_detach),
	DEVMETHOD(device_shutdown, bus_generic_shutdown),
	DEVMETHOD_END
};

static driver_t adin_driver = {
	"adin1100phy",
	adin_methods,
	sizeof(struct mii_softc)
};

DRIVER_MODULE(adin1100phy, miibus, adin_driver, 0, 0);
