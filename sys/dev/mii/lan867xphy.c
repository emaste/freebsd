/*
 * Copyright 2026 Ed Maste
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

/*
 * Microchip LAN8670/1/2 10BASE-T1S Single Pair Ethernet (SPE) PHY Driver.
 *
 * This driver is sufficient for basic connectivity with CSMA/CD or PLCA.
 *
 * PHY-Level Collision Avoidance (PLCA) is currently configured via sysctls
 * (which are also settable as loader tunables):
 *
 *   dev.lan867xphy.N.plca.enable
 *   dev.lan867xphy.N.plca.node_id
 *   dev.lan867xphy.N.plca.node_count
 *
 * These should instead be handled via a generic interface for setting PHY
 * parameters, once it exists.
 *
 * TODO:
 * - PLCA configuration for D0+
 * - Interrupt-driven PLCA status change
 * - Sleep mode (C2, D0 and later)
 * - Topology discovery (D0 and later)
 * - Signal Quality Indicator (SQI) (C2, D0 and later)
 * - Cable fault diagnostics (C2 and later)
 * - Harness Defect Detection (D0 and later)
 * - Link status (D0 and later)
 */

#include <sys/param.h>
#include <sys/systm.h>
#include <sys/bus.h>
#include <sys/kernel.h>
#include <sys/module.h>
#include <sys/socket.h>
#include <sys/sysctl.h>

#include <net/if.h>
#include <net/if_media.h>

#include <dev/mii/mii.h>
#include <dev/mii/miivar.h>
#include "miidevs.h"
#include "miibus_if.h"

/* Indirect configuration parameter access (MMD 0x1F). */
#define	LAN867X_REG_CFGPARAM_ADDR	0x00d8
#define	LAN867X_REG_CFGPARAM_DATA	0x00d9
#define	LAN867X_REG_CFGPARAM_CTRL	0x00da
#define	LAN867X_CFGPARAM_CTRL_READ	0x0002

/* Reset-complete status. */
#define	LAN867X_REG_STS2		0x0019
#define	LAN867X_STS2_RESETC		0x0800

#define	LAN867X_MMD_VEND2		0x1f	/* vendor-specific MMD 2 */

/* Silicon revisions. */
#define	LAN867X_REV_C2			5
#define	LAN867X_REV_D0			6

struct lan867x_cfg_fixup {
	uint16_t address;
	uint16_t value;
};

struct lan867x_softc {
	struct mii_softc		mii_sc;	/* Must be first */
};

/*
 * MMD (MDIO Manageable Device) read/write helpers.
 */
static int
lan867xphy_mmd_read(struct mii_softc *sc, int devad, int reg)
{
	PHY_WRITE(sc, MII_MMDACR, MMDACR_FN_ADDRESS |
	    (devad & MMDACR_DADDRMASK));
	PHY_WRITE(sc, MII_MMDAADR, reg);
	PHY_WRITE(sc, MII_MMDACR, MMDACR_FN_DATANPI |
	    (devad & MMDACR_DADDRMASK));
	return (PHY_READ(sc, MII_MMDAADR));
}

static void
lan867xphy_mmd_write(struct mii_softc *sc, int devad, int reg, int val)
{
	PHY_WRITE(sc, MII_MMDACR, MMDACR_FN_ADDRESS |
	    (devad & MMDACR_DADDRMASK));
	PHY_WRITE(sc, MII_MMDAADR, reg);
	PHY_WRITE(sc, MII_MMDACR, MMDACR_FN_DATANPI |
	    (devad & MMDACR_DADDRMASK));
	PHY_WRITE(sc, MII_MMDAADR, val);
}

/*
 * Microchip Indirect Read - proprietary access mechanism via Vendor specific 2
 * MMD 0x1F.
 */
