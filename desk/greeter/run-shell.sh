#!/bin/sh
# Shell přihlašovací obrazovky pod jejím Hyprlandem; po přihlášení nebo pádu shellu Hyprland ukončí.
# Selhání si start.sh pozná podle značky a spustí záložní textové přihlášení.
qs -p /usr/share/desk-greeter/shell.qml || touch "$XDG_RUNTIME_DIR/desk-greeter-failed"
hyprctl eval 'hl.dispatch(hl.dsp.exit())'
