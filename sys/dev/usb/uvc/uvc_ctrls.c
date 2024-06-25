/*
 *
 * Copyright (c) 2024 Dell Inc.. All rights reserved.
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

/*
 * UVC spec:https://www.usb.org/sites/default/files/USB_Video_Class_1_5.zip
 */

#include <sys/cdefs.h>
#include <sys/param.h>
#include <sys/kernel.h>
#include <sys/sdt.h>
#include <sys/systm.h>
#include <sys/sysctl.h>
#include <sys/proc.h>

#include <sys/types.h>
#include <sys/bus.h>
#include <sys/mutex.h>
#include <sys/condvar.h>
#include <sys/malloc.h>
#include <sys/priv.h>
#include <sys/conf.h>
#include <sys/fcntl.h>

#include <dev/usb/usb.h>
#define USB_DEBUG_VAR uvc_debug
#include <dev/usb/usb_debug.h>
#include <dev/usb/usbdi.h>

#include <contrib/v4l/videodev.h>
#include <contrib/v4l/videodev2.h>

#include "uvc_drv.h"
#include "uvc_buf.h"
#include "uvc_v4l2.h"

#define UVC_CTRL_DATA_CURRENT	0
#define UVC_CTRL_DATA_BACKUP	1
#define UVC_CTRL_DATA_MIN	2
#define UVC_CTRL_DATA_MAX	3
#define UVC_CTRL_DATA_RES	4
#define UVC_CTRL_DATA_DEF	5
#define UVC_CTRL_DATA_LAST	6

#define ARRAY_SIZE(x)	(sizeof(x) / sizeof((x)[0]))

/* ------------------------------------------------------------------------
 * Controls
 */

