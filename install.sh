#!/bin/bash
# Puts this repository's files in place on a fresh Arch install.
#
#   ./install.sh --dry-run    show what would be copied, change nothing
#   ./install.sh              copy, build Dolphin's shim, enable the user services
#
# It only touches your home folder and never asks for a password. Files it replaces are kept in
# ~/.dotfiles-backup-<date>. Packages, the files under system/, the SF Pro font and the
# wallpaper are separate steps: they are printed at the end and described in README.md.
set -eu
REPO="$(cd "$(dirname "$0")" && pwd)"
DRY=""; [ "${1:-}" = "--dry-run" ] && DRY="--dry-run"
BACKUP="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

command -v rsync >/dev/null || { echo "rsync is needed: sudo pacman -S rsync"; exit 1; }

echo "== copying .config and .local into $HOME"
rsync -a $DRY --itemize-changes --backup --backup-dir="$BACKUP" "$REPO/.config" "$REPO/.local" "$HOME/" | grep -v '/$' | sed 's/^/   /' | head -400
[ -n "$DRY" ] && { echo "(dry run: nothing changed)"; exit 0; }

# The files were written on a machine whose home is /home/shanks.
if [ "$HOME" != "/home/shanks" ]; then
    echo "== pointing absolute paths at $HOME"
    ( cd "$REPO" && find .config .local -type f ) | while read -r f; do
        if grep -Iq . "$HOME/$f" 2>/dev/null && grep -q '/home/shanks' "$HOME/$f"; then
            sed -i "s|/home/shanks|$HOME|g" "$HOME/$f"
        fi
    done
fi

chmod +x "$HOME"/.local/bin/* "$HOME/.config/dolphin-macos/glass-shim/build.sh" 2>/dev/null || true
mkdir -p "$HOME/.local/state/claude-status"

echo "== building Dolphin's glass shim"
if sh "$HOME/.config/dolphin-macos/glass-shim/build.sh"; then echo "   built"; else
    echo "   NOT built (needs base-devel, qt6-base and kio). Dolphin still works without it."; fi

echo "== fonts"
fc-cache -f >/dev/null 2>&1 || true

echo "== user services"
systemctl --user daemon-reload
for u in dolphin-warm.service xremap.service glass-doctor.path glass-doctor.service; do
    [ -f "$HOME/.config/systemd/user/$u" ] && systemctl --user enable "$u" >/dev/null 2>&1 && echo "   enabled $u"
done
# only where their other half exists: the dictation environment, the laptop's dGPU scripts
if [ -x "$HOME/.local/share/ptt/.venv/bin/python" ]; then systemctl --user enable pttd.service >/dev/null 2>&1 && echo "   enabled pttd.service"
else echo "   pttd.service left off (dictation environment not set up yet, see CLAUDE.md)"; fi
if [ -x /usr/local/sbin/dgpu-disable.sh ]; then systemctl --user enable dgpu-power-off.service >/dev/null 2>&1 && echo "   enabled dgpu-power-off.service"
else echo "   dgpu-power-off.service left off (hardware files from system/ are not installed)"; fi
systemctl --user enable hypridle.service foot-server.socket >/dev/null 2>&1 || true

echo "== Claude Code hooks for the status island"
if [ -f "$HOME/.claude/settings.json" ] && command -v python3 >/dev/null; then
    python3 - "$REPO/claude/status-island-hooks.json" "$HOME" <<'PY'
import json, os, sys
src, home = sys.argv[1], sys.argv[2]
p = os.path.join(home, '.claude/settings.json')
s = json.load(open(p)); add = json.load(open(src))['hooks']
cmd = os.path.join(home, '.local/bin/claude-status-hook')
hooks = s.setdefault('hooks', {})
for ev in add:
    lst = hooks.setdefault(ev, [])
    if not any('claude-status-hook' in h.get('command', '') for g in lst for h in g.get('hooks', [])):
        lst.append({'hooks': [{'type': 'command', 'command': cmd}]})
json.dump(s, open(p + '.tmp', 'w'), indent=2); os.replace(p + '.tmp', p)
print('   merged into', p)
PY
else echo "   ~/.claude/settings.json not found: start Claude Code once, then re-run this script"; fi

"$HOME/.local/bin/glass-snapshot" "installed from dotfiles" >/dev/null 2>&1 || true

cat <<MSG

Done. Replaced files (if any) are in $BACKUP

Still to do by hand (details in README.md):
  1. Packages:      sudo pacman -S --needed - < packages/pacman.txt
                    yay -S --needed - < packages/aur.txt
  2. SF Pro font:   put SF-Pro-Text-Medium.otf in ~/.config/quickshell/ii/assets/fonts/
  3. Wallpaper:     put an image at ~/Downloads/desktopbg.jpg (or change 50-startup.kdl)
  4. Lock screen:   hyprlock shows the image named in ~/.config/hypr/hyprlock.conf (path = ...)
  5. Weather city:  set bar.weather.city in ~/.config/illogical-impulse/config.json
  6. Fish prompt:   fisher update
  7. Hardware:      system/ holds /etc and /usr/local files for a Legion Slim 5 16APH8 only
  8. Log out and back in to niri.
MSG
