#!/usr/bin/env python3
"""Generate Redelka's tiling environment textures (PS1-style, 128 px, muted night palette).

Run (all textures, or only the listed names):
    python3 tools/generate_textures.py
    python3 tools/generate_textures.py cobble plaster

Writes assets/textures/explore/<name>.png. Every texture tiles seamlessly. Materials map them
in world space (triplanar), so one tile covers TILE_METERS of surface; see
scripts/assets/environment_materials.gd. Then reimport: godot --headless --path . --import
"""

from __future__ import annotations

import struct
import sys
import zlib
from pathlib import Path

import numpy as np

OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "textures" / "explore"
SIZE = 128


# --- helpers -------------------------------------------------------------------------

def rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def value_noise(seed: int, period: int, size: int = SIZE) -> np.ndarray:
    """Tileable smooth noise in [0, 1] with `period` cells across the texture."""
    grid = rng(seed).random((period, period))
    coords = np.arange(size) * period / size
    i0 = np.floor(coords).astype(int)
    f = coords - i0
    f = f * f * (3.0 - 2.0 * f)
    i1 = (i0 + 1) % period
    i0 %= period
    top = grid[np.ix_(i0, i0)] * (1 - f)[None, :] + grid[np.ix_(i0, i1)] * f[None, :]
    bottom = grid[np.ix_(i1, i0)] * (1 - f)[None, :] + grid[np.ix_(i1, i1)] * f[None, :]
    return top * (1 - f)[:, None] + bottom * f[:, None]


def fbm(seed: int, periods=(4, 8, 16, 32), weights=(0.5, 0.25, 0.15, 0.1)) -> np.ndarray:
    out = np.zeros((SIZE, SIZE))
    for i, (p, w) in enumerate(zip(periods, weights)):
        out += value_noise(seed + i * 17, p) * w
    return out / sum(weights)