static const struct uvc_control_info uvc_ctrls[] = {
	{
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_BRIGHTNESS_CONTROL,
		.index		= 0,
		.size		= 2,
		.flags		= UVC_CTRL_FLAG_SET_CUR
				| UVC_CTRL_FLAG_GET_RANGE
				| UVC_CTRL_FLAG_RESTORE,
	},
	{
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_CONTRAST_CONTROL,
		.index		= 1,
		.size		= 2,
		.flags		= UVC_CTRL_FLAG_SET_CUR
				| UVC_CTRL_FLAG_GET_RANGE
				| UVC_CTRL_FLAG_RESTORE,
	},
	{
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_HUE_CONTROL,
		.index		= 2,
		.size		= 2,
		.flags		= UVC_CTRL_FLAG_SET_CUR
				| UVC_CTRL_FLAG_GET_RANGE
				| UVC_CTRL_FLAG_RESTORE
				| UVC_CTRL_FLAG_AUTO_UPDATE,
	},
	{
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_SATURATION_CONTROL,
		.index		= 3,
		.size		= 2,
		.flags		= UVC_CTRL_FLAG_SET_CUR
				| UVC_CTRL_FLAG_GET_RANGE
				| UVC_CTRL_FLAG_RESTORE,
	},
	{
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_SHARPNESS_CONTROL,
		.index		= 4,
		.size		= 2,
		.flags		= UVC_CTRL_FLAG_SET_CUR
				| UVC_CTRL_FLAG_GET_RANGE
				| UVC_CTRL_FLAG_RESTORE,
	},
	{
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_GAMMA_CONTROL,
		.index		= 5,
		.size		= 2,
		.flags		= UVC_CTRL_FLAG_SET_CUR
				| UVC_CTRL_FLAG_GET_RANGE
				| UVC_CTRL_FLAG_RESTORE,
	},
	{
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_WHITE_BALANCE_TEMPERATURE_CONTROL,
		.index		= 6,
		.size		= 2,
		.flags		= UVC_CTRL_FLAG_SET_CUR
				| UVC_CTRL_FLAG_GET_RANGE
				| UVC_CTRL_FLAG_RESTORE
				| UVC_CTRL_FLAG_AUTO_UPDATE,
	},
	{
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_WHITE_BALANCE_COMPONENT_CONTROL,
		.index		= 7,
		.size		= 4,
		.flags		= UVC_CTRL_FLAG_SET_CUR
				| UVC_CTRL_FLAG_GET_RANGE
				| UVC_CTRL_FLAG_RESTORE
				| UVC_CTRL_FLAG_AUTO_UPDATE,
	},
	{
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_BACKLIGHT_COMPENSATION_CONTROL,
		.index		= 8,
		.size		= 2,
		.flags		= UVC_CTRL_FLAG_SET_CUR
				| UVC_CTRL_FLAG_GET_RANGE
				| UVC_CTRL_FLAG_RESTORE,
	},
	{
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_GAIN_CONTROL,
		.index		= 9,
		.size		= 2,
		.flags		= UVC_CTRL_FLAG_SET_CUR
				| UVC_CTRL_FLAG_GET_RANGE
				| UVC_CTRL_FLAG_RESTORE,
	},
	{
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_POWER_LINE_FREQUENCY_CONTROL,
		.index		= 10,
		.size		= 1,
		.flags		= UVC_CTRL_FLAG_SET_CUR | UVC_CTRL_FLAG_GET_CUR
				| UVC_CTRL_FLAG_GET_DEF | UVC_CTRL_FLAG_RESTORE,
	},
	{
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_HUE_AUTO_CONTROL,
		.index		= 11,
		.size		= 1,
		.flags		= UVC_CTRL_FLAG_SET_CUR | UVC_CTRL_FLAG_GET_CUR
				| UVC_CTRL_FLAG_GET_DEF | UVC_CTRL_FLAG_RESTORE,
	},
	{
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_WHITE_BALANCE_TEMPERATURE_AUTO_CONTROL,
		.index		= 12,
		.size		= 1,
		.flags		= UVC_CTRL_FLAG_SET_CUR | UVC_CTRL_FLAG_GET_CUR
				| UVC_CTRL_FLAG_GET_DEF | UVC_CTRL_FLAG_RESTORE,
	},
	{
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_WHITE_BALANCE_COMPONENT_AUTO_CONTROL,
		.index		= 13,
		.size		= 1,
		.flags		= UVC_CTRL_FLAG_SET_CUR | UVC_CTRL_FLAG_GET_CUR
				| UVC_CTRL_FLAG_GET_DEF | UVC_CTRL_FLAG_RESTORE,
	},
	{
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_DIGITAL_MULTIPLIER_CONTROL,
		.index		= 14,
		.size		= 2,
		.flags		= UVC_CTRL_FLAG_SET_CUR
				| UVC_CTRL_FLAG_GET_RANGE
				| UVC_CTRL_FLAG_RESTORE,
	},
	{
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_DIGITAL_MULTIPLIER_LIMIT_CONTROL,
		.index		= 15,
		.size		= 2,
		.flags		= UVC_CTRL_FLAG_SET_CUR
				| UVC_CTRL_FLAG_GET_RANGE
				| UVC_CTRL_FLAG_RESTORE,
	},
	{
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_ANALOG_VIDEO_STANDARD_CONTROL,
		.index		= 16,
		.size		= 1,
		.flags		= UVC_CTRL_FLAG_GET_CUR,
	},
	{
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_ANALOG_LOCK_STATUS_CONTROL,
		.index		= 17,
		.size		= 1,
		.flags		= UVC_CTRL_FLAG_GET_CUR,
	},
	{
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_SCANNING_MODE_CONTROL,
		.index		= 0,
		.size		= 1,
		.flags		= UVC_CTRL_FLAG_SET_CUR | UVC_CTRL_FLAG_GET_CUR
				| UVC_CTRL_FLAG_RESTORE,
	},
	{
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_AE_MODE_CONTROL,
		.index		= 1,
		.size		= 1,
		.flags		= UVC_CTRL_FLAG_SET_CUR | UVC_CTRL_FLAG_GET_CUR
				| UVC_CTRL_FLAG_GET_DEF | UVC_CTRL_FLAG_GET_RES
				| UVC_CTRL_FLAG_RESTORE,
	},
	{
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_AE_PRIORITY_CONTROL,
		.index		= 2,
		.size		= 1,
		.flags		= UVC_CTRL_FLAG_SET_CUR | UVC_CTRL_FLAG_GET_CUR
				| UVC_CTRL_FLAG_RESTORE,
	},
	{
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_EXPOSURE_TIME_ABSOLUTE_CONTROL,
		.index		= 3,
		.size		= 4,
		.flags		= UVC_CTRL_FLAG_SET_CUR
				| UVC_CTRL_FLAG_GET_RANGE
				| UVC_CTRL_FLAG_RESTORE
				| UVC_CTRL_FLAG_AUTO_UPDATE,
	},
	{
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_EXPOSURE_TIME_RELATIVE_CONTROL,
		.index		= 4,
		.size		= 1,
		.flags		= UVC_CTRL_FLAG_SET_CUR | UVC_CTRL_FLAG_RESTORE,
	},
	{
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_FOCUS_ABSOLUTE_CONTROL,
		.index		= 5,
		.size		= 2,
		.flags		= UVC_CTRL_FLAG_SET_CUR
				| UVC_CTRL_FLAG_GET_RANGE
				| UVC_CTRL_FLAG_RESTORE
				| UVC_CTRL_FLAG_AUTO_UPDATE,
	},
	{
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_FOCUS_RELATIVE_CONTROL,
		.index		= 6,
		.size		= 2,
		.flags		= UVC_CTRL_FLAG_SET_CUR | UVC_CTRL_FLAG_GET_MIN
				| UVC_CTRL_FLAG_GET_MAX | UVC_CTRL_FLAG_GET_RES
				| UVC_CTRL_FLAG_GET_DEF
				| UVC_CTRL_FLAG_AUTO_UPDATE,
	},
	{
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_IRIS_ABSOLUTE_CONTROL,
		.index		= 7,
		.size		= 2,
		.flags		= UVC_CTRL_FLAG_SET_CUR
				| UVC_CTRL_FLAG_GET_RANGE
				| UVC_CTRL_FLAG_RESTORE
				| UVC_CTRL_FLAG_AUTO_UPDATE,
	},
	{
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_IRIS_RELATIVE_CONTROL,
		.index		= 8,
		.size		= 1,
		.flags		= UVC_CTRL_FLAG_SET_CUR
				| UVC_CTRL_FLAG_AUTO_UPDATE,
	},
	{
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_ZOOM_ABSOLUTE_CONTROL,
		.index		= 9,
		.size		= 2,
		.flags		= UVC_CTRL_FLAG_SET_CUR
				| UVC_CTRL_FLAG_GET_RANGE
				| UVC_CTRL_FLAG_RESTORE
				| UVC_CTRL_FLAG_AUTO_UPDATE,
	},
	{
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_ZOOM_RELATIVE_CONTROL,
		.index		= 10,
		.size		= 3,
		.flags		= UVC_CTRL_FLAG_SET_CUR | UVC_CTRL_FLAG_GET_MIN
				| UVC_CTRL_FLAG_GET_MAX | UVC_CTRL_FLAG_GET_RES
				| UVC_CTRL_FLAG_GET_DEF
				| UVC_CTRL_FLAG_AUTO_UPDATE,
	},
	{
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_PANTILT_ABSOLUTE_CONTROL,
		.index		= 11,
		.size		= 8,
		.flags		= UVC_CTRL_FLAG_SET_CUR
				| UVC_CTRL_FLAG_GET_RANGE
				| UVC_CTRL_FLAG_RESTORE
				| UVC_CTRL_FLAG_AUTO_UPDATE,
	},
	{
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_PANTILT_RELATIVE_CONTROL,
		.index		= 12,
		.size		= 4,
		.flags		= UVC_CTRL_FLAG_SET_CUR
				| UVC_CTRL_FLAG_GET_RANGE
				| UVC_CTRL_FLAG_AUTO_UPDATE,
	},
	{
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_ROLL_ABSOLUTE_CONTROL,
		.index		= 13,
		.size		= 2,
		.flags		= UVC_CTRL_FLAG_SET_CUR
				| UVC_CTRL_FLAG_GET_RANGE
				| UVC_CTRL_FLAG_RESTORE
				| UVC_CTRL_FLAG_AUTO_UPDATE,
	},
	{
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_ROLL_RELATIVE_CONTROL,
		.index		= 14,
		.size		= 2,
		.flags		= UVC_CTRL_FLAG_SET_CUR | UVC_CTRL_FLAG_GET_MIN
				| UVC_CTRL_FLAG_GET_MAX | UVC_CTRL_FLAG_GET_RES
				| UVC_CTRL_FLAG_GET_DEF
				| UVC_CTRL_FLAG_AUTO_UPDATE,
	},
	{
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_FOCUS_AUTO_CONTROL,
		.index		= 17,
		.size		= 1,
		.flags		= UVC_CTRL_FLAG_SET_CUR | UVC_CTRL_FLAG_GET_CUR
				| UVC_CTRL_FLAG_GET_DEF | UVC_CTRL_FLAG_RESTORE,
	},
	{
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_PRIVACY_CONTROL,
		.index		= 18,
		.size		= 1,
		.flags		= UVC_CTRL_FLAG_SET_CUR | UVC_CTRL_FLAG_GET_CUR
				| UVC_CTRL_FLAG_RESTORE
				| UVC_CTRL_FLAG_AUTO_UPDATE,
	},
};