static uint8_t
lan867xphy_indirect_read(struct mii_softc *sc, uint8_t addr, uint8_t mask)
{

	// XXX try reading back, unsure if this will actually work.
	lan867xphy_mmd_write(sc, LAN867X_MMD_VEND2,
	    LAN867X_REG_CFGPARAM_ADDR, addr);
	device_printf(sc->mii_dev, "addr 0x%02x readback 0x%02x\n", addr,
	    lan867xphy_mmd_read(sc, LAN867X_MMD_VEND2,
	    LAN867X_REG_CFGPARAM_ADDR));
	//

	lan867xphy_mmd_write(sc, LAN867X_MMD_VEND2, LAN867X_REG_CFGPARAM_ADDR,
	    addr);
	lan867xphy_mmd_write(sc, LAN867X_MMD_VEND2, LAN867X_REG_CFGPARAM_CTRL,
	    LAN867X_CFGPARAM_CTRL_READ);
	return (lan867xphy_mmd_read(sc, LAN867X_MMD_VEND2,
	    LAN867X_REG_CFGPARAM_DATA) & mask);
}

/*
 * Hardware revision C2 configuration parameters.
 *
 * From Microchip AN1699 LAN8670/1/2 Configuration Application Note
 * (Revision G, October 2025).
 *
 * Five registers require configuration with values derived from reads of other
 * registers, between blocks of constants.
 */
static const struct lan867x_cfg_fixup lan867x_cfgdata_revc_part1[] = {
	{ 0x00d0, 0x3f31 },
	{ 0x00e0, 0xc000 },
};

static const struct lan867x_cfg_fixup lan867x_cfgdata_revc_part2[] = {
	{ 0x00e9, 0x9e50 },
	{ 0x00f5, 0x1cf8 },
	{ 0x00f4, 0xc020 },
	{ 0x00f8, 0xb900 },
	{ 0x00f9, 0x4e53 },
	{ 0x0081, 0x0080 },
	{ 0x0091, 0x9660 },
};

static const struct lan867x_cfg_fixup lan867x_cfgdata_revc_part3[] = {
	{ 0x00b0, 0x0103 },
	{ 0x00b1, 0x0910 },
	{ 0x00b2, 0x1d26 },
	{ 0x00b3, 0x002a },
	{ 0x00b4, 0x0103 },
	{ 0x00b5, 0x070d },
	{ 0x00b6, 0x1720 },
	{ 0x00b7, 0x0027 },
	{ 0x00b8, 0x0509 },
	{ 0x00b9, 0x0e13 },
	{ 0x00ba, 0x1c25 },
	{ 0x00bb, 0x002b },
};

static void
lan867xphy_config(struct mii_softc *sc, const struct lan867x_cfg_fixup *fixup,
    size_t len)
{
	size_t i;

	for (i = 0; i < len; i++) {
		lan867xphy_mmd_write(sc, LAN867X_MMD_VEND2, fixup[i].address,
		    fixup[i].value);
	}
}