def voronoi(seed: int, count: int, jitter: float = 1.0):
    """Tileable Voronoi: returns (cell index, distance to nearest, distance to second nearest)."""
    r = rng(seed)
    pts = r.random((count, 2)) * SIZE
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(float)
    best = np.full((SIZE, SIZE), 1e9)
    second = np.full((SIZE, SIZE), 1e9)
    idx = np.zeros((SIZE, SIZE), dtype=int)
    for i, (px, py) in enumerate(pts):
        dx = np.abs(xx - px)
        dy = np.abs(yy - py)
        dx = np.minimum(dx, SIZE - dx)
        dy = np.minimum(dy, SIZE - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < best
        second = np.where(closer, best, np.minimum(second, d))
        idx = np.where(closer, i, idx)
        best = np.where(closer, d, best)
    return idx, best, second


def colorize(value: np.ndarray, dark, light) -> np.ndarray:
    dark = np.array(dark, dtype=float)
    light = np.array(light, dtype=float)
    v = np.clip(value, 0.0, 1.0)[..., None]
    return dark + (light - dark) * v


def speckle(img: np.ndarray, seed: int, chance: float, color, strength: float = 1.0) -> np.ndarray:
    mask = rng(seed).random((SIZE, SIZE)) < chance
    col = np.array(color, dtype=float)
    img[mask] = img[mask] * (1 - strength) + col * strength
    return img


def quantize(img: np.ndarray, levels: int = 24) -> np.ndarray:
    """A light posterize keeps the PS1 look under nearest filtering."""
    return np.round(np.clip(img, 0, 1) * levels) / levels


def write_png(path: Path, img: np.ndarray) -> None:
    data = (np.clip(img, 0, 1) * 255).astype(np.uint8)
    h, w, _ = data.shape
    raw = b"".join(b"\x00" + data[y].tobytes() for y in range(h))

    def chunk(tag: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    path.write_bytes(png)


def planks(seed: int, count: int, base, gap_color, vertical: bool, knots: int = 3, nails: bool = True):
    r = rng(seed)
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(float)
    across = xx if vertical else yy
    along = yy if vertical else xx
    width = SIZE / count
    plank = np.floor(across / width).astype(int)
    shade = r.random(count)[plank] * 0.22 - 0.11
    offsets = r.random(count)[plank] * 40.0
    grain = np.sin((along + offsets) * 0.09 + value_noise(seed + 1, 8) * 9.0 + (across % width) * 0.6) * 0.5 + 0.5
    grain = grain * 0.45 + value_noise(seed + 2, 32) * 0.35 + fbm(seed + 3) * 0.2
    img = colorize(grain * 0.6 + 0.2 + shade, np.array(base) * 0.55, np.array(base) * 1.15)
    # Dark gaps between boards and worn, lighter board edges.
    local = across % width
    img[local < 1.2] = gap_color
    edge = (local >= 1.2) & (local < 2.4)
    img[edge] *= 1.12
    for k in range(knots):
        cx, cy = r.random() * SIZE, r.random() * SIZE
        d = np.sqrt(((xx - cx + SIZE / 2) % SIZE - SIZE / 2) ** 2 + ((yy - cy + SIZE / 2) % SIZE - SIZE / 2) ** 2)
        img[d < 3.2] *= 0.6
        img[(d >= 3.2) & (d < 4.6)] *= 0.85
    if nails:
        for p in range(count):
            for along_pos in (10, SIZE - 10):
                cx = int(p * width + width / 2)
                x, y = (cx, along_pos) if vertical else (along_pos, cx)
                img[y - 1:y + 1, x - 1:x + 1] = (0.12, 0.11, 0.11)
    return img


# --- textures ------------------------------------------------------------------------

def cobble() -> np.ndarray:
    idx, d1, d2 = voronoi(11, 46)
    edge = d2 - d1
    stone = np.clip(edge / 5.0, 0, 1) ** 0.6
    r = rng(12)
    tone = r.random(idx.max() + 1)[idx] * 0.35
    noise = fbm(13)
    value = stone * (0.55 + tone) * (0.7 + noise * 0.5)
    img = colorize(value, (0.07, 0.07, 0.075), (0.47, 0.45, 0.42))
    # Mortar gaps hold dirt and a little moss.
    gap = edge < 1.4
    moss = value_noise(14, 8) > 0.62
    img[gap] = (0.09, 0.085, 0.07)
    img[gap & moss] = (0.1, 0.115, 0.075)
    img = speckle(img, 15, 0.012, (0.62, 0.64, 0.66), 0.5)  # frost glints
    return quantize(img)


def flagstone() -> np.ndarray:
    r = rng(21)
    img = np.zeros((SIZE, SIZE, 3))
    noise = fbm(22)
    rows = 4
    row_h = SIZE // rows
    for row in range(rows):
        x = int(r.random() * 20)
        while x < SIZE + 40:
            w = int(28 + r.random() * 30)
            tone = 0.35 + r.random() * 0.25
            y0, y1 = row * row_h, (row + 1) * row_h
            xs = np.arange(x, x + w) % SIZE
            block = noise[y0:y1][:, xs] * 0.5 + tone
            img[y0:y1, xs] = colorize(block, (0.12, 0.12, 0.13), (0.5, 0.49, 0.47))
            img[y0:y1, xs[:1]] = (0.08, 0.08, 0.085)
            x += w
        img[row * row_h:row * row_h + 1] = (0.08, 0.08, 0.085)
    # A few cracks.
    for c in range(5):
        x, y = r.random() * SIZE, r.random() * SIZE
        for _ in range(26):
            img[int(y) % SIZE, int(x) % SIZE] = (0.09, 0.09, 0.095)
            x += r.random() * 2 - 0.6
            y += r.random() * 2 - 1
    return quantize(img)


def plaster() -> np.ndarray:
    noise = fbm(31, (4, 8, 16, 64), (0.4, 0.3, 0.2, 0.1))
    damp = value_noise(32, 3)
    value = 0.55 + noise * 0.35 - np.clip(damp - 0.55, 0, 1) * 1.2
    img = colorize(value, (0.13, 0.13, 0.13), (0.5, 0.48, 0.44))
    r = rng(33)
    # Fallen patches showing the bricks underneath.
    for _ in range(2):
        cx, cy = int(r.random() * SIZE), int(r.random() * SIZE)
        for y in range(cy - 7, cy + 7):
            for x in range(cx - 11, cx + 11):
                if ((x - cx) / 11) ** 2 + ((y - cy) / 7) ** 2 < 1:
                    brick_row = (y // 4) % 2
                    mortar = (y % 4 == 0) or ((x + brick_row * 4) % 9 == 0)
                    img[y % SIZE, x % SIZE] = (0.11, 0.09, 0.08) if mortar else (0.3, 0.19, 0.16)
    for _ in range(4):
        x, y = r.random() * SIZE, r.random() * SIZE
        for _ in range(30):
            img[int(y) % SIZE, int(x) % SIZE] *= 0.55
            x += r.random() * 2 - 1
            y += r.random() * 1.6
    return quantize(img)


def timber() -> np.ndarray:
    return quantize(planks(41, 6, (0.36, 0.27, 0.19), (0.06, 0.05, 0.045), vertical=False))


def boards() -> np.ndarray:
    """Door and shutter boards: darker, vertical, weathered."""
    img = planks(42, 5, (0.3, 0.22, 0.16), (0.04, 0.035, 0.03), vertical=True, knots=4)
    img *= (0.85 + value_noise(43, 4)[..., None] * 0.3)
    return quantize(img)


def brick() -> np.ndarray:
    r = rng(51)
    img = np.zeros((SIZE, SIZE, 3))
    noise = fbm(52)
    bh, bw = 8, 22
    for row in range(SIZE // bh):
        offset = (row % 2) * (bw // 2)
        for col in range(-1, SIZE // bw + 2):
            x0 = col * bw + offset
            tone = r.random() * 0.3
            xs = np.arange(x0 + 1, x0 + bw - 1) % SIZE
            ys = np.arange(row * bh + 1, row * bh + bh - 1)
            block = noise[np.ix_(ys, xs)] * 0.5 + 0.35 + tone
            img[np.ix_(ys, xs)] = colorize(block, (0.13, 0.07, 0.06), (0.45, 0.27, 0.22))
    mortar = img.sum(axis=2) == 0
    img[mortar] = (0.1, 0.095, 0.1)
    return quantize(img)


def rubble() -> np.ndarray:
    """Field-stone walls: big irregular stones."""
    idx, d1, d2 = voronoi(61, 22)
    edge = d2 - d1
    stone = np.clip(edge / 7.0, 0, 1) ** 0.5
    tone = rng(62).random(idx.max() + 1)[idx] * 0.4
    value = stone * (0.45 + tone) * (0.75 + fbm(63) * 0.4)
    img = colorize(value, (0.06, 0.06, 0.065), (0.42, 0.42, 0.41))
    img[edge < 1.8] = (0.07, 0.07, 0.07)
    lichen = (value_noise(64, 8) > 0.66) & (edge > 3)
    img[lichen] = img[lichen] * 0.6 + np.array((0.3, 0.33, 0.24)) * 0.4
    return quantize(img)


def dirt() -> np.ndarray:
    value = fbm(71, (4, 8, 16, 64), (0.35, 0.3, 0.2, 0.15))
    img = colorize(value, (0.09, 0.075, 0.06), (0.32, 0.26, 0.2))
    img = speckle(img, 72, 0.03, (0.36, 0.33, 0.3), 0.8)  # pebbles
    img = speckle(img, 73, 0.02, (0.06, 0.05, 0.04), 0.8)
    return quantize(img)


def grass() -> np.ndarray:
    """Frost-bitten grass: dull green streaks with pale frosted tips."""
    r = rng(81)
    base = fbm(82)
    img = colorize(base, (0.08, 0.1, 0.07), (0.27, 0.3, 0.22))
    for _ in range(900):
        x, y = int(r.random() * SIZE), int(r.random() * SIZE)
        length = int(3 + r.random() * 5)
        lean = r.random() * 2 - 1
        tint = 0.7 + r.random() * 0.6
        for i in range(length):
            yy, xx = (y - i) % SIZE, int(x + lean * i * 0.5) % SIZE
            img[yy, xx] = np.array((0.2, 0.24, 0.16)) * tint
        img[(y - length) % SIZE, int(x + lean * length * 0.5) % SIZE] = (0.52, 0.56, 0.56)
    return quantize(img)


def needles() -> np.ndarray:
    r = rng(91)
    img = colorize(fbm(92), (0.05, 0.04, 0.035), (0.2, 0.15, 0.11))
    for _ in range(1400):
        x, y = r.random() * SIZE, r.random() * SIZE
        angle = r.random() * np.pi
        dx, dy = np.cos(angle), np.sin(angle)
        tint = 0.6 + r.random() * 0.8
        for i in range(4):
            img[int(y + dy * i) % SIZE, int(x + dx * i) % SIZE] = np.array((0.24, 0.17, 0.11)) * tint
    return quantize(img)


def thatch() -> np.ndarray:
    r = rng(101)
    img = colorize(fbm(102), (0.12, 0.1, 0.06), (0.3, 0.25, 0.15))
    for _ in range(1600):
        x, y = r.random() * SIZE, r.random() * SIZE
        tint = 0.55 + r.random() * 0.8
        for i in range(9):
            img[int(y + i) % SIZE, int(x + i * 0.25) % SIZE] = np.array((0.38, 0.31, 0.18)) * tint
    # Bundles: darker bands every quarter.
    for band in range(4):
        img[band * 32:band * 32 + 2] *= 0.5
    return quantize(img)


def shingle() -> np.ndarray:
    """Slate roof: overlapping rows with rounded bottoms."""
    r = rng(111)
    img = np.zeros((SIZE, SIZE, 3))
    noise = fbm(112)
    rh, sw = 16, 16
    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    for row in range(SIZE // rh):
        offset = (row % 2) * (sw // 2)
        y0 = row * rh
        for col in range(-1, SIZE // sw + 1):
            x0 = col * sw + offset
            tone = r.random() * 0.25
            for y in range(rh):
                for x in range(sw - 1):
                    if y > rh - 4 and abs(x - sw / 2) > (sw / 2) * (1 - (y - (rh - 4)) / 4):
                        continue
                    px, py = (x0 + x) % SIZE, (y0 + y) % SIZE
                    v = noise[py, px] * 0.4 + 0.25 + tone - y / rh * 0.15
                    img[py, px] = colorize(np.array([v]), (0.06, 0.065, 0.075), (0.36, 0.37, 0.4))[0]
    empty = img.sum(axis=2) == 0
    img[empty] = (0.04, 0.04, 0.05)
    return quantize(img)


def bark() -> np.ndarray:
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(float)
    furrows = np.sin(xx * 0.4 + value_noise(121, 8) * 6.0) * 0.5 + 0.5
    value = furrows * 0.5 + fbm(122, (4, 16, 32, 64)) * 0.5
    img = colorize(value, (0.04, 0.035, 0.03), (0.24, 0.19, 0.15))
    return quantize(img)


def canvas() -> np.ndarray:
    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    weave = ((xx + yy) % 2) * 0.08
    stains = value_noise(131, 4)
    value = 0.55 + weave + fbm(132) * 0.25 - np.clip(stains - 0.6, 0, 1) * 1.5
    img = colorize(value, (0.1, 0.05, 0.045), (0.46, 0.24, 0.2))
    return quantize(img)


def sackcloth() -> np.ndarray:
    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    weave = ((xx // 2 + yy // 2) % 2) * 0.12
    value = 0.45 + weave + fbm(141) * 0.3
    img = colorize(value, (0.14, 0.12, 0.08), (0.46, 0.4, 0.28))
    return quantize(img)


def straw() -> np.ndarray:
    r = rng(151)
    img = colorize(fbm(152), (0.16, 0.13, 0.07), (0.38, 0.31, 0.16))
    for _ in range(1800):
        x, y = r.random() * SIZE, r.random() * SIZE
        angle = r.random() * np.pi
        dx, dy = np.cos(angle), np.sin(angle)
        tint = 0.7 + r.random() * 0.7
        for i in range(7):
            img[int(y + dy * i) % SIZE, int(x + dx * i) % SIZE] = np.array((0.5, 0.42, 0.22)) * tint
    return quantize(img)


def iron() -> np.ndarray:
    value = fbm(161, (8, 16, 32, 64))
    img = colorize(value, (0.07, 0.07, 0.075), (0.25, 0.25, 0.27))
    rust = value_noise(162, 8) > 0.6
    img[rust] = img[rust] * 0.75 + np.array((0.26, 0.15, 0.09)) * 0.25
    return quantize(img)


def earth() -> np.ndarray:
    """Packed cellar floor: dark, damp, with roots and stones."""
    value = fbm(171, (4, 8, 32, 64), (0.4, 0.3, 0.2, 0.1))
    damp = value_noise(172, 4)
    img = colorize(value - damp * 0.15, (0.04, 0.035, 0.03), (0.2, 0.16, 0.12))
    img = speckle(img, 173, 0.025, (0.25, 0.24, 0.22), 0.8)
    r = rng(174)
    for _ in range(10):
        x, y = r.random() * SIZE, r.random() * SIZE
        for _ in range(20):
            img[int(y) % SIZE, int(x) % SIZE] = (0.17, 0.12, 0.08)
            x += r.random() * 2 - 1
            y += r.random() * 2 - 1
    return quantize(img)


TEXTURES = {
    "cobble": cobble,
    "flagstone": flagstone,
    "plaster": plaster,
    "timber": timber,
    "boards": boards,
    "brick": brick,
    "rubble": rubble,
    "dirt": dirt,
    "grass": grass,
    "needles": needles,
    "thatch": thatch,
    "shingle": shingle,
    "bark": bark,
    "canvas": canvas,
    "sackcloth": sackcloth,
    "straw": straw,
    "iron": iron,
    "earth": earth,
}


def main() -> None:
    names = sys.argv[1:] or list(TEXTURES)
    unknown = [n for n in names if n not in TEXTURES]
    if unknown:
        raise SystemExit(f"Unknown textures {unknown}; choose from {list(TEXTURES)}")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name in names:
        path = OUT_DIR / f"{name}.png"
        write_png(path, TEXTURES[name]())
        print(f"[textures] wrote {path}")


if __name__ == "__main__":
    main()
