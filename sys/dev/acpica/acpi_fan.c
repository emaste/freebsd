/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2026 The FreeBSD Foundation
 * All rights reserved.
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
#include <sys/param.h>
#include <sys/bus.h>
#include <sys/kernel.h>
#include <sys/malloc.h>
#include <sys/mutex.h>
#include <sys/module.h>
#include <sys/sbuf.h>

#include <contrib/dev/acpica/include/acpi.h>

#include <dev/acpica/acpivar.h>

#define	ACPI_FAN_PACKAGE_SIZE	20
#define	ACPI_FAN_INVALID_VALUE	0xffffffff

struct acpi_fan_package {
	uint32_t control;
	uint32_t trip_point;
	uint32_t speed;
	uint32_t noise_level;
	uint32_t power;
};

struct acpi_fan_param {
	struct acpi_fan_package *pkgs;
	int cnts;
};

struct acpi_fan_softc {
	device_t dev;
	int (*set_level)(struct acpi_fan_softc *sc, uint32_t val);
	uint32_t cached_level;
	bool fine_grind;
	union {
		uint32_t step;
		struct acpi_fan_param pkg;
	};
	struct mtx mtx;
};

static int
acpi_fan_set(struct acpi_fan_softc *sc, uint32_t val)
{
	ACPI_OBJECT_LIST arglist;
	ACPI_OBJECT arg;

	arglist.Count = 1;
	arglist.Pointer = &arg;
	arg.Type = ACPI_TYPE_INTEGER;
	arg.Buffer.Length = sizeof(val);
	arg.Buffer.Pointer = (uint8_t *)&val;
	if (ACPI_FAILURE(AcpiEvaluateObject(sc->dev, "_FSL", &arglist, NULL)))
		return (ENXIO);
	return (0);
}

static int
acpi_fan_set_fine_grind(struct acpi_fan_softc *sc, uint32_t val)
{
	if (val < 0 || val > 100)
		return (EINVAL);
	val = rounddown(val, sc->step);
	return (acpi_fan_set(sc, val));
}

static int
acpi_fan_set_level(struct acpi_fan_softc *sc, uint32_t val)
{
	struct acpi_fan_package *pkg;
	int i, n;

	pkg = sc->pkg.pkgs;
	for (i = 0, n = sc->pkg.cnts; i < n; i++) {
		if (pkg[i].control == val)
			break;
	}
	if (i == sc->pkg.cnts)
		return (EINVAL);
	return (acpi_fan_set(sc, val));
}

static int
acpi_fan_get_status(const device_t dev, uint32_t *ctrl, uint32_t *speed)
{
	ACPI_HANDLE handle;
	ACPI_BUFFER buffer;
	ACPI_OBJECT *obj;
	int err = 0;

	handle = acpi_get_handle(dev);
	buffer.Length = ACPI_ALLOCATE_BUFFER;
	buffer.Pointer = NULL;
	if (ACPI_FAILURE(AcpiEvaluateObject(handle, "_FST", NULL, &buffer)))
		return (ENXIO);
	obj = buffer.Pointer;
	if (ctrl && (err = acpi_PkgInt32(obj, 1, ctrl)) != 0)
		goto end;
	if (speed)
		err = acpi_PkgInt32(obj, 2, speed);
end:
	AcpiOsFree(buffer.Pointer);
	return (err);
}

static int
sysctl_show_fan_status(SYSCTL_HANDLER_ARGS)
{
	const device_t dev = arg1;
	struct sbuf sbs, *sb;
	uint32_t control, speed;
	int err;

	if ((err = acpi_fan_get_status(dev, &control, &speed)) != 0)
		return (err);
	sb = sbuf_new_for_sysctl(&sbs, NULL, 0, req);
	sbuf_printf(sb, "Control Level: %u, Speed: %u RPM", control, speed);
	err = sbuf_finish(sb);
	sbuf_delete(sb);
	return (0);
}

static int
sysctl_list_fan_levels(SYSCTL_HANDLER_ARGS)
{
	const device_t dev = arg1;
	struct acpi_fan_softc *sc = device_get_softc(dev);
	struct acpi_fan_package *pkg;
	struct sbuf sbs, *sb;
	int err, i, n;

	sb = sbuf_new_for_sysctl(&sbs, NULL, 0, req);
	for (i = 0, n = sc->pkg.cnts; i < n; i++) {
		pkg = &sc->pkg.pkgs[i];
		sbuf_printf(sb,
		    "Ctrl: %u, TripPoint: %u, Speed: %u, NoiseLevel: %u, Power: %u\n",
		    pkg->control, pkg->trip_point, pkg->speed, pkg->noise_level,
		    pkg->power);
	}
	err = sbuf_finish(sb);
	sbuf_delete(sb);
	return (err);
}

