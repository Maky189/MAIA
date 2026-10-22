#!/usr/bin/env bash
# MAIA installer: turns a fresh Arch Linux (or any Arch based distro) into MAIA.
#
#   ./install.sh                 everything (packages, dotfiles, system, apps, games)
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
ok()   { printf '%s  ok%s %s\n' "$c_green" "$c_off" "$*"; }
warn() { printf '%s  !!%s %s\n' "$c_yellow" "$c_off" "$*"; }
die()  { printf '%s  xx%s %s\n' "$c_red" "$c_off" "$*"; exit 1; }
ask()  { [ "$YES" = 1 ] && return 0; read -rp "  $1 [Y/n] " r; [[ -z "$r" || "$r" =~ ^[Yy] ]]; }
pkglist() { grep -vE '^\s*(#|$)' "$1"; }
installed() { pacman -Qq "$1" &>/dev/null; }
in_repos() { pacman -Si "$1" &>/dev/null; }

gpus() { lspci | grep -iE 'vga|3d|display'; }
has_nvidia() { gpus | grep -qi nvidia; }
has_intel_gpu() { gpus | grep -qi intel; }
has_amd_gpu() { gpus | grep -qiE 'amd|ati'; }
is_asus() { grep -qi asus /sys/class/dmi/id/sys_vendor 2>/dev/null; }

[ "$(id -u)" -ne 0 ] || die "Run this as your normal user, not root (it asks for sudo when needed)."
command -v pacman >/dev/null || die "MAIA needs Arch Linux or an Arch based distro."

cat <<'EOF'

   ███╗   ███╗ █████╗ ██╗ █████╗
   ████╗ ████║██╔══██╗██║██╔══██╗
   ██╔████╔██║███████║██║███████║
   ██║╚██╔╝██║██╔══██║██║██╔══██║
   ██║ ╚═╝ ██║██║  ██║██║██║  ██║
   ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝   Arch Linux · Hyprland · Noctalia
EOF

# ---------------------------------------------------------------- packages
enable_multilib() {
  grep -q '^\[multilib\]' /etc/pacman.conf && return
  sudo cp /etc/pacman.conf /etc/pacman.conf.maia-bak
  sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
  ok "enabled the multilib repo (needed for Steam and Wine)"
}

install_yay() {
  command -v yay >/dev/null && return
  step "Installing yay (AUR helper)"
  local tmp; tmp=$(mktemp -d)
  git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"
}

