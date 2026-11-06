#!/bin/bash
# Spuštění prostředí desk; po odhlášení vrátí klávesnici a tlačítka oken do výchozího stavu pro Plasmu a Caelestii.
desk_dir=$(dirname "$(realpath "$0")")

# Nepotvrzené rozložení monitorů (odhlášení nebo pád během odpočtu) nesmí přežít do dalšího přihlášení
previous_monitors="${XDG_STATE_HOME:-$HOME/.local/state}/desk/monitor-settings.previous.lua"
[ -f "$previous_monitors" ] && mv -f "$previous_monitors" "$desk_dir/monitor-settings.lua"

/usr/bin/start-hyprland -- -c "$desk_dir/hyprland.lua"
"$desk_dir/keyd-mode.sh" off
gsettings set org.gnome.desktop.wm.preferences button-layout 'icon:minimize,maximize,close'