static int
sysctl_set_fan_level(SYSCTL_HANDLER_ARGS)
{
	const device_t dev = arg1;
	struct acpi_fan_softc *sc = device_get_softc(dev);
	int err;
	uint32_t val;

	mtx_lock(&sc->mtx);
	val = sc->cached_level;
	mtx_unlock(&sc->mtx);
	err = sysctl_handle_int(oidp, &val, 0, req);
	if (err)
		return (err);
	mtx_lock(&sc->mtx);
	if (val == sc->cached_level)
		return (0);
	mtx_unlock(&sc->mtx);
	err = sc->set_level(sc, val);
	if (err)
		return (err);
	mtx_lock(&sc->mtx);
	sc->cached_level = val;
	mtx_unlock(&sc->mtx);
	return (0);
}

static int
acpi_fan_probe(device_t dev)
{
	static char *fan_ids[] = { "PNP0C0B", NULL };
	ACPI_STATUS status;
	int res;

	if (acpi_disabled("fan"))
		return (ENXIO);
	res = ACPI_ID_PROBE(device_get_parent(dev), dev, fan_ids, NULL);
	if (res)
		return (res);
	status = AcpiEvaluateObject(acpi_get_handle(dev), "_FIF", NULL, NULL);
	if (ACPI_FAILURE(status))
		return (ENXIO);
	device_set_desc(dev, "ACPI Fan");
	return (0);
}

static int
acpi_fan_parse_fps(ACPI_HANDLE handle, struct acpi_fan_softc *sc)
{
	ACPI_BUFFER buf;
	ACPI_OBJECT *pkg_obj, *obj;
	int idx, cnt, err = 0;

	buf.Pointer = NULL;
	buf.Length = ACPI_ALLOCATE_BUFFER;
	if (ACPI_FAILURE(AcpiEvaluateObject(handle, "_FPS", NULL, &buf)))
		return (ENXIO);
	// ACPI_TYPE + NUM_ELEMENTS + Package[0] == REVISION
	if (buf.Length < 12 || (buf.Length - 12) % ACPI_FAN_PACKAGE_SIZE != 0) {
		err = EINVAL;
		goto end;
	}
	pkg_obj = buf.Pointer;
	if (pkg_obj->Type != ACPI_TYPE_PACKAGE) {
		err = EINVAL;
		goto end;
	}
	cnt = pkg_obj->Package.Count - 1;
	sc->pkg.cnts = cnt;
	if (cnt == 0)
		goto end;
	sc->pkg.pkgs = malloc(cnt * sizeof(struct acpi_fan_package), M_DEVBUF,
	    M_WAITOK);
	for (idx = 0; idx < cnt; idx++) {
		// + 1 for revision
		obj = &(pkg_obj->Package.Elements[idx + 1]);
		acpi_PkgInt32(obj, 0, &sc->pkg.pkgs[idx].control);
		acpi_PkgInt32(obj, 1, &sc->pkg.pkgs[idx].trip_point);
		acpi_PkgInt32(obj, 2, &sc->pkg.pkgs[idx].speed);
		acpi_PkgInt32(obj, 3, &sc->pkg.pkgs[idx].noise_level);
		acpi_PkgInt32(obj, 4, &sc->pkg.pkgs[idx].power);
	}
end:
	AcpiOsFree(buf.Pointer);
	return (err);
}

