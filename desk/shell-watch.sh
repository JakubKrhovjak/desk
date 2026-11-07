#!/bin/bash
# Drží shell naživu: po pádu ho spustí znovu, dokud běží Hyprland. Startuje ho Hyprland, aby shell dostal jeho prostředí.
# Spadl-li shell na zamčené obrazovce, Hyprland zůstane zamčený bez možnosti zadat heslo; nový shell proto zámek převezme
# (misc.allow_session_lock_restore v hyprland.lua). Zastaví se po pěti rychlých koncích za sebou.
quick_exits=0

# Oznámení obstarává právě shell; když neběží, notify-send by čekal navždy, proto na pozadí s časovým limitem
warn() { timeout 5 notify-send -u critical "Desk" "$1" & }

is_locked() { [[ $(hyprctl -j locked 2>/dev/null | jq -r .locked) == true ]]; }

relock() {
    local _
    for _ in $(seq 1 40); do
        qs -c desk ipc call lock lock >/dev/null 2>&1
        [[ $(qs -c desk ipc call lock isLocked 2>/dev/null | tail -n 1) == true ]] && return 0
        sleep 0.25
    done
    return 1
}

while hyprctl version >/dev/null 2>&1; do
    was_locked=false
    is_locked && was_locked=true
    started=$SECONDS
    qs -c desk -n &
    shell=$!
    $was_locked && { relock || warn "Zámek se po pádu shellu nepodařilo obnovit"; }
    wait "$shell"
    (( SECONDS - started < 10 )) && (( quick_exits += 1 )) || quick_exits=0
    if (( quick_exits >= 5 )); then
        warn "Shell opakovaně padá, automatické spouštění je vypnuté. Log: qs -c desk log, znovu: desk/restart-shell.sh"
        exit 1
    fi
    sleep 1
done