static struct uvc_menu_info power_line_frequency_controls[] = {
	{ 0, "Disabled" },
	{ 1, "50 Hz" },
	{ 2, "60 Hz" },
};

static struct uvc_menu_info exposure_auto_controls[] = {
	{ 2, "Auto Mode" },
	{ 1, "Manual Mode" },
	{ 4, "Shutter Priority Mode" },
	{ 8, "Aperture Priority Mode" },
};

static const struct uvc_control_mapping uvc_ctrl_mappings[] = {
	{
		.id		= V4L2_CID_BRIGHTNESS,
		.name		= "Brightness",
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_BRIGHTNESS_CONTROL,
		.size		= 16,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_INTEGER,
		.data_type	= UVC_CTRL_DATA_TYPE_SIGNED,
	},
	{
		.id		= V4L2_CID_CONTRAST,
		.name		= "Contrast",
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_CONTRAST_CONTROL,
		.size		= 16,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_INTEGER,
		.data_type	= UVC_CTRL_DATA_TYPE_UNSIGNED,
	},
	{
		.id		= V4L2_CID_HUE,
		.name		= "Hue",
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_HUE_CONTROL,
		.size		= 16,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_INTEGER,
		.data_type	= UVC_CTRL_DATA_TYPE_SIGNED,
		.master_id	= V4L2_CID_HUE_AUTO,
		.master_manual	= 0,
	},
	{
		.id		= V4L2_CID_SATURATION,
		.name		= "Saturation",
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_SATURATION_CONTROL,
		.size		= 16,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_INTEGER,
		.data_type	= UVC_CTRL_DATA_TYPE_UNSIGNED,
	},
	{
		.id		= V4L2_CID_SHARPNESS,
		.name		= "Sharpness",
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_SHARPNESS_CONTROL,
		.size		= 16,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_INTEGER,
		.data_type	= UVC_CTRL_DATA_TYPE_UNSIGNED,
	},
	{
		.id		= V4L2_CID_GAMMA,
		.name		= "Gamma",
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_GAMMA_CONTROL,
		.size		= 16,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_INTEGER,
		.data_type	= UVC_CTRL_DATA_TYPE_UNSIGNED,
	},
	{
		.id		= V4L2_CID_BACKLIGHT_COMPENSATION,
		.name		= "Backlight Compensation",
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_BACKLIGHT_COMPENSATION_CONTROL,
		.size		= 16,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_INTEGER,
		.data_type	= UVC_CTRL_DATA_TYPE_UNSIGNED,
	},
	{
		.id		= V4L2_CID_GAIN,
		.name		= "Gain",
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_GAIN_CONTROL,
		.size		= 16,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_INTEGER,
		.data_type	= UVC_CTRL_DATA_TYPE_UNSIGNED,
	},
	{
		.id		= V4L2_CID_POWER_LINE_FREQUENCY,
		.name		= "Power Line Frequency",
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_POWER_LINE_FREQUENCY_CONTROL,
		.size		= 2,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_MENU,
		.data_type	= UVC_CTRL_DATA_TYPE_ENUM,
		.menu_info	= power_line_frequency_controls,
		.menu_count	= ARRAY_SIZE(power_line_frequency_controls),
	},
	{
		.id		= V4L2_CID_HUE_AUTO,
		.name		= "Hue, Auto",
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_HUE_AUTO_CONTROL,
		.size		= 1,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_BOOLEAN,
		.data_type	= UVC_CTRL_DATA_TYPE_BOOLEAN,
		.slave_ids	= { V4L2_CID_HUE, },
	},
	{
		.id		= V4L2_CID_EXPOSURE_AUTO,
		.name		= "Exposure, Auto",
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_AE_MODE_CONTROL,
		.size		= 4,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_MENU,
		.data_type	= UVC_CTRL_DATA_TYPE_BITMASK,
		.menu_info	= exposure_auto_controls,
		.menu_count	= ARRAY_SIZE(exposure_auto_controls),
		.slave_ids	= { V4L2_CID_EXPOSURE_ABSOLUTE, },
	},
	{
		.id		= V4L2_CID_EXPOSURE_AUTO_PRIORITY,
		.name		= "Exposure, Auto Priority",
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_AE_PRIORITY_CONTROL,
		.size		= 1,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_BOOLEAN,
		.data_type	= UVC_CTRL_DATA_TYPE_BOOLEAN,
	},
	{
		.id		= V4L2_CID_EXPOSURE_ABSOLUTE,
		.name		= "Exposure (Absolute)",
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_EXPOSURE_TIME_ABSOLUTE_CONTROL,
		.size		= 32,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_INTEGER,
		.data_type	= UVC_CTRL_DATA_TYPE_UNSIGNED,
		.master_id	= V4L2_CID_EXPOSURE_AUTO,
		.master_manual	= V4L2_EXPOSURE_MANUAL,
	},
	{
		.id		= V4L2_CID_AUTO_WHITE_BALANCE,
		.name		= "White Balance Temperature, Auto",
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_WHITE_BALANCE_TEMPERATURE_AUTO_CONTROL,
		.size		= 1,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_BOOLEAN,
		.data_type	= UVC_CTRL_DATA_TYPE_BOOLEAN,
		.slave_ids	= { V4L2_CID_WHITE_BALANCE_TEMPERATURE, },
	},
	{
		.id		= V4L2_CID_WHITE_BALANCE_TEMPERATURE,
		.name		= "White Balance Temperature",
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_WHITE_BALANCE_TEMPERATURE_CONTROL,
		.size		= 16,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_INTEGER,
		.data_type	= UVC_CTRL_DATA_TYPE_UNSIGNED,
		.master_id	= V4L2_CID_AUTO_WHITE_BALANCE,
		.master_manual	= 0,
	},
	{
		.id		= V4L2_CID_AUTO_WHITE_BALANCE,
		.name		= "White Balance Component, Auto",
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_WHITE_BALANCE_COMPONENT_AUTO_CONTROL,
		.size		= 1,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_BOOLEAN,
		.data_type	= UVC_CTRL_DATA_TYPE_BOOLEAN,
		.slave_ids	= { V4L2_CID_BLUE_BALANCE,
				    V4L2_CID_RED_BALANCE },
	},
	{
		.id		= V4L2_CID_BLUE_BALANCE,
		.name		= "White Balance Blue Component",
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_WHITE_BALANCE_COMPONENT_CONTROL,
		.size		= 16,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_INTEGER,
		.data_type	= UVC_CTRL_DATA_TYPE_SIGNED,
		.master_id	= V4L2_CID_AUTO_WHITE_BALANCE,
		.master_manual	= 0,
	},
	{
		.id		= V4L2_CID_RED_BALANCE,
		.name		= "White Balance Red Component",
		.entity		= UVC_GUID_UVC_PROCESSING,
		.selector	= UVC_PU_WHITE_BALANCE_COMPONENT_CONTROL,
		.size		= 16,
		.offset		= 16,
		.v4l2_type	= V4L2_CTRL_TYPE_INTEGER,
		.data_type	= UVC_CTRL_DATA_TYPE_SIGNED,
		.master_id	= V4L2_CID_AUTO_WHITE_BALANCE,
		.master_manual	= 0,
	},
	{
		.id		= V4L2_CID_FOCUS_ABSOLUTE,
		.name		= "Focus (absolute)",
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_FOCUS_ABSOLUTE_CONTROL,
		.size		= 16,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_INTEGER,
		.data_type	= UVC_CTRL_DATA_TYPE_UNSIGNED,
		.master_id	= V4L2_CID_FOCUS_AUTO,
		.master_manual	= 0,
	},
	{
		.id		= V4L2_CID_FOCUS_AUTO,
		.name		= "Focus, Auto",
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_FOCUS_AUTO_CONTROL,
		.size		= 1,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_BOOLEAN,
		.data_type	= UVC_CTRL_DATA_TYPE_BOOLEAN,
		.slave_ids	= { V4L2_CID_FOCUS_ABSOLUTE, },
	},
	{
		.id		= V4L2_CID_IRIS_ABSOLUTE,
		.name		= "Iris, Absolute",
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_IRIS_ABSOLUTE_CONTROL,
		.size		= 16,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_INTEGER,
		.data_type	= UVC_CTRL_DATA_TYPE_UNSIGNED,
	},
	{
		.id		= V4L2_CID_IRIS_RELATIVE,
		.name		= "Iris, Relative",
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_IRIS_RELATIVE_CONTROL,
		.size		= 8,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_INTEGER,
		.data_type	= UVC_CTRL_DATA_TYPE_SIGNED,
	},
	{
		.id		= V4L2_CID_ZOOM_ABSOLUTE,
		.name		= "Zoom, Absolute",
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_ZOOM_ABSOLUTE_CONTROL,
		.size		= 16,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_INTEGER,
		.data_type	= UVC_CTRL_DATA_TYPE_UNSIGNED,
	},
	{
		.id		= V4L2_CID_ZOOM_CONTINUOUS,
		.name		= "Zoom, Continuous",
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_ZOOM_RELATIVE_CONTROL,
		.size		= 0,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_INTEGER,
		.data_type	= UVC_CTRL_DATA_TYPE_SIGNED,
		//.get		= uvc_ctrl_get_zoom,
		//.set		= uvc_ctrl_set_zoom,
	},
	{
		.id		= V4L2_CID_PAN_ABSOLUTE,
		.name		= "Pan (Absolute)",
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_PANTILT_ABSOLUTE_CONTROL,
		.size		= 32,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_INTEGER,
		.data_type	= UVC_CTRL_DATA_TYPE_SIGNED,
	},
	{
		.id		= V4L2_CID_TILT_ABSOLUTE,
		.name		= "Tilt (Absolute)",
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_PANTILT_ABSOLUTE_CONTROL,
		.size		= 32,
		.offset		= 32,
		.v4l2_type	= V4L2_CTRL_TYPE_INTEGER,
		.data_type	= UVC_CTRL_DATA_TYPE_SIGNED,
	},
	{
		.id		= V4L2_CID_PAN_SPEED,
		.name		= "Pan (Speed)",
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_PANTILT_RELATIVE_CONTROL,
		.size		= 16,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_INTEGER,
		.data_type	= UVC_CTRL_DATA_TYPE_SIGNED,
		//.get		= uvc_ctrl_get_rel_speed,
		//.set		= uvc_ctrl_set_rel_speed,
	},
	{
		.id		= V4L2_CID_TILT_SPEED,
		.name		= "Tilt (Speed)",
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_PANTILT_RELATIVE_CONTROL,
		.size		= 16,
		.offset		= 16,
		.v4l2_type	= V4L2_CTRL_TYPE_INTEGER,
		.data_type	= UVC_CTRL_DATA_TYPE_SIGNED,
		//.get		= uvc_ctrl_get_rel_speed,
		//.set		= uvc_ctrl_set_rel_speed,
	},
	{
		.id		= V4L2_CID_PRIVACY,
		.name		= "Privacy",
		.entity		= UVC_GUID_UVC_CAMERA,
		.selector	= UVC_CT_PRIVACY_CONTROL,
		.size		= 1,
		.offset		= 0,
		.v4l2_type	= V4L2_CTRL_TYPE_BOOLEAN,
		.data_type	= UVC_CTRL_DATA_TYPE_BOOLEAN,
	},
};

