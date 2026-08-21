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

#include <dev/clk/clk.h>

#include "pic_if.h"
#include "rpiclock.h"

struct rpi_periph_sc {
	device_t clkdev;

	uint32_t ctrl_reg;
	uint32_t div_int_reg;
	uint32_t div_frac_reg;
	uint32_t sel_reg;
	uint32_t div_int_max;
	uint32_t clk_src_mask;

	/*
	 * XXX: Hack for determining whether to use an auxiliary clock source;
	 * we assume all sources have only standard or auxiliary parents.
	 */
	bool std_only;
};

struct clknode_periph_def {
	struct clknode_init_def clkdef;

	uint32_t ctrl_reg;
	uint32_t div_int_reg;
	uint32_t div_frac_reg;
	uint32_t sel_reg;
	uint32_t div_int_max;
	uint32_t clk_src_mask;

	bool std_only;
} rpiclock_periph_defs[] = {
	{
		.clkdef = {
			.name = "clk_sys",
			.id = RP1_CLK_SYS,
			.parent_names = (const char *[]){
			    "xosc",
			    NULL,
			    "pll_sys"
			},
			.parent_cnt = 3,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = CLK_SYS_CTRL,
		.div_int_reg = CLK_SYS_DIV_INT,
		.div_frac_reg = 0,
		.sel_reg = CLK_SYS_SEL,
		.div_int_max = DIV_INT_24BIT_MAX,
		.clk_src_mask = 0x3,
		.std_only = 1
	},
	{
		.clkdef = {
			.name = "clk_slow_sys",
			.id = RP1_CLK_SLOW_SYS,
			.parent_names = (const char *[]){"xosc"},
			.parent_cnt = 1,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = CLK_SLOW_SYS_CTRL,
		.div_int_reg = CLK_SLOW_SYS_DIV_INT,
		.div_frac_reg = 0,
		.sel_reg = CLK_SLOW_SYS_SEL,
		.div_int_max = DIV_INT_8BIT_MAX,
		.clk_src_mask = 0x1,
		.std_only = 1
	},
	{
		.clkdef = {
			.name = "clk_uart",
			.id = RP1_CLK_UART,
			.parent_names = (const char *[]){
			    "pll_sys_pri_ph",
			    "pll_video",
			    "xosc"
			},
			.parent_cnt = 3,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = CLK_UART_CTRL,
		.div_int_reg = CLK_UART_DIV_INT,
		.sel_reg = CLK_UART_SEL,
		.div_int_max = DIV_INT_8BIT_MAX,
		.std_only = 0
	},
	{
		.clkdef = {
			.name = "clk_eth",
			.id = RP1_CLK_ETH,
			.parent_names = (const char *[]){NULL},
			.parent_cnt = 0,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = CLK_ETH_CTRL,
		.div_int_reg = CLK_ETH_DIV_INT,
		.div_frac_reg = 0,
		.sel_reg = CLK_ETH_SEL,
		.div_int_max = DIV_INT_8BIT_MAX,
		.std_only = 1
	},
	{
		.clkdef = {
			.name = "clk_pwm0",
			.id = RP1_CLK_PWM0,
			.parent_names = (const char *[]){
			    "pll_audio_pri_ph",
			    "pll_video_sec",
			    "xosc"
			},
			.parent_cnt = 3,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = CLK_PWM0_CTRL,
		.div_int_reg = CLK_PWM0_DIV_INT,
		.div_frac_reg = CLK_PWM0_DIV_FRAC,
		.sel_reg = CLK_PWM0_SEL,
		.div_int_max = DIV_INT_16BIT_MAX,
		.std_only = 0
	},
	{
		.clkdef = {
			.name = "clk_pwm1",
			.id = RP1_CLK_PWM1,
			.parent_names = (const char *[]){
			    "pll_audio_pri_ph",
			    "pll_video_sec",
			    "xosc"
			},
			.parent_cnt = 3,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = CLK_PWM1_CTRL,
		.div_int_reg = CLK_PWM1_DIV_INT,
		.div_frac_reg = CLK_PWM1_DIV_FRAC,
		.sel_reg = CLK_PWM1_SEL,
		.div_int_max = DIV_INT_16BIT_MAX,
		.std_only = 0
	},
	{
		.clkdef = {
			.name = "clk_audio_in",
			.id = RP1_CLK_AUDIO_IN,
			.parent_names = (const char *[]){NULL},
			.parent_cnt = 0,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = CLK_AUDIO_IN_CTRL,
		.div_int_reg = CLK_AUDIO_IN_DIV_INT,
		.div_frac_reg = 0,
		.sel_reg = CLK_AUDIO_IN_SEL,
		.div_int_max = DIV_INT_8BIT_MAX,
		.std_only = 1
	},
	{
		.clkdef = {
			.name = "clk_audio_out",
			.id = RP1_CLK_AUDIO_OUT,
			.parent_names = (const char *[]){NULL},
			.parent_cnt = 0,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = CLK_AUDIO_OUT_CTRL,
		.div_int_reg = CLK_AUDIO_OUT_DIV_INT,
		.div_frac_reg = 0,
		.sel_reg = CLK_AUDIO_OUT_SEL,
		.div_int_max = DIV_INT_8BIT_MAX,
		.std_only = 1
	},
	{
		.clkdef = {
			.name = "clk_i2s",
			.id = RP1_CLK_I2S,
			.parent_names = (const char *[]){
			    "xosc",
			    "pll_audio",
			    "pll_audio_sec"
			},
			.parent_cnt = 3,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = CLK_I2S_CTRL,
		.div_int_reg = CLK_I2S_DIV_INT,
		.div_frac_reg = 0,
		.sel_reg = CLK_I2S_SEL,
		.div_int_max = DIV_INT_8BIT_MAX,
		.std_only = 0
	},
	{
		.clkdef = {
			.name = "clk_mipi0_cfg",
			.id = RP1_CLK_MIPI0_CFG,
			.parent_names = (const char *[]){"xosc"},
			.parent_cnt = 1,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = CLK_MIPI0_CFG_CTRL,
		.div_int_reg = CLK_MIPI0_CFG_DIV_INT,
		.div_frac_reg = 0,
		.sel_reg = CLK_MIPI0_CFG_SEL,
		.div_int_max = DIV_INT_8BIT_MAX,
		.std_only = 0
	},
	{
		.clkdef = {
			.name = "clk_mipi1_cfg",
			.id = RP1_CLK_MIPI1_CFG,
			.parent_names = (const char *[]){"xosc"},
			.parent_cnt = 1,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = CLK_MIPI1_CFG_CTRL,
		.div_int_reg = CLK_MIPI1_CFG_DIV_INT,
		.div_frac_reg = 0,
		.sel_reg = CLK_MIPI1_CFG_SEL,
		.clk_src_mask = 1,
		.div_int_max = DIV_INT_8BIT_MAX,
		.std_only = 0
	},
	{
		.clkdef = {
			.name = "clk_eth_tsu",
			.id = RP1_CLK_ETH_TSU,
			.parent_names = (const char *[]){"xosc"},
			.parent_cnt = 1,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = CLK_ETH_TSU_CTRL,
		.div_int_reg = CLK_ETH_TSU_DIV_INT,
		.div_frac_reg = 0,
		.sel_reg = CLK_ETH_TSU_SEL,
		.div_int_max = DIV_INT_8BIT_MAX,
		.std_only = 0
	},
	{
		.clkdef = {
			.name = "clk_adc",
			.id = RP1_CLK_ADC,
			.parent_names = (const char *[]){"xosc"},
			.parent_cnt = 1,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = CLK_ADC_CTRL,
		.div_int_reg = CLK_ADC_DIV_INT,
		.div_frac_reg = 0,
		.sel_reg = CLK_ADC_SEL,
		.div_int_max = DIV_INT_8BIT_MAX,
		.std_only = 0
	},
	{
		.clkdef = {
			.name = "clk_sdio_timer",
			.id = RP1_CLK_SDIO_TIMER,
			.parent_names = (const char *[]){"xosc"},
			.parent_cnt = 1,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = CLK_SDIO_TIMER_CTRL,
		.div_int_reg = CLK_SDIO_TIMER_DIV_INT,
		.div_frac_reg = 0,
		.sel_reg = CLK_SDIO_TIMER_SEL,
		.div_int_max = DIV_INT_8BIT_MAX,
		.std_only = 0
	},
	{
		.clkdef = {
			.name = "clk_sdio_alt_src",
			.id = RP1_CLK_SDIO_ALT_SRC,
			.parent_names = (const char *[]){"pll_sys"},
			.parent_cnt = 1,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = CLK_SDIO_ALT_SRC_CTRL,
		.div_int_reg = CLK_SDIO_ALT_SRC_DIV_INT,
		.div_frac_reg = 0,
		.sel_reg = CLK_SDIO_ALT_SRC_SEL,
		.div_int_max = DIV_INT_8BIT_MAX,
		.std_only = 0
	},
	{
		.clkdef = {
			.name = "clk_gp0",
			.id = RP1_CLK_GP0,
			.parent_names = (const char *[]){"xosc"},
			.parent_cnt = 1,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = CLK_GP0_CTRL,
		.div_int_reg = CLK_GP0_DIV_INT,
		.div_frac_reg = CLK_GP0_DIV_FRAC,
		.sel_reg = CLK_GP0_SEL,
		.div_int_max = DIV_INT_16BIT_MAX,
		.std_only = 0
	},
	{
		.clkdef = {
			.name = "clk_gp1",
			.id = RP1_CLK_GP1,
			.parent_names = (const char *[]){"xosc"},
			.parent_cnt = 1,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = CLK_GP1_CTRL,
		.div_int_reg = CLK_GP1_DIV_INT,
		.div_frac_reg = CLK_GP1_DIV_FRAC,
		.sel_reg = CLK_GP1_SEL,
		.div_int_max = DIV_INT_16BIT_MAX,
		.std_only = 0
	},
	{
		.clkdef = {
			.name = "clk_gp2",
			.id = RP1_CLK_GP2,
			.parent_names = (const char *[]){"xosc"},
			.parent_cnt = 1,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = CLK_GP2_CTRL,
		.div_int_reg = CLK_GP2_DIV_INT,
		.div_frac_reg = CLK_GP2_DIV_FRAC,
		.sel_reg = CLK_GP2_SEL,
		.div_int_max = DIV_INT_16BIT_MAX,
		.std_only = 0
	},
	{
		.clkdef = {
			.name = "clk_gp3",
			.id = RP1_CLK_GP3,
			.parent_names = (const char *[]){"xosc"},
			.parent_cnt = 1,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = CLK_GP3_CTRL,
		.div_int_reg = CLK_GP3_DIV_INT,
		.div_frac_reg = CLK_GP3_DIV_FRAC,
		.sel_reg = CLK_GP3_SEL,
		.div_int_max = DIV_INT_16BIT_MAX,
		.std_only = 0
	},
	{
		.clkdef = {
			.name = "clk_gp4",
			.id = RP1_CLK_GP4,
			.parent_names = (const char *[]){"xosc"},
			.parent_cnt = 1,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = CLK_GP4_CTRL,
		.div_int_reg = CLK_GP4_DIV_INT,
		.div_frac_reg = CLK_GP4_DIV_FRAC,
		.sel_reg = CLK_GP4_SEL,
		.div_int_max = DIV_INT_16BIT_MAX,
		.std_only = 0
	},
	{
		.clkdef = {
			.name = "clk_gp5",
			.id = RP1_CLK_GP5,
			.parent_names = (const char *[]){"xosc"},
			.parent_cnt = 1,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = CLK_GP5_CTRL,
		.div_int_reg = CLK_GP5_DIV_INT,
		.div_frac_reg = CLK_GP5_DIV_FRAC,
		.sel_reg = CLK_GP5_SEL,
		.div_int_max = DIV_INT_16BIT_MAX,
		.std_only = 0
	},
	{
		.clkdef = {
			.name = "clk_vec",
			.id = RP1_CLK_VEC,
			.parent_names = (const char *[]){
			    "pll_sys_pri_ph",
			    "pll_video_sec",
			    "pll_video",
			    "clk_gp0",
			    "clk_gp1",
			    "clk_gp2",
			    "clk_gp3",
			    "clk_gp4"
			},
			.parent_cnt = 8,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = VIDEO_CLK_VEC_CTRL,
		.div_int_reg = VIDEO_CLK_VEC_DIV_INT,
		.div_frac_reg = 0,
		.sel_reg = VIDEO_CLK_VEC_SEL,
		.div_int_max = DIV_INT_8BIT_MAX,
		.std_only = 0
	},
	{
		.clkdef = {
			.name = "clk_dpi",
			.id = RP1_CLK_DPI,
			.parent_names = (const char *[]){
			    "pll_sys",
			    "pll_video_sec",
			    "pll_video",
			    "clk_gp0",
			    "clk_gp1",
			    "clk_gp2",
			    "clk_gp3",
			    "clk_gp4"
			},
			.parent_cnt = 8,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = VIDEO_CLK_DPI_CTRL,
		.div_int_reg = VIDEO_CLK_DPI_DIV_INT,
		.div_frac_reg = 0,
		.sel_reg = VIDEO_CLK_DPI_SEL,
		.div_int_max = DIV_INT_8BIT_MAX,
		.std_only = 0
	},
	{
		.clkdef = {
			.name = "clk_mipi0_dpi",
			.id = RP1_CLK_MIPI0_DPI,
			.parent_names = (const char *[]){
			    "pll_sys",
			    "pll_video_sec",
			    "pll_video",
			    "clksrc_mipi0_dsi_byteclk",
			    "clk_gp0",
			    "clk_gp1",
			    "clk_gp2",
			    "clk_gp3"
			},
			.parent_cnt = 8,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = VIDEO_CLK_MIPI0_DPI_CTRL,
		.div_int_reg = VIDEO_CLK_MIPI0_DPI_DIV_INT,
		.div_frac_reg = VIDEO_CLK_MIPI0_DPI_DIV_FRAC,
		.sel_reg = VIDEO_CLK_MIPI0_DPI_SEL,
		.div_int_max = DIV_INT_8BIT_MAX,
		.std_only = 0
	},
	{
		.clkdef = {
			.name = "clk_mipi1_dpi",
			.id = RP1_CLK_MIPI1_DPI,
			.parent_names = (const char *[]){
			    "pll_sys",
			    "pll_video_sec",
			    "pll_video",
			    "clksrc_mipi1_dsi_byteclk",
			    "clk_gp0",
			    "clk_gp1",
			    "clk_gp2",
			    "clk_gp3"
			},
			.parent_cnt = 8,
			.flags = CLK_NODE_STATIC_STRINGS
		},
		.ctrl_reg = VIDEO_CLK_MIPI1_DPI_CTRL,
		.div_int_reg = VIDEO_CLK_MIPI1_DPI_DIV_INT,
		.div_frac_reg = VIDEO_CLK_MIPI1_DPI_DIV_FRAC,
		.sel_reg = VIDEO_CLK_MIPI1_DPI_SEL,
		.div_int_max = DIV_INT_8BIT_MAX,
		.std_only = 0
	},
};

static int
rpiclock_periph_init(struct clknode *clk, device_t dev)
{
	struct rpi_periph_sc *sc;
	uint32_t idx;
	uint32_t sel, ctrl;

	sc = clknode_get_softc(clk);

	/* XXX: Should not assume sel_reg is readable; check ctrl */
	if (sc->std_only) {
		RD4(sc, sc->sel_reg, &sel);
		idx = ffs(sel) - 1;
	} else {
		RD4(sc, sc->ctrl_reg, &ctrl);
		idx = (ctrl & CLK_CTRL_AUXSRC_MASK) >> CLK_CTRL_AUXSRC_SHIFT;
	}

	if (idx >= clknode_get_parents_num(clk))
		return (EINVAL);

	clknode_init_parent_idx(clk, idx);
	return (0);
}

static int
rpiclock_periph_recalc(struct clknode *clk, uint64_t *freq)
{
	struct clknode *parent_clk;
	struct rpi_periph_sc *sc;
	uint64_t parent_freq;
	uint32_t div_int, div_frac;
	uint64_t div;
	int error;

	sc = clknode_get_softc(clk);

	parent_clk = clknode_get_parent(clk);

	error = clknode_get_freq(parent_clk, &parent_freq);
	if (error != 0)
		return error;

	RD4(sc, sc->div_int_reg, &div_int);
	if (sc->div_frac_reg) {
		RD4(sc, sc->div_frac_reg, &div_frac);
	} else {
		div_frac = 0;
	}

	div =
	    ((uint64_t)div_int << CLK_DIV_FRAC_BITS) |
	    (div_frac >> (32 - CLK_DIV_FRAC_BITS));

	*freq = DIV_ROUND((uint64_t)parent_freq << CLK_DIV_FRAC_BITS, div) >>
	    CLK_DIV_FRAC_BITS;

	return (0);
}

static void
calculate_freq(
    struct rpi_periph_sc *sc, uint64_t parent, uint64_t target,
    uint64_t *freq, uint64_t *div)
{
	*div = DIV_ROUND(parent << CLK_DIV_FRAC_BITS, target);

	/* Round up */
	*div += (1 << (CLK_DIV_FRAC_BITS - 1));

	/* Clip div_int.div_frac to between 1 and div_int_max */
	*div = MIN((uint64_t)sc->div_int_max << CLK_DIV_FRAC_BITS, *div);
	*div = MAX((uint64_t)1 << CLK_DIV_FRAC_BITS, *div);

	*freq = DIV_ROUND(parent, *div);
}

static int
rpiclock_periph_set_freq(
    struct clknode *clk, uint64_t fin, uint64_t *fout, int flags, int *stop)
{
	struct rpi_periph_sc *sc;

	uint64_t freq, best_freq;
	uint64_t div, best_div;
	uint8_t best_mux;

	uint32_t div_int, div_frac;

	uint32_t ctrl, sel;

	int parent_cnt;
	const char **parent_names;
	struct clknode *parent_clk;
	uint64_t parent_freq;

	int i;

	sc = clknode_get_softc(clk);

	/*
	 * Start out with the current parent.  This prevents
	 * unnecessary switching to a different parent.
	 */
	if (sc->std_only) {
		RD4(sc, sc->sel_reg, &sel);
		best_mux = ffs(sel) - 1;
	} else {
		RD4(sc, sc->ctrl_reg, &ctrl);
		best_mux = (ctrl & CLK_CTRL_AUXSRC_MASK) >>
		     CLK_CTRL_AUXSRC_SHIFT;
	}

	best_freq = *fout;

	/*
	 * Find the parent that allows configuration of a frequency
	 * closest to the target frequency.
	 */
	parent_cnt = clknode_get_parents_num(clk);
	parent_names = clknode_get_parent_names(clk);
	for (i = 0; i < parent_cnt; i++) {
		if(parent_names[i] == NULL)
			continue;

		parent_clk = clknode_find_by_name(parent_names[i]);
		clknode_get_freq(parent_clk, &parent_freq);

		calculate_freq(sc, parent_freq, fin, &freq, &div);

		if ((fin <= freq && freq < best_freq) ||
		    (best_freq < freq && freq <= fin)) {
			best_div = div;
			best_freq = freq;
			best_mux = i;
		}

		if (freq == fin)
			break;
	}

	if (!(flags & CLK_SET_DRYRUN)) {
		RD4(sc, sc->ctrl_reg, &ctrl);
		if (sc->std_only) {
			ctrl &= ~sc->clk_src_mask;
			ctrl |= (best_mux << CLK_CTRL_SRC_SHIFT);
		} else {
			ctrl &= ~CLK_CTRL_AUXSRC_MASK;
			ctrl |= (best_mux << CLK_CTRL_AUXSRC_SHIFT);
			ctrl &= ~sc->clk_src_mask;
			ctrl |= AUX_SEL; // CLK_CTRL_SRC_AUX
		}
		WR4(sc, sc->ctrl_reg, ctrl);

		div_int = best_div >> CLK_DIV_FRAC_BITS;
		div_frac = (best_div & ((1ULL << CLK_DIV_FRAC_BITS) - 1)) <<
		    (32 - CLK_DIV_FRAC_BITS);

		WR4(sc, sc->div_int_reg, div_int);
		WR4(sc, sc->div_frac_reg, div_frac);
	}

	*fout = best_freq;
	*stop = 1;

	return 0;
}


static int
rpiclock_periph_get_gate(struct clknode *clk, bool *enabled)
{
	struct rpi_periph_sc *sc;
	uint32_t reg;

	sc = clknode_get_softc(clk);
	RD4(sc, sc->ctrl_reg, &reg);

	*enabled = !!(reg & CLK_CTRL_ENABLE);

	return (0);
}

static int
rpiclock_periph_set_gate(struct clknode *clk, bool enable)
{
	struct rpi_periph_sc *sc;
	uint32_t reg;

	sc = clknode_get_softc(clk);
	RD4(sc, sc->ctrl_reg, &reg);

	if (enable) {
		reg |= CLK_CTRL_ENABLE;
	} else {
		reg &= ~CLK_CTRL_ENABLE;
	}

	WR4(sc, sc->ctrl_reg, reg);

	return (0);
}

static clknode_method_t rpiclock_periph_methods[] = {
	/* Device interface */
	CLKNODEMETHOD(clknode_init,		rpiclock_periph_init),
	CLKNODEMETHOD(clknode_recalc_freq,	rpiclock_periph_recalc),
	CLKNODEMETHOD(clknode_set_freq,		rpiclock_periph_set_freq),
	CLKNODEMETHOD(clknode_get_gate,		rpiclock_periph_get_gate),
	CLKNODEMETHOD(clknode_set_gate,		rpiclock_periph_set_gate),
	CLKNODEMETHOD_END
};
DEFINE_CLASS_1(rpiclock_periph, rpiclock_periph_class,
   rpiclock_periph_methods, sizeof(struct rpi_periph_sc), clknode_class);

static int
rpiclock_init_periph(struct clkdom *clkdom, struct clknode_periph_def *def)
{
	struct clknode *clk;
	struct rpi_periph_sc *sc;

	clk = clknode_create(clkdom, &rpiclock_periph_class,
	    (struct clknode_init_def *)def);
	if (clk == NULL) {
		return (ENXIO);
	}

	sc = clknode_get_softc(clk);
	sc->clkdev = clknode_get_device(clk);

	sc->ctrl_reg = def->ctrl_reg;
	sc->div_int_reg = def->div_int_reg;
	sc->sel_reg = def->sel_reg;
	sc->div_int_max = def->div_int_max;
	sc->clk_src_mask = def->clk_src_mask;

	sc->std_only = def->std_only;

	clknode_register(clkdom, clk);

	return (0);
}


void
rpiclock_init_periphs(struct rpiclock_softc *sc)
{
	struct clkdom *clkdom;
	int error;
	int i;

	clkdom = sc->clkdom;

	for (i = 0; i < nitems(rpiclock_periph_defs); i++) {
		error = rpiclock_init_periph(clkdom, &rpiclock_periph_defs[i]);
		if (error != 0)
			panic("periph '%s' initialization failed",
			    rpiclock_periph_defs[i].clkdef.name);
	}
}
