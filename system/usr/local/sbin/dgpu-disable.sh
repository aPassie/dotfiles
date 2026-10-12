#!/bin/bash
# Tear the dGPU back down to the pristine powered-off state, from EITHER mode.
#
#   1) Refuse ONLY if a real CUDA compute job is running -- identified by an
#      open /dev/nvidia-uvm (UVM is CUDA-specific). In DISPLAY mode the
#      compositor (niri) and GL/Vulkan apps (browsers, ...) legitimately hold
#      /dev/nvidia0 + /dev/nvidiactl; those are graphics users, not CUDA, and
#      are force-released by the hot-unplug in step 2 -- so they must NOT block.
#   2) DISPLAY-mode release: hot-remove the dGPU from the PCI tree. That fires a
#      DRM hot-unplug; niri drops the card via its udev "remove" handler (NO
#      relogin needed) and the nvidia driver unbinds.
#      SAFETY GUARD: the hot-remove blocks in D-state and HANGS (~8min, survives
#      SIGKILL) if a live compositor still holds the dGPU's DRM node. So we do it
#      ONLY when nothing holds the card -- i.e. at logout, after niri has exited
#      (dgpu-power-off.service is ordered to stop After niri). Mid-session we
#      refuse cleanly instead of wedging the kernel.
#   3) Unload the nvidia stack -- BEST EFFORT. A GPU app may keep a stale fd open
#      after the hot-unplug and pin a module; that must never keep the power rail
#      energised, so we log it and carry on to the rail-off regardless.
#   4) Rail-off (disable-nvidia-dgpu.sh) -- removes the bridge + ACPI power-off.
#      This is what actually drops the rail to ~0W, with or without lingering
#      resident modules (they're inert once the device is gone).
set -u

DGPU="0000:01:00.0"
DGPU_AUDIO="0000:01:00.1"

DISPLAY_MODE=0
lsmod | grep -q '^nvidia_drm' && DISPLAY_MODE=1

# 1. Refuse on an active CUDA job (open /dev/nvidia-uvm) in EITHER mode.
if command -v fuser >/dev/null 2>&1 && [ -e /dev/nvidia-uvm ]; then
    if fuser -s /dev/nvidia-uvm 2>/dev/null; then
        echo "ERROR: dGPU is running a CUDA job (/dev/nvidia-uvm in use); stop it first." >&2
        logger -t dgpu-disable "refused: /dev/nvidia-uvm in use (CUDA job)"
        exit 1
    fi
fi
# In COMPUTE mode (no display stack), also refuse if the control nodes are held
# -- that's a GPU app we shouldn't yank. In DISPLAY mode those are expected.
if [ "$DISPLAY_MODE" -eq 0 ] && command -v fuser >/dev/null 2>&1; then
    for n in /dev/nvidia0 /dev/nvidiactl; do
        [ -e "$n" ] || continue
        if fuser -s "$n" 2>/dev/null; then
            echo "ERROR: dGPU is in use by a running process; close it first." >&2
            logger -t dgpu-disable "refused: ${n} in use"
            exit 1
        fi
    done
fi

# 2. Display-mode release: hot-remove the dGPU PCI functions (DRM hot-unplug).
if [ "$DISPLAY_MODE" -eq 1 ]; then
    # SAFETY GUARD (Finding 4): a PCI hot-remove blocks in D-state and HANGS
    # (~8min, survives SIGKILL) if a live compositor still holds the dGPU's DRM
    # card/render node. Only remove once nothing holds it -- i.e. at logout,
    # after niri has exited and released the card. Mid-session (niri alive,
    # holding the card) refuse cleanly. Blanking the output + Runtime D3 already
    # idles the dGPU to ~0W in-session, so nothing is lost by deferring.
    drm_nodes=""
    for n in /sys/bus/pci/devices/${DGPU}/drm/card* /sys/bus/pci/devices/${DGPU}/drm/renderD*; do
        [ -e "$n" ] && drm_nodes="${drm_nodes} /dev/dri/$(basename "$n")"
    done
    if [ -n "${drm_nodes}" ] && command -v fuser >/dev/null 2>&1 && fuser -s ${drm_nodes} 2>/dev/null; then
        echo "ERROR: dGPU display is still held by the compositor; refusing in-session hot-remove (it would hang the kernel ~8min). Blank the output (Runtime D3 idles it to ~0W); it powers off fully at logout." >&2
        logger -t dgpu-disable "refused: display-mode hot-remove while DRM nodes held (${drm_nodes} ) -- would hang; deferring to logout"
        exit 1
    fi
    logger -t dgpu-disable "display mode: hot-removing ${DGPU} to release niri's DRM card"
    for dev in "$DGPU_AUDIO" "$DGPU"; do
        [ -e "/sys/bus/pci/devices/${dev}/remove" ] && \
            echo 1 > "/sys/bus/pci/devices/${dev}/remove" 2>/dev/null || true
    done
    # Wait for the dGPU to leave the PCI tree (niri processes the udev remove and
    # closes its card fd during this window). Capped ~10s.
    for _ in $(seq 1 50); do
        [ -e "/sys/bus/pci/devices/${DGPU}" ] || break
        sleep 0.2
    done
fi

# 3. Best-effort unload. drm/modeset first (releasable after the hot-unplug),
#    then core + uvm, retrying while the RM quiesces and fds drop. ~15s cap.
modprobe -r nvidia_drm nvidia_modeset 2>/dev/null || true
for _ in $(seq 1 30); do
    modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia 2>/dev/null || true
    lsmod | grep -qE '^nvidia ' || break
    sleep 0.5
done
if lsmod | grep -qE '^nvidia '; then
    # Not fatal: the device is (or is about to be) gone; resident modules are
    # inert and cost no power. The rail-off below is what matters.
    held=$(lsmod | grep -E '^nvidia' | awk '{print $1"="$3}' | tr '\n' ' ')
    logger -t dgpu-disable "note: nvidia modules linger after unload (app holds a stale fd?): ${held} -- proceeding to rail-off"
fi

# 4. Rail-off regardless. If we already removed the dGPU above, the device-remove
#    writes in disable-nvidia-dgpu.sh are guarded no-ops; it still removes the
#    bridge and runs the ACPI power-off that drops the rail.
# Tell the rail-off guard this is a deliberate teardown: the device is already
# released, so it must proceed even if nvidia modules are still resident.
export DGPU_TEARDOWN=1
exec /usr/local/sbin/disable-nvidia-dgpu.sh
