#!/bin/bash
# Pin power-profiles-daemon to power-saver, then disable global CPU boost.
#
# Order matters on AMD: PPD writes per-policy boost (/sys/.../policyN/boost)
# at startup. If global cpufreq/boost is 0 when PPD initializes, those writes
# return EINVAL and PPD fails to apply *any* profile. So:
#   1. Wait for PPD to finish initializing (boost still 1 here)
#   2. Switch PPD to power-saver
#   3. Then clear global boost.
# Side effect: with global boost off, PPD can no longer switch to balanced
# or performance — system is locked to power-saver. That is intentional.
set -u

# Give PPD a moment after its service "started" signal — it does its
# per-policy boost writes asynchronously.
sleep 2

if command -v powerprofilesctl >/dev/null 2>&1; then
    powerprofilesctl set power-saver || true
fi

# Force EPP=power on every cpufreq policy (PPD on AMD doesn't always set
# EPP itself — amd-pstate-epp respects the file).
for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
    [ -w "$f" ] && echo power > "$f" 2>/dev/null || true
done

# Now turn off global boost.
[ -w /sys/devices/system/cpu/cpufreq/boost ] && \
    echo 0 > /sys/devices/system/cpu/cpufreq/boost

logger -t disable-cpu-boost "profile=power-saver EPP=power boost=0"
