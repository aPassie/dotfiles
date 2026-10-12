#!/bin/bash
# Bring the dGPU up as a DISPLAY device (external monitor via dGPU-wired HDMI).
# Rail-on + rescan (compute path), then FORCE-load the KMS stack past the
# compute-mode install-block so nvidia_drm registers a card niri can use.
#
# IMPORTANT: niri enumerates GPUs at startup; log out / back in after this for
# the external display to be adopted. The launcher prompts for it.
set -u

/usr/local/sbin/dgpu-enable-compute.sh || exit 1

# --ignore-install bypasses the `install ... /bin/true` block from
# nvidia-dgpu-compute.conf. Load modeset first (drm depends on it).
modprobe --ignore-install nvidia_modeset && \
modprobe --ignore-install nvidia_drm modeset=1
rc=$?
logger -t dgpu-enable "display: force-load nvidia_drm modeset=1 rc=${rc}"
exit $rc
