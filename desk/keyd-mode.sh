#!/bin/bash
# Nastaví klávesu Command v keyd podle aktivní aplikace: keyd-mode.sh base|ghostty|idea|off
# Klávesa s logem Windows: držení = Ctrl (vrstva cmd v /etc/keyd/desk-cmd), ťuknutí = F24 (menu aplikací).

base=(
    'main.hostcmd=overload(cmd,f24)'
    'main.hostalt=layer(alt)'
    'main.hostaltgr=layer(altgr)'
)

# Terminál jako na Macu: Cmd posílá Super a zkratky super+… jsou v ~/.config/ghostty/config. Ostatní Cmd + … nedělají
# nic, protože Ctrl v terminálu posílá signály (Z pozastaví proces, D ukončí shell). F, Q a šipky zůstávají na oknech.
ghostty=(
    $(printf 'cmd.%s=noop ' {a..e} {g..p} {r..z} backslash slash semicolon dot)
    $(printf '%s\n' c v a t n w k d p {0..9} minus equal leftbrace rightbrace comma enter backspace | sed 's/.*/cmd.&=M-&/')
)

# IntelliJ s mapou macOS: Cmd = Ctrl, fyzický Ctrl = Meta (v mapě jsou prohozené)
idea=(
    'main.leftcontrol=layer(meta)'
    'main.rightcontrol=layer(meta)'
)

case "$1" in
    base) bindings=("${base[@]}") ;;
    ghostty) bindings=("${base[@]}" "${ghostty[@]}") ;;
    idea) bindings=("${base[@]}" "${idea[@]}") ;;
    off) bindings=() ;;
    *) echo "použití: $0 base|ghostty|idea|off" >&2; exit 2 ;;
esac

# Přístup má skupina keyd; než se po jejím přidání uživatel znovu přihlásí, jde to přes sudo
command=(keyd bind reset "${bindings[@]}")
"${command[@]}" 2>/dev/null || sudo -n "${command[@]}"
