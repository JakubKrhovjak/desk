#!/bin/bash
# Toolbox si ikonu v trayi zaregistruje jen jednou při svém startu. Když se restartuje shell, přijde o ni,
# proto ho po startu shellu znovu spustí, pokud běží a ikonu nemá. Pouští se ze shell.qml.
# Čerstvě spuštěnému Toolboxu nechá čas na registraci a zkouší to znovu, takže to zvládne i víc restartů shellu za sebou.

registration_seconds=30

for _ in {1..24}; do
    sleep 5

    items=$(busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null) || continue
    [[ $items == *com.jetbrains.toolbox* ]] && exit 0

    pid=$(pgrep -x jetbrains-toolb | head -n 1)
    [[ -z $pid ]] && exit 0
    (( $(ps -o etimes= -p "$pid") < registration_seconds )) && continue

    kill "$pid"
    while kill -0 "$pid" 2>/dev/null; do sleep 0.5; done
    hyprctl eval "hl.exec_cmd([==[/opt/jetbrains-toolbox/jetbrains-toolbox --minimize]==])" >/dev/null
done
