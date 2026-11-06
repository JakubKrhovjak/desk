#!/bin/bash
# Spustí hyprsunset s uloženým nastavením Night Shiftu z panelu.
state="$HOME/.config/desk/nightshift.json"

if [ "$(jq -r '.enabled // false' "$state" 2>/dev/null)" = "true" ]; then
    exec hyprsunset --temperature "$(jq -r '.temperature // 4000' "$state")"
fi
exec hyprsunset --identity
