# Firefox VA-API on X11 with AMD/NVIDIA GPUs

## Findings

The current evidence confirms that Firefox is using the software VP9 decoder
(`ffvpx`, `RequestDecode sw,vp9`). `about:support` reports the hardware-decoding
probe failed. Wodan has an AMD render node selected for VA-API while Firefox's
WebRender uses the NVIDIA GPU. The AMD `vainfo` check succeeds, so the VA-API
driver can initialize outside Firefox.

X11 alone should not disable VA-API in this Firefox version. Mozilla fixed an
X11-only build that skipped the hardware-decoding probe in Firefox 117; the
historical bug is a poor fit for Firefox 153.5.0esr.
[Mozilla bug 1843425](https://bugzilla.mozilla.org/show_bug.cgi?id=1843425)

A closer version-era match is a separate AMD/Mesa DMA-BUF regression introduced
in Firefox 152. Firefox could initialize VA-API, then fail while importing
decoded surfaces (`EGL_BAD_MATCH`); Mozilla marked the fix present in Firefox
153 and 154. The report's GPU-specific detail was Polaris, so it is not yet
proof of Wodan's failure. Bugzilla does not state whether the fix was included
in the ESR 153 branch, so the `153.5.0esr` version string alone cannot settle
that.
[Mozilla bug 2052037](https://bugzilla.mozilla.org/show_bug.cgi?id=2052037),
[fix commit](https://github.com/mozilla-firefox/firefox/commit/1320500719b3)

The AMD-decoder/NVIDIA-renderer split is another plausible failure point:
Firefox exports decoded frames through DMA-BUF, and Mozilla notes that different
GPUs must support compatible buffer modifiers for cross-GPU import. This is a
hypothesis for Wodan, not a demonstrated root cause.
[Mozilla bug 1738545](https://bugzilla.mozilla.org/show_bug.cgi?id=1738545)

This split is present in Wodan's configuration: `LIBVA_DRIVER_NAME=radeonsi` and
`MOZ_DRM_DEVICE` point Firefox at the AMD render node, while `about:support`
identifies the NVIDIA RTX 4070 Ti as the active WebRender GPU. Mozilla's
guidance for this setup is to use the same GPU for WebRender and VA-API. This
makes the forced AMD decode device a stronger lead than X11 itself.
[Mozilla bug 1835504](https://bugzilla.mozilla.org/show_bug.cgi?id=1835504)

NixOS already enables `hardware.nvidia.videoAcceleration` by default and
installs `nvidia-vaapi-driver`; Wodan's global `LIBVA_DRIVER_NAME=radeonsi`
selects the AMD implementation instead. The Firefox ESR desktop entry now
overrides that environment only for Firefox, and the NVIDIA workstation
preferences set `gfx.x11-egl.force-enabled`.
[NixOS NVIDIA module](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/hardware/video/nvidia.nix),
[nvidia-vaapi-driver README](https://github.com/elFarto/nvidia-vaapi-driver)

A stale user-local `~/.local/share/applications/firefox-esr.desktop` was
shadowing the Home Manager desktop entry. It was moved to
`firefox-esr.desktop.backup-2026-10-22`, and `xdg-mime` now resolves HTTPS to
`firefox-esr.desktop` from the profile.

There is a material sandbox caveat: the NVIDIA VA-API driver's README lists
`MOZ_DISABLE_RDD_SANDBOX=1` for Firefox. This disables the sandbox for Firefox's
remote decoder process. The README also calls the direct backend experimental
and warns that it uses an unstable NVIDIA interface.
[nvidia-vaapi-driver README](https://github.com/elFarto/nvidia-vaapi-driver)

Firefox's newer Vulkan video decoder is another future path for recent NVIDIA
cards, but Mozilla's enablement work targets Firefox 156 Nightly. It is not a
verified workaround for the installed Firefox ESR 153.5.
[Mozilla bug 2045970](https://bugzilla.mozilla.org/show_bug.cgi?id=2045970)

The fresh Firefox log confirms the current AV1 path: Firefox recognizes AV1 as a
hardware codec and loads `nvidia_drv_video.so`, but the driver initialization
fails (`vaInitialize failed`, `Failed to create VA-API device context`). Firefox
then reports `IsHardwareAccelerated=false` and selects the software `libdav1d`
decoder. This is consistent with the NVIDIA VA-API driver requiring access
outside Firefox's RDD sandbox, but the generic initialization error does not
prove sandbox denial by itself. The driver README lists
`MOZ_DISABLE_RDD_SANDBOX=1`; treat that as a security-affecting diagnostic, not
a routine preference.

A one-time test with `MOZ_DISABLE_RDD_SANDBOX=1` confirmed the cause: NVIDIA
VA-API initialized successfully, AV1 was marked accelerated, and Firefox
reported `IsHardwareAccelerated=true`. The desktop entry applies the setting
only to Firefox and its quick actions; other applications keep their current
environment. Firefox launched from a shell does not receive this override.

## Applying and testing the change

After `just switch`, fully exit Firefox and start it from the desktop entry so
it receives the NVIDIA environment and sandbox override. Check `about:support`
for `HARDWARE_VIDEO_DECODING`; YouTube's `Codecs` field only identifies the
stream codec. Firefox launched from a shell deliberately does not receive the
sandbox override, so that launch will not use this NVIDIA VA-API path.

The one-time unsandboxed test already confirmed AV1 hardware decoding. If it
regresses after activation, capture a new log through the desktop entry before
changing any other setting. Review logs before sharing them because they can
contain signed video URLs and other session details.
[Mozilla logging guidance](https://firefox-source-docs.mozilla.org/xpcom/logging.html)
