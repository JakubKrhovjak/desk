#!/bin/bash
# Dokončí instalaci po naklonování repozitáře, postup je v README.md. Opakované spuštění je bezpečné.
# Použití: install.sh              všechno včetně systémových částí (přes sudo)
#          install.sh --user-only  jen části v domovské složce
set -euo pipefail

desk_dir=$(dirname "$(realpath "$0")")
config_dir=$(dirname "$desk_dir")
caelestia_dir="$config_dir/quickshell/caelestia"
desk_git_dir="$HOME/.local/share/desk.git"
packages=(hyprland hyprsunset caelestia-shell quickshell-git jq rsync keyd ghostty wl-clipboard cliphist bluez-utils gnome-keyring polkit-gnome xorg-xrandr make gcc cmake cpio pkgconf papirus-icon-theme qt6ct adw-gtk-theme papers loupe gnome-text-editor udisks2 udiskie libayatana-appindicator system-config-printer)

say() { printf '==> %s\n' "$*"; }

check_packages() {
    local missing
    missing=$(pacman -T "${packages[@]}" | tr '\n' ' ' || true)
    [ -z "$missing" ] && return
    say "Chybějící balíčky: $missing"
    [ "${user_only:-false}" = true ] && { echo "Nainstaluj je: yay -S --needed $missing" >&2; exit 1; }
    # shellcheck disable=SC2086 # missing je záměrně seznam oddělený mezerami
    yay -S --needed --noconfirm $missing
}

# Nastavení mimo repozitář (shell, Qt, GTK): výchozí hodnoty jen na čistém systému, existující soubory se nepřepisují
setup_defaults() {
    say "Výchozí nastavení shellu a vzhledu"
    rsync -a --ignore-existing --exclude /state/ "$desk_dir/defaults/" "$config_dir/"
    # Osobní nastavení desku (panel, monitory, autostart, myš) je mimo git; start.sh doplňuje totéž při každém startu
    local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/desk"
    mkdir -p "$state_dir"
    rsync -a --ignore-existing "$desk_dir/defaults/state/" "$state_dir/"
}

