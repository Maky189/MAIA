#!/usr/bin/env bash
# MAIA installer: turns a fresh CachyOS install into the full MAIA desktop.
#
#   ./install.sh                 everything (packages, dotfiles, services, gaming)
#   ./install.sh --dotfiles-only only copy the config files
#   ./install.sh --no-aur        skip AUR packages
#   ./install.sh --yes           don't ask before each step
#
# Existing files are never lost: anything that gets replaced is moved to
# ~/.maia-backup/<date>/ first. Running the script again is safe.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.maia-backup/$(date +%Y%m%d-%H%M%S)"
DOTFILES_ONLY=0 NO_AUR=0 YES=0
for a in "$@"; do
  case "$a" in
    --dotfiles-only) DOTFILES_ONLY=1 ;;
    --no-aur) NO_AUR=1 ;;
    -y|--yes) YES=1 ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $a"; exit 1 ;;
  esac
done

c_blue=$'\e[1;34m' c_green=$'\e[1;32m' c_yellow=$'\e[1;33m' c_red=$'\e[1;31m' c_off=$'\e[0m'
step() { printf '\n%s==>%s %s\n' "$c_blue" "$c_off" "$*"; }
ok()   { printf '%s  ✓%s %s\n' "$c_green" "$c_off" "$*"; }
warn() { printf '%s  !%s %s\n' "$c_yellow" "$c_off" "$*"; }
die()  { printf '%s  ✗%s %s\n' "$c_red" "$c_off" "$*"; exit 1; }
ask()  { [ "$YES" = 1 ] && return 0; read -rp "  $1 [Y/n] " r; [[ -z "$r" || "$r" =~ ^[Yy] ]]; }
pkglist() { grep -vE '^\s*(#|$)' "$1"; }

[ "$(id -u)" -ne 0 ] || die "Run this as your normal user, not root (it asks for sudo when needed)."
command -v pacman >/dev/null || die "This needs an Arch-based distro (made for CachyOS)."
grep -qi cachyos /etc/os-release || warn "Not CachyOS: some packages (cachyos-*) will be skipped."

cat <<'EOF'

   ███╗   ███╗ █████╗ ██╗ █████╗
   ████╗ ████║██╔══██╗██║██╔══██╗
   ██╔████╔██║███████║██║███████║
   ██║╚██╔╝██║██╔══██║██║██╔══██║
   ██║ ╚═╝ ██║██║  ██║██║██║  ██║
   ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝   CachyOS · Hyprland · Noctalia
EOF

