#!/bin/bash
# Spustí hyprsunset s uloženým nastavením Night Shiftu z panelu.
state="${XDG_STATE_HOME:-$HOME/.local/state}/desk/nightshift.json"

if [ "$(jq -r '.enabled // false' "$state" 2>/dev/null)" = "true" ]; then
    exec hyprsunset --temperature "$(jq -r '.temperature // 4000' "$state")"
fi
exec hyprsunset --identity
