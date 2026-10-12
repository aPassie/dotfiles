#!/bin/bash
# Disable NVIDIA dGPU rail on Lenovo Legion Slim 5 16APH8 (RTX 4060 Mobile).
#
# Race-free rewrite (2026-06): the previous version backgrounded the bridge
# removal and then immediately ran the ACPI power-off, so PG00._OFF raced the
# bridge teardown -- on the boots it lost, the rail stayed energized (~24W
# instead of ~9W). Two changes fix that:
#   (a) WAIT for the bridge to actually leave the PCI tree before the ACPI
#       power-off (capped, so a stuck removal never blocks boot), and
#   (b) VERIFY the rail is off (PG00._STA==0) and RETRY the sequence if not.
#
# Power-off path on this board (unchanged, validated by DSDT analysis):
#   _DSM(Optimus, fn 0x1A, FLCH=1 OMPR=3) sets OPCE=3, then PEGP._PS3 takes the
#   OPCE==3 branch -> PG00._OFF runs DL23 + SGPC(0), M239=0 -> rail genuinely off.
#
# Order is critical: PCI removal MUST happen while the link is still up.
# Running _PS3 first puts the link in L2/L3, after which /sys/.../remove writes
# hang in D-state forever and block boot -- hence remove-then-power-off.
#
# HDMI port is wired through the dGPU and is dead after this. USB-C/DP-Alt is
# on a different bridge (00:08.x) and still works.

set -u

BRIDGE="0000:00:01.1"
DGPU="0000:01:00.0"
DGPU_AUDIO="0000:01:00.1"

DSM_SET_OPCE3='\_SB.PCI0.GPP0.PEGP._DSM {0xf8,0xd8,0x86,0xa4,0xda,0x0b,0x1b,0x47,0xa7,0x2b,0x60,0x42,0xa6,0xb5,0xbe,0xe0} 0x102 0x1A {0x01,0x00,0x00,0x03}'
PEGP_PS3='\_SB.PCI0.GPP0.PEGP._PS3'
PG00_STA='\_SB.PCI0.GPP0.PG00._STA'

acpi() { echo "$1" > /proc/acpi/call; tr -d '\0' < /proc/acpi/call; }

# --- SAFETY GUARD (added 2026-08-16) ----------------------------------------
# This script PCI-hot-removes the dGPU. That is only safe when nothing has the
# device open. The systemd system-sleep hook runs it unconditionally on EVERY
# resume, so if the dGPU was driving the HDMI output across the suspend, niri
# still holds /dev/dri/card0 on it and nv_pci_remove_helper deadlocks in
# unkillable D-state. The card is deleted out from under the compositor and
# BOTH screens stay black until a reboot. Observed 2026-08-16:
#   nv_pci_remove_helper+0x19c ... task disable-nvidia- blocked for 245 seconds
#   niri: error clearing drm surface: /dev/dri/card0 (deleted), No such device
#
# Boot is unaffected: there the nvidia modules are not loaded and
# dgpu-display.service is inactive, so the guard passes and the rail is powered
# off exactly as before (~9.9W idle preserved).
#
# When the guard DOES trip, power is not lost: with the modules loaded, the
# dGPU's fine-grained Runtime D3 suspends it to ~0W (D3cold) on its own.
dgpu_in_use() {
    # An explicit teardown (dgpu-disable.sh) has already released the device and
    # NEEDS the rail-off to run even if modules linger -- resident modules are
    # inert once the device is gone, but an energised rail costs ~15W. Never
    # block that path.
    [ "${DGPU_TEARDOWN:-0}" = "1" ] && return 1
    # Nothing to hot-remove if the device is already out of the PCI tree; the
    # remaining work is bridge removal + ACPI power-off, which is always safe.
    [ -e "/sys/bus/pci/devices/${DGPU}" ] || return 1
    # The display service explicitly owns the dGPU right now.
    systemctl is-active --quiet dgpu-display.service && return 0
    # Or the nvidia driver is loaded and something holds a reference to it
    # (nvidia_drm driving a display, or a CUDA client). Yanking the PCI device
    # from under either is what deadlocks.
    # NOTE: do NOT use /sys/module/nvidia/refcnt here. nvidia-utils' udev rule
    # (60-nvidia.rules) runs `nvidia-modprobe -u` the moment nvidia binds, which
    # loads nvidia_uvm and bumps refcnt to 1 with nobody actually using the GPU.
    # That raced the boot-time rail-off on 2026-09-07 and left the dGPU on.
    # Real users are: the KMS stack (nvidia_drm) or a process with /dev/nvidia*
    # open (CUDA client, Chrome's GPU process, ...).
    [ -d /sys/module/nvidia_drm ] && return 0
    if command -v fuser >/dev/null 2>&1; then
        fuser -s /dev/nvidia0 /dev/nvidiactl /dev/nvidia-uvm 2>/dev/null && return 0
    fi
    # Idle: drop the inert helper module so the PCI remove is clean.
    modprobe -r nvidia_uvm 2>/dev/null || true
    return 1
}

