# Functionality in uvc/ missing from uvideo/

High-value ports

1. SS companion descriptor in alt-setting selection
uvc/ reads UDESC_ENDPOINT_SS_COMP and uses wBytesPerInterval for SuperSpeed
endpoint bandwidth. video/ ignores this entirely, which will select the wrong
alt-setting on USB 3.x cameras.

2. Probe/commit retry loop with quality adjustment
uvc_drv_probe_video() does up to 2 iterations — after a failed probe it adjusts
wKeyFrameRate, wPFrameRate, wCompQuality from GET_MIN/MAX results and retries.
video/ does a single SET+GET with no retry.

3. GET_DEF fallback in init
uvc_drv_init_video() tries GET_DEF first, falls back to GET_CUR on failure
(workaround for Logitech C922 Pro). video/ uses only GET_CUR.

4. Error frame tracking across isochronous packets
uvc/ sets v->bad_frame on UVC_PL_HEADER_BIT_ERR and discards the entire
in-progress frame via uvc_buf_reset_buf(). video/ sets fb->error but does not
track cross-packet state.

5. Bulk endpoint CLEAR_HALT / LED-off on stop
uvc_drv_stop_video() sends UR_CLEAR_FEATURE / UF_ENDPOINT_HALT explicitly to
turn off the camera LED (documented as mimicking Windows). video/ only calls
usbd_transfer_unsetup().

6. Extension Unit (XU) support
uvc/uvc_drv.h defines uvc_vc_extension_unit_desc and uvc_v4l2.c implements
UVCIOC_CTRL_QUERY / UVCIOC_CTRL_MAP for raw GET/SET requests to XUs. video/ has
no XU parsing or ioctls at all. This is needed for vendor-specific camera
controls (e.g. Logitech BRIO H.264 mode switching via v->htsf).

7. Selector unit parsing
uvc/uvc_drv.h defines uvc_vc_selector_unit_desc; video/uvideo.c ignores
selector units entirely.

8. Interrupt endpoint infrastructure
uvc_intr_callback() and uvc_intr_config[] exist for the UVC status interrupt
endpoint (asynchronous control update notifications). Currently dead code in
uvc/, but the structure is there. video/ has nothing.

# Functionality in uvc/ missing from video(4)

1. VIDIOC_QUERYMENU
uvc/ routes this to uvc_query_v4l2_menu() in uvc_ctrls.c, supporting menu
enumeration for power-line frequency and exposure-auto mode. video/ has no handler.

2. VIDIOC_CROPCAP / VIDIOC_G_SELECTION
uvc/uvc_v4l2.c implements both. video/ has neither.

3. VIDIOC_G_PRIORITY / VIDIOC_S_PRIORITY — defined in videoio.h but not handled
   in video.c

4. UVCIOC_CTRL_QUERY / UVCIOC_CTRL_MAP — no extension unit passthrough path
