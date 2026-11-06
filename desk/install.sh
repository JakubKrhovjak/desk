#!/bin/bash
# Dokončí instalaci po naklonování repozitáře, postup je v README.md. Opakované spuštění je bezpečné.
# Použití: install.sh              všechno včetně systémových částí (přes sudo)
#          install.sh --user-only  jen části v domovské složce
set -euo pipefail

desk_dir=$(dirname "$(realpath "$0")")
config_dir=$(dirname "$desk_dir")
caelestia_dir="$config_dir/quickshell/caelestia"
desk_git_dir="$HOME/.local/share/desk.git"
packages=(hyprland hyprsunset caelestia-shell quickshell-git jq rsync keyd ghostty wl-clipboard cliphist bluez-utils gnome-keyring polkit-gnome xorg-xrandr make gcc cmake cpio pkgconf)

say() { printf '==> %s\n' "$*"; }

check_packages() {
    local missing
    missing=$(pacman -T "${packages[@]}" | tr '\n' ' ' || true)
    [ -z "$missing" ] && return
    say "Chybějící balíčky: $missing"
    [ "${user_only:-false}" = true ] && { echo "Nainstaluj je: yay -S --needed $missing" >&2; exit 1; }
    # shellcheck disable=SC2086 # missing je záměrně seznam oddělený mezerami
    yay -S --needed $missing
}

# Submodul se po klonu nachází mimo větev a bez lokální upstream; desk-update potřebuje obojí
setup_caelestia() {
    say "Caelestia: větve master a upstream"
    [ -e "$caelestia_dir/.git" ] || { echo "Chybí submodul $caelestia_dir, viz README.md" >&2; exit 1; }
    git -C "$caelestia_dir" symbolic-ref -q HEAD >/dev/null || git -C "$caelestia_dir" checkout -q master
    git -C "$caelestia_dir" rev-parse -q --verify refs/heads/upstream >/dev/null || git -C "$caelestia_dir" branch -q upstream origin/upstream
}

# info/exclude se neklonuje; bez něj by git status ukazoval celý ~/.config
setup_exclude() {
    say "Whitelist repozitáře desk"
    mkdir -p "$desk_git_dir/info"
    printf '%s\n' '/*' '!/README.md' '!/.gitmodules' '!/desk/' '/desk/plugins/' '!/quickshell/' '/quickshell/*' '!/quickshell/desk/' '!/quickshell/caelestia' '!/ghostty/' '/ghostty/*' '!/ghostty/config' > "$desk_git_dir/info/exclude"
}

setup_user() {
    say "Příkaz desk-update a stavová složka"
    mkdir -p "$HOME/.local/bin" "${XDG_STATE_HOME:-$HOME/.local/state}/desk"
    ln -sfn "$desk_dir/desk-update.sh" "$HOME/.local/bin/desk-update"
    if [ -x "$desk_dir/plugins/hyprbars.so" ]; then
        say "hyprbars už je zkompilovaný"
    else
        "$desk_dir/desk-update.sh" --hyprbars
    fi
}

# Správce přihlášení nerozvíjí proměnné v Exec, proto se položka generuje s plnou cestou
setup_system() {
    say "Položka Desk ve správci přihlášení"
    printf '%s\n' '[Desktop Entry]' 'Name=Desk' 'Comment=Vlastní prostředí nad Hyprlandem' "Exec=$desk_dir/start.sh" 'Type=Application' 'DesktopNames=Hyprland' | sudo tee /usr/share/wayland-sessions/desk.desktop >/dev/null

    say "keyd"
    sudo systemctl enable --now keyd
    sudo usermod -aG keyd "$USER"
    "$desk_dir/system/install-keyd.sh"
}

[ "${1:-}" = "--user-only" ] && user_only=true
check_packages
setup_caelestia
setup_exclude
setup_user
[ "${user_only:-false}" = true ] || setup_system
say "Hotovo. Po odhlášení vyber ve správci přihlášení Desk. Co je potřeba doladit ručně, je v README.md."
