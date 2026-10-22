<div align="center">

# MAIA

**A cozy gaming and dev desktop for CachyOS. One script sets it all up.**

CachyOS · Hyprland · Noctalia shell · Quickshell · kitty · fish · LazyVim

</div>

---

MAIA is my full Linux setup: every package, dotfile, script and tweak. Put it on a fresh
CachyOS install, run one script, log back in, and you get the same desktop.
It's open source, so you can fork it and make it your own.

## ✨ What you get

| Area | What's inside |
|---|---|
| **Desktop** | Hyprland (Lua config) with the **Noctalia** shell: bar, control center, notifications, lock screen, a wallpaper-based color theme, and the Noctalia greeter as the login screen |
| **Custom overlays** | Quickshell app launcher, power menu, a transparent wallpaper picker (images *and* video wallpapers via mpvpaper), and an **AI chat panel** (Claude Code / Codex) in the bar |
| **Terminal** | kitty, fish, starship prompt, fastfetch, btop, cava, yazi, plus fun extras (`clock`, `bonsai`, `matrix`) |
| **"Rice" scene** | `Super + Shift + K` opens a showcase workspace with floating cards: fastfetch, clock, cava, bonsai and btop |
| **Editor** | Neovim (LazyVim) with clangd, DAP, Copilot, Claude Code; VS Code settings and extension list |
| **Gaming** | Steam, Heroic, Lutris, gamemode, MangoHud, gamescope, PCSX2 and PPSSPP configured; **PS2/PSP games added to Steam and Heroic with full artwork** |
| **Hybrid GPU laptops** | Steam, PCSX2 and PPSSPP always run on the NVIDIA card (`prime-run`), and Brave plus the AI panel pause while a game runs to save resources |
| **Extras** | NVENC screen recorder toggle, scratchpad helpers, two-way OneDrive sync (rclone), ASUS keyboard RGB |

## 🚀 Install

On a fresh **CachyOS** install (choose the *Hyprland* desktop, or any desktop; the script installs Hyprland):

```sh
git clone https://github.com/Maky189/MAIA.git ~/MAIA
cd ~/MAIA
./install.sh
```

Then **log out and back in** (or reboot).

The script asks before each big step. Options:

| Flag | Does |
|---|---|
| `--yes` | Don't ask, do everything |
| `--dotfiles-only` | Only copy the config files (no packages, no sudo) |
| `--no-aur` | Skip AUR packages |

> **Nothing is lost.** Every file the installer would replace is first moved to
> `~/.maia-backup/<date>/`. Running it again is safe.

### What `install.sh` does

1. **Packages:** installs everything in [`packages/pacman.txt`](packages/pacman.txt), plus extras only when matching hardware is found:
   NVIDIA ([`hw-nvidia.txt`](packages/hw-nvidia.txt)), Intel ([`hw-intel.txt`](packages/hw-intel.txt)), ASUS ([`hw-asus.txt`](packages/hw-asus.txt)).
   Then it installs `yay` if needed and the AUR packages in [`packages/aur.txt`](packages/aur.txt).
   Packages your repos don't have are skipped and listed.
2. **Dotfiles:** copies everything under [`home/`](home) into your `$HOME`. Paths are adapted to your username automatically.
3. **System:** makes fish the default shell, enables the needed services (NetworkManager, Bluetooth, ufw, snapper, NVIDIA/supergfx…), sets the Noctalia login screen and turns on the ASUS keyboard RGB.
4. **Apps:** installs the VS Code extensions and syncs the Neovim plugins.
5. **Gaming:** creates launchers for the PS2/PSP ISOs and adds them to Steam and Heroic with artwork (see below).

## 🎮 PS2 / PSP games in Steam & Heroic

1. Put your ISOs in `~/Games/PS2` and `~/Games/PSP`.
2. List them in [`gaming/games.json`](gaming/games.json):
   ```json
   {"key": "gow2", "title": "God of War II", "system": "ps2", "iso": "~/Games/PS2/God of War II (USA).iso"}
   ```
   `system` is `ps2` or `psp`. Add `"sgdb_id"` if the title search finds the wrong game (the id is in the SteamGridDB URL).
