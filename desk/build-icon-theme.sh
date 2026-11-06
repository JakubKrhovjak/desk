#!/bin/bash
# Doplní motiv Simpleton o ikony, které nekreslí sám (akce, typy souborů, zařízení, stav), kopií z balíčku papirus-icon-theme.
# Motiv pak nezávisí ani na Papirusu, ani na Breeze. Vlastní ikony Simpletonu mají přednost, opakované spuštění je bezpečné.
# Použití: build-icon-theme.sh [cílový adresář motivu]
set -euo pipefail

desk_dir=$(dirname "$(realpath "$0")")
theme=${1:-$HOME/.local/share/icons/Simpleton}
index_source="$desk_dir/icon-theme/Simpleton/index.theme"
papirus=/usr/share/icons/Papirus
papirus_dark=/usr/share/icons/Papirus-Dark
sizes=(16 22 24 32 48 64)
contexts=(actions devices emblems mimetypes places status)

[ -d "$papirus_dark" ] && [ -d "$papirus" ] || { echo "Chybí balíček papirus-icon-theme" >&2; exit 1; }
[ -d "$theme/scalable" ] || { echo "V $theme chybí scalable/, nejdřív zkopíruj desk/icon-theme/Simpleton" >&2; exit 1; }

# Co Simpleton kreslí sám, se nekopíruje, jinak by Papirus v přesné velikosti vyhrál nad škálovatelnou ikonou
own_names=$(mktemp)
trap 'rm -f "$own_names"' EXIT
find "$theme/scalable" \( -type f -o -type l \) -name '*.svg' -printf '%f\n' | sort -u > "$own_names"

copy_context() { # zdrojový adresář, cílový adresář (uvnitř motivu)
    [ -d "$1" ] || return 0
    mkdir -p "$theme/$2"
    rsync -a --copy-unsafe-links --exclude-from="$own_names" "$(realpath "$1")/" "$theme/$2/"
}

for size in "${sizes[@]}"; do
    rm -rf "${theme:?}/${size}x${size}"
    for context in "${contexts[@]}"; do
        # Papirus-Dark je kopírovaný naposled: jeho světlé varianty pro tmavé pozadí přepíší ty ze základního motivu
        copy_context "$papirus/${size}x${size}/$context" "${size}x${size}/$context"
        copy_context "$papirus_dark/${size}x${size}/$context" "${size}x${size}/$context"
    done
    # Symbolické ikony pro GTK, v Papirusu mají vlastní podadresář
    copy_context "$papirus/${size}x${size}/symbolic" "${size}x${size}/symbolic"
    copy_context "$papirus_dark/${size}x${size}/symbolic" "${size}x${size}/symbolic"
done

# Odkazy, které mířily na vynechané ikony (třeba na aplikace), by v motivu jen překážely
find "$theme" -xtype l -delete

# index.theme: vlastní část z repozitáře, popis zkopírovaných adresářů z Papirus-Dark
copied=$(cd "$theme" && find . -name '*.svg' ! -path './scalable/*' -printf '%h\n' | sed 's|^\./||' | sort -uV | paste -sd,)
{
    sed -E "s|^Directories=(.*)|Directories=\1,$copied|" "$index_source"
    awk -v list=",$copied," '
        /^\[/ { name = substr($0, 2, length($0) - 2); keep = index(list, "," name ",") > 0 }
        keep { print }
    ' "$papirus_dark/index.theme"
} > "$theme/index.theme"

gtk-update-icon-cache -f -q -t "$theme" 2>/dev/null || true
echo "Simpleton: $(find "$theme" -type f -name '*.svg' | wc -l) souborů, $(find "$theme" -type l | wc -l) odkazů, $(du -sh "$theme" | cut -f1)"
