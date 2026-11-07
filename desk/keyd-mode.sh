#!/bin/bash
# Nastaví klávesu Command v keyd podle aktivní aplikace: keyd-mode.sh base|ghostty|idea|off
# Command je levý Alt jako na Macu: držení = Ctrl (vrstva cmd v /etc/keyd/desk-cmd).
# Klávesa s logem Windows je Super pro práci s okny, ťuknutí = F24 (menu aplikací). Pravý Alt zůstává (na us běžný Alt, na cz AltGr).

base=(
    'main.hostalt=layer(cmd)'
    'main.hostwin=overload(vt,f24)'
    'main.hostaltgr=layer(altgr)'
)

# Terminál jako na Macu: Cmd posílá Super a zkratky super+… jsou v ~/.config/ghostty/config. Nová zkratka patří do obou seznamů. Ostatní Cmd + … nedělají
# nic, protože Ctrl v terminálu posílá signály (Z pozastaví proces, D ukončí shell). Q, M, H, mezerník a Tab zůstávají na systémových zkratkách.
ghostty=(
    $(printf 'cmd.%s=noop ' {a..g} {i..l} {n..p} {r..z} backslash slash semicolon dot)
    $(printf '%s\n' c v a t n w k d p {0..9} minus equal leftbrace rightbrace comma enter backspace | sed 's/.*/cmd.&=M-&/')
)

# IntelliJ s mapou macOS: Cmd = Ctrl, fyzický Ctrl = Meta (v mapě jsou prohozené); Cmd + šipky řeší mapa, ne Home a End z vrstvy
idea=(
    'main.leftcontrol=layer(meta)'
    'main.rightcontrol=layer(meta)'
    $(printf '%s\n' left right up down | sed 's/.*/cmd.&=C-&/')
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