# Schéma Simpleton a tapeta; bez něj by Hyprland zůstal na záložních barvách z colours.lua
setup_scheme() {
    [ -e "${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/scheme.json" ] && return 0
    say "Barevné schéma Simpleton"
    "$desk_dir/season-scheme.py" simpleton || say "Schéma se nepodařilo nastavit, později stačí spustit desk/season-scheme.py simpleton"
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

# Živá kopie se přebarvuje podle schématu (recolor-icons.sh), proto mimo git; existující soubory se nepřepisují
setup_icons() {
    say "Motiv ikon Desk"
    local icons="$HOME/.local/share/icons"
    mkdir -p "$icons"
    # Dřív se motiv jmenoval Simpleton a míchal se do Plasmy se stejnojmenným motivem z instalace Archu; přesune se jednou
    if [ ! -e "$icons/Desk" ] && grep -qs 'desk/build-icon-theme.sh' "$icons/Simpleton/index.theme"; then
        mv "$icons/Simpleton" "$icons/Desk"
        sed -i 's/^Name=Simpleton$/Name=Desk/' "$icons/Desk/index.theme"
    fi
    local cli="$config_dir/caelestia/cli.json"
    if [ "$(jq -r '.theme.iconTheme // empty' "$cli" 2>/dev/null)" = Simpleton ]; then
        jq '.theme.iconTheme = "Desk"' "$cli" > "$cli.tmp" && mv "$cli.tmp" "$cli"
    fi
    rsync -a --ignore-existing "$desk_dir/icon-theme/Desk" "$icons/"
    "$desk_dir/build-icon-theme.sh"
}

# Odkazy, aby tapety ročních období byly vidět i ve výběru tapet v Nastavení
setup_wallpapers() {
    say "Tapety ročních období"
    mkdir -p "$HOME/Pictures/Wallpapers"
    ln -sf "$desk_dir"/wallpapers/*.jpg "$HOME/Pictures/Wallpapers/"
}

# Files jsou výchozí správce složek; položka má plnou cestu, proměnné v Exec se nerozvíjí
setup_files() {
    say "Správce souborů Files"
    mkdir -p "$HOME/.local/share/applications"
    printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=Files' 'Comment=Two-pane file browser' "Exec=$desk_dir/files-open.sh %f" 'Icon=folder' 'MimeType=inode/directory;' > "$HOME/.local/share/applications/caelestia-files.desktop"
    xdg-mime default caelestia-files.desktop inode/directory
}

# Vzhled aplikací v Qt potřebuje schéma, proto až po setup_scheme
setup_qt() {
    say "Vzhled aplikací v Qt"
    "$desk_dir/qt-theme.sh" || say "Vzhled Qt se nepodařilo nastavit, později stačí spustit desk/qt-theme.sh"
}

# Výchozí aplikace pro všechny typy, které umí otevřít: PDF, obrázky a textové soubory
setup_viewers() {
    say "Výchozí prohlížeč PDF a obrázků a textový editor"
    local app
    for app in org.gnome.Papers org.gnome.Loupe org.gnome.TextEditor; do
        # shellcheck disable=SC2046 # seznam typů se má rozdělit na jednotlivé argumenty
        xdg-mime default "$app.desktop" $(sed -n 's/^MimeType=//p' "/usr/share/applications/$app.desktop" | tr ';' ' ')
    done
}

# Mapa kláves, se kterou počítá keyd-mode.sh; v IDE se vybírá ručně, existující soubor se nepřepisuje
setup_idea() {
    say "Mapa kláves macOS Cmd pro IntelliJ"
    local dir
    for dir in "$HOME"/.config/JetBrains/IntelliJIdea*/; do
        [ -d "$dir" ] || continue
        mkdir -p "$dir/keymaps"
        rsync -a --ignore-existing "$desk_dir/jetbrains/macOS Cmd.xml" "$dir/keymaps/"
    done
}

setup_user() {
    say "Příkazy desk-update a desk-deploy"
    mkdir -p "$HOME/.local/bin"
    ln -sfn "$desk_dir/desk-update.sh" "$HOME/.local/bin/desk-update"
    ln -sfn "$desk_dir/desk-deploy.sh" "$HOME/.local/bin/desk-deploy"
    if [ -x "$desk_dir/plugins/hyprbars.so" ]; then
        say "hyprbars už je zkompilovaný"
    else
        # Bez pluginu jsou okna jen bez lišt, zbytek instalace na něm nezávisí
        "$desk_dir/desk-update.sh" --hyprbars || say "hyprbars se nepodařilo zkompilovat, později stačí spustit desk-update --hyprbars"
    fi
}

# Správce přihlášení nerozvíjí proměnné v Exec, proto se položka generuje s plnou cestou
setup_system() {
    say "Položka Desk ve správci přihlášení"
    printf '%s\n' '[Desktop Entry]' 'Name=Desk' 'Comment=Custom desktop on Hyprland' "Exec=$desk_dir/start.sh" 'Type=Application' 'DesktopNames=Hyprland' | sudo tee /usr/share/wayland-sessions/desk.desktop >/dev/null

    say "keyd"
    sudo systemctl enable --now keyd
    sudo usermod -aG keyd "$USER"
    "$desk_dir/system/install-keyd.sh"

    say "Přihlašovací obrazovka"
    "$desk_dir/greeter/install.sh"
}

[ "${1:-}" = "--user-only" ] && user_only=true
check_packages
setup_caelestia
setup_exclude
setup_defaults
setup_icons
setup_wallpapers
setup_scheme
setup_qt
setup_files
setup_viewers
setup_idea
setup_user
[ "${user_only:-false}" = true ] || setup_system
say "Hotovo. Po odhlášení vyber ve správci přihlášení Desk. Co je potřeba doladit ručně, je v README.md."
