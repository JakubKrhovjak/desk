#!/bin/bash
# Spuštění prostředí desk; po odhlášení vrátí klávesnici a tlačítka oken do výchozího stavu pro Plasmu a Caelestii.
desk_dir=$(dirname "$(realpath "$0")")
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/desk"

# Osobní nastavení je mimo git; co chybí (čistá instalace, nová položka), doplní výchozí hodnoty z repozitáře
mkdir -p "$state_dir"
cp -rn "$desk_dir/defaults/state/." "$state_dir/"

# Nepotvrzené rozložení monitorů (odhlášení nebo pád během odpočtu) nesmí přežít do dalšího přihlášení
previous_monitors="$state_dir/monitor-settings.previous.lua"
[ -f "$previous_monitors" ] && mv -f "$previous_monitors" "$state_dir/monitor-settings.lua"

/usr/bin/start-hyprland -- -c "$desk_dir/hyprland.lua"
"$desk_dir/keyd-mode.sh" off
gsettings set org.gnome.desktop.wm.preferences button-layout 'icon:minimize,maximize,close'
