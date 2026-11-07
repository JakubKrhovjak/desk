#!/bin/bash
# Aktualizace systému s ohledem na prostředí desk (změny našeho kódu nasazuje desk-deploy, ne tenhle skript):
#   1. spustí yay -Syu,
#   2. když hyprbars neodpovídá nainstalovanému Hyprlandu, zkompiluje ho,
#   3. sloučí nainstalovanou verzi Caelestie do naší kopie; při konfliktu kopii nechá beze změny.
# Slučuje se v pracovní kopii (~/projects/desk), kde vznikne commit, a nasadí se přes desk-deploy; push je na uživateli.
# Bez pracovní kopie (čistá instalace, test ve virtuálce) se slučuje přímo v nasazené kopii v ~/.config, bez pushe.
# Kroky 2 a 3 se řídí stavem, ne změnou v tomto běhu: doženou i selhaný yay nebo aktualizaci mimo tento skript.
# Použití: desk-update            celá aktualizace
#          desk-update --hyprbars jen kompilace pluginu hyprbars
#          desk-update --yes      celá aktualizace bez dotazů, pro test ve virtuálce
set -uo pipefail

desk_git=(git -C "$HOME/.config" --git-dir="$HOME/.local/share/desk.git" --work-tree="$HOME/.config")
dev_dir=${DESK_DEV_DIR:-$HOME/projects/desk}
caelestia_system=/etc/xdg/quickshell/caelestia
plugins_src="$HOME/.local/src/hyprland-plugins"
desk_dir=$(dirname "$(realpath "$0")")
plugin_target="$desk_dir/plugins/hyprbars.so"
plugin_stamp="$plugin_target.built-for"

say() { printf '\n==> %s\n' "$*"; }
warn() { printf '\n!!! %s\n' "$*" >&2; }
version_of() { pacman -Q "$1" 2>/dev/null | cut -d' ' -f2; }

has_dev_copy() { [[ -d $dev_dir/.git && -e $dev_dir/quickshell/caelestia/.git ]]; }

# Zdrojem pravdy pro keyd je repo; změna jen v /etc/keyd by se při kopírování zpět mohla přepsat s opravou v repu
check_keyd() {
    local changes
    changes=$(diff -rq -x '*.bak*' -x '*.disabled' "$desk_dir/system/keyd" /etc/keyd 2>&1) && return 0
    warn "keyd v /etc/keyd se liší od repa. Z repa do systému: $desk_dir/system/install-keyd.sh, opačný směr se kopíruje ručně."
    printf '%s\n' "$changes" >&2
}

# Nasazená kopie se ručně neupravuje; necommitnutá změna by se dalším desk-deploy zastavila
check_deployed() {
    "${desk_git[@]}" diff --quiet HEAD && git -C "$HOME/.config/quickshell/caelestia" diff --quiet HEAD && return 0
    warn "nasazená kopie v ~/.config má necommitnuté změny; patří do pracovní kopie $dev_dir"
}

hyprbars_is_current() {
    [ -x "$plugin_target" ] && [ "$(cat "$plugin_stamp" 2>/dev/null)" = "$(version_of hyprland)" ]
}

rebuild_hyprbars() {
    say "Kompiluji hyprbars pro aktuální Hyprland"
    [ -d "$plugins_src/.git" ] || git clone -q https://github.com/hyprwm/hyprland-plugins "$plugins_src" || { warn "nepodařilo se naklonovat zdroj pluginu"; return 1; }
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
        install -Dm755 "$plugins_src/hyprbars/hyprbars.so" "$plugin_target"
        version_of hyprland > "$plugin_stamp"
        say "hyprbars zkompilován, načte se po dalším přihlášení"
    else
        warn "kompilace hyprbars selhala: okna budou bez lišt, zbytek prostředí poběží"
        return 1
    fi
}