static int
acpi_fan_attach(device_t dev)
{
	ACPI_HANDLE handle;
	ACPI_BUFFER buf;
	ACPI_OBJECT *obj;
	struct acpi_fan_softc *sc;
	uint32_t val;
	int err;

	handle = acpi_get_handle(dev);
	sc = device_get_softc(dev);
	sc->dev = dev;
	buf.Pointer = NULL;
	buf.Length = ACPI_ALLOCATE_BUFFER;
	if (ACPI_FAILURE(AcpiEvaluateObject(handle, "_FIF", NULL, &buf)))
		return (ENXIO);
	obj = buf.Pointer;

	if (!ACPI_PKG_VALID(obj, 4)) {
		err = ENXIO;
		goto end;
	}
	if ((err = acpi_PkgInt32(obj, 1, &val)) != 0)
		goto end;
	sc->fine_grind = val;
	// Fine grind control of the fan. Read the step.
	if (sc->fine_grind) {
		if ((err = acpi_PkgInt32(obj, 2, &val)) != 0)
			goto end;
		sc->step = val;
		sc->set_level = &acpi_fan_set_fine_grind;
	} else
		sc->set_level = &acpi_fan_set_level;
	err = acpi_fan_parse_fps(handle, sc);
	if (err) {
		device_printf(dev, "Unable to parse _FPS object");
		err = 0;
	}
	err = acpi_fan_get_status(dev, &sc->cached_level, NULL);
	if (err) {
		device_printf(dev, "Failed to get _FST object");
		sc->cached_level = ACPI_FAN_INVALID_VALUE;
		err = 0;
	}
	mtx_init(&sc->mtx, "Fan mutex", NULL, MTX_SPIN);
	if (sc->fine_grind) {
		SYSCTL_ADD_INT(device_get_sysctl_ctx(dev),
		    SYSCTL_CHILDREN(device_get_sysctl_tree(dev)), OID_AUTO,
		    "steps", CTLFLAG_RD | CTLFLAG_MPSAFE, &sc->step, 0,
		    "Steps for Fine Grind Control");
	} else {
		SYSCTL_ADD_PROC(device_get_sysctl_ctx(dev),
		    SYSCTL_CHILDREN(device_get_sysctl_tree(dev)), OID_AUTO,
		    "levels", CTLTYPE_STRING | CTLFLAG_RD | CTLFLAG_MPSAFE, dev,
		    0, sysctl_list_fan_levels, "A",
		    "List all available speeds");
	}
	SYSCTL_ADD_PROC(device_get_sysctl_ctx(dev),
	    SYSCTL_CHILDREN(device_get_sysctl_tree(dev)), OID_AUTO, "status",
	    CTLTYPE_STRING | CTLFLAG_RD | CTLFLAG_MPSAFE, dev, 0,
	    sysctl_show_fan_status, "A", "Show fan's status");
	SYSCTL_ADD_PROC(device_get_sysctl_ctx(dev),
	    SYSCTL_CHILDREN(device_get_sysctl_tree(dev)), OID_AUTO, "set_level",
	    CTLTYPE_UINT | CTLFLAG_RWTUN | CTLFLAG_MPSAFE, dev, 0,
	    sysctl_set_fan_level, "IU", "Set fan level");
	SYSCTL_ADD_BOOL(device_get_sysctl_ctx(dev),
	    SYSCTL_CHILDREN(device_get_sysctl_tree(dev)), OID_AUTO,
	    "fine_grind", CTLFLAG_RD | CTLFLAG_MPSAFE, &sc->fine_grind, 0,
	    "Check if fan is operated in fine_grind");
end:
	AcpiOsFree(buf.Pointer);
	return (err);
}

static int
acpi_fan_detach(device_t dev)
{
	struct acpi_fan_softc *sc = device_get_softc(dev);

	if (sc->pkg.cnts != 0)
		free(sc->pkg.pkgs, M_DEVBUF);
	mtx_destroy(&sc->mtx);
	return (0);
}

static int
acpi_fan_suspend(device_t dev)
{
	struct acpi_fan_softc *sc = device_get_softc(dev);

	return (sc->set_level(sc, 0));
}

static int
acpi_fan_resume(device_t dev)
{
	struct acpi_fan_softc *sc = device_get_softc(dev);

	return (sc->set_level(sc, sc->cached_level));
}

static device_method_t acpi_fan_methods[] = {
	/* device interface */
	DEVMETHOD(device_probe, acpi_fan_probe),
	DEVMETHOD(device_attach, acpi_fan_attach),
	DEVMETHOD(device_detach, acpi_fan_detach),
	DEVMETHOD(device_suspend, acpi_fan_suspend),
	DEVMETHOD(device_resume, acpi_fan_resume),

	DEVMETHOD_END
};

static driver_t acpi_fan_driver = {
	"fan",
	acpi_fan_methods,
	sizeof(struct acpi_fan_softc),
};

DRIVER_MODULE(acpi_smbat, acpi, acpi_fan_driver, 0, 0);
MODULE_DEPEND(acpi_smbat, acpi, 1, 1, 1);
