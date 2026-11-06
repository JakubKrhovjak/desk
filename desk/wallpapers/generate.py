#!/usr/bin/python3
"""Vygeneruje abstraktní tapety ročních období, vrstvené pastelové vlny: generate.py [spring summer ...]

Barvy nejsou přímo z palet schémat: tmavé plochy z nich dávají blátivý výsledek, pastel potřebuje vlastní přechod.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
WIDTH, HEIGHT = 2560, 1440
LAYERS = 7

# Náhodné semínko a barvy od nebe po nejnižší vlnu
SEASONS = {
    "spring": (11, ["eef2d8", "dfe8bd", "c9d99d", "aec480", "93ad66", "7b9652"]),
    "summer": (23, ["fff6d0", "fdeca8", "f9dd80", "f2cb5e", "e6b545", "d59f33"]),
    "autumn": (37, ["f6e6cf", "ecd2ae", "dcb68a", "c6966a", "a9774f", "8a5c3b"]),
    "winter": (51, ["fffdf8", "fbf6ec", "f5eee0", "ece3d2", "e1d6c3", "d3c7b2"]),
}


def rgb(hex_colour: str) -> np.ndarray:
    return np.array([int(hex_colour[i : i + 2], 16) for i in (0, 2, 4)], dtype=float)


def stop(colours: list[np.ndarray], position: float) -> np.ndarray:
    scaled = position * (len(colours) - 1)
    index = min(int(scaled), len(colours) - 2)
    return colours[index] + (colours[index + 1] - colours[index]) * (scaled - index)


def render(seed: int, hex_colours: list[str]) -> Image.Image:
    random = np.random.default_rng(seed)
    colours = [rgb(colour) for colour in hex_colours]

    x = np.linspace(0, 1, WIDTH)[None, :]
    y = np.linspace(0, 1, HEIGHT)[:, None]
    image = np.repeat(colours[0][None, None, :], HEIGHT, axis=0).repeat(WIDTH, axis=1)

    for layer in range(LAYERS):
        depth = layer / (LAYERS - 1)
        edge = 0.22 + 0.68 * depth + np.zeros_like(x)
        for harmonic in (1, 2, 3):
            amplitude = random.uniform(0.02, 0.065) / harmonic
            edge = edge + amplitude * np.sin(2 * np.pi * harmonic * random.uniform(0.6, 1.3) * x + random.uniform(0, 2 * np.pi))

        distance = y - edge
        mask = np.clip(distance / 0.002 + 0.5, 0, 1)
        # Každá vlna je nahoře světlejší a směrem dolů mírně tmavne, takže působí měkce
        shade = 1.03 - 0.07 * np.clip(distance / 0.3, 0, 1)
        colour = stop(colours, depth)[None, None, :] * shade[..., None]
        image = image * (1 - mask[..., None]) + colour * mask[..., None]

    image += random.normal(0, 0.9, image.shape)
    return Image.fromarray(np.clip(image, 0, 255).astype(np.uint8))


def main(names: list[str]) -> None:
    for season in names or SEASONS:
        path = HERE / f"{season}.jpg"
        render(*SEASONS[season]).save(path, quality=92, subsampling=0)
        print(path.name, path.stat().st_size // 1024, "kB")


if __name__ == "__main__":
    main(sys.argv[1:])
