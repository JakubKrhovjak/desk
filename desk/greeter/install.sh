#!/bin/bash
# Nainstaluje přihlašovací obrazovku do /usr/share/desk-greeter a nastaví ji v greetd; opakované spuštění je bezpečné.
# Bere aktuální barvy, tapetu a hlavní monitor, po jejich změně stačí spustit znovu. Projeví se při dalším přihlášení.
set -euo pipefail

source_dir=$(dirname "$(realpath "$0")")
desk_dir=$(dirname "$source_dir")
target=/usr/share/desk-greeter
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia"

# Grafická obrazovka potřebuje Hyprland a Quickshell, které instaluje desk/install.sh; jinde se greetd nepoužívá
systemctl is-enabled -q greetd || { echo "greetd není zapnutý, přihlašovací obrazovka se neinstaluje" >&2; exit 0; }

wallpaper=$(cat "$state_dir/wallpaper/path.txt" 2>/dev/null || true)
[ -r "$wallpaper" ] || wallpaper="$desk_dir/wallpapers/simpleton.jpg"

# Dokud neběžel setup z prvního přihlášení, spouští se přes něj; desk-session.sh pak rovnou pustí desk
session="$HOME/arch-setup/desk-session.sh"
[ -x "$session" ] || session="$desk_dir/start.sh"

main=$(sed -n -E 's/^\s*main = "([^"]+)".*/\1/p' "${XDG_STATE_HOME:-$HOME/.local/state}/desk/monitor-settings.lua" 2>/dev/null | head -n 1 || true)

settings=$(mktemp)
trap 'rm -f "$settings"' EXIT
jq -n --arg user "$USER" --arg command "$session" --arg main "$main" --slurpfile scheme "$state_dir/scheme.json" \
    '{user: $user, command: [$command], main: $main, colours: $scheme[0].colours}' > "$settings"

sudo install -d "$target"
sudo install -m644 "$source_dir/shell.qml" "$source_dir/hyprland.lua" "$target/"
sudo install -m755 "$source_dir/start.sh" "$source_dir/run-shell.sh" "$target/"
sudo install -m644 "$settings" "$target/settings.json"
sudo install -m644 "$wallpaper" "$target/wallpaper.jpg"

config=$(printf '%s\n' '[terminal]' 'vt = 1' '' '[default_session]' "command = \"$target/start.sh\"" 'user = "greeter"')
# Běžící greetd čte konfiguraci jen při startu a jeho restart by ukončil přihlášené sezení; soubory obrazovky čte při každém spuštění znovu
if [ "$(cat /etc/greetd/config.toml)" = "$config" ]; then
    echo "Přihlašovací obrazovka je nainstalovaná, projeví se při dalším přihlášení"
else
    printf '%s\n' "$config" | sudo tee /etc/greetd/config.toml >/dev/null
    echo "Přihlašovací obrazovka je nainstalovaná, projeví se po restartu počítače"
fi
