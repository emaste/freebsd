#include <sys/cdefs.h>

#include <sys/param.h>
#include <sys/systm.h>
#include <sys/bus.h>
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

#include <dev/pci/pcivar.h>
#include <dev/pci/pcireg.h>

#include "pic_if.h"
#include "rpiclock.h"

/*
 * Enumeration of the 4 different PLL types: core, primary, secondary, and
 * phase-shifted primary.
 */
enum rpiclock_pll_type {
	CORE,
	PRIM,
	SEC,
	PH
};

/*
 * Registers for core PLL data
 */
struct rpi_pll_core_sc {
	uint32_t cs_reg;
	uint32_t pwr_reg;
	uint32_t fbdiv_int_reg;
	uint32_t fbdiv_frac_reg;
};

/*
 * Registers for primary or secondary PLL data
 */
struct rpi_pll_data_sc {
	uint32_t ctrl_reg;
};

/*
 * Registers for phase-shifted primary PLL data
 */
struct rpi_pll_ph_sc {
	uint32_t ctrl_reg;
	uint32_t fixed_divider;
	uint32_t phase;
};

/*
 * Software context for arbitrary PLL type
 */
struct rpi_pll_sc {
	device_t clkdev;
	enum rpiclock_pll_type type;

	union {
		struct rpi_pll_core_sc core;
		struct rpi_pll_data_sc pll;
		struct rpi_pll_ph_sc pll_ph;
	};
};

static const char *pll_sys_core_parents[] = {"xosc"};
static const char *pll_audio_core_parents[] = {"xosc"};
static const char *pll_video_core_parents[] = {"xosc"};
static const char *pll_sys_parents[] = {"pll_sys_core"};
static const char *pll_audio_parents[] = {"pll_audio_core"};
static const char *pll_video_parents[] = {"pll_video_core"};
static const char *pll_sys_pri_ph_parents[] = {"pll_sys"};
static const char *pll_audio_pri_ph_parents[] = {"pll_audio"};
static const char *pll_sys_sec_parents[] = {"pll_sys_core"};
static const char *pll_audio_sec_parents[] = {"pll_audio_core"};
static const char *pll_video_sec_parents[] = {"pll_video_core"};
/*
 * Table of data for each PLL expected to be on the RP1
 */
struct clknode_pll_def {
	struct clknode_init_def clkdef;

	enum rpiclock_pll_type type;

	uint32_t cs_reg;
	uint32_t pwr_reg;
	uint32_t fbdiv_int_reg;
	uint32_t fbdiv_frac_reg;

