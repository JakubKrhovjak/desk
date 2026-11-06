#!/bin/sh
# Aplikace po přihlášení, seznam nastavuje Nexus (Apps → aplikace → Startup).
# Spouští se až po startu shellu, protože ikonu v trayi registrují u jeho StatusNotifierWatcheru
# a například Toolbox to později už nezkusí znovu.

config=${1:-$HOME/.config/desk/autostart.json}

attempts=0
while [ "$attempts" -lt 60 ] && ! busctl --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1; do
    sleep 0.5
    attempts=$((attempts + 1))
done

# Skrytý start: okno se otevře ve special:minimized, odkud ho vrátí klik v panelu.
# Toolbox umí vlastní přepínač a žádné okno neotevře.
tab=$(printf '\t')
jq -r 'to_entries[]
    | (.key == "jetbrains-toolbox" and .value.tray) as $own_flag
    | "\(if .value.tray and ($own_flag | not) then "hidden" else "normal" end)\t\(.value.command + (if $own_flag then ["--minimize"] else [] end) | @sh)"' "$config" |
    while IFS="$tab" read -r mode command; do
        rules=""
        [ "$mode" = "hidden" ] && rules=", { workspace = 'special:minimized silent' }"
        hyprctl eval "hl.dispatch(hl.dsp.exec_cmd([==[$command]==]$rules))" >/dev/null
    done