static unsigned int
uvc_test_bit(const uint8_t *data, int bit)
{
	return (data[bit >> 3] >> (bit & 7)) & 1;
}

static unsigned int
uvc_ctrl_calc_control_num(const uint8_t *bmControls, uint8_t bControlSize)
{
	int i = 0;
	unsigned int count = 0;
	const uint8_t *data = bmControls;

	if (data == NULL || bControlSize == 0)
		return 0;

	for (; i < bControlSize * 8; i++) {
		if ((data[i >> 3] >> (i & 7)) & 1)
			count++;
	}
	return count;
}
static int
__uvc_query_v4l2_ctrl(struct uvc_drv_video *video,
		      struct uvc_control *ctrl,
		      struct uvc_control_mapping *mapping,
		      struct v4l2_queryctrl *v4l2_ctrl)
{
	memset(v4l2_ctrl, 0, sizeof(*v4l2_ctrl));
	v4l2_ctrl->id = mapping->id;
	v4l2_ctrl->type = mapping->v4l2_type;
	strlcpy(v4l2_ctrl->name, mapping->name, sizeof(v4l2_ctrl->name));
	v4l2_ctrl->flags = 0;

	/*todo*/
	DPRINTF("WARNING __TO_BE_IMPLEMENT__ other par %s\n", __func__);