	uint32_t ctrl_reg;
	uint32_t fixed_divider;
	uint32_t phase;
} rpiclock_pll_defs[] = {
	{
		.clkdef = {
			.id = RP1_PLL_SYS_CORE,
			.name = "pll_sys_core",
			.parent_names = pll_sys_core_parents,
			.parent_cnt = nitems(pll_sys_core_parents),
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.type = CORE,
		.cs_reg = PLL_SYS_CS,
		.pwr_reg = PLL_SYS_PWR,
		.fbdiv_int_reg = PLL_SYS_FBDIV_INT,
		.fbdiv_frac_reg = PLL_SYS_FBDIV_FRAC,
	},
	{
		.clkdef = {
			.id = RP1_PLL_AUDIO_CORE,
			.name = "pll_audio_core",
			.parent_names = pll_audio_core_parents,
			.parent_cnt = nitems(pll_audio_core_parents),
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.type = CORE,
		.cs_reg = PLL_AUDIO_CS,
		.pwr_reg = PLL_AUDIO_PWR,
		.fbdiv_int_reg = PLL_AUDIO_FBDIV_INT,
		.fbdiv_frac_reg = PLL_AUDIO_FBDIV_FRAC,
	},
	{
		.clkdef = {
			.id = RP1_PLL_VIDEO_CORE,
			.name = "pll_video_core",
			.parent_names = pll_video_core_parents,
			.parent_cnt = nitems(pll_video_core_parents),
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.type = CORE,
		.cs_reg = PLL_VIDEO_CS,
		.pwr_reg = PLL_VIDEO_PWR,
		.fbdiv_int_reg = PLL_VIDEO_FBDIV_INT,
		.fbdiv_frac_reg = PLL_VIDEO_FBDIV_FRAC,
	},
	{
		.clkdef = {
			.id = RP1_PLL_SYS,
			.name = "pll_sys",
			.parent_names = pll_sys_parents,
			.parent_cnt = nitems(pll_sys_parents),
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.type = PRIM,
		.ctrl_reg = PLL_SYS_PRIM,
	},
	{
		.clkdef = {
			.id = RP1_PLL_AUDIO,
			.name = "pll_audio",
			.parent_names = pll_audio_parents,
			.parent_cnt = nitems(pll_audio_parents),
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.type = PRIM,
		.ctrl_reg = PLL_AUDIO_PRIM,
	},
	{
		.clkdef = {
			.id = RP1_PLL_VIDEO,
			.name = "pll_video",
			.parent_names = pll_video_parents,
			.parent_cnt = nitems(pll_video_parents),
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.type = PRIM,
		.ctrl_reg = PLL_VIDEO_PRIM,
	},
	{
		.clkdef = {
			.id = RP1_PLL_SYS_PRI_PH,
			.name = "pll_sys_pri_ph",
			.parent_names = pll_sys_pri_ph_parents,
			.parent_cnt = nitems(pll_sys_pri_ph_parents),
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.type = PH,
		.ctrl_reg = PLL_SYS_PRIM,
		.fixed_divider = 2,
		.phase = RP1_PLL_PHASE_0,
	},
	{
		.clkdef = {
			.id = RP1_PLL_AUDIO_PRI_PH,
			.name = "pll_audio_pri_ph",
			.parent_names = pll_audio_pri_ph_parents,
			.parent_cnt = nitems(pll_audio_pri_ph_parents),
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.type = PH,
		.ctrl_reg = PLL_AUDIO_PRIM,
		.fixed_divider = 2,
		.phase = RP1_PLL_PHASE_0,
	},
	{
		.clkdef = {
			.id = RP1_PLL_SYS_SEC,
			.name = "pll_sys_sec",
			.parent_names = pll_sys_sec_parents,
			.parent_cnt = nitems(pll_sys_parents),
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.type = SEC,
		.ctrl_reg = PLL_SYS_SEC,
	},
	{
		.clkdef = {
			.id = RP1_PLL_AUDIO_SEC,
			.name = "pll_audio_sec",
			.parent_names = pll_audio_sec_parents,
			.parent_cnt = nitems(pll_audio_sec_parents),
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.type = SEC,
		.ctrl_reg = PLL_AUDIO_SEC,
	},
	{
		.clkdef = {
			.id = RP1_PLL_VIDEO_SEC,
			.name = "pll_video_sec",
			.parent_names = pll_video_sec_parents,
			.parent_cnt = nitems(pll_video_sec_parents),
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.type = SEC,
		.ctrl_reg = PLL_VIDEO_SEC,
	}
};

static int
rpiclock_pll_init(struct clknode *clk, device_t dev)
{
	/* PLLs all have only one parent */
	clknode_init_parent_idx(clk, 0);
	return (0);
}

static int
rpiclock_pll_core_recalc(
    struct clknode *clk, uint32_t parent_freq, uint64_t *freq)
{
	struct rpi_pll_sc *sc;
	uint32_t fbdiv_int, fbdiv_frac;
	uint64_t multiplier;

	sc = clknode_get_softc(clk);

	RD4(sc, sc->core.fbdiv_int_reg, &fbdiv_int);
	RD4(sc, sc->core.fbdiv_frac_reg, &fbdiv_frac);

	/*
	 * Scale the core frequency by sc->sc_xosc_freq, rounding up the
	 * nearest integer
	 */
	multiplier = (((uint64_t)fbdiv_int << 24) + fbdiv_frac) + (1 << 23);
	*freq = ((uint64_t)parent_freq * multiplier) >> 24;

	return (0);
}

static int
rpiclock_pll_prim_recalc(
    struct clknode *clk, uint32_t parent_freq, uint64_t *freq)
{
	struct rpi_pll_sc *sc;
	uint32_t reg, div1, div2;

	sc = clknode_get_softc(clk);

	RD4(sc, sc->pll.ctrl_reg, &reg);

	/* Extract the 2 3-bit dividers */
	div1 = (reg & PLL_PRIM_DIV1_MASK) >> PLL_PRIM_DIV1_SHIFT;
	div2 = (reg & PLL_PRIM_DIV2_MASK) >> PLL_PRIM_DIV2_SHIFT;
	if (div1 == 0 || div2 == 0)
		return (EINVAL);

	*freq = DIV_ROUND((uint64_t)parent_freq, div1 * div2);

	return (0);
}

static int
rpiclock_pll_sec_recalc(
    struct clknode *clk, uint32_t parent_freq, uint64_t *freq)
{
	struct rpi_pll_sc *sc;
	uint32_t sec, div;

	sc = clknode_get_softc(clk);

	RD4(sc, sc->pll.ctrl_reg, &sec);
	/* sec clocks per core clock */
	div = (sec & PLL_SEC_DIV_MASK) >> PLL_SEC_DIV_SHIFT;
	if (div == 0)
		return (EINVAL);

	*freq = parent_freq / div;

	return (0);
}

static int
rpiclock_pll_ph_recalc(
    struct clknode *clk, uint32_t parent_freq, uint64_t *freq)
{
	struct rpi_pll_sc *sc;

	sc = clknode_get_softc(clk);

	*freq = DIV_ROUND((uint64_t)parent_freq, sc->pll_ph.fixed_divider);

	return (0);
}

/*
 * Calculate and return the frequency of a given PLL
 */
static int
rpiclock_pll_recalc(struct clknode *clk, uint64_t *freq)
{
	struct rpi_pll_sc *sc;
	struct clknode *parent_clk;
	uint64_t parent_freq;
	int error;

	sc = clknode_get_softc(clk);
	parent_clk = clknode_get_parent(clk);

	error = clknode_get_freq(parent_clk, &parent_freq);
	if (error)
		return error;

	switch (sc->type) {
	case CORE:
		return rpiclock_pll_core_recalc(clk, parent_freq, freq);
	case PRIM:
		return rpiclock_pll_prim_recalc(clk, parent_freq, freq);
	case SEC:
		return rpiclock_pll_sec_recalc(clk, parent_freq, freq);
	case PH:
		return rpiclock_pll_ph_recalc(clk, parent_freq, freq);
	default:
		return (EINVAL);
	}
}

static int
rpiclock_pll_core_set_freq(
    struct clknode *clk, uint64_t fin, uint64_t *fout, int flags, int *stop)
{
	struct rpi_pll_sc *sc;
	uint32_t fbdiv_int, fbdiv_frac;
	uint64_t div;

	uint32_t reg;

	sc = clknode_get_softc(clk);

	if (*fout > (fin / 16))
		return -1;

	div = DIV_ROUND(fin << 32, *fout);

	div += (1 << (32 - 24 - 1));

	/* Get the closest 32.24 fixed point factor to approximate target */
	fbdiv_int = div >> 32;
	fbdiv_frac = (div >> (32 - 24)) & 0xffffff;

	if (!(flags & CLK_SET_DRYRUN)) {
		WR4(sc, sc->core.fbdiv_int_reg, fbdiv_int);
		WR4(sc, sc->core.fbdiv_frac_reg, fbdiv_frac);

		/* Disable power saving iff there exists a fractional component */
		RD4(sc, sc->core.pwr_reg, &reg);
		if (fbdiv_frac != 0) {
			reg &= ~PLL_PWR_DSMPD;
		} else {
			reg |= PLL_PWR_DSMPD;
		}
		WR4(sc, sc->core.pwr_reg, reg);

		/* Indicate desire to write a new divider value */
		RD4(sc, sc->core.cs_reg, &reg);
		reg |= 1 << PLL_CS_REFDIV_SHIFT;
		WR4(sc, sc->core.cs_reg, reg);
	}

	*fout *= div;
	*fout >>= 32;

	*stop = 1;

	return (0);
}

static int
rpiclock_pll_prim_set_freq(
    struct clknode *clk, uint64_t fin, uint64_t *fout, int flags, int *stop)
{
	struct rpi_pll_sc *sc;

	uint32_t best_div1, best_div2, best_freq;
	uint32_t div1, div2, freq;

	uint32_t prim;

	sc = clknode_get_softc(clk);

	/* Both dividers = 1 is a guaranteed option */
	best_freq = *fout;
	best_div1 = 1;
	best_div2 = 1;

	/*
	 * Brute force every combination of cascading dividers to get as close
	 * as possible
	 */
	for (div1 = 1; div1 <= 7; div1++) {
		for (div2 = 1; div2 <= div1; div2++) {
			freq = DIV_ROUND(*fout, div1 * div2);

			if (freq == fin) {
				best_div1 = div1;
				best_div2 = div2;
				best_freq = freq;
				goto found;
			}

			/*
			 * Quality is determined by absulute numerical
			 * distance to target_freq.
			 * i.e.
			 *   abs(best_freq - target_freq)
			 * vs.
			 *   abs(freq - target_freq)
			 *
			 */
			if ((best_freq > freq && best_freq > fin) ||
			    (best_freq < freq && freq < fin)) {
				best_div1 = div1;
				best_div2 = div2;
				best_freq = freq;
			}
		}
	}

found:
	/* Write out optimal divider combination */
	if (!(flags & CLK_SET_DRYRUN)) {
		RD4(sc, sc->pll.ctrl_reg, &prim);
		prim &= ~(PLL_PRIM_DIV1_MASK | PLL_PRIM_DIV2_MASK);
		prim |= (best_div1 << PLL_PRIM_DIV1_SHIFT);
		prim |= (best_div2 << PLL_PRIM_DIV2_SHIFT);
		WR4(sc, sc->pll.ctrl_reg, prim);
	}

	*fout = best_freq;
	*stop = 1;

	return (0);
}

/*
 * Find the best divider (between 8 and 19) to achieve fin, given *fout
 * initially
 */
static int
rpiclock_pll_sec_set_freq(
    struct clknode *clk, uint64_t fin, uint64_t *fout, int flags, int *stop)
{
	struct rpi_pll_sc *sc;
	uint32_t sec, div;

	sc = clknode_get_softc(clk);

	/* Clip div between 8 and 19 */
	div = MIN(19, MAX(8, DIV_ROUND(*fout, fin)));

	RD4(sc, sc->pll.ctrl_reg, &sec);
	sec &= ~PLL_SEC_DIV_MASK;
	sec |= (div << PLL_SEC_DIV_SHIFT);

	if (!(flags & CLK_SET_DRYRUN)) {
		DEVICE_LOCK(sc);
		WR4(sc, sc->pll.ctrl_reg, sec | PLL_SEC_RST);
		DELAY((10 * div * 1000000) / *fout);
		WR4(sc, sc->pll.ctrl_reg, sec);
		DEVICE_UNLOCK(sc);
	}

	*fout = *fout / div;
	*stop = 1;

	return (0);
}

static int
rpiclock_pll_ph_set_freq(
    struct clknode *clk, uint64_t fin, uint64_t *fout, int flags, int *stop)
{
	/*
	 * Since it's a phase shift of the PRIM PLL, setting frequency here
	 * doesn't make sense. No-op. Instead, change prim.
	 */
	*stop = 1;
	return (0);
}

/*
 * Set the frequency of a PLL
 */
static int
rpiclock_pll_set_freq(
    struct clknode *clk, uint64_t fin, uint64_t *fout, int flags, int *stop)
{
	struct rpi_pll_sc *sc;

	sc = clknode_get_softc(clk);

	switch (sc->type) {
	case CORE:
		return rpiclock_pll_core_set_freq(clk, fin, fout, flags, stop);
	case PRIM:
		return rpiclock_pll_prim_set_freq(clk, fin, fout, flags, stop);
	case SEC:
		return rpiclock_pll_sec_set_freq(clk, fin, fout, flags, stop);
	case PH:
		return rpiclock_pll_ph_set_freq(clk, fin, fout, flags, stop);
	default:
		*stop = 0;
		return (EINVAL);
	}

	return (0);
}

static int
rpiclock_pll_core_get_gate(struct rpi_pll_sc *sc, bool *enabled)
{
	uint32_t reg;

	RD4(sc, sc->core.pwr_reg, &reg);

	*enabled = (reg & PLL_PWR_PD) || (reg & PLL_PWR_POSTDIVPD);

	return (0);
}

static int
rpiclock_pll_primsec_get_gate(struct rpi_pll_sc *sc, bool *enabled)
{
	uint32_t reg;

	RD4(sc, sc->pll.ctrl_reg, &reg);

	*enabled = !(reg & PLL_SEC_RST);

	return (0);
}

static int
rpiclock_pll_ph_get_gate(struct rpi_pll_sc *sc, bool *enabled)
{
	uint32_t reg;

	RD4(sc, sc->pll_ph.ctrl_reg, &reg);

	*enabled = !!(reg & PLL_PH_EN);

	return (0);
}

/*
 * Determine if a given PLL is currently enabled
 */
static int
rpiclock_pll_get_gate(struct clknode *clk, bool *enabled)
{
	struct rpi_pll_sc *sc;

	sc = clknode_get_softc(clk);

	switch (sc->type) {
	case CORE:
		return rpiclock_pll_core_get_gate(sc, enabled);
	case PRIM:
	case SEC:
		return rpiclock_pll_primsec_get_gate(sc, enabled);
	case PH:
		return rpiclock_pll_ph_get_gate(sc, enabled);
	default:
		return (EINVAL);
	}

	return (0);
}

static int
rpiclock_pll_core_set_gate(struct rpi_pll_sc *sc, bool enable)
{
	uint32_t reg;

	RD4(sc, sc->pll.ctrl_reg, &reg);

	if (enable) {
		reg |= CLK_CTRL_ENABLE;
	} else {
		reg &= ~CLK_CTRL_ENABLE;
	}

	WR4(sc, sc->pll.ctrl_reg, reg);

	return (0);
}

static int
rpiclock_pll_primsec_set_gate(struct rpi_pll_sc *sc, bool enable)
{
	uint32_t reg;

	RD4(sc, sc->pll.ctrl_reg, &reg);

	if (enable) {
		reg &= ~PLL_SEC_RST;
	} else {
		reg |= PLL_SEC_RST;
	}

	WR4(sc, sc->pll.ctrl_reg, reg);

	return (0);
}

static int
rpiclock_pll_ph_set_gate(struct rpi_pll_sc *sc, bool enable)
{
	uint32_t reg;

	RD4(sc, sc->pll.ctrl_reg, &reg);

	if (enable) {
		reg |= PLL_PH_EN;
	} else {
		reg &= ~PLL_PH_EN;
	}

	WR4(sc, sc->pll.ctrl_reg, reg);

	return (0);
}

static int
rpiclock_pll_set_gate(struct clknode *clk, bool enable)
{
	struct rpi_pll_sc *sc;

	sc = clknode_get_softc(clk);

	switch (sc->type) {
	case CORE:
		return rpiclock_pll_core_set_gate(sc, enable);
	case PRIM:
	case SEC:
		return rpiclock_pll_primsec_set_gate(sc, enable);
	case PH:
		return rpiclock_pll_ph_set_gate(sc, enable);
	default:
		return (EINVAL);
	}

	return (0);
}

static clknode_method_t rpiclock_pll_methods[] = {
	/* Device interface */
	CLKNODEMETHOD(clknode_init,		rpiclock_pll_init),
	CLKNODEMETHOD(clknode_recalc_freq,	rpiclock_pll_recalc),
	CLKNODEMETHOD(clknode_set_freq,		rpiclock_pll_set_freq),
	CLKNODEMETHOD(clknode_get_gate,		rpiclock_pll_get_gate),
	CLKNODEMETHOD(clknode_set_gate,		rpiclock_pll_set_gate),
	CLKNODEMETHOD_END
};
DEFINE_CLASS_1(rpiclock_pll, rpiclock_pll_class,
   rpiclock_pll_methods, sizeof(struct rpi_pll_sc), clknode_class);

/*
 * From a definition, create a new clock node in the given clock domain, then
 * initialize its software context.
 */
static int
rpiclock_init_pll(struct clkdom *clkdom, struct clknode_pll_def *def)
{
	struct clknode *clk;
	struct rpi_pll_sc *sc;

	clk = clknode_create(clkdom, &rpiclock_pll_class,
	    (const struct clknode_init_def *)def);
	if (clk == NULL) {
		return (ENXIO);
	}

	sc = clknode_get_softc(clk);

	sc->clkdev = clknode_get_device(clk);
	sc->type = def->type;

	switch (def->type) {
	case CORE:
		sc->core.cs_reg = def->cs_reg;
		sc->core.pwr_reg = def->pwr_reg;
		sc->core.fbdiv_int_reg = def->fbdiv_int_reg;
		sc->core.fbdiv_frac_reg = def->fbdiv_frac_reg;
		break;
	case PRIM:
	case SEC:
		sc->pll.ctrl_reg = def->ctrl_reg;
		break;
	case PH:
		sc->pll_ph.ctrl_reg = def->ctrl_reg;
		sc->pll_ph.fixed_divider = def->fixed_divider;
		sc->pll_ph.phase = def->phase;
		break;
	default:
		panic("attempted to initialize unknown PLL type '%d'",
		    def->type);
	}

	clknode_register(clkdom, clk);

	return (0);
}

/*
 * Given a clock domain, iterate over the PLLs in rp1's space and add them
 * to the domain.
 */
void
rpiclock_init_plls(struct rpiclock_softc *sc)
{
	struct clkdom *clkdom;
	int error;
	int i;

	clkdom = sc->clkdom;

	for (i = 0; i < nitems(rpiclock_pll_defs); i++) {
		error = rpiclock_init_pll(clkdom, &rpiclock_pll_defs[i]);
		if (error != 0)
			panic("pll '%s' initialization failed",
			    rpiclock_pll_defs[i].clkdef.name);
	}
}
