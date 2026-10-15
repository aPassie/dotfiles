# dotfiles

My desktop on Arch Linux: the **niri** compositor with a clear-glass shell built on
**Quickshell**, a pitch-black macOS-style **Dolphin**, and black Qt/GTK apps to match.

Files mirror `$HOME`. `install.sh` copies them into place; `CLAUDE.md` is the full rebuild guide
written for Claude Code.

## What's here

| Part | Where | What it is |
|---|---|---|
| Compositor | `.config/niri/` | niri config split into `config.d/*.kdl`: input, layout, window rules, startup, key binds, layer rules (blur for the glass panels) |
| Glass shell | `.config/quickshell/ii/` | Top bar of glass "islands", drop-down panels (Wi-Fi, Bluetooth, notifications, Control Centre, media), app launcher, clipboard picker, OSD, notification pop-ups |
| Shell settings | `.config/illogical-impulse/config.json` | Options the shell reads (fonts, time format, apps it launches) |
| Lock and idle | `.config/hypr/` | hyprlock + hypridle |
| Dolphin | `.config/dolphin-macos/`, `.local/bin/dolphin-macos` | Dolphin in its own config folder: black Kvantum theme, round toolbar buttons, a breadcrumb drawn by a small preload library |
| Qt / GTK apps | `.config/kdeglobals`, `.config/gtk-*/gtk.css`, `.local/share/color-schemes/` | "GlassBlack": black surfaces, white text, grey fills |
| Scripts | `.local/bin/` | Display modes, screen recording, battery power readout, Claude status hooks, update protection |
| Services | `.config/systemd/user/` | Warm-started Dolphin, key remapping, dictation daemon, after-update checks |
| Terminal and shell | `.config/foot/`, `.config/fish/` | foot + fish |
| Hardware | `system/` | `/etc` and `/usr/local` files for one laptop (Lenovo Legion Slim 5 16APH8). Not installed automatically |
| Packages | `packages/` | What the desktop needs, split into official repositories and AUR |

## The bar

Left to right: workspace ring and focused app, system monitor island, **app island** (every open
app with Dock-style magnification, plus apps running in the background; right-click for windows
and the app's own menu), media island, **Claude island** (folder and Working / Asking / Done for
each Claude Code session), status island (Wi-Fi, Bluetooth, notifications), weather and battery,
clock (click for the Control Centre).

## Install on a fresh Arch system

```sh
git clone https://github.com/aPassie/dotfiles ~/dotfiles && cd ~/dotfiles
sudo pacman -S --needed - < packages/pacman.txt
yay -S --needed - < packages/aur.txt        # needs an AUR helper
./install.sh --dry-run                      # look first
./install.sh
```

Then the things the script cannot do:

1. **SF Pro font.** The bar's symbols come from Apple's *SF Pro Text Medium*, which cannot be
   redistributed. Download "SF Pro" from <https://developer.apple.com/fonts/>, extract
   `SF-Pro-Text-Medium.otf` from the `.dmg` (`7z x` twice works) and put it in
   `~/.config/quickshell/ii/assets/fonts/`.
2. **Wallpaper.** niri starts `swaybg` with `~/Downloads/desktopbg.jpg`. Put an image there or
   change the last line of `.config/niri/config.d/50-startup.kdl`. The bar derives its tint
   from this image.
3. **Lock-screen image.** `~/.config/hypr/hyprlock.conf` names a picture under
   `~/Pictures/Wallpapers/` (`path = ...`). Put an image there or change the path.
4. **Weather.** Set `bar.weather.city` in `~/.config/illogical-impulse/config.json`.
5. **Fish prompt.** `fisher update` installs the tide prompt listed in `fish_plugins`.
6. **Dictation (optional).** Holding Right Ctrl needs a Python environment and a speech model
   that are not in this repository; `CLAUDE.md` has the steps. Until then `pttd.service` stays off.
7. **Hardware files.** Everything under `system/` is for one specific laptop (hybrid-GPU power
   scripts, TLP profile, Wi-Fi driver options, login-screen theme setting). Skip it on other
   hardware.

Log out and choose the niri session.

## Key bindings

| Keys | Action |
|---|---|
| `Mod+Return`, `Mod+T` | Terminal (foot) |
| `Mod+E` | Files (Dolphin) |
| `Mod+Space` | App launcher |
| `Mod+Y` | Clipboard |
| `Mod+P` | Control Centre |
| `Mod+N` | Notifications |
| `Mod+M` | Media controls |
| `Mod+Tab` | Overview |
| `Mod+L` | Lock |
| `Mod+Q` | Close window |
| `Mod+F` | Maximise |
| `Mod+V` | Float as a small centred box |
| `Mod+Shift+S` | Screenshot a region |
| `Mod+Alt+R` | Record the screen (toggle) |
| `Mod+I` | Keep awake |
| Hold `Right Ctrl` | Dictate |

`Mod+Shift+/` shows niri's own list of every binding.

## Keeping it working

- `glass-doctor` runs after every pacman transaction and at login. It rebuilds and tests
  Dolphin's preload library, checks the shell and niri configs, and sends a notification if
  something broke. `glass-doctor --report` shows the last result.
- `glass-snapshot` keeps a local git history of these files in
  `~/.local/share/glass-snapshots.git`. `glass-snapshot restore <path>` brings a file back.
- After a Qt update, rebuild Quickshell: `yay -S quickshell-git --rebuild`.

## Updating this repository

```sh
tools/sync-from-home.sh    # copy the live files in, private items left out
git diff --stat && git commit -am "..." && git push
```

## Not in this repository

- Apple's SF Pro font and the wallpaper image (see above).
- Browser profiles, application data, caches.
- A few personal scripts and their key binds, stripped by `tools/sync-from-home.sh` using a
  local, uncommitted list.
- PhoneLink's Android app and its Wi-Fi Direct root helper: they live in their own project.
  This repository has only the laptop side (`phonelinkd`, `phonelink`, the user service, the
  shell's phone icon, panel and call pop-up, and Dolphin's "Send to phone").
- The speech model and Python environment for dictation (`~/.local/share/ptt/.venv`); only
  `pttd.py` is here.

## Credits and licence

The shell under `.config/quickshell/ii/` started from
[end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) ("illogical-impulse") and is
distributed under the same licence, GPL-3.0 (`.config/quickshell/ii/LICENSE`). The glass bar,
panels and services under `modules/ii/glassbar/` and `services/Glass*.qml` are new work on top
of it. Icons come from the WhiteSur icon theme, installed as a package.
