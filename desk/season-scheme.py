#!/usr/bin/python3
"""Barevná schémata ročních období stejným generátorem jako schéma z tapety v Caelestii.

Použití: season-scheme.py simpleton|simpleton-test|spring|summer|autumn|winter   nastaví schéma
         season-scheme.py --mode dark|light             přepne tmavý a světlý motiv
         season-scheme.py --print spring                vypíše barvy, nic nemění

caelestia zná jen schémata z adresáře balíčku, proto se o tato stará skript sám. Vlastní jméno
chrání barvy před změnou tapety, ale `caelestia scheme set -m` by na něm spadl.
"""
import subprocess
import sys
from pathlib import Path

from caelestia.utils.material.generator import gen_scheme, hex_to_hct
from caelestia.utils.scheme import Scheme, get_scheme
from caelestia.utils.theme import apply_colours
from caelestia.utils.wallpaper import set_wallpaper as apply_wallpaper

PREFIX = "season-"

# Semínko palety, varianta generátoru a výchozí motiv. Období jsou teplá a pastelová: měkká semínka a tlumené varianty.
# Zima je krémově bílá, proto světlá. Simpleton je modré schéma ze stejnojmenné tapety, pevné, změna tapety ho nepřebarví.
SEASONS = {
    "simpleton": ("607998", "tonalspot", "dark"),
    "simpleton-test": ("607998", "tonalspot", "dark"),
    "spring": ("a3b86c", "tonalspot", "dark"),
    "summer": ("e8c872", "tonalspot", "dark"),
    "autumn": ("b5835a", "tonalspot", "dark"),
    "winter": ("e8dcc8", "tonalspot", "light"),
}

# Ruční úpravy generované palety v tmavém motivu. Simpleton Test: stejné jako Simpleton, jen se světlejším modrošedým pozadím a panelem.
DARK_OVERRIDES = {
    "simpleton-test": {
        "background": "2b3139",
        "surface": "2b3139",
        "surfaceDim": "262c33",
    },
}


def build(season: str, mode: str) -> Scheme:
    seed, variant, _ = SEASONS[season]
    scheme = Scheme({"name": PREFIX + season, "flavour": "default", "mode": mode, "variant": variant, "colours": {}})
    overrides = DARK_OVERRIDES.get(season, {}) if mode == "dark" else {}
    scheme._colours = {**gen_scheme(scheme, hex_to_hct(seed)), **overrides}
    return scheme


def activate(season: str, mode: str) -> None:
    scheme = build(season, mode)
    scheme.save()
    apply_colours(scheme.colours, scheme.mode)


def wallpaper_for(season: str) -> Path:
    if season in ("simpleton", "simpleton-test"):
        return Path.home() / ".local/share/wallpapers/Simpleton/contents/images/3965x2645.jpg"
    return Path(__file__).resolve().parent / "wallpapers" / f"{season}.jpg"


# Tapeta jde až po schématu. caelestia po nastavení tapety přepočítává barvy ze schémat svého balíčku,
# kde tohle není, a spadla by; barvy jsou hotové, takže se přepočet přeskočí. Totéž se stane při změně
# tapety ve výběru v Nastavení: tapeta se změní, barvy zůstanou a chyba se nikde neukáže.
def set_wallpaper(season: str) -> None:
    path = wallpaper_for(season)
    if path.exists():
        get_scheme().update_colours = lambda: None
        apply_wallpaper(path, True)


def set_mode(mode: str) -> None:
    name = get_scheme().name
    if name.startswith(PREFIX):
        activate(name.removeprefix(PREFIX), mode)
    else:
        subprocess.run(["caelestia", "scheme", "set", "--notify", "-m", mode], check=True)


def main(args: list[str]) -> int:
    if len(args) == 2 and args[0] == "--mode" and args[1] in ("dark", "light"):
        set_mode(args[1])
    elif len(args) == 2 and args[0] == "--print" and args[1] in SEASONS:
        colours = build(args[1], SEASONS[args[1]][2]).colours
        print(" ".join(f"{key}={colours[key]}" for key in ("primary", "secondary", "surface", "surfaceContainer", "onSurface")))
    elif len(args) == 1 and args[0] in SEASONS:
        activate(args[0], SEASONS[args[0]][2])
        set_wallpaper(args[0])
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