static void
lan867xphy_config_revc(struct mii_softc *sc)
{
	uint16_t cfgparam1, cfgparam2, cfgparam3, cfgparam4, cfgparam5;
	uint8_t value1, value2;
	int8_t offset1, offset2;

	value1 = lan867xphy_indirect_read(sc, 0x04, 0x1f);
	if ((value1 & 0x10) != 0)
		offset1 = (int8_t)(value1 - 0x20);
	else
		offset1 = (int8_t)value1;

	value2 = lan867xphy_indirect_read(sc, 0x08, 0x1f);
	if ((value2 & 0x10) != 0)
		offset2 = (int8_t)(value2 - 0x20);
	else
		offset2 = (int8_t)value2;

	cfgparam1 = (uint16_t)(((9 + offset1) & 0x3f) << 10) |
	    (uint16_t)(((14 + offset1) & 0x3f) << 4) | 0x03;
	cfgparam2 = (uint16_t)(((40 + offset2) & 0x3f) << 10);
	cfgparam3 = (uint16_t)(((5 + offset1) & 0x3f) << 8) |
	    (uint16_t)((9 + offset1) & 0x3f);
	cfgparam4 = (uint16_t)(((9 + offset1) & 0x3f) << 8) |
	    (uint16_t)((14 + offset1) & 0x3f);
	cfgparam5 = (uint16_t)(((17 + offset1) & 0x3f) << 8) |
	    (uint16_t)((22 + offset1) & 0x3f);

	lan867xphy_config(sc, lan867x_cfgdata_revc_part1,
	    nitems(lan867x_cfgdata_revc_part1));
	lan867xphy_mmd_write(sc, LAN867X_MMD_VEND2, 0x0084, cfgparam1);
	lan867xphy_mmd_write(sc, LAN867X_MMD_VEND2, 0x008a, cfgparam2);
	lan867xphy_config(sc, lan867x_cfgdata_revc_part2,
	    nitems(lan867x_cfgdata_revc_part2));
	lan867xphy_mmd_write(sc, LAN867X_MMD_VEND2, 0x00ad, cfgparam3);
	lan867xphy_mmd_write(sc, LAN867X_MMD_VEND2, 0x00ae, cfgparam4);
	lan867xphy_mmd_write(sc, LAN867X_MMD_VEND2, 0x00af, cfgparam5);
	lan867xphy_config(sc, lan867x_cfgdata_revc_part3,
	    nitems(lan867x_cfgdata_revc_part3));
}

/*
 * Hardware revision D0 configuration parameters.
 *
 * From Microchip AN1699 LAN8670/1/2 Configuration Application Note
 * (Revision G, October 2025).
 */
static const struct lan867x_cfg_fixup lan867x_cfgdata_revd[] = {
	{ 0x0037, 0x0800 },
	{ 0x008a, 0xbfc0 },
	{ 0x0118, 0x029c },
	{ 0x00d6, 0x1001 },
	{ 0x0082, 0x001c },
	/* Per AN1699, write 0x00fd twice with different values. */
	{ 0x00fd, 0x0c0b },
	{ 0x00fd, 0x8c07 },
	{ 0x0091, 0x9660 },
	/* 0x0012 (LSCTL) to be added along with link state reporting. */
};

static void
lan867xphy_config_revd(struct mii_softc *sc)
{
	lan867xphy_config(sc, lan867x_cfgdata_revd,
	    nitems(lan867x_cfgdata_revd));
}

static int lan867x_probe(device_t);
static int lan867x_attach(device_t);

static int lan867xphy_service(struct mii_softc *, struct mii_data *, int);
static void lan867xphy_status(struct mii_softc *);


static const struct mii_phydesc lan867xphys[] = {
	MII_PHY_DESC(SMSC, LAN867X),
	MII_PHY_END
};

static int
lan867xphy_plca_sysctl(SYSCTL_HANDLER_ARGS)
{
//	struct lan867x_softc *lsc = arg1;
//	u_int cfg, mcfg;
//	int error, val;
	printf("%s\n", __func__);
	return (0);
}

static void
lan867xphy_sysctl_attach(device_t dev, struct lan867x_softc *lsc)
{
	struct sysctl_ctx_list *ctx = device_get_sysctl_ctx(dev);
	struct sysctl_oid_list *children =
	    SYSCTL_CHILDREN(device_get_sysctl_tree(dev));
	struct sysctl_oid *plca_node;

	device_printf(dev, "%s: tree %p\n", __func__,
	    device_get_sysctl_tree(dev));

	plca_node = SYSCTL_ADD_NODE(ctx, children, OID_AUTO, "plca",
	    CTLFLAG_RD | CTLFLAG_MPSAFE, NULL, "PHY-Level Collision Avoidance");
	children = SYSCTL_CHILDREN(plca_node);

	SYSCTL_ADD_PROC(ctx, children, OID_AUTO, "enable",
	    CTLTYPE_INT | CTLFLAG_RWTUN | CTLFLAG_MPSAFE, lsc,
	    0, lan867xphy_plca_sysctl, "I",
	    "Enable PHY-Level Collision Avoidance");
	SYSCTL_ADD_PROC(ctx, children, OID_AUTO, "node_id",
	    CTLTYPE_INT | CTLFLAG_RWTUN | CTLFLAG_MPSAFE, lsc,
	    0, lan867xphy_plca_sysctl, "I",
	    "PLCA Node ID (0 = coordinator, 255 = unconfigured)");
	SYSCTL_ADD_PROC(ctx, children, OID_AUTO, "node_count",
	    CTLTYPE_INT | CTLFLAG_RWTUN | CTLFLAG_MPSAFE, lsc,
	    0, lan867xphy_plca_sysctl, "I",
	    "PLCA transmit slots");
}


