#!/bin/bash
# Aktualizace systému s ohledem na prostředí desk:
#   1. uloží aktuální stav desk a kopie Caelestie do gitu,
#   2. spustí yay -Syu,
#   3. když hyprbars neodpovídá nainstalovanému Hyprlandu, zkompiluje ho,
#   4. sloučí nainstalovanou verzi Caelestie do kopie; při konfliktu kopii nechá beze změny.
# Kroky 3 a 4 se řídí stavem, ne změnou v tomto běhu: doženou i selhaný yay nebo aktualizaci mimo tento skript.
# Použití: desk-update            celá aktualizace
#          desk-update --snapshot jen uložení do gitu
#          desk-update --hyprbars jen kompilace pluginu hyprbars
set -uo pipefail

desk_git=(git -C "$HOME/.config" --git-dir="$HOME/.local/share/desk.git" --work-tree="$HOME/.config")
# Výčet je tady, ne jen v info/exclude: ten se neklonuje a na novém stroji by add -A poslal do veřejného repa celý ~/.config
desk_paths=(README.md desk quickshell/desk quickshell/caelestia .gitmodules ghostty/config)
caelestia_dir="$HOME/.config/quickshell/caelestia"
caelestia_git=(git -C "$caelestia_dir")
caelestia_system=/etc/xdg/quickshell/caelestia
plugins_src="$HOME/.local/src/hyprland-plugins"
desk_dir=$(dirname "$(realpath "$0")")
plugin_target="$desk_dir/plugins/hyprbars.so"
plugin_stamp="$plugin_target.built-for"
# Délka za prefixem je povinná, jinak by vzor našel sám sebe v diffu tohoto skriptu
secret_pattern='ghp_[A-Za-z0-9]{20}|gho_[A-Za-z0-9]{20}|github_pat_[A-Za-z0-9_]{20}|glpat-[A-Za-z0-9_-]{20}|sk-ant-[A-Za-z0-9_-]{20}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY'

say() { printf '\n==> %s\n' "$*"; }
warn() { printf '\n!!! %s\n' "$*" >&2; }
version_of() { pacman -Q "$1" 2>/dev/null | cut -d' ' -f2; }

commit_repo() { # $1 = popis, $2 = důvod, zbytek = příkaz gitu; změny už musí být v indexu
    local label=$1 reason=$2
    shift 2
    "$@" diff --cached --quiet && return 0

    "$@" diff --cached --stat
    # Přes here-string: grep -q ukončí rouru dřív a pipefail by nález vydával za neúspěch hledání
    if grep -qE "$secret_pattern" <<< "$("$@" diff --cached -U0 | grep -E '^\+')"; then
        warn "$label: ve změnách je něco jako tajemství, nic se neuložilo ani nepushnulo. Změny jsou v indexu."
        return 1
    fi

    "$@" commit -q -m "Snapshot $(date '+%Y-%m-%d %H:%M') ($reason)" || { warn "$label: commit selhal"; return 1; }
    say "$label: uložen nový stav"
}

push_repo() { # $1 = popis, $2 = větve k pushnutí, zbytek = příkaz gitu
    local label=$1 refs=$2
    shift 2
    "$@" remote get-url origin >/dev/null 2>&1 || return 0
    # shellcheck disable=SC2086 # refs je záměrně seznam oddělený mezerami
    "$@" push -q origin $refs || { warn "$label: push selhal, stav je uložený jen lokálně"; return 1; }
}

# Zdrojem pravdy pro keyd je repo; změna jen v /etc/keyd by se při kopírování zpět mohla přepsat s opravou v repu
check_keyd() {
    local changes
    changes=$(diff -rq -x '*.bak*' -x '*.disabled' "$desk_dir/system/keyd" /etc/keyd 2>&1) && return 0
    warn "keyd v /etc/keyd se liší od repa. Z repa do systému: $desk_dir/system/install-keyd.sh, opačný směr se kopíruje ručně."
    printf '%s\n' "$changes" >&2
}

# Vrací 1, když se stav neuložil, a 2, když je uložený jen lokálně
snapshot() { # $1 = důvod
    check_keyd
    "${caelestia_git[@]}" add -A && commit_repo "caelestia" "$1" "${caelestia_git[@]}" || return 1
    "${desk_git[@]}" add -A -- "${desk_paths[@]}" && commit_repo "desk" "$1" "${desk_git[@]}" || return 1

    # Caelestia první: desk v submodulu odkazuje na její commit, který už musí existovat i na GitHubu
    if ! push_repo "caelestia" "HEAD upstream" "${caelestia_git[@]}"; then
        warn "desk se nepushuje, jeho submodul by ukazoval na commit, který na GitHubu není"
        return 2
    fi
    push_repo "desk" "HEAD" "${desk_git[@]}" || return 2
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

# Bez nové verze nic nezmění; po konfliktu se ozve při každém dalším běhu
merge_caelestia() {
    [ -d "$caelestia_system" ] || { warn "chybí $caelestia_system, balíček caelestia-shell není nainstalovaný"; return 1; }
    local work before
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
        [ "$("${caelestia_git[@]}" rev-parse HEAD)" = "$before" ] || say "Caelestia sloučena, projeví se po restartu shellu"
    else
        "${caelestia_git[@]}" merge --abort
        warn "sloučení Caelestie má konflikty, kopie zůstala beze změny. Nová verze je ve větvi upstream: git -C $caelestia_dir merge upstream"
        return 1
    fi
}

case "${1:-}" in
    --hyprbars)
        rebuild_hyprbars
        exit
        ;;
    --snapshot)
        snapshot "manual"
        exit
        ;;
esac

# Bez bodu návratu se neaktualizuje; samotný nedostupný GitHub aktualizaci nezastaví
snapshot "before update"
[ $? -eq 1 ] && { warn "stav se neuložil, aktualizace se nespustí"; exit 1; }

result=0

say "Spouštím yay -Syu"
yay -Syu || { warn "aktualizace neproběhla celá, dokončuji zbývající kroky"; result=1; }

hyprbars_is_current || rebuild_hyprbars || result=1
merge_caelestia || result=1

snapshot "after update" || { warn "uložení do gitu po aktualizaci selhalo"; result=1; }

if [ "$result" -eq 0 ]; then
    say "Hotovo. Nové verze aplikací a jádra se projeví po odhlášení nebo restartu počítače."
else
    warn "Aktualizace skončila s chybami, podrobnosti jsou výše."
fi
exit "$result"
