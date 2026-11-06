#!/bin/sh
# Spuštění správce souborů Files z nabídky nebo z aplikace, která otevírá složku.
# Files jsou výchozí správce složek ve všech sezeních, proto i v záložní Caelestii.
if [ -n "${1:-}" ]; then
    set -- openPath "$1"
else
    set -- open
fi
qs -c desk ipc call files "$@" 2>/dev/null || exec qs -c caelestia ipc call files "$@"
