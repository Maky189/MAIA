# MAIA

I use Arch. MAIA is my Arch Linux setup, with all my dotfiles, apps and configurations, and a script that installs everything on a fresh Arch install. It also works on other Arch based distros.

The idea is simple: I install Arch, I clone this repo, I run one script, and my PC is the same as before. Same desktop, same apps, same configs, same games in Steam. If you like it you can do the same on your PC.

It uses Hyprland with the Noctalia shell, kitty with fish, and Neovim (LazyVim). It is set up mostly for gaming and programming.

## What it has

- Hyprland (Lua config) with Noctalia for the bar, notifications, control center, lock screen and the login screen. The colors of everything change with the wallpaper.
- My own Quickshell widgets: an app launcher, a power menu, a wallpaper picker (images and video wallpapers) and an AI chat panel in the bar for Claude Code and Codex.
- kitty, fish, starship, fastfetch, btop, cava and yazi, plus some fun terminal stuff like `clock`, `bonsai` and `matrix`.
- A "rice" scene on `Super + Shift + K` that opens fastfetch, a clock, cava, bonsai and btop as floating windows.
- Neovim with LazyVim, plus my VS Code settings and extensions.
- Gaming: Steam, Heroic, Lutris, gamemode, MangoHud, PCSX2 and PPSSPP. My PS2 and PSP games are added to Steam and Heroic with covers and artwork.
- On laptops with an NVIDIA card, Steam and the emulators always run on the NVIDIA GPU.
- Some system tweaks: zram, sysctl, I/O schedulers, ntsync for Wine, and my fish config.

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
5. Puts the system tweaks from `system/` in `/etc`, makes fish your shell, turns on the services (network, bluetooth, firewall...) and sets up the Noctalia login screen.
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

## Folders

- `install.sh`: the installer
- `packages/`: package lists (official repos, AUR, hardware, VS Code extensions)
- `home/`: all the dotfiles, in the same place they go in your home
- `system/`: files that go to `/etc` (login screen, zram, sysctl...)
- `gaming/`: the script that adds the games to Steam and Heroic
- `wallpapers/`: some starter wallpapers, until you add your own

## Some notes

- Put your wallpapers in `~/Pictures/Walpappers`. The theme takes its colors from them.
- To change the default apps (terminal, browser...) edit `~/.config/hypr/config/variables.lua`. Monitors are in `monitors.lua`.
- If you don't have an NVIDIA card, remove `prime-run` from `~/.local/share/applications/steam.desktop` (and the pcsx2 and PPSSPP ones).
- Very old NVIDIA cards (older than the GTX 16 series) don't work with the open driver; you need `nvidia-580xx-dkms` from the AUR instead.
- The AI chat panel needs Claude Code or Codex installed and logged in.
- OneDrive sync: run `rclone config` and name the remote `onedrive`. Then run `onedrive-sync --resync` once and `systemctl --user enable --now onedrive-sync.timer`.
- If I change something on my PC, I copy the file back into `home/` and commit it, so the repo stays up to date.

## Acknowledgments

A lot of this comes from other people's work. Some configs, tweaks and the starter wallpapers come from [CachyOS](https://cachyos.org). [Noctalia](https://github.com/noctalia-dev/noctalia) is the shell and the login screen. [SteamGridDB](https://www.steamgriddb.com) has the game artwork. Thanks to all of them.

You're free to take it and change it however you want (MIT license).
