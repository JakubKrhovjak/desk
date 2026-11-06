#!/bin/bash
# Restart shellu desk přes Hyprland, aby dostal jeho prostředí (DESK_MAIN_MONITOR určuje monitor s panelem).
# Zamčený shell se nerestartuje, zámek by tím zmizel. Restart zavře okna shellu, třeba Nastavení.

[[ $(qs -c desk ipc call lock isLocked 2>/dev/null | tail -n 1) == true ]] && { echo "obrazovka je zamčená, restart vynechán" >&2; exit 1; }

pid=$(pgrep -x qs -a | awk '/qs -c desk/ { print $1 }')
[[ -n $pid ]] && kill "$pid"
while [[ -n $pid ]] && kill -0 "$pid" 2>/dev/null; do sleep 0.1; done

hyprctl eval 'hl.exec_cmd("qs -c desk -n -d")' >/dev/null
