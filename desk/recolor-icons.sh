#!/bin/bash
# Přebarví ikony motivu Simpleton podle barevného schématu Caelestie a doplní ikony, které v motivu chybí.
# Spouští se při startu shellu a po změně schématu (shell.qml). Dá se pouštět opakovaně.
set -uo pipefail

theme="$HOME/.local/share/icons/Simpleton"
apps="$theme/scalable/apps"
scheme="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/scheme.json"

colour_of() { jq -r --arg name "$1" '(.colours // .)[$name] // empty' "$scheme"; }

icon_colour=$(colour_of secondary)
tint_colour=$(colour_of primary)
[[ $icon_colour =~ ^[0-9a-fA-F]{6}$ && $tint_colour =~ ^[0-9a-fA-F]{6}$ ]] || { echo "recolor-icons: ve schématu chybí barvy" >&2; exit 1; }

# Vlastní ikony aplikací: kopie z repa, ať se přebarví s ostatními (desk/icons má barvu v .ColorScheme-Text)
desk_dir=$(dirname "$(realpath "$0")")
install -m644 "$desk_dir"/icons/*.svg "$apps/"

# Tyhle aplikace míří na obrázek ve svém projektu, který se nepřebarví; vrací je to na ikonu motivu
use_theme_icon() { # $1 = soubor .desktop, $2 = jméno ikony v motivu
    local entry="$HOME/.local/share/applications/$1"
    [[ -f $entry ]] && sed -i -E "s|^Icon=/.*|Icon=$2|" "$entry"
}
use_theme_icon arch-assistant.desktop arch-assistant
use_theme_icon mindmap.desktop mindmap
use_theme_icon mindmap-linux.desktop mindmap
use_theme_icon modbus-gui.desktop modbus-gui
use_theme_icon openplc-editor.desktop openplc-editor

# Barva čar je v každém souboru jen v .ColorScheme-Text, jemný podklad v přechodu stop-color
find "$theme/scalable" -type f -name '*.svg' -print0 | xargs -0 sed -i -E \
    -e "s/(\.ColorScheme-Text \{ color:#)[0-9a-fA-F]{6}/\1$icon_colour/" \
    -e "s/(stop-color=\"#)[0-9a-fA-F]{6}/\1$tint_colour/g"

alias_icon() { # $1 = jméno, které aplikace hledá, $2 = existující ikona motivu
    [[ -e "$apps/$2.svg" && ! -e "$apps/$1.svg" ]] && ln -s "$2.svg" "$apps/$1.svg"
}

# Toolbox dává IDE po každé instalaci nové jméno ikony s UUID, kreslí se pořád stejnou ikonou daného IDE
for entry in "$HOME"/.local/share/applications/jetbrains-*-*.desktop; do
    icon=$(sed -n 's/^Icon=//p' "$entry" | head -n 1)
    [[ $icon == jetbrains-* ]] || continue
    product=${icon%%-[0-9a-f]*-[0-9a-f]*-[0-9a-f]*-[0-9a-f]*-[0-9a-f]*}
    existing=$(find "$apps" -maxdepth 1 -type f -name "$product-*.svg" -printf '%f\n' | head -n 1)
    [[ -n $existing ]] && alias_icon "$icon" "${existing%.svg}"
done

alias_icon com.mitchellh.ghostty utilities-terminal
alias_icon btop utilities-system-monitor
alias_icon chromium brave-desktop
alias_icon com.saivert.pwvucontrol multimedia-volume-control

gtk-update-icon-cache -f -q -t "$theme" 2>/dev/null
exit 0
