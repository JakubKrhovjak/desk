#!/bin/bash
# Nasadí commity z pracovní kopie (výchozí ~/projects/desk) do ~/.config, bez pushe na GitHub, a znovu načte Hyprland
# a shell. Necommitnuté úpravy pracovní kopie nasazuje až commit. Nasazená kopie v ~/.config se ručně neupravuje.
# Použití: desk-deploy [cesta k pracovní kopii]
set -euo pipefail

source=${1:-$HOME/projects/desk}
desk_git=(git -C "$HOME/.config" --git-dir="$HOME/.local/share/desk.git" --work-tree="$HOME/.config")
caelestia="$HOME/.config/quickshell/caelestia"
desk_dir="$HOME/.config/desk"

fail() { echo "desk-deploy: $1" >&2; exit 1; }

[[ -d $source/.git && -e $source/quickshell/caelestia/.git ]] || fail "pracovní kopie $source neexistuje (git clone --recurse-submodules git@github.com:JakubKrhovjak/desk.git $source)"

# Neuložená změna v nasazené kopii by se nasazením přepsala nebo zastavila; patří do pracovní kopie
"${desk_git[@]}" diff --quiet HEAD || fail "$HOME/.config má necommitnuté změny v desku: ${desk_git[*]} status"
git -C "$caelestia" diff --quiet HEAD || fail "$caelestia má necommitnuté změny: git -C $caelestia status"

before=$("${desk_git[@]}" rev-parse HEAD)

# Caelestia první, desk na ni odkazuje. Jen posun vpřed: commity, které má jen nasazená kopie (třeba sloučení
# z desk-update), musí pracovní kopie nejdřív stáhnout z GitHubu.
git -C "$caelestia" pull -q --ff-only "$source/quickshell/caelestia" master \
    || fail "Caelestia nejde posunout vpřed; v pracovní kopii nejdřív: git -C $source/quickshell/caelestia pull"
"${desk_git[@]}" pull -q --ff-only "$source" main \
    || fail "desk nejde posunout vpřed; v pracovní kopii nejdřív: git -C $source pull"

after=$("${desk_git[@]}" rev-parse HEAD)
echo "desk ${before:0:7} → ${after:0:7}, Caelestia $(git -C "$caelestia" rev-parse --short HEAD)"

# keyd čte /etc/keyd, kopii z repozitáře instaluje zvláštní skript (chce sudo)
if ! "${desk_git[@]}" diff --quiet "$before" "$after" -- desk/system/keyd; then
    "$desk_dir/system/install-keyd.sh"
fi

hyprctl reload >/dev/null
"$desk_dir/restart-shell.sh" || echo "desk-deploy: shell se nerestartoval (zamčená obrazovka?), spusť $desk_dir/restart-shell.sh"