	return 0;
}

static void
__uvc_find_control(struct uvc_drv_entity *entity, uint32_t v4l2_id,
		   struct uvc_control_mapping **mapping,
		   struct uvc_control **control,
		   int next)
{
	struct uvc_control *ctrl = NULL;
	struct uvc_control_mapping *map = NULL, *tmp = NULL;
	unsigned int i;

	if (entity == NULL)
		return;

	for (i = 0; i < entity->ncontrols; ++i) {
		ctrl = &entity->controls[i];

		if (!ctrl->initialized)
			continue;

		STAILQ_FOREACH_SAFE(map, &ctrl->info.mappings, link, tmp) {
			if ((map->id == v4l2_id) && !next) {
				*control = ctrl;
				*mapping = map;
				return;
			}

			if ((*mapping == NULL || (*mapping)->id > map->id) &&
				(map->id > v4l2_id) && next) {
				*control = ctrl;
				*mapping = map;
			}
		}
	}
}

static struct uvc_control *
uvc_find_control(struct uvc_drv_ctrl *ctrls,
		 uint32_t v4l2_id,
		 struct uvc_control_mapping **mapping)
{
	struct uvc_control *ctrl = NULL;
	struct uvc_drv_entity *entity = NULL, *tmp = NULL;
	int next = v4l2_id & V4L2_CTRL_FLAG_NEXT_CTRL;

