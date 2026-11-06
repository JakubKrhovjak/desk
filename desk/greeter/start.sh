#!/bin/sh
# Příkaz, který spouští greetd. Když grafická přihlašovací obrazovka nevydrží, nabídne textovou, aby šlo přihlásit se vždycky.
dir=/usr/share/desk-greeter
failed="$XDG_RUNTIME_DIR/desk-greeter-failed"
rm -f "$failed"

# Uživatel greeter má jako domov /, kam nesmí zapisovat; cache a stav se při restartu zahodí, nic v nich nepotřebuje
export XDG_CACHE_HOME="$XDG_RUNTIME_DIR/cache" XDG_CONFIG_HOME="$XDG_RUNTIME_DIR/config" XDG_STATE_HOME="$XDG_RUNTIME_DIR/state" XDG_DATA_HOME="$XDG_RUNTIME_DIR/data"

start-hyprland -- -c "$dir/hyprland.lua"
status=$?

[ "$status" -eq 0 ] && [ ! -e "$failed" ] && exit 0
exec tuigreet --time --remember --asterisks --cmd "$(jq -r '.command | join(" ")' "$dir/settings.json")"
