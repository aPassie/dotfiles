#!/bin/bash
# Refreshes this repository from the live system: copies every file the desktop setup owns out
# of $HOME (and the hardware files out of /etc and /usr/local) into the repo, leaving out
# anything private. Run it, look at `git diff`, commit.
#
#   tools/sync-from-home.sh
#
# What is deliberately NOT copied: see "Not in this repository" in README.md.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

# Start the mirrored trees from scratch so files deleted at home disappear here too.
rm -rf .config .local system claude

cpf() { # cpf <path relative to $HOME> : copy a file or folder if it exists
    local p
    for p in "$@"; do
        [ -e "$HOME/$p" ] || { echo "skip (absent): $p"; continue; }
        mkdir -p "$(dirname "$p")"
        cp -a --no-preserve=ownership "$HOME/$p" "$(dirname "$p")/"
    done
}

# ── compositor, lock, idle ──────────────────────────────────────────────────
cpf .config/niri/config.kdl .config/niri/config.d .config/hypr
# ── the glass shell (Quickshell) ────────────────────────────────────────────
cpf .config/quickshell/ii .config/illogical-impulse/config.json
# ── Dolphin's isolated pitch-black theme ────────────────────────────────────
cpf .config/dolphin-macos/glass.qss .config/dolphin-macos/glass-icons .config/dolphin-macos/Kvantum \
    .config/dolphin-macos/kdeglobals .config/dolphin-macos/mimeapps.list \
    .config/dolphin-macos/glass-shim/glass-shim.cpp .config/dolphin-macos/glass-shim/build.sh \
    .config/dolphinrc .local/share/kxmlgui5/dolphin/dolphinui.rc \
    .local/share/kio/servicemenus/glass-quicklook.desktop \
    .local/share/dbus-1/services/org.freedesktop.FileManager1.service \
    .local/share/applications/org.kde.dolphin.desktop
# ── Qt / GTK look ───────────────────────────────────────────────────────────
cpf .config/kdeglobals .config/darklyrc .config/qt6ct .local/share/color-schemes/GlassBlack.colors \
    .config/gtk-3.0/gtk.css .config/gtk-3.0/settings.ini .config/gtk-4.0/gtk.css .config/gtk-4.0/settings.ini \
    .config/environment.d .config/fontconfig .local/share/fonts/outfit
# ── portals, defaults, session ──────────────────────────────────────────────
cpf .config/xdg-desktop-portal .config/mimeapps.list .config/user-dirs.dirs \
    .config/autostart/localsearch-3.desktop
# ── terminal, shell, apps ───────────────────────────────────────────────────
cpf .config/foot .config/fish/config.fish .config/fish/conf.d .config/fish/fish_plugins \
    .config/zathura .config/mpv/mpv.conf .config/zed/settings.json .config/btop/btop.conf .config/btop/themes \
    .config/chrome-flags.conf .config/brave-origin-beta-flags.conf
# ── keyboard remap + push-to-talk dictation ─────────────────────────────────
cpf .config/xremap .local/bin/ptt .local/share/ptt/pttd.py
# ── user services ───────────────────────────────────────────────────────────
for u in dgpu-power-off.service dolphin-warm.service pttd.service xremap.service \
         screenoff-after-lock.service screenoff-after-lock.timer glass-doctor.service glass-doctor.path; do
    cpf ".config/systemd/user/$u"
done
# ── scripts ─────────────────────────────────────────────────────────────────
cpf .local/bin/claude-status-hook .local/bin/claude-status-list .local/bin/dolphin-macos \
    .local/bin/glass-quicklook .local/bin/glass-snapshot .local/bin/glass-doctor \
    .local/bin/ii-battery-power .local/bin/niri-display-mode .local/bin/niri-record \
    .local/bin/idle-inhibit-toggle .local/bin/keep-awake-locked

# ── leave private things out ────────────────────────────────────────────────
rm -f  .config/quickshell/ii/assets/fonts/SF-Pro-*.otf        # Apple's font: not redistributable
rm -rf .config/quickshell/ii/docs
# tools/private.local (not committed) lists what else to strip, one entry per line:
#   file <path in repo>          delete that file
#   lines <path in repo> <word>  delete every line containing that word (case-insensitive)
if [ -r tools/private.local ]; then
    while read -r kind path word; do
        case "$kind" in
            file) rm -rf "$path" ;;
            lines) [ -f "$path" ] && grep -vi -- "$word" "$path" > "$path.tmp" && mv "$path.tmp" "$path" ;;
        esac
    done < tools/private.local
fi
python3 - <<'PY'
import json, pathlib
# shell config: no home location
p = pathlib.Path('.config/illogical-impulse/config.json')
d = json.loads(p.read_text())
d.get('bar', {}).get('weather', {})['city'] = ''
p.write_text(json.dumps(d, indent=2) + '\n')
PY

# ── Claude Code hooks for the status island (only the hooks, not the whole settings file) ──
mkdir -p claude
python3 - <<'PY'
import json, os
s = json.load(open(os.path.expanduser('~/.claude/settings.json')))
out = {}
for ev, groups in s.get('hooks', {}).items():
    keep = [g for g in groups if any('claude-status-hook' in h.get('command', '') for h in g.get('hooks', []))]
    if keep: out[ev] = keep
json.dump({'hooks': out}, open('claude/status-island-hooks.json', 'w'), indent=2)
PY

# ── hardware files (Lenovo Legion Slim 5 16APH8: AMD 780M + RTX 4060) ───────
sys() { local f; for f in "$@"; do [ -r "$f" ] || { echo "skip (unreadable): $f"; continue; }; mkdir -p "system$(dirname "$f")"; cp --no-preserve=ownership,mode "$f" "system$f"; done; }
sys /usr/local/bin/niri-smart-maximize \
    /usr/local/sbin/dgpu-disable.sh /usr/local/sbin/dgpu-enable-compute.sh /usr/local/sbin/dgpu-enable-display.sh \
    /usr/local/sbin/dgpu-guard-not-display /usr/local/sbin/dgpu-status /usr/local/sbin/disable-cpu-boost.sh \
    /usr/local/sbin/disable-nvidia-dgpu.sh \
    /etc/systemd/system/disable-nvidia-dgpu.service /etc/systemd/system/dgpu-compute.service \
    /etc/systemd/system/dgpu-display.service /etc/systemd/system/disable-cpu-boost.service \
    /etc/modprobe.d/blacklist-nvidia-dgpu.conf /etc/modprobe.d/nvidia-dgpu-compute.conf \
    /etc/modprobe.d/nvidia-no-autoload.conf /etc/modprobe.d/mt7921e.conf /etc/modprobe.d/mt7921e-aspm.conf \
    /etc/udev/rules.d/99-rapl-readable.rules /etc/udev/rules.d/90-brightnessctl.rules \
    /etc/tlp.d/01-shanks-battery.conf /etc/sddm.conf

echo; echo "synced. Review with: git status --short | head -50"
