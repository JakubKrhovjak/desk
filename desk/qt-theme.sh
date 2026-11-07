#!/bin/bash
# Vzhled aplikací v Qt přes qt6ct: styl Fusion, ikony podle cli.json a paleta z barevného schématu Caelestie.
# Spouští se při startu sezení a po změně schématu (shell.qml). Běžící aplikace nové barvy uvidí až po restartu.
set -euo pipefail

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
scheme="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/scheme.json"
target="$config_dir/qt6ct"
colours="$target/colors/caelestia.conf"
icon_theme=$(jq -r '.theme.iconTheme // "Desk"' "$config_dir/caelestia/cli.json" 2>/dev/null || echo Desk)

# Pořadí rolí palety určuje qt6ct: WindowText, Button, Light, Midlight, Dark, Mid, Text, BrightText, ButtonText, Base, Window,
# Shadow, Highlight, HighlightedText, Link, LinkVisited, AlternateBase, NoRole, ToolTipBase, ToolTipText, PlaceholderText
palette() { # $1 = barva textu
    jq -er --arg text "$1" '.colours as $c
        | [$text, "surfaceContainerHigh", "surfaceBright", "surfaceContainerHighest", "surfaceContainerLowest", "outlineVariant",
           $text, "error", $text, "surface", "surfaceContainer", "shadow", "primary", "onPrimary", "klink", "kvisited",
           "surfaceContainerLow", "surface", "surfaceContainerHigh", $text, "outline"]
        | map("#ff" + $c[.]) | join(", ")' "$scheme"
}

write_file() { # $1 = cíl, obsah na vstupu; přes přejmenování, aby aplikace nikdy nečetla napůl zapsaný soubor
    cat > "$1.tmp"
    mv "$1.tmp" "$1"
}

active=$(palette onSurface)
disabled=$(palette outline)

mkdir -p "$target/colors"
write_file "$colours" <<EOF
[ColorScheme]
active_colors=$active
disabled_colors=$disabled
inactive_colors=$active
EOF

write_file "$target/qt6ct.conf" <<EOF
[Appearance]
color_scheme_path=$colours
custom_palette=true
icon_theme=$icon_theme
standard_dialogs=default
style=Fusion

[Fonts]
fixed="Monospace,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
general="Sans Serif,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"

[Interface]
activate_item_on_single_click=0
menus_have_icons=true
EOF