# Bez nové verze nic nezmění; po konfliktu se ozve při každém dalším běhu. Vypíše, zda se kopie změnila (changed).
merge_caelestia() { # $1 = repozitář kopie Caelestie
    local repo=$1 work before
    local caelestia_git=(git -C "$repo")
    [ -d "$caelestia_system" ] || { warn "chybí $caelestia_system, balíček caelestia-shell není nainstalovaný"; return 1; }
    [ "$("${caelestia_git[@]}" symbolic-ref -q --short HEAD)" = master ] || { warn "Caelestia v $repo není na větvi master"; return 1; }
    "${caelestia_git[@]}" diff --quiet HEAD || { warn "Caelestia v $repo má necommitnuté změny, slučování přeskočeno"; return 1; }
    "${caelestia_git[@]}" rev-parse -q --verify refs/heads/upstream >/dev/null \
        || "${caelestia_git[@]}" branch -q upstream origin/upstream || { warn "Caelestia v $repo nemá větev upstream"; return 1; }

    work=$(mktemp -d)
    # Přerušený běh mohl nechat zaregistrovaný worktree, se kterým by další add selhal
    "${caelestia_git[@]}" worktree prune
    "${caelestia_git[@]}" worktree add -q "$work" upstream || { rm -rf "$work"; warn "nepovedlo se připravit větev upstream"; return 1; }

    rsync -a --delete --exclude .git "$caelestia_system/" "$work/"
    git -C "$work" add -A
    git -C "$work" diff --cached --quiet || git -C "$work" commit -q -m "Caelestia shell $(version_of caelestia-shell)"
    "${caelestia_git[@]}" worktree remove --force "$work"
    rm -rf "$work"

    before=$("${caelestia_git[@]}" rev-parse HEAD)
    if "${caelestia_git[@]}" merge -q --no-edit upstream; then
        [ "$("${caelestia_git[@]}" rev-parse HEAD)" = "$before" ] || echo changed
    else
        "${caelestia_git[@]}" merge --abort
        warn "sloučení Caelestie má konflikty, kopie zůstala beze změny. Nová verze je ve větvi upstream: git -C $repo merge upstream"
        return 1
    fi
}

# V pracovní kopii: sloučit, zapsat nový odkaz na Caelestii do desku a nasadit
update_caelestia() {
    local merged
    if ! has_dev_copy; then
        merged=$(merge_caelestia "$HOME/.config/quickshell/caelestia") || return 1
        [ "$merged" = changed ] && say "Caelestia sloučena v nasazené kopii, projeví se po restartu shellu"
        return 0
    fi

    merged=$(merge_caelestia "$dev_dir/quickshell/caelestia") || return 1
    [ "$merged" = changed ] || return 0
    git -C "$dev_dir" add quickshell/caelestia
    git -C "$dev_dir" commit -q -m "caelestia: merge Caelestia shell $(version_of caelestia-shell)" || { warn "commit odkazu na Caelestii v $dev_dir selhal"; return 1; }
    say "Caelestia sloučena v $dev_dir, nasazuji"
    "$desk_dir/desk-deploy.sh" "$dev_dir" || return 1
    say "Nezapomeň pushnout: git -C $dev_dir/quickshell/caelestia push origin master upstream && git -C $dev_dir push"
}

if [ "${1:-}" = --hyprbars ]; then
    rebuild_hyprbars
    exit
fi

check_keyd
check_deployed
result=0

say "Spouštím yay -Syu"
yay_options=()
[ "${1:-}" = --yes ] && yay_options=(--noconfirm --answerdiff None --answerclean None)
yay -Syu "${yay_options[@]}" || { warn "aktualizace neproběhla celá, dokončuji zbývající kroky"; result=1; }

hyprbars_is_current || rebuild_hyprbars || result=1
update_caelestia || result=1

if [ "$result" -eq 0 ]; then
    say "Hotovo. Nové verze aplikací a jádra se projeví po odhlášení nebo restartu počítače."
else
    warn "Aktualizace skončila s chybami, podrobnosti jsou výše."
fi
exit "$result"
