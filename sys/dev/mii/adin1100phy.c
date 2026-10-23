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

#define	ADIN_MMD_PMAPMD		1
#define	ADIN_MMD_VEND1		30

#define	ADIN_PMA_STAT1		0x0001
#define	  ADIN_PMA_STAT1_LINK	0x0004		/* latched low */

#define	ADIN_CRSM_SFT_RST	0x8810
#define	  ADIN_CRSM_SFT_RST_EN	0x0001
#define	ADIN_CRSM_SFT_PD_CNTRL	0x8812
#define	  ADIN_CRSM_SFT_PD_EN	0x0001
#define	ADIN_CRSM_STAT		0x8818
#define	  ADIN_CRSM_SYS_RDY	0x0001
#define	  ADIN_CRSM_SFT_PD_RDY	0x0002

static int
adin_mmd_read(struct mii_softc *sc, int devad, int reg)
{
	PHY_WRITE(sc, MII_MMDACR, MMDACR_FN_ADDRESS | devad);
	PHY_WRITE(sc, MII_MMDAADR, reg);
	PHY_WRITE(sc, MII_MMDACR, MMDACR_FN_DATANPI | devad);
	return (PHY_READ(sc, MII_MMDAADR));
}

static void
adin_mmd_write(struct mii_softc *sc, int devad, int reg, int val)
{
	PHY_WRITE(sc, MII_MMDACR, MMDACR_FN_ADDRESS | devad);
	PHY_WRITE(sc, MII_MMDAADR, reg);
	PHY_WRITE(sc, MII_MMDACR, MMDACR_FN_DATANPI | devad);
	PHY_WRITE(sc, MII_MMDAADR, val);
}

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

static int
adin_crsm_wait(struct mii_softc *sc, int mask, int want)
{
	int i;

	for (i = 0; i < 100; i++) {
		DELAY(1000);
		if ((adin_mmd_read(sc, ADIN_MMD_VEND1, ADIN_CRSM_STAT) &
		    mask) == want)
			return (0);
	}
	return (ETIMEDOUT);
}

static void
adin1100phy_reset(struct mii_softc *sc)
{
	adin_mmd_write(sc, ADIN_MMD_VEND1, ADIN_CRSM_SFT_RST,
	    ADIN_CRSM_SFT_RST_EN);
	if (adin_crsm_wait(sc, ADIN_CRSM_SYS_RDY, ADIN_CRSM_SYS_RDY) != 0)
		device_printf(sc->mii_dev, "soft reset timed out\n");

	adin_mmd_write(sc, ADIN_MMD_VEND1, ADIN_CRSM_SFT_PD_CNTRL, 0);
	if (adin_crsm_wait(sc, ADIN_CRSM_SFT_PD_RDY, 0) != 0)
		device_printf(sc->mii_dev, "power-down exit timed out\n");
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
