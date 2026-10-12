#!/bin/bash
# Bring the NVIDIA dGPU online for HEADLESS CUDA compute (no display path).
#
# Reverses /usr/local/sbin/disable-nvidia-dgpu.sh:
#   PG00._ON re-energises the rail (the ACPI spec REQUIRES _ON on any
#   PowerResource, and the disable script proves PG00 is one), PEGP._PS0 puts
#   the device in D0, then a PCI rescan re-enumerates the bridge + dGPU + its
#   audio function. We load ONLY nvidia + nvidia_uvm -- deliberately NOT
#   nvidia_drm/modeset -- so amdgpu/niri and the display are never touched.
# Self-verifying with retries, in the same defensive spirit as the disable side.
set -u

BRIDGE="0000:00:01.1"
DGPU="0000:01:00.0"

PG00_ON='\_SB.PCI0.GPP0.PG00._ON'
PEGP_PS0='\_SB.PCI0.GPP0.PEGP._PS0'
PG00_STA='\_SB.PCI0.GPP0.PG00._STA'

acpi() { echo "$1" > /proc/acpi/call; tr -d '\0' < /proc/acpi/call; }
present() { [ -e "/sys/bus/pci/devices/${DGPU}" ]; }

[ -e /proc/acpi/call ] || modprobe acpi_call 2>/dev/null || true
if [ ! -e /proc/acpi/call ]; then
    echo "ERROR: acpi_call unavailable, cannot power on the rail" >&2
    logger -t dgpu-enable "ERROR: acpi_call unavailable"
    exit 1
fi

attempt=0
for attempt in 1 2 3 4 5; do
    present && break
    acpi "$PG00_ON"  >/dev/null
    acpi "$PEGP_PS0" >/dev/null
    sleep 0.3
    echo 1 > /sys/bus/pci/rescan 2>/dev/null || true
    for _ in $(seq 1 25); do present && break; sleep 0.2; done
    present && break
    sleep 0.5
done

sta=$(acpi "$PG00_STA")
if ! present; then
    echo "ERROR: dGPU did not enumerate after rescan (PG00._STA=${sta})" >&2
    logger -t dgpu-enable "FAILED: ${DGPU} absent after rescan (PG00._STA=${sta}, attempt=${attempt})"
    exit 1
fi

# Compute modules only. modprobe binds to the now-present PCI device.
modprobe nvidia && modprobe nvidia_uvm
rc=$?
logger -t dgpu-enable "compute: dGPU present, PG00._STA=${sta}, attempt=${attempt}, modprobe rc=${rc}"
exit $rc
