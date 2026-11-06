#!/bin/bash
# Spuštění prostředí desk; po odhlášení vrátí klávesnici a tlačítka oken do výchozího stavu pro Plasmu a Caelestii.
desk_dir=$(dirname "$(realpath "$0")")
/usr/bin/start-hyprland -- -c "$desk_dir/hyprland.lua"
"$desk_dir/keyd-mode.sh" off
gsettings set org.gnome.desktop.wm.preferences button-layout 'icon:minimize,maximize,close'
