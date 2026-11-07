#!/bin/bash
# Krytí Ghostty v procentech z Nastavení. Ghostty ho čte z vloženého souboru (config-file v ghostty/config).
# Načtení přes D-Bus: signál by procesu bez obsluhy zavřel terminál se všemi sezeními.

opacity=$(awk -v percent="$1" 'BEGIN { printf "%.2f", percent / 100 }')
printf 'background-opacity = %s\n' "$opacity" > "$HOME/.config/ghostty/opacity"

gdbus call --session --dest com.mitchellh.ghostty --object-path /com/mitchellh/ghostty --method org.gtk.Actions.Activate reload-config '[]' '{}' >/dev/null 2>&1
