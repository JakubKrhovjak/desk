#!/bin/bash
# Obnoví konfiguraci keyd z kopie v repozitáři, třeba po přeinstalaci systému. Bez rozdílů nic nedělá.
# HP 720 sama posílá Alt a Win prohozené, proto je aliasy v hp720.conf opravdu potřebuje.
set -euo pipefail

source_dir=$(dirname "$(realpath "$0")")/keyd
target_dir=/etc/keyd

different=false
for file in "$source_dir"/*; do
    if ! sudo cmp -s "$file" "$target_dir/$(basename "$file")"; then
        echo "liší se: $(basename "$file")"
        different=true
    fi
done

if [[ $different == false ]]; then
    echo "konfigurace keyd je aktuální"
    exit 0
fi

sudo install -d "$target_dir"
for file in "$source_dir"/*; do
    sudo install -m644 "$file" "$target_dir/"
done
sudo keyd check
# keyd reload může spadnout a smazat vazby, proto restart a nové nastavení režimu
sudo systemctl restart keyd
"$(dirname "$source_dir")/../keyd-mode.sh" base
echo "konfigurace keyd je nainstalovaná"