# NVIDIA kernel module that matches the kernel(s) installed
nvidia_kernel_packages() {
  local k out=()
  for k in $(cat /usr/lib/modules/*/pkgbase 2>/dev/null | sort -u); do
    if in_repos "$k-nvidia-open"; then out+=("$k-nvidia-open")   # prebuilt, e.g. CachyOS kernels
    else out+=(nvidia-open-dkms "$k-headers"); fi
  done
  [ ${#out[@]} -gt 0 ] || out=(nvidia-open-dkms linux-headers)
  printf '%s\n' "${out[@]}" | sort -u
}

install_packages() {
  step "Packages"
  enable_multilib
  sudo pacman -Syu --needed --noconfirm base-devel git

  local want=()
  mapfile -t want < <(pkglist "$REPO/packages/base.txt")
  grep -q GenuineIntel /proc/cpuinfo && want+=(intel-ucode)
  grep -q AuthenticAMD /proc/cpuinfo && want+=(amd-ucode)
  if has_nvidia; then
    mapfile -t -O "${#want[@]}" want < <(pkglist "$REPO/packages/hw-nvidia.txt"; nvidia_kernel_packages)
    ok "NVIDIA GPU found"
  fi
  if has_intel_gpu; then mapfile -t -O "${#want[@]}" want < <(pkglist "$REPO/packages/hw-intel.txt"); ok "Intel GPU found"; fi
  if has_amd_gpu; then mapfile -t -O "${#want[@]}" want < <(pkglist "$REPO/packages/hw-amd.txt"); ok "AMD GPU found"; fi
  if is_asus; then mapfile -t -O "${#want[@]}" want < <(pkglist "$REPO/packages/hw-asus.txt"); ok "ASUS laptop found"; fi

  local install=() missing=() p
  for p in "${want[@]}"; do
    if in_repos "$p"; then install+=("$p"); else missing+=("$p"); fi
  done
  sudo pacman -S --needed --noconfirm "${install[@]}"
  ok "${#install[@]} packages from the official repos"
  [ ${#missing[@]} -eq 0 ] || warn "not in your repos, skipped: ${missing[*]}"

  [ "$NO_AUR" = 1 ] && return
  install_yay
  local list=() repo=() aur=() base
  mapfile -t list < <(pkglist "$REPO/packages/aur.txt")
  if is_asus; then mapfile -t -O "${#list[@]}" list < <(pkglist "$REPO/packages/hw-asus-aur.txt"); fi
  if ask "Install DaVinci Resolve too? (big download, built from the AUR)"; then
    mapfile -t -O "${#list[@]}" list < <(pkglist "$REPO/packages/optional-aur.txt")
  fi
  for p in "${list[@]}"; do
    # some distros (CachyOS, EndeavourOS...) have these in their own repos, use that when they do
    base="${p%-bin}"; base="${base%-git}"
    if installed "$p" || installed "$base"; then continue
    elif in_repos "$p"; then repo+=("$p")
    elif in_repos "$base"; then repo+=("$base")
    else aur+=("$p"); fi
  done
  [ ${#repo[@]} -eq 0 ] || sudo pacman -S --needed --noconfirm "${repo[@]}"
  if [ ${#aur[@]} -gt 0 ]; then
    step "AUR packages (${#aur[@]})"
    yay -S --needed --noconfirm --answerdiff None --answerclean None "${aur[@]}" || warn "some AUR packages failed, see above"
  fi
}

# ---------------------------------------------------------------- dotfiles
install_dotfiles() {
  step "Dotfiles  (old files go to $BACKUP)"
  local n=0 src rel dst tmp
  while IFS= read -r -d '' src; do
    rel="${src#"$REPO/home/"}"; dst="$HOME/$rel"
    mkdir -p "$(dirname "$dst")"
    tmp=$(mktemp)
    sed "s#__HOME__#$HOME#g" "$src" >"$tmp"
    if [ -e "$dst" ] && ! cmp -s "$tmp" "$dst"; then
      mkdir -p "$BACKUP/$(dirname "$rel")"
      mv "$dst" "$BACKUP/$rel"
    fi
    mv "$tmp" "$dst"
    if [ -x "$src" ]; then chmod 755 "$dst"; else chmod 644 "$dst"; fi
    n=$((n + 1))
  done < <(find "$REPO/home" -type f -print0)
  ok "$n files in place"

  # folders the configs expect
  mkdir -p "$HOME"/{Desktop,Documents,Downloads,Music,Public,Templates,Videos,Projects,Games/PS2,Games/PSP,Games/Launchers,Pictures/Walpappers}
  if command -v xdg-user-dirs-update >/dev/null; then xdg-user-dirs-update; fi
  if [ -z "$(ls -A "$HOME/Pictures/Walpappers" 2>/dev/null)" ]; then
    cp "$REPO"/wallpapers/*.png "$HOME/Pictures/Walpappers/"
    ok "starter wallpapers copied to ~/Pictures/Walpappers"
  fi
  if command -v update-desktop-database >/dev/null; then update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true; fi
}

# ---------------------------------------------------------------- system
enable_unit() {
  systemctl cat "$1" &>/dev/null || return 0
  if sudo systemctl enable "$1" &>/dev/null; then ok "enabled $1"; else warn "could not enable $1"; fi
}

setup_system() {
  step "System settings"
  # tweaks taken from CachyOS: zram, sysctl, io schedulers, ntsync, Hyprland env
  local f rel u
  while IFS= read -r -d '' f; do
    rel="${f#"$REPO/system/"}"
    case "$rel" in
      etc/modprobe.d/maia-nvidia.conf) has_nvidia || continue ;;
      etc/greetd/*) continue ;;
    esac
    sudo install -Dm644 "$f" "/$rel"
  done < <(find "$REPO/system/etc" -type f -print0)
  sudo sysctl --system &>/dev/null || true
  ok "system tweaks in /etc (zram, sysctl, io schedulers, ntsync)"
  if has_nvidia && command -v mkinitcpio >/dev/null; then
    sudo mkinitcpio -P &>/dev/null && ok "rebuilt the initramfs for NVIDIA" || warn "mkinitcpio -P failed, run it yourself"
  fi

  if command -v fish >/dev/null && [ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v fish)" ]; then
    sudo chsh -s "$(command -v fish)" "$USER" && ok "fish is now your shell"
  fi
  if getent group realtime >/dev/null; then sudo usermod -aG realtime "$USER"; fi

  # NetworkManager, unless the system already uses systemd-networkd
  systemctl is-enabled systemd-networkd &>/dev/null || enable_unit NetworkManager
  for u in bluetooth ufw avahi-daemon power-profiles-daemon switcheroo-control ananicy-cpp fstrim.timer \
           supergfxd snapper-cleanup.timer limine-snapper-sync; do
    enable_unit "$u"
  done
  if has_nvidia; then enable_unit nvidia-powerd; fi

  # login screen: Noctalia greeter on greetd
  if installed noctalia-greeter && installed greetd; then
    if [ -f /etc/greetd/config.toml ] && [ ! -f /etc/greetd/config.toml.maia-bak ]; then
      sudo cp /etc/greetd/config.toml /etc/greetd/config.toml.maia-bak
    fi
    sudo install -Dm644 "$REPO/system/etc/greetd/config.toml" /etc/greetd/config.toml
    if [ -f /usr/share/noctalia-greeter/setup_greetd_pam.sh ]; then
      sudo bash /usr/share/noctalia-greeter/setup_greetd_pam.sh >/dev/null || true
    fi
    for u in sddm gdm lightdm ly lxdm; do sudo systemctl disable "$u" &>/dev/null || true; done
    sudo systemctl enable greetd &>/dev/null && ok "Noctalia login screen (greetd)"
  fi

  if command -v asusctl >/dev/null; then
    asusctl aura effect rainbow-cycle --speed med &>/dev/null && ok "keyboard RGB: rainbow" || true
  fi

  # OneDrive sync timer only makes sense once rclone has a "onedrive" remote
  systemctl --user daemon-reload || true
  if command -v rclone >/dev/null && rclone listremotes 2>/dev/null | grep -qx 'onedrive:'; then
    systemctl --user enable --now onedrive-sync.timer && ok "OneDrive sync every 5 min"
  else
    warn "OneDrive sync is off. See the README if you want it."
  fi
}

# ---------------------------------------------------------------- apps
setup_apps() {
  if command -v code >/dev/null; then
    step "VS Code extensions"
    local ext
    while read -r ext; do
      if code --install-extension "$ext" --force &>/dev/null; then printf '.'; else printf 'x'; fi
    done < <(pkglist "$REPO/packages/vscode-extensions.txt")
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
  warn "PS2 BIOS is not included: put it in ~/Documents/PCSX2/bios"
}

# ---------------------------------------------------------------- run
if [ "$DOTFILES_ONLY" = 1 ]; then
  install_dotfiles
else
  if ask "Install packages?"; then install_packages; fi
  install_dotfiles
  if ask "Apply system settings?"; then setup_system; fi
  if ask "Set up VS Code / Neovim?"; then setup_apps; fi
  if ask "Add PS2/PSP games to Steam & Heroic?"; then setup_gaming; fi
fi

step "Done"
if [ -d "$BACKUP" ]; then echo "  Your old files are in $BACKUP"; fi
echo "  Reboot to start MAIA."