	*mapping = NULL;

	/* Mask the query flags. */
	v4l2_id &= V4L2_CTRL_ID_MASK;

	/* Find the control. */
	STAILQ_FOREACH_SAFE(entity, &ctrls->entities, link, tmp) {
		__uvc_find_control(entity, v4l2_id, mapping, &ctrl, next);
		if (ctrl && !next)
			return ctrl;
	}

	if (ctrl == NULL && !next)
		DPRINTF("Control 0x%08x not found.\n", v4l2_id);

	return ctrl;
}

static const uint8_t uvc_processing_guid[16] = UVC_GUID_UVC_PROCESSING;
static const uint8_t uvc_camera_guid[16] = UVC_GUID_UVC_CAMERA;
static const uint8_t uvc_media_transport_input_guid[16] =
					UVC_GUID_UVC_MEDIA_TRANSPORT_INPUT;

static int
uvc_entity_match_guid(const struct uvc_drv_entity *entity,
				 const uint8_t guid[16])
{
	switch (UVC_ENTITY_TYPE(entity)) {
	case UVC_ITT_CAMERA:
		return memcmp(uvc_camera_guid, guid, 16) == 0;

	case UVC_ITT_MEDIA_TRANSPORT_INPUT:
		return memcmp(uvc_media_transport_input_guid, guid, 16) == 0;

	case UDESCSUB_VC_PROCESSING_UNIT:
		return memcmp(uvc_processing_guid, guid, 16) == 0;

	case UDESCSUB_VC_EXTENSION_UNIT:
		return memcmp(entity->extension.guidExtensionCode,
			      guid, 16) == 0;

	default:
		return 0;
	}
}

