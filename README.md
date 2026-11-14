# MAIA

I use Arch. MAIA is my Arch Linux setup, with all my dotfiles, apps and configurations, and a script that installs everything on a fresh Arch install. It also works on other Arch based distros.

The idea is simple: I install Arch, I clone this repo, I run one script, and my PC is the same as before. Same desktop, same apps, same configs, same games in Steam. If you like it you can do the same on your PC.

It uses Hyprland with the Noctalia shell, kitty with fish, and Neovim (LazyVim). It is set up mostly for gaming and programming.

## What it has

- Hyprland (Lua config) with Noctalia for the bar, notifications, control center, lock screen and the login screen. The colors of everything change with the wallpaper.
- A Noctalia dock with pinned apps and dots for running apps. It stays below fullscreen windows, so moving the pointer to the bottom doesn't bring it over a fullscreen app.
- My own Quickshell widgets: an app launcher, a power menu, a wallpaper picker (images and video wallpapers) and an AI chat panel in the bar for Claude Code and Codex.
- kitty, fish, starship, fastfetch, btop, cava and yazi, plus some fun terminal stuff like `clock`, `bonsai` and `matrix`.
- A "rice" scene on `Super + Shift + K` that opens fastfetch, a clock, cava, bonsai and btop as floating windows.
- Neovim with LazyVim, plus my VS Code settings and extensions.
- Gaming: Steam, Heroic, Lutris, gamemode, MangoHud, PCSX2 and PPSSPP. My PS2 and PSP games are added to Steam and Heroic with covers and artwork.
- On laptops with an NVIDIA card, Steam, Blender, Godot, Unity Hub and the emulators always run on the NVIDIA GPU, and Blender renders with OptiX.
- Some system tweaks: zram, sysctl, I/O schedulers, ntsync for Wine, and my fish config.
- A warning before the disk fills up: a notification under 30 GB free and a red one under 10 GB. The package cache also cleans itself every week and keeps the last two versions of each package. I added this because a full disk once broke my whole session.
- `Super + Shift + Escape` force-kills the focused window, for when a game freezes and doesn't close with `Super + Q`.
- A fix for MediaTek MT7921 Wi-Fi cards that drop the connection after a while (it turns off their PCIe power saving).

## How to install:

1. Install Arch Linux. With `archinstall` the easiest way is to choose a minimal profile, NetworkManager for the network, and pipewire for audio. You don't need to install any desktop because the script does that. Any other Arch based distro works too.

2. Clone the repo:
```bash
sudo pacman -S git
git clone https://github.com/Maky189/MAIA.git ~/MAIA
cd ~/MAIA
```

3. Run the script:
```bash
./install.sh
```
It asks before every big step. If you don't want it to ask, use `./install.sh --yes`. If you only want the config files, use `./install.sh --dotfiles-only`.

4. Reboot. You'll see the Noctalia login screen, then you're in.

Before the script replaces any file, it copies it to `~/.maia-backup/`, so you don't lose anything. You can run it again without problems.

## What the script does

1. Turns on the multilib repo (needed for Steam and Wine) and installs everything in `packages/base.txt`.
2. Looks at your hardware and adds what it needs: NVIDIA drivers (the right module for your kernel), Intel or AMD drivers, CPU microcode, and the ASUS tools on ASUS laptops.
3. Installs `yay` and the AUR packages in `packages/aur.txt`. If your distro already has one of them in its own repos, it uses that version instead. DaVinci Resolve is optional because it's a big download.
4. Copies everything in `home/` to your home folder, changing the paths to your username.
5. Puts the system tweaks from `system/` in `/etc`, makes fish your shell, turns on the services (network, bluetooth, firewall, weekly package cache cleanup, the disk space warning...) and sets up the Noctalia login screen.
6. Installs the VS Code extensions and the Neovim plugins.
7. Adds the PS2/PSP games to Steam and Heroic (only if the ISOs are there).

## Games in Steam and Heroic