static bool
lan867xphy_wait_reset(struct mii_softc *sc)
{
	size_t i;
	int sts2;

	for (i = 0; i < 100; i++) {
		sts2 = lan867xphy_mmd_read(sc, LAN867X_MMD_VEND2,
		    LAN867X_REG_STS2);
		if ((sts2 & LAN867X_STS2_RESETC) != 0) {
			device_printf(sc->mii_dev, "reset count %zu\n", i);
			return (true);
		}
		DELAY(10);
	}
	device_printf(sc->mii_dev, "reset did not complete (STS2 0x%04x)\n",
	    sts2);
	return (false);
}

static void
lan867xphy_reset(struct mii_softc *sc)
{
	mii_phy_reset(sc);
	if (!lan867xphy_wait_reset(sc))
		return;

	switch (sc->mii_mpd_rev) {
	case LAN867X_REV_C2:
		lan867xphy_config_revc(sc);
		break;
	case LAN867X_REV_D0:
		lan867xphy_config_revd(sc);
		break;
	}

	/* XXX apply PLCA settings */
}

static const struct mii_phy_funcs lan867xphy_funcs = {
	lan867xphy_service,
	lan867xphy_status,
	lan867xphy_reset,
};

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

	PHY_STATUS(sc);
	mii_phy_update(sc, cmd);
	return (0);
}

static void
lan867xphy_status(struct mii_softc *sc)
{
	struct mii_data *mii = sc->mii_pdata;

	mii->mii_media_status = IFM_AVALID | IFM_ACTIVE;
	mii->mii_media_active = IFM_ETHER | IFM_10_T1S | IFM_HDX;
}

static int
lan867x_probe(device_t dev)
{
	return (mii_phy_dev_probe(dev, lan867xphys, BUS_PROBE_DEFAULT));
}

static int
lan867x_attach(device_t dev)
{
	struct lan867x_softc *lsc = device_get_softc(dev);
	struct mii_softc *sc = &lsc->mii_sc;
	int media;

	mii_phy_dev_attach(dev, MIIF_NOISOLATE | MIIF_NOMANPAUSE,
	    &lan867xphy_funcs, 0);
	lan867xphy_sysctl_attach(dev, lsc);

	switch (sc->mii_mpd_rev) {
	case LAN867X_REV_C2:
	case LAN867X_REV_D0:
		break;
	default:
		device_printf(dev,
		    "no revision-specific configuration for rev %d\n",
		    sc->mii_mpd_rev);
	}
	PHY_RESET(sc);

	/* PHY supports 10BASE-T1S only, no negotiation. */
	media = IFM_MAKEWORD(IFM_ETHER, IFM_10_T1S, IFM_HDX, sc->mii_inst);
	ifmedia_add(&sc->mii_pdata->mii_media, media, 0, NULL);
	ifmedia_set(&sc->mii_pdata->mii_media, media);

	return (0);
}

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
	sizeof(struct lan867x_softc)
};

DRIVER_MODULE(lan867xphy, miibus, lan867x_driver, 0, 0);