static int
uvc_ctrl_add_info(struct uvc_control *ctrl, const struct uvc_control_info *info)
{
	int ret = 0;

	ctrl->info = *info;
	//INIT_LIST_HEAD(&ctrl->info.mappings);
	STAILQ_INIT(&ctrl->info.mappings);

	/* Allocate an array to save control values (cur, def, max, etc.) */
	ctrl->uvc_data = malloc(ctrl->info.size * UVC_CTRL_DATA_LAST + 1,
				M_UVC, M_ZERO | M_WAITOK);
	if (ctrl->uvc_data == NULL) {
		ret = ENOMEM;
		goto done;
	}
	ctrl->initialized = 1;

done:
	if (ret < 0)
		free(ctrl->uvc_data, M_UVC);
	return ret;
}

static void *
uvc_memdup(const void *src, size_t len)
{
	void *dst;

	dst = malloc(len, M_UVC, M_ZERO | M_WAITOK);
	if (dst != NULL)
		memcpy(dst, src, len);
	return dst;
}

static int
__uvc_ctrl_add_mapping(struct uvc_control *ctrl,
		       const struct uvc_control_mapping *mapping)
{
	struct uvc_control_mapping *map;
	unsigned int size;

	map = uvc_memdup(mapping, sizeof(*mapping));
	if (map == NULL)
		return ENOMEM;

	if (mapping->menu_info && mapping->menu_count != 0) {
		size = sizeof(*mapping->menu_info) * mapping->menu_count;
		map->menu_info = uvc_memdup(mapping->menu_info, size);
		if (map->menu_info == NULL) {
			free(map, M_UVC);
			return ENOMEM;
		}
	}
	/*todo*/
	//if (map->get == NULL)
	//	map->get = uvc_get_le_value;
	//if (map->set == NULL)
	//	map->set = uvc_set_le_value;

	STAILQ_INSERT_TAIL(&ctrl->info.mappings, map, link);

	DPRINTF("Adding mapping '%s' to control %pUl/%u.\n",
		map->name, ctrl->info.entity, ctrl->info.selector);

	return 0;
}