# ---------------------------------------------------------------- packages
install_packages() {
  step "Packages"
  sudo pacman -Sy --noconfirm >/dev/null

  local want=() avail missing=()
  mapfile -t want < <(pkglist "$REPO/packages/pacman.txt")
  # hardware-specific extras
  if lspci | grep -qi 'vga.*nvidia\|3d.*nvidia'; then
    mapfile -t -O "${#want[@]}" want < <(pkglist "$REPO/packages/hw-nvidia.txt"); ok "NVIDIA GPU found"
  fi
  if lspci | grep -qi 'vga.*intel'; then
    mapfile -t -O "${#want[@]}" want < <(pkglist "$REPO/packages/hw-intel.txt"); ok "Intel GPU found"
  fi
  if grep -qi asus /sys/class/dmi/id/sys_vendor 2>/dev/null; then
    mapfile -t -O "${#want[@]}" want < <(pkglist "$REPO/packages/hw-asus.txt"); ok "ASUS laptop found"
  fi

  # only ask pacman for what the enabled repos actually have
  avail=$(pacman -Slq | sort -u)
  local install=()
  for p in "${want[@]}"; do
    if grep -qxF "$p" <<<"$avail"; then install+=("$p"); else missing+=("$p"); fi
  done
  sudo pacman -S --needed --noconfirm "${install[@]}"
  ok "${#install[@]} repo packages installed"
  [ ${#missing[@]} -eq 0 ] || warn "not in your repos, skipped: ${missing[*]}"

  if [ "$NO_AUR" = 0 ]; then
    if ! command -v yay >/dev/null; then
      step "Installing yay (AUR helper)"
      local tmp; tmp=$(mktemp -d)
      git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
      (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
      rm -rf "$tmp"
    fi
    local aur=()
    mapfile -t aur < <(pkglist "$REPO/packages/aur.txt")
    grep -qi asus /sys/class/dmi/id/sys_vendor 2>/dev/null && mapfile -t -O "${#aur[@]}" aur < <(pkglist "$REPO/packages/hw-asus-aur.txt")
    step "AUR packages (${#aur[@]})"
    yay -S --needed --noconfirm --answerdiff None --answerclean None "${aur[@]}" || warn "some AUR packages failed, see above"
  fi
}

# ---------------------------------------------------------------- dotfiles
install_dotfiles() {
  step "Dotfiles  (old files go to $BACKUP)"
  local n=0
  while IFS= read -r -d '' src; do
    local rel="${src#"$REPO/home/"}" dst="$HOME/${src#"$REPO/home/"}"
    mkdir -p "$(dirname "$dst")"
    local tmp; tmp=$(mktemp)
    sed "s#__HOME__#$HOME#g" "$src" >"$tmp"
    if [ -e "$dst" ] && ! cmp -s "$tmp" "$dst"; then
      mkdir -p "$BACKUP/$(dirname "$rel")"
      mv "$dst" "$BACKUP/$rel"
    fi
    mv "$tmp" "$dst"
    if [ -x "$src" ]; then chmod 755 "$dst"; else chmod 644 "$dst"; fi
    n=$((n + 1))
  done < <(find "$REPO/home" -type f -print0)
  chmod +x "$HOME"/.local/bin/* 2>/dev/null || true
  ok "$n files in place"

  # folders the configs expect
  mkdir -p "$HOME"/{Desktop,Documents,Downloads,Music,Public,Templates,Games/PS2,Games/PSP,Games/Launchers,Pictures/Walpappers,Videos,Projects}
  command -v xdg-user-dirs-update >/dev/null && xdg-user-dirs-update
  if [ -z "$(ls -A "$HOME/Pictures/Walpappers" 2>/dev/null)" ] && [ -d /usr/share/wallpapers/cachyos-wallpapers ]; then
    cp /usr/share/wallpapers/cachyos-wallpapers/* "$HOME/Pictures/Walpappers/" 2>/dev/null || true
    ok "CachyOS wallpapers copied to ~/Pictures/Walpappers (add your own there)"
  fi
  command -v update-desktop-database >/dev/null && update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
}

# ---------------------------------------------------------------- system
setup_system() {
  step "System settings"
  if command -v fish >/dev/null && [ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v fish)" ]; then
    sudo chsh -s "$(command -v fish)" "$USER" && ok "fish is now your shell"
  fi

  local units=(NetworkManager bluetooth ufw avahi-daemon systemd-resolved switcheroo-control fstrim.timer)
  pacman -Q cachyos-snapper-support &>/dev/null && units+=(snapper-cleanup.timer limine-snapper-sync)
  pacman -Q ananicy-cpp &>/dev/null && units+=(ananicy-cpp)
  pacman -Q nvidia-utils &>/dev/null && units+=(nvidia-powerd)
  pacman -Q supergfxctl &>/dev/null && units+=(supergfxd)
  for u in "${units[@]}"; do
    systemctl list-unit-files "$u"* &>/dev/null && sudo systemctl enable "$u" &>/dev/null && ok "enabled $u" || true
  done

  # login screen: Noctalia greeter on greetd
  if pacman -Q noctalia-greeter greetd &>/dev/null; then
    [ -f /etc/greetd/config.toml ] && sudo cp -n /etc/greetd/config.toml /etc/greetd/config.toml.maia-bak
    sudo install -m644 "$REPO/system/greetd/config.toml" /etc/greetd/config.toml
    sudo systemctl disable sddm &>/dev/null || true
    sudo systemctl enable greetd &>/dev/null && ok "Noctalia login screen (greetd)"
  fi

  # ASUS keyboard lighting
  command -v asusctl >/dev/null && asusctl aura effect rainbow-cycle --speed med &>/dev/null && ok "keyboard RGB: rainbow"

  # OneDrive sync timer only makes sense once rclone has a "onedrive" remote
  systemctl --user daemon-reload
  if command -v rclone >/dev/null && rclone listremotes 2>/dev/null | grep -qx 'onedrive:'; then
    systemctl --user enable --now onedrive-sync.timer && ok "OneDrive sync every 5 min"
  else
    warn "OneDrive sync is off. To use it: 'rclone config' (name the remote onedrive), run 'onedrive-sync --resync' once, then 'systemctl --user enable --now onedrive-sync.timer'"
  fi
}

# ---------------------------------------------------------------- apps
setup_apps() {
  if command -v code >/dev/null; then
    step "VS Code extensions"
    while read -r ext; do code --install-extension "$ext" --force &>/dev/null && printf '.' || printf 'x'; done < <(pkglist "$REPO/packages/vscode-extensions.txt")
    echo; ok "VS Code extensions"
  fi
  if command -v nvim >/dev/null; then
    step "Neovim plugins (LazyVim)"
    nvim --headless "+Lazy! sync" +qa &>/dev/null && ok "Neovim plugins synced" || warn "open nvim once to finish plugin setup"
  fi
}

setup_gaming() {
  step "PS2 / PSP games in Steam and Heroic"
  if pgrep -x steam >/dev/null || pgrep -x heroic >/dev/null; then
    warn "Steam or Heroic is open: close them and run  $REPO/gaming/maia-games.py"
    return
  fi
  python3 -I "$REPO/gaming/maia-games.py" "$REPO/gaming/games.json" || warn "games step failed (are the ISOs in ~/Games/PS2 and ~/Games/PSP?)"
  warn "PS2 BIOS is not included (copyright): put it in ~/Documents/PCSX2/bios"
}

# ---------------------------------------------------------------- run
if [ "$DOTFILES_ONLY" = 1 ]; then
  install_dotfiles
else
  ask "Install packages?"        && install_packages
  install_dotfiles
  ask "Apply system settings?"   && setup_system
  ask "Set up VS Code / Neovim?" && setup_apps
  ask "Add PS2/PSP games to Steam & Heroic?" && setup_gaming
fi

step "Done"
[ -d "$BACKUP" ] && echo "  Your old files are in $BACKUP"
echo "  Log out and back in (or reboot) to start the MAIA desktop."