if dgpu_in_use; then
    logger -t disable-nvidia-dgpu "SKIP: dGPU in use (display/compute active) - refusing hot-remove; D3cold handles power"
    exit 0
fi

# 1. acpi_call must be available for the power-off.
[ -e /proc/acpi/call ] || modprobe acpi_call 2>/dev/null || true

# 2. Unbind PCIe port services on the bridge (kernel 7.0+: pci_express bus).
for svc in /sys/bus/pci_express/devices/${BRIDGE}:pcie*; do
    [ -e "$svc" ] || continue
    drv=$(readlink -f "$svc/driver" 2>/dev/null || true)
    if [ -n "$drv" ] && [ -d "$drv" ]; then
        echo "$(basename "$svc")" > "$drv/unbind" 2>/dev/null || true
    fi
done

# 3. Remove from PCI tree while link is up: audio -> dGPU (foreground).
for dev in "$DGPU_AUDIO" "$DGPU"; do
    [ -e "/sys/bus/pci/devices/${dev}/remove" ] && \
        echo 1 > "/sys/bus/pci/devices/${dev}/remove" 2>/dev/null || true
done

# Bridge runtime PM (cosmetic).
[ -e "/sys/bus/pci/devices/${BRIDGE}/power/wakeup" ]  && echo disabled > "/sys/bus/pci/devices/${BRIDGE}/power/wakeup"
[ -e "/sys/bus/pci/devices/${BRIDGE}/power/control" ] && echo auto     > "/sys/bus/pci/devices/${BRIDGE}/power/control"

# 3b. Remove the bridge. Backgrounded+disowned so a stuck teardown can never
#     block boot -- but we then WAIT (capped at 8s) for it to actually go away
#     before the power-off. This wait is the race fix.
if [ -e "/sys/bus/pci/devices/${BRIDGE}/remove" ]; then
    ( echo 1 > "/sys/bus/pci/devices/${BRIDGE}/remove" 2>/dev/null || true ) &
    disown 2>/dev/null || true
fi
for _ in $(seq 1 40); do
    [ -e "/sys/bus/pci/devices/${BRIDGE}" ] || break
    sleep 0.2
done

logger -t disable-nvidia-dgpu "removed ${DGPU_AUDIO} + ${DGPU} + ${BRIDGE} (bridge gone: $([ -e /sys/bus/pci/devices/${BRIDGE} ] && echo no || echo yes))"

# 4. Optimus power-off, then verify PG00._STA==0; retry the sequence if not.
#    (_STA is read via an ACPI method eval -- it does NOT wake the PCI device,
#    unlike reading /sys/.../power_state.)
if [ ! -e /proc/acpi/call ]; then
    logger -t disable-nvidia-dgpu "ERROR: acpi_call unavailable, cannot power off rail"
    exit 0
fi

railoff=0
for attempt in 1 2 3 4 5; do
    rc_dsm=$(acpi "$DSM_SET_OPCE3")
    rc_ps3=$(acpi "$PEGP_PS3")
    sleep 1
    sta=$(acpi "$PG00_STA")
    if [ "$sta" = "0x0" ] || [ "$sta" = "0" ]; then railoff=1; break; fi
    sleep 1
done

logger -t disable-nvidia-dgpu "attempt=${attempt} PG00._STA=${sta} DSM=${rc_dsm} PS3=${rc_ps3} railoff=${railoff}"
exit 0