3. **Close Steam and Heroic**, then run:
   ```sh
   ./gaming/maia-games.py
   ```

For each game this writes `~/Games/Launchers/<key>.sh` (fullscreen, on the NVIDIA GPU) and downloads the
portrait, wide, hero, logo and icon art from [SteamGridDB](https://www.steamgriddb.com) (no API key needed).
It then adds the game to **every Steam account** on the PC and to **Heroic's** library.

> BIOS files and games are **not** included (copyright). Put your PS2 BIOS in `~/Documents/PCSX2/bios`.

## ⌨️ Keybinds

`Super + H` shows the full cheat sheet ([`cheatsheet.txt`](home/.local/share/keybinds/cheatsheet.txt)). The essentials:

| Keys | Action |
|---|---|
| `Super + Return` | Terminal (kitty) |
| `Super + Space` | App launcher |
| `Super + W` | Browser (Brave) |
| `Super + E` | File manager |
| `Super + Y` | yazi |
| `Super + Q` | Close window |
| `Super + F` / `Super + D` | Fullscreen / maximize |
| `Super + V` | Clipboard history |
| `Super + X` / `Super + Z` | Control center / settings |
| `Super + Shift + W` | Wallpaper picker |
| `Super + Alt + ←/→/R` | Previous / next / random wallpaper |
| `Super + Shift + K` | Rice scene |
| `Super + K` | Floating clock |
| `Super + Shift + R` | Start / stop screen recording |
| `Super + Shift + C` / `X` | Claude Code / Codex in a terminal |
| `Super + Shift + M` | Spotify (spotify_player) |
| `Super + S` | Scratchpad |
| `Super + L` | Lock |
| `Super + Alt + C` | Power menu |
| `Print` / `Super + Print` | Screenshot region / full screen |

## 📁 Layout

```
MAIA/
├── install.sh              the installer
├── packages/               pacman, AUR, hardware and VS Code lists
├── home/                   mirrors $HOME, copied as-is
│   ├── .config/
│   │   ├── hypr/           Hyprland (Lua): binds, rules, animations…
│   │   ├── noctalia/       shell config + local plugins (wallpaper hub, AI chat)
│   │   ├── quickshell/     launcher, power menu, wallpaper picker, AI chat panel
│   │   ├── kitty/ fish/ starship.toml fastfetch/ btop/ cava/ rofi/ …
│   │   ├── nvim/           LazyVim
│   │   ├── PCSX2/ ppsspp/  emulator settings
│   │   └── autostart/ systemd/ uwsm/
│   └── .local/
│       ├── bin/            helper scripts (toggles, recorder, rice, gamewatch…)
│       └── share/          NVIDIA desktop overrides, keybind cheat sheet
├── gaming/                 maia-games.py + games.json
└── system/                 files for /etc (login screen)
```

## 🛠️ Make it yours

- **Wallpapers:** not included. Drop images or videos in `~/Pictures/Walpappers`; the theme colors follow the wallpaper.
- **Default apps:** `~/.config/hypr/config/variables.lua` (terminal, browser, editor…).
- **Monitors:** `~/.config/hypr/config/monitors.lua`.
- **Spotify:** `spotify_player` uses its built-in client. To use your own, set `client_id` in `~/.config/spotify-player/app.toml`.
- **OneDrive:** run `rclone config` (name the remote `onedrive`), then `onedrive-sync --resync` once, then
  `systemctl --user enable --now onedrive-sync.timer`.
- **AI chat panel:** needs [Claude Code](https://claude.com/claude-code) and/or Codex logged in.
- **No NVIDIA GPU?** Remove `prime-run` from `~/.local/share/applications/{steam,pcsx2,PPSSPPSDL}.desktop` and from the game launchers.

To pick up changes you made on your PC, copy the file back into `home/` and commit.

## ↩️ Undo

Your previous files are in `~/.maia-backup/<date>/`; copy them back to `$HOME`.
The old login screen config is at `/etc/greetd/config.toml.maia-bak`.

## 📜 License

[MIT](LICENSE). Take it, fork it, rice it.