Put your ISOs in `~/Games/PS2` and `~/Games/PSP`, and add them to `gaming/games.json`:
```json
{"key": "gow2", "title": "God of War II", "system": "ps2", "iso": "~/Games/PS2/God of War II (USA).iso"}
```
`system` is `ps2` or `psp`. Then close Steam and Heroic and run:
```bash
./gaming/maia-games.py
```
For each game it makes a launcher in `~/Games/Launchers`, downloads the covers, banners, logos and icons from SteamGridDB, and adds the game to Steam and Heroic. If it finds the wrong game, put the right `sgdb_id` in the json (it's the number in the SteamGridDB link).

The games and the PS2 BIOS are not in the repo. Put the BIOS in `~/Documents/PCSX2/bios`.

## Keybinds

`Super + H` opens the full list. The ones I use most:

```
Super + Return          terminal
Super + Space           app launcher
Super + W               browser
Super + E               file manager
Super + Q               close window
Super + Shift + Escape  force-kill the focused window (frozen game)
Super + F               fullscreen
Super + V               clipboard history
Super + X               control center
Super + Shift + W       wallpaper picker
Super + Alt + Left/Right/R   previous / next / random wallpaper
Super + Shift + K       rice scene
Super + Shift + R       start / stop screen recording
Super + Shift + C       Claude Code
Super + S               scratchpad
Super + L               lock
Super + Alt + C         power menu
Print                   screenshot
```

## If a game freezes

Most of the time only the game is frozen, not the PC, so don't hold the power button. I try these in order:

1. `Super + Shift + Escape` to force-kill the game.
2. `Super + Escape`, then click the game.
3. `Ctrl + Alt + F3` to get a text login, log in, run `pkill -9 -f <game>.exe`, then `Ctrl + Alt + F1` to go back to the desktop.
4. If nothing works, hold `Alt + PrtSc` (with `Fn` on some laptops) and press `R E I S U B` slowly, one key at a time. It saves everything to disk and reboots cleanly.

On my laptop the GPU only has 4 GB of VRAM, and on Linux the NVIDIA driver handles a full VRAM much worse than Windows does. Games crash or freeze instead of just stuttering. So I keep the in-game VRAM bar some room below the limit, and I cap heavy games at 50 fps with MangoHud. For GTA V the Steam launch option is:
```
MANGOHUD_CONFIG=fps_limit=50,no_display mangohud %command%
```
`Right Shift + F12` shows the fps counter. Steam keeps launch options in its own config, so they aren't in the repo.

## Folders

- `install.sh`: the installer
- `packages/`: package lists (official repos, AUR, hardware, VS Code extensions)
- `home/`: all the dotfiles, in the same place they go in your home
- `system/`: files that go to `/etc` (login screen, zram, sysctl...)
- `gaming/`: the script that adds the games to Steam and Heroic
- `wallpapers/`: some starter wallpapers, until you add your own

## Current desktop snapshot

The snapshot includes both `home/.config/noctalia/config.toml` and the saved UI settings in `home/.local/state/noctalia/settings.toml`. The installer restores both files, including the dock, launcher, plugins, desktop widgets and lock screen layout. The current wallpaper and lock screen image are in `home/Pictures/`.

The dock order is VS Code, Brave, Blender, Rider, Steam, Minecraft Launcher, Neovim, IntelliJ IDEA, Discord, Notion, Spotify, CLion, Files and OBS Studio. Running apps show dots. Smart auto-hide is enabled, and `layer = "top"` keeps the dock below fullscreen windows.

The Applications button at the start of the dock opens a grid version of the custom cozy launcher, with the same artwork, clock and search as `Super + Space`. The keyboard shortcut opens the list version. Both use `home/.config/quickshell/launcher/Launcher.qml`; `shell.qml` selects the list and `grid.qml` selects the grid. `launcher-toggle [list|grid]` opens or closes either layout, and switches layouts when the other one is open. In the grid, use the arrow keys to browse, Enter to launch and Escape to close.

The launcher uses the wallpaper's Noctalia colors, a quiet opaque surface, inset artwork and spaced app tiles. Both layouts always show all apps in alphabetical order, with no category filters. Search includes every app. Both layouts offer clear-search and close buttons, keyboard hints and scroll indicators. App names use Noto Sans while the clock keeps Fantasque Sans Mono. Narrow windows hide the artwork to leave room for browsing.

The dock uses the pinned `maia-launcher-grid.desktop` shortcut for this button, with Noctalia's built-in launcher button disabled (`launcher_position = "none"`). Keep that shortcut first in `dock.pinned` to preserve the button's position.

Both launcher layouts pick random artwork on each opening, avoiding the image used on the previous opening even when switching layouts. The set includes the original banner and four generated cozy anime scenes: a rainy studio, sunset train, bookshop café and snowy attic. Add images to `home/.config/quickshell/launcher/artwork/` to extend it (PNG, JPEG or WebP). `choose-banner.py` remembers the last image in `$XDG_CACHE_HOME/maia-launcher/last-banner` (or `~/.cache/maia-launcher/last-banner`); that runtime cache is not included in the snapshot.

The JetBrains launchers and icons are included so the pinned IDs resolve. Install IntelliJ IDEA, Rider and CLion through JetBrains Toolbox; the launchers expect its default `~/.local/share/JetBrains/Toolbox/apps/` paths. Toolbox itself is in the package list, but the installer does not download these IDEs.

The Ubuntu launcher includes its own Alacritty profile and floating window rule. It expects a Distrobox container named `ubuntu`; container contents are not part of the snapshot. The TerraFora development preview also has a dedicated floating window rule. `Super + Shift + M` opens the Spotify desktop app.

## Some notes

- Put your wallpapers in `~/Pictures/Walpappers`. The theme takes its colors from them.
- To change the default apps (terminal, browser...) edit `~/.config/hypr/config/variables.lua`. Monitors are in `monitors.lua`.
- If you don't have an NVIDIA card, remove `prime-run` from `~/.local/share/applications/steam.desktop` (and the blender, godot, unityhub, pcsx2, PPSSPP and minecraft-launcher ones) and from `~/.local/bin/blender`, `~/.local/bin/godot-mono` and `~/.local/bin/unityhub`.
- Very old NVIDIA cards (older than the GTX 16 series) don't work with the open driver; you need `nvidia-580xx-dkms` from the AUR instead.
- The AI chat panel needs Claude Code or Codex installed and logged in.
- OneDrive sync: run `rclone config` and name the remote `onedrive`. Then run `onedrive-sync --resync` once and `systemctl --user enable --now onedrive-sync.timer`.
- If I change something on my PC, I copy the file back into `home/` and commit it, so the repo stays up to date. Noctalia UI changes go in `home/.local/state/noctalia/settings.toml`; replace home-directory paths with `__HOME__` before saving them. Keep personal credentials, recent-file history and notification/clipboard state out of the repo. The Fish and XDG folder defaults remain portable to other Arch installs.

## Acknowledgments

A lot of this comes from other people's work. Some configs, tweaks and the starter wallpapers come from [CachyOS](https://cachyos.org). [Noctalia](https://github.com/noctalia-dev/noctalia) is the shell and the login screen. [SteamGridDB](https://www.steamgriddb.com) has the game artwork. Thanks to all of them.

You're free to take it and change it however you want (MIT license).
