#!/bin/bash
# Aktualizace systému s ohledem na prostředí desk:
#   1. uloží aktuální stav desk a kopie Caelestie do gitu,
#   2. spustí yay -Syu,
#   3. po změně Hyprlandu znovu zkompiluje plugin hyprbars,
#   4. po změně Caelestie sloučí novou verzi do kopie; při konfliktu kopii nechá beze změny.
# Použití: desk-update            celá aktualizace
#          desk-update --snapshot jen uložení do gitu
set -uo pipefail

desk_git=(git -C "$HOME/.config" --git-dir="$HOME/.local/share/desk.git" --work-tree="$HOME/.config")
# Výčet je tady, ne jen v info/exclude: ten se neklonuje a na novém stroji by add -A poslal do veřejného repa celý ~/.config
desk_paths=(desk quickshell/desk quickshell/caelestia .gitmodules ghostty/config)
caelestia_dir="$HOME/.config/quickshell/caelestia"
caelestia_git=(git -C "$caelestia_dir")
caelestia_system=/etc/xdg/quickshell/caelestia
plugins_src="$HOME/.local/src/hyprland-plugins"
desk_dir=$(dirname "$(realpath "$0")")
plugin_target="$desk_dir/plugins/hyprbars.so"

say() { printf '\n==> %s\n' "$*"; }
warn() { printf '\n!!! %s\n' "$*" >&2; }
version_of() { pacman -Q "$1" 2>/dev/null | cut -d' ' -f2; }

save_repo() { # $1 = popis, $2 = větve k pushnutí, zbytek = příkaz gitu; změny už musí být v indexu
    local label=$1 refs=$2
    shift 2
    if ! "$@" diff --cached --quiet; then
        "$@" commit -q -m "Snapshot $(date '+%Y-%m-%d %H:%M')" && say "$label: uložen nový stav"
    fi
    if "$@" remote get-url origin >/dev/null 2>&1; then
        # shellcheck disable=SC2086 # refs je záměrně seznam oddělený mezerami
        "$@" push -q origin $refs || warn "$label: push selhal, stav je uložený jen lokálně"
    fi
}

snapshot() {
    mkdir -p "$desk_dir/system/keyd"
    cp /etc/keyd/*.conf /etc/keyd/desk-cmd "$desk_dir/system/keyd/" 2>/dev/null
    # Caelestia první: desk si v submodulu ukládá její commit, který už musí existovat i na GitHubu
    "${caelestia_git[@]}" add -A && save_repo "caelestia" "HEAD upstream" "${caelestia_git[@]}"
    "${desk_git[@]}" add -A -- "${desk_paths[@]}" && save_repo "desk" "HEAD" "${desk_git[@]}"
}

rebuild_hyprbars() {
    say "Hyprland se změnil, kompiluji hyprbars"
    git -C "$plugins_src" fetch -q origin || { warn "nepodařilo se stáhnout zdroj pluginu"; return 1; }

    # hyprpm.toml páruje commit Hyprlandu s commitem pluginu; bez záznamu platí nejnovější verze
    local hyprland_commit pin
    hyprland_commit=$(Hyprland --version | grep -oE 'commit [0-9a-f]{40}' | head -n 1 | cut -d' ' -f2)
    git -C "$plugins_src" checkout -q -- .
    git -C "$plugins_src" checkout -q origin/main
    pin=$(grep -F "\"$hyprland_commit\"" "$plugins_src/hyprpm.toml" | grep -oE '"[0-9a-f]{40}"' | tail -n 1 | tr -d '"')
    [ -n "$pin" ] && git -C "$plugins_src" checkout -q "$pin"

    # Bez patche plugin zruší na liště i pravý klik a nabídka okna se neotevře
    git -C "$plugins_src" apply "$desk_dir/system/hyprbars-right-click.patch" \
        || warn "patch hyprbars nesedí na novou verzi: pravý klik na lištu nebude otevírat nabídku okna"

    if make -C "$plugins_src/hyprbars" all >/dev/null; then
        install -m755 "$plugins_src/hyprbars/hyprbars.so" "$plugin_target"
        say "hyprbars zkompilován, načte se po dalším přihlášení"
    else
        warn "kompilace hyprbars selhala: okna budou bez lišt, zbytek prostředí poběží"
        return 1
    fi
}

merge_caelestia() {
    say "Caelestia se změnila, slučuji novou verzi do kopie"
    local work
    work=$(mktemp -d)
    "${caelestia_git[@]}" worktree add -q "$work" upstream || { rm -rf "$work"; warn "nepovedlo se připravit větev upstream"; return 1; }

    rsync -a --delete --exclude .git "$caelestia_system/" "$work/"
    git -C "$work" add -A
    git -C "$work" diff --cached --quiet || git -C "$work" commit -q -m "Caelestia shell $(version_of caelestia-shell)"
    "${caelestia_git[@]}" worktree remove --force "$work"
    rm -rf "$work"

    if "${caelestia_git[@]}" merge -q --no-edit upstream; then
        say "Caelestia sloučena, projeví se po restartu shellu"
    else
        "${caelestia_git[@]}" merge --abort
        warn "sloučení Caelestie má konflikty, kopie zůstala beze změny. Nová verze je ve větvi upstream: git -C $caelestia_dir merge upstream"
        return 1
    fi
}

snapshot || warn "uložení do gitu selhalo"
[ "${1:-}" = "--snapshot" ] && exit 0

hyprland_before=$(version_of hyprland)
caelestia_before=$(version_of caelestia-shell)

say "Spouštím yay -Syu"
yay -Syu || { warn "aktualizace neproběhla celá"; exit 1; }

[ "$(version_of hyprland)" != "$hyprland_before" ] && rebuild_hyprbars
[ "$(version_of caelestia-shell)" != "$caelestia_before" ] && merge_caelestia

snapshot || warn "uložení do gitu selhalo"

say "Hotovo. Nové verze aplikací a jádra se projeví po odhlášení nebo restartu počítače."