static void
uvc_ctrl_init_ctrl(struct uvc_softc *sc, struct uvc_drv_ctrl *ctrls,
		   struct uvc_control *ctrl)
{
	const struct uvc_control_info *info = uvc_ctrls;
	const struct uvc_control_info *iend = info + ARRAY_SIZE(uvc_ctrls);
	const struct uvc_control_mapping *mapping = uvc_ctrl_mappings;
	const struct uvc_control_mapping *mend =
				mapping + ARRAY_SIZE(uvc_ctrl_mappings);

	/*like linux does*/
	if (UVC_ENTITY_TYPE(ctrl->entity) == UDESCSUB_VC_EXTENSION_UNIT)
		return;

	for (; info < iend; ++info) {
		if (uvc_entity_match_guid(ctrl->entity, info->entity) &&
		    ctrl->index == info->index) {
			uvc_ctrl_add_info(ctrl, info);
			break;
		}
	}

	if (!ctrl->initialized)
		return;

	for (; mapping < mend; ++mapping) {
		if (uvc_entity_match_guid(ctrl->entity, mapping->entity) &&
		    ctrl->info.selector == mapping->selector) {
			__uvc_ctrl_add_mapping(ctrl, mapping);
		}
	}
}

int
uvc_ctrl_init_device(struct uvc_softc *sc, struct uvc_drv_ctrl *ctrls)
{
	struct uvc_drv_entity *entity, *tmp;
	struct uvc_control *ctrl = NULL;
	unsigned int bControlSize = 0, ncontrols = 0;
	uint8_t *bmControls = NULL;

	if (!ctrls) {
		return EINVAL;
	}

	STAILQ_FOREACH_SAFE(entity, &ctrls->entities, link, tmp) {
		unsigned int i = 0;

		if (UVC_ENTITY_TYPE(entity) == UDESCSUB_VC_EXTENSION_UNIT) {
			bmControls = entity->extension.bmControls;
			bControlSize = entity->extension.bControlSize;
		} else if (UVC_ENTITY_TYPE(entity) ==
			   UDESCSUB_VC_PROCESSING_UNIT) {
			bmControls = entity->processing.bmControls;
			bControlSize = entity->processing.bControlSize;
		} else if (UVC_ENTITY_TYPE(entity) == UVC_ITT_CAMERA) {
			bmControls = entity->camera.bmControls;
			bControlSize = entity->camera.bControlSize;
		} else
			continue;

		ncontrols = uvc_ctrl_calc_control_num(bmControls, bControlSize);
		if (ncontrols == 0)
			continue;
		entity->controls = malloc(ncontrols * sizeof(*ctrl),
					  M_UVC, M_ZERO | M_WAITOK);
		if (!entity->controls)
			return ENOMEM;
		entity->ncontrols = ncontrols;

		ctrl = entity->controls;
		for (; i < bControlSize * 8; i++) {
			if (uvc_test_bit(bmControls, i) == 0)
				continue;
			ctrl->entity = entity;
			ctrl->index = i;
			uvc_ctrl_init_ctrl(sc, ctrls, ctrl);
			ctrl++;
		}
	}

	return 0;
}

void
uvc_ctrl_cleanup_mappings(struct uvc_control *ctrl)
{
	struct uvc_control_mapping *mapping, *tmp;

	if (!ctrl)
		return;

	STAILQ_FOREACH_SAFE(mapping, &ctrl->info.mappings, link, tmp) {
	DPRINTF("removing mapping '%s' to control %pUl/%u.\n",
		mapping->name, ctrl->info.entity, ctrl->info.selector);
		if (mapping->menu_info)
			free((void *)mapping->menu_info, M_UVC);
		free(mapping, M_UVC);
	}
}

int
uvc_query_v4l2_ctrl(struct uvc_drv_video *video,
		    struct v4l2_queryctrl *v4l2_ctrl)
{
	struct uvc_control *ctrl;
	struct uvc_control_mapping *mapping;
	int ret = EINVAL;

	mtx_lock(&video->ctrl->mtx);

	ctrl = uvc_find_control(video->ctrl, v4l2_ctrl->id, &mapping);
	if (ctrl == NULL) {
		ret = EINVAL;
		goto done;
	}

	ret = __uvc_query_v4l2_ctrl(video, ctrl, mapping, v4l2_ctrl);
done:
	mtx_unlock(&video->ctrl->mtx);
	return ret;
}


