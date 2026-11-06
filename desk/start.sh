#!/bin/bash
# Spuštění prostředí desk; po odhlášení vrátí klávesnici a tlačítka oken do výchozího stavu pro Plasmu a Caelestii.
/usr/bin/start-hyprland -- -c "$HOME/.config/desk/hyprland.lua"
"$HOME/.config/desk/keyd-mode.sh" off
gsettings set org.gnome.desktop.wm.preferences button-layout 'icon:minimize,maximize,close'
