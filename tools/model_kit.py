"""Building blocks for Redelka's Blender-generated character models.

Everything is authored in Godot space (x right, y up, +z = the model's front,
feet at y = 0) and converted to Blender space only when the mesh, armature and
animations are created. Imported by tools/generate_models.py inside Blender.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

Color3 = tuple[float, float, float]
WeightSpec = "str | dict[str, float] | Callable[[Vector], dict[str, float]]"

# Godot (x, y, z) -> Blender (x, -z, y). A proper rotation, so winding survives.
GODOT_TO_BLENDER = Matrix(((1.0, 0.0, 0.0), (0.0, 0.0, -1.0), (0.0, 1.0, 0.0)))

FPS = 30
MATERIAL_BODY = 0
MATERIAL_GLOW = 1


def to_blender(v: Vector) -> Vector:
    return GODOT_TO_BLENDER @ Vector(v)


def hex_color(value: str) -> Color3:
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4))  # type: ignore[return-value]


def shade(color: Color3, factor: float) -> Color3:
    return (color[0] * factor, color[1] * factor, color[2] * factor)


def mix(a: Color3, b: Color3, t: float) -> Color3:
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def srgb_to_linear(channel: float) -> float:
    channel = clamp(channel, 0.0, 1.0)
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def V(x: float, y: float, z: float) -> Vector:
    return Vector((x, y, z))


# --- Texture atlas --------------------------------------------------------------

ATLAS_W = 320
ATLAS_H = 128

# name -> (x, y, w, h) in pixels, origin bottom-left (Blender image convention).
TILES: dict[str, tuple[int, int, int, int]] = {
    "face": (0, 0, 128, 128),
    "cloth": (128, 64, 64, 64),
    "leather": (192, 64, 64, 64),
    "metal": (256, 64, 64, 64),
    "hair": (128, 0, 64, 64),
    "flesh": (192, 0, 64, 64),
    "plain": (256, 0, 64, 64),
}
# Per-model painted fabric (see Atlas.paint_brocade). Shares the flesh slot: no model uses both.
TILES["pattern"] = TILES["flesh"]


def tile_uv(tile: str, u: float, v: float) -> tuple[float, float]:
    x, y, w, h = TILES[tile]
    inset = 0.5
    px = x + inset + clamp(u, 0.0, 1.0) * (w - 2.0 * inset)
    py = y + inset + clamp(v, 0.0, 1.0) * (h - 2.0 * inset)
    return (px / ATLAS_W, py / ATLAS_H)


def _periodic_noise(rng: np.random.Generator, size: int, cells: int) -> np.ndarray:
    grid = rng.random((cells, cells))
    coords = np.arange(size) * cells / size
    i0 = np.floor(coords).astype(int)
    frac = coords - i0
    frac = frac * frac * (3.0 - 2.0 * frac)
    i1 = (i0 + 1) % cells
    rows0 = grid[i0][:, i0] * (1 - frac)[None, :] + grid[i0][:, i1] * frac[None, :]
    rows1 = grid[i1][:, i0] * (1 - frac)[None, :] + grid[i1][:, i1] * frac[None, :]
    return rows0 * (1 - frac)[:, None] + rows1 * frac[:, None]


class Atlas:
    """RGB float image, indexed [y, x] with y = 0 at the bottom."""

    def __init__(self, seed: int) -> None:
        self.rng = np.random.default_rng(seed)
        self.pixels = np.ones((ATLAS_H, ATLAS_W, 3), dtype=np.float32)
        self._paint_tiles()

    def _gray_tile(self, name: str, values: np.ndarray) -> None:
        x, y, w, h = TILES[name]
        self.pixels[y:y + h, x:x + w, :] = np.clip(values, 0.0, 1.2)[:, :, None]

    def _paint_tiles(self) -> None:
        rng = self.rng
        size = 64
        yy, xx = np.mgrid[0:size, 0:size]

        weave = ((xx + yy) % 2) * 0.015
        cloth = 0.86 + weave + _periodic_noise(rng, size, 8) * 0.1 - _periodic_noise(rng, size, 3) * 0.06
        self._gray_tile("cloth", cloth)

        leather = 0.8 + _periodic_noise(rng, size, 6) * 0.16 + _periodic_noise(rng, size, 16) * 0.08
        for _ in range(9):
            sx, sy, length = rng.integers(0, size, 3)
            for step in range(int(length) // 3):
                leather[(sy + step // 3) % size, (sx + step) % size] -= 0.18
        self._gray_tile("leather", leather)

        metal = 0.9 + _periodic_noise(rng, size, 10) * 0.1 - (rng.random((size, size)) > 0.985) * 0.35
        x, y, w, h = TILES["metal"]
        tile = np.repeat(np.clip(metal, 0.0, 1.2)[:, :, None], 3, axis=2)
        rust = _periodic_noise(rng, size, 7)
        rust_mask = ((rust > 0.78) & (rng.random((size, size)) > 0.6))[:, :, None]
        tile = np.where(rust_mask, tile * np.array([0.72, 0.56, 0.48]), tile)
        self.pixels[y:y + h, x:x + w, :] = tile

        columns = 0.78 + rng.random(size) * 0.3
        hair = np.repeat(columns[None, :], size, axis=0) + _periodic_noise(rng, size, 12) * 0.08
        hair -= ((xx * 7 + yy // 5) % 13 == 0) * 0.12
        self._gray_tile("hair", hair)

        flesh = 0.82 + _periodic_noise(rng, size, 5) * 0.16 + _periodic_noise(rng, size, 14) * 0.06
        veins = np.abs(np.sin(xx * 0.31 + _periodic_noise(rng, size, 4) * 9.0)) < 0.06
        flesh -= veins * 0.14
        self._gray_tile("flesh", flesh)

        self._gray_tile("plain", np.ones((size, size)))

    def paint_brocade(self, base: Color3, accent: Color3, cell: int = 16) -> None:
        """Coloured fabric for the "pattern" tile: a worn diamond lattice with dotted motifs.
        Meshes using it should carry near-white vertex colours (shading only)."""
        x, y, w, h = TILES["pattern"]
        yy, xx = np.mgrid[0:h, 0:w]
        lattice = ((xx + yy) % cell == 0) | ((xx - yy) % cell == 0)
        centre = ((xx % cell) == cell // 2) & ((yy % cell) == 0) | ((xx % cell) == 0) & ((yy % cell) == cell // 2)
        worn = self.rng.random((h, w)) > 0.45
        mask = ((lattice | centre) & worn)[:, :, None]
        shade_noise = 0.85 + _periodic_noise(self.rng, w, 8)[:h, :w, None] * 0.25
        tile = np.array(base, dtype=np.float32)[None, None, :] * shade_noise
        tile = np.where(mask, np.array(accent, dtype=np.float32)[None, None, :] * shade_noise, tile)
        self.pixels[y:y + h, x:x + w, :] = tile

    def fill_face(self, color: Color3, noise: float = 0.05) -> None:
        x, y, w, h = TILES["face"]
        n = _periodic_noise(self.rng, w, 16)[:h, :w] * noise - noise * 0.5
        base = np.array(color, dtype=np.float32)
        self.pixels[y:y + h, x:x + w, :] = base[None, None, :] * (1.0 + n[:, :, None])

    def save(self, path: Path) -> bpy.types.Image:
        image = bpy.data.images.new(path.stem, ATLAS_W, ATLAS_H, alpha=False)
        rgba = np.ones((ATLAS_H, ATLAS_W, 4), dtype=np.float32)
        rgba[:, :, :3] = np.clip(self.pixels, 0.0, 1.0)
        image.pixels.foreach_set(rgba.ravel())
        image.filepath_raw = str(path)
        image.file_format = "PNG"
        image.save()
        return image


class FacePainter:
    """Paints onto the cylindrical head unwrap.

    theta is the angle around the head (0 = front, + toward +x) and y is
    model-space height; both map through the same projection the head mesh uses.
    """

    def __init__(self, atlas: Atlas, y0: float, y1: float) -> None:
        self.atlas = atlas
        self.y0 = y0
        self.y1 = y1

    def _px(self, theta: float, y: float) -> tuple[float, float]:
        x, yy, w, h = TILES["face"]
        u = 0.5 + theta / (2.0 * math.pi)
        v = (y - self.y0) / (self.y1 - self.y0)
        return (x + u * w, yy + v * h)

    def ellipse(self, theta: float, y: float, half_theta: float, half_y: float, color: Color3,
                alpha: float = 1.0, mirror: bool = False) -> None:
        centers = [theta, -theta] if mirror else [theta]
        for center in centers:
            cx, cy = self._px(center, y)
            ex, _ = self._px(center + half_theta, y)
            _, ey = self._px(center, y + half_y)
            rx = max(abs(ex - cx), 0.5)
            ry = max(abs(ey - cy), 0.5)
            x0, y0 = int(math.floor(cx - rx)), int(math.floor(cy - ry))
            x1, y1 = int(math.ceil(cx + rx)), int(math.ceil(cy + ry))
            for py in range(max(y0, 0), min(y1 + 1, ATLAS_H)):
                for px in range(max(x0, 0), min(x1 + 1, TILES["face"][2])):
                    dx = (px + 0.5 - cx) / rx
                    dy = (py + 0.5 - cy) / ry
                    if dx * dx + dy * dy <= 1.0:
                        old = self.atlas.pixels[py, px]
                        self.atlas.pixels[py, px] = old + (np.array(color) - old) * alpha

    def band(self, y_from: float, y_to: float, color: Color3, alpha: float = 1.0,
             theta_from: float = -math.pi, theta_to: float = math.pi) -> None:
        x0, py0 = self._px(theta_from, y_from)
        x1, py1 = self._px(theta_to, y_to)
        xs = slice(max(int(min(x0, x1)), 0), min(int(math.ceil(max(x0, x1))), TILES["face"][2]))
        ys = slice(max(int(min(py0, py1)), 0), min(int(math.ceil(max(py0, py1))), ATLAS_H))
        region = self.atlas.pixels[ys, xs]
        self.atlas.pixels[ys, xs] = region + (np.array(color) - region) * alpha

    def speckle(self, theta: float, y: float, half_theta: float, half_y: float, color: Color3,
                density: float, alpha: float = 0.6) -> None:
        cx, cy = self._px(theta, y)
        ex, _ = self._px(theta + half_theta, y)
        _, ey = self._px(theta, y + half_y)
        rx, ry = abs(ex - cx), abs(ey - cy)
        for py in range(max(int(cy - ry), 0), min(int(cy + ry) + 1, ATLAS_H)):
            for px in range(max(int(cx - rx), 0), min(int(cx + rx) + 1, TILES["face"][2])):
                dx = (px + 0.5 - cx) / max(rx, 0.5)
                dy = (py + 0.5 - cy) / max(ry, 0.5)
                if dx * dx + dy * dy <= 1.0 and self.atlas.rng.random() < density:
                    old = self.atlas.pixels[py, px]
                    self.atlas.pixels[py, px] = old + (np.array(color) - old) * alpha


# --- Mesh building --------------------------------------------------------------

@dataclass
class Ring:
    c: Vector
    rx: float
    rz: float
    col: Color3
    ax: Vector = field(default_factory=lambda: V(1.0, 0.0, 0.0))
    az: Vector = field(default_factory=lambda: V(0.0, 0.0, 1.0))
    fn: Callable[[float], float] | None = None


def ring(y: float, rx: float, rz: float, col: Color3, x: float = 0.0, z: float = 0.0,
         fn: Callable[[float], float] | None = None) -> Ring:
    return Ring(V(x, y, z), rx, rz, col, fn=fn)


def resolve_weights(spec, p: Vector) -> dict[str, float]:
    if isinstance(spec, str):
        return {spec: 1.0}
    if callable(spec):
        weights = spec(p)
    else:
        weights = dict(spec)
    total = sum(w for w in weights.values() if w > 0.0)
    return {bone: w / total for bone, w in weights.items() if w > 1e-4}


def blend_y(upper_bone: str, lower_bone: str, y_mid: float, half: float):
    """Upper bone above y_mid + half, lower bone below y_mid - half, linear between."""

    def fn(p: Vector) -> dict[str, float]:
        t = clamp((y_mid + half - p.y) / (2.0 * half), 0.0, 1.0)
        return {upper_bone: 1.0 - t, lower_bone: t}

    return fn


class MeshBuilder:
    def __init__(self) -> None:
        self.verts: list[Vector] = []
        self.weights: list[dict[str, float]] = []
        self.faces: list[tuple[int, ...]] = []
        self.face_cols: list[list[Color3]] = []
        self.face_uvs: list[list[tuple[float, float]]] = []
        self.face_smooth: list[bool] = []
        self.face_mat: list[int] = []
        self.xform: Matrix = Matrix.Identity(4)

    def vert(self, p: Vector, weights) -> int:
        p = self.xform @ Vector(p)
        self.verts.append(p)
        self.weights.append(resolve_weights(weights, p))
        return len(self.verts) - 1

    def face(self, idx: tuple[int, ...], cols: list[Color3], uvs: list[tuple[float, float]],
             smooth: bool, material: int = MATERIAL_BODY) -> None:
        self.faces.append(idx)
        self.face_cols.append(cols)
        self.face_uvs.append(uvs)
        self.face_smooth.append(smooth)
        self.face_mat.append(material)

    def _normal(self, idx: tuple[int, ...]) -> Vector:
        a, b, c = (self.verts[i] for i in idx[:3])
        return (b - a).cross(c - a)

    def loft(self, rings: list[Ring], weights, *, sides: int = 10, tile: str = "cloth",
             cap_bottom: bool | Vector = True, cap_top: bool | Vector = True, smooth: bool = True,
             two_sided: bool = False, inner_shade: float = 0.45, arc: tuple[float, float] | None = None,
             theta0: float = 0.0, uv_fn=None, u_scale: float = 1.0, material: int = MATERIAL_BODY) -> None:
        """Skins a tube through elliptical rings.

        theta = 0 points along the ring's az axis (the front for vertical tubes).
        arc limits the tube to [a0, a1] radians, leaving it open (for capes, hoods).
        uv_fn(p, u, v) -> atlas uv overrides the default tile mapping.
        """
        start_face = len(self.faces)
        start_vert = len(self.verts)
        count = sides + 1 if arc is not None else sides
        ring_ids: list[list[int]] = []
        ring_us: list[float] = []
        for j in range(count):
            if arc is not None:
                ring_us.append(j / sides)
            else:
                ring_us.append(j / sides)
        for ring_data in rings:
            ids: list[int] = []
            for j in range(count):
                if arc is not None:
                    theta = arc[0] + (arc[1] - arc[0]) * j / sides
                else:
                    theta = theta0 + 2.0 * math.pi * j / sides
                m = ring_data.fn(theta) if ring_data.fn is not None else 1.0
                p = ring_data.c + ring_data.ax * (math.sin(theta) * ring_data.rx * m) \
                    + ring_data.az * (math.cos(theta) * ring_data.rz * m)
                ids.append(self.vert(p, weights))
            ring_ids.append(ids)

        def uv_at(vid: int, u: float, v: float) -> tuple[float, float]:
            if uv_fn is not None:
                return uv_fn(self.verts[vid], u, v)
            return tile_uv(tile, u * u_scale, v)

        n = len(rings)
        quads: list[tuple[tuple[int, ...], list[Color3], list[tuple[float, float]]]] = []
        for r in range(n - 1):
            lo, up = ring_ids[r], ring_ids[r + 1]
            v0, v1 = r / (n - 1), (r + 1) / (n - 1)
            segs = sides if arc is not None else sides
            for j in range(segs):
                k = j + 1 if arc is not None else (j + 1) % sides
                u0 = ring_us[j]
                u1 = ring_us[k] if arc is not None else (j + 1) / sides
                idx = (lo[j], lo[k], up[k], up[j])
                cols = [rings[r].col, rings[r].col, rings[r + 1].col, rings[r + 1].col]
                uvs = [uv_at(lo[j], u0, v0), uv_at(lo[k], u1, v0), uv_at(up[k], u1, v1), uv_at(up[j], u0, v1)]
                quads.append((idx, cols, uvs))

        # Orient outward: compare quad normals against the ring centre.
        score = 0.0
        for r_idx, (idx, _cols, _uvs) in enumerate(quads):
            ring_index = r_idx // sides
            centre = self.xform @ ((rings[ring_index].c + rings[ring_index + 1].c) * 0.5)
            quad_centre = sum((self.verts[i] for i in idx), Vector()) / 4.0
            score += self._normal(idx).dot(quad_centre - centre)
        flip = score < 0.0

        def add(idx, cols, uvs, smooth_face=smooth):
            if flip:
                idx, cols, uvs = tuple(reversed(idx)), list(reversed(cols)), list(reversed(uvs))
            self.face(idx, cols, uvs, smooth_face, material)

        for idx, cols, uvs in quads:
            add(idx, cols, uvs)

        if arc is None:
            for cap, ring_index, top in ((cap_bottom, 0, False), (cap_top, n - 1, True)):
                if cap is False:
                    continue
                ring_data = rings[ring_index]
                apex = ring_data.c if cap is True else Vector(cap)
                centre = self.vert(apex, weights)
                ids = ring_ids[ring_index]
                v = 1.0 if top else 0.0
                for j in range(sides):
                    k = (j + 1) % sides
                    if top:
                        tri = (ids[j], ids[k], centre)
                    else:
                        tri = (ids[k], ids[j], centre)
                    cols = [ring_data.col] * 3
                    u_mid = (j + 0.5) / sides
                    uvs = [uv_at(tri[0], u_mid, v), uv_at(tri[1], u_mid, v), uv_at(centre, u_mid, v)]
                    add(tri, cols, uvs, smooth if cap is not True else False)

        if two_sided:
            self._add_inner_shell(start_vert, start_face, inner_shade)

    def _add_inner_shell(self, start_vert: int, start_face: int, inner_shade: float) -> None:
        remap: dict[int, int] = {}
        # Bypass vert(): these points are already transformed.
        for vid in range(start_vert, len(self.verts)):
            remap[vid] = len(self.verts)
            self.verts.append(Vector(self.verts[vid]))
            self.weights.append(dict(self.weights[vid]))
        end_face = len(self.faces)
        for f in range(start_face, end_face):
            idx = tuple(remap[i] for i in reversed(self.faces[f]))
            cols = [shade(c, inner_shade) for c in reversed(self.face_cols[f])]
            uvs = list(reversed(self.face_uvs[f]))
            self.face(idx, cols, uvs, self.face_smooth[f], self.face_mat[f])

    def box(self, centre: Vector, size: Vector, col: Color3, weights, *, tile: str = "plain",
            rot: Matrix | None = None, top_shade: float = 1.0, bottom_shade: float = 0.8,
            material: int = MATERIAL_BODY) -> None:
        rot = rot or Matrix.Identity(3)
        h = size * 0.5
        corners = [V(sx * h.x, sy * h.y, sz * h.z) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
        ids = [self.vert(centre + rot @ c, weights) for c in corners]

        def i(sx: int, sy: int, sz: int) -> int:
            return ids[(sx > 0) * 4 + (sy > 0) * 2 + (sz > 0)]

        faces = [
            ((i(-1, -1, 1), i(1, -1, 1), i(1, 1, 1), i(-1, 1, 1)), None),
            ((i(1, -1, -1), i(-1, -1, -1), i(-1, 1, -1), i(1, 1, -1)), None),
            ((i(-1, -1, -1), i(-1, -1, 1), i(-1, 1, 1), i(-1, 1, -1)), None),
            ((i(1, -1, 1), i(1, -1, -1), i(1, 1, -1), i(1, 1, 1)), None),
            ((i(-1, 1, 1), i(1, 1, 1), i(1, 1, -1), i(-1, 1, -1)), top_shade),
            ((i(-1, -1, -1), i(1, -1, -1), i(1, -1, 1), i(-1, -1, 1)), bottom_shade),
        ]
        uv = [tile_uv(tile, 0, 0), tile_uv(tile, 1, 0), tile_uv(tile, 1, 1), tile_uv(tile, 0, 1)]
        for idx, face_shade in faces:
            factor = face_shade if face_shade is not None else 1.0
            self.face(idx, [shade(col, factor)] * 4, uv, False, material)

    def quad(self, corners: list[Vector], col: Color3, weights, *, tile: str = "plain",
             two_sided: bool = True, material: int = MATERIAL_BODY) -> None:
        ids = tuple(self.vert(c, weights) for c in corners)
        uv = [tile_uv(tile, 0, 0), tile_uv(tile, 1, 0), tile_uv(tile, 1, 1), tile_uv(tile, 0, 1)]
        self.face(ids, [col] * 4, uv, False, material)
        if two_sided:
            back = tuple(self.vert(c, weights) for c in reversed(corners))
            self.face(back, [col] * 4, list(reversed(uv)), False, material)


def sphere(mb: MeshBuilder, centre: Vector, radius: Vector, col: Color3, weights, *, lat: int = 4,
           sides: int = 8, tile: str = "plain", bottom_col: Color3 | None = None, smooth: bool = True,
           material: int = MATERIAL_BODY) -> None:
    rings = []
    for step in range(1, lat):
        a = -math.pi * 0.5 + math.pi * step / lat
        t = step / lat
        c = mix(bottom_col or col, col, t) if bottom_col else col
        rings.append(Ring(centre + V(0.0, radius.y * math.sin(a), 0.0), radius.x * math.cos(a),
                          radius.z * math.cos(a), c))
    mb.loft(rings, weights, sides=sides, tile=tile, smooth=smooth, material=material,
            cap_bottom=centre - V(0.0, radius.y, 0.0), cap_top=centre + V(0.0, radius.y, 0.0))


def path_rings(points: list[Vector], rx: float, rz: float, cols: list[Color3],
               up_hint: Vector = V(0.0, 1.0, 0.0)) -> list[Ring]:
    """Rings perpendicular to a polyline (for straps, bows, tails)."""
    rings = []
    for i, p in enumerate(points):
        prev_p = points[max(i - 1, 0)]
        next_p = points[min(i + 1, len(points) - 1)]
        tangent = (next_p - prev_p).normalized()
        side = tangent.cross(up_hint)
        if side.length < 1e-4:
            side = tangent.cross(V(0.0, 0.0, 1.0))
        side.normalize()
        normal = side.cross(tangent).normalized()
        rings.append(Ring(Vector(p), rx, rz, cols[min(i, len(cols) - 1)], ax=side, az=normal))
    return rings


# --- Skeleton -------------------------------------------------------------------

@dataclass
class Bone:
    name: str
    head: Vector
    tail: Vector
    parent: str | None


@dataclass
class Skeleton:
    bones: list[Bone]

    def joint(self, name: str) -> Vector:
        for bone in self.bones:
            if bone.name == name:
                return Vector(bone.head)
        raise KeyError(name)


@dataclass
class Proportions:
    hip_y: float = 0.88
    leg_splay: float = 0.09
    upper_leg: float = 0.40
    lower_leg: float = 0.34
    torso: float = 0.46
    shoulder_y: float = 0.40
    shoulder_x: float = 0.19
    upper_arm: float = 0.27
    fore_arm: float = 0.24
    hand: float = 0.09
    neck: float = 0.07

    @property
    def ankle_y(self) -> float:
        return self.hip_y - 0.06 - self.upper_leg - self.lower_leg


def humanoid_skeleton(p: Proportions) -> Skeleton:
    hips = V(0.0, p.hip_y, 0.0)
    spine = hips + V(0.0, 0.04, 0.0)
    neck = spine + V(0.0, p.torso, 0.0)
    head = neck + V(0.0, p.neck, 0.0)
    bones = [
        Bone("Hips", hips, hips + V(0.0, 0.03, 0.0), None),
        Bone("Spine", spine, neck, "Hips"),
        Bone("Neck", neck, head, "Spine"),
        Bone("Head", head, head + V(0.0, 0.2, 0.0), "Neck"),
    ]
    for suffix, side in (("L", -1.0), ("R", 1.0)):
        shoulder = spine + V(side * p.shoulder_x, p.shoulder_y, 0.0)
        elbow = shoulder - V(0.0, p.upper_arm, 0.0)
        wrist = elbow - V(0.0, p.fore_arm, 0.0)
        bones += [
            Bone("UpperArm" + suffix, shoulder, elbow, "Spine"),
            Bone("ForeArm" + suffix, elbow, wrist, "UpperArm" + suffix),
            Bone("Hand" + suffix, wrist, wrist - V(0.0, p.hand, 0.0), "ForeArm" + suffix),
        ]
        hip = hips + V(side * p.leg_splay, -0.06, 0.0)
        knee = hip - V(0.0, p.upper_leg, 0.0)
        ankle = knee - V(0.0, p.lower_leg, 0.0)
        bones += [
            Bone("UpperLeg" + suffix, hip, knee, "Hips"),
            Bone("LowerLeg" + suffix, knee, ankle, "UpperLeg" + suffix),
            Bone("Foot" + suffix, ankle, ankle + V(0.0, -0.04, 0.1), "LowerLeg" + suffix),
        ]
    return Skeleton(bones)


# --- Animation ------------------------------------------------------------------

@dataclass
class Clip:
    """Keys use the old Godot rig's convention: Euler degrees applied in an
    identity-oriented frame per bone (Godot YXZ order), plus Hips offsets."""

    name: str
    length: float
    rot: dict[str, tuple[list[float], list[tuple[float, float, float]]]] = field(default_factory=dict)
    hips: tuple[list[float], list[Vector]] | None = None
    interpolation: str = "BEZIER"

    def track(self, bone: str, times: list[float], eulers: list[tuple[float, float, float]]) -> None:
        self.rot[bone] = (times, eulers)


def godot_euler_matrix(deg: tuple[float, float, float]) -> Matrix:
    x, y, z = (math.radians(a) for a in deg)
    return Matrix.Rotation(y, 3, "Y") @ Matrix.Rotation(x, 3, "X") @ Matrix.Rotation(z, 3, "Z")


# --- Blender scene assembly -----------------------------------------------------

def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS


def create_armature(name: str, skeleton: Skeleton) -> bpy.types.Object:
    data = bpy.data.armatures.new(name + "Armature")
    obj = bpy.data.objects.new("Armature", data)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    for bone in skeleton.bones:
        edit_bone = data.edit_bones.new(bone.name)
        edit_bone.head = to_blender(bone.head)
        edit_bone.tail = to_blender(bone.tail)
        edit_bone.roll = 0.0
    for bone in skeleton.bones:
        if bone.parent is not None:
            data.edit_bones[bone.name].parent = data.edit_bones[bone.parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def create_material(name: str, image: bpy.types.Image, glow: Color3 | None = None) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 1.0
    if glow is not None:
        bsdf.inputs["Base Color"].default_value = (*glow, 1.0)
        bsdf.inputs["Emission Color"].default_value = (*glow, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.0
        return material
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"
    attr = nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Color"
    multiply = nodes.new("ShaderNodeMix")
    multiply.data_type = "RGBA"
    multiply.blend_type = "MULTIPLY"
    multiply.inputs["Factor"].default_value = 1.0
    links.new(tex.outputs["Color"], multiply.inputs["A"])
    links.new(attr.outputs["Color"], multiply.inputs["B"])
    links.new(multiply.outputs["Result"], bsdf.inputs["Base Color"])
    return material


def create_mesh_objects(name: str, mb: MeshBuilder, armature: bpy.types.Object,
                        materials: list[bpy.types.Material]) -> None:
    """One skinned object per material, so Godot can override each MeshInstance3D whole."""
    for material_index, material in enumerate(materials):
        faces = [f for f, mat in enumerate(mb.face_mat) if mat == material_index]
        if faces:
            suffix = "" if material_index == 0 else material.name
            _create_mesh_object(name + suffix, mb, faces, armature, material)


def _create_mesh_object(name: str, mb: MeshBuilder, faces: list[int], armature: bpy.types.Object,
                        material: bpy.types.Material) -> bpy.types.Object:
    remap: dict[int, int] = {}
    for f in faces:
        for vid in mb.faces[f]:
            remap.setdefault(vid, len(remap))
    source_ids = list(remap)
    mesh = bpy.data.meshes.new(name)
    verts = [to_blender(mb.verts[vid]) for vid in source_ids]
    mesh.from_pydata(verts, [], [tuple(remap[vid] for vid in mb.faces[f]) for f in faces])
    mesh.update()
    mesh.materials.append(material)

    uv_layer = mesh.uv_layers.new(name="UVMap")
    color_layer = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="CORNER")
    for poly, f in zip(mesh.polygons, faces):
        cols, uvs = mb.face_cols[f], mb.face_uvs[f]
        poly.use_smooth = mb.face_smooth[f]
        for corner, loop_index in enumerate(poly.loop_indices):
            uv_layer.data[loop_index].uv = uvs[corner]
            # Colours are authored in sRGB; the float attribute (and glTF COLOR_0) is linear.
            r, g, b = (srgb_to_linear(c) for c in cols[corner])
            color_layer.data[loop_index].color = (r, g, b, 1.0)
    mesh.color_attributes.active_color = color_layer

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = armature
    for bone in armature.data.bones:
        obj.vertex_groups.new(name=bone.name)
    for new_id, vid in enumerate(source_ids):
        for bone, w in mb.weights[vid].items():
            obj.vertex_groups[bone].add([new_id], w, "REPLACE")
    modifier = obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = armature
    return obj


def bake_clips(armature: bpy.types.Object, clips: list[Clip], hip_rest: Vector) -> None:
    bones = armature.data.bones
    rest = {bone.name: bone.matrix_local.to_3x3() for bone in bones}
    armature.animation_data_create()
    for pose_bone in armature.pose.bones:
        pose_bone.rotation_mode = "QUATERNION"

    for clip in clips:
        action = bpy.data.actions.new(clip.name)
        action.use_fake_user = True
        armature.animation_data.action = action
        for pose_bone in armature.pose.bones:
            pose_bone.rotation_quaternion = Quaternion()
            pose_bone.location = Vector()

        end_frame = round(clip.length * FPS)
        for pose_bone in armature.pose.bones:
            name = pose_bone.name
            times, eulers = clip.rot.get(name, ([0.0, clip.length], [(0.0, 0.0, 0.0)] * 2))
            if len(times) == 1:
                times, eulers = [0.0, clip.length], [eulers[0], eulers[0]]
            r = rest[name]
            previous: Quaternion | None = None
            for t, euler in zip(times, eulers):
                d_blender = GODOT_TO_BLENDER @ godot_euler_matrix(euler) @ GODOT_TO_BLENDER.transposed()
                q = (r.transposed() @ d_blender @ r).to_quaternion()
                if previous is not None and previous.dot(q) < 0.0:
                    q.negate()
                previous = q
                pose_bone.rotation_quaternion = q
                pose_bone.keyframe_insert("rotation_quaternion", frame=round(t * FPS))
            if name == "Hips":
                hip_times, offsets = clip.hips or ([0.0, clip.length], [V(0, 0, 0), V(0, 0, 0)])
                for t, offset in zip(hip_times, offsets):
                    pose_bone.location = r.transposed() @ (GODOT_TO_BLENDER @ offset)
                    pose_bone.keyframe_insert("location", frame=round(t * FPS))

        for fcurve in _action_fcurves(action):
            for key in fcurve.keyframe_points:
                key.interpolation = clip.interpolation
        action.frame_range = (0.0, float(end_frame))
        action.use_frame_range = True
        track = armature.animation_data.nla_tracks.new()
        track.name = clip.name
        track.strips.new(clip.name, 0, action)
        track.mute = True
        armature.animation_data.action = None


def _action_fcurves(action: bpy.types.Action):
    if hasattr(action, "fcurves") and len(getattr(action, "fcurves", [])) > 0:
        return list(action.fcurves)
    curves = []
    for layer in getattr(action, "layers", []):
        for strip in layer.strips:
            for bag in strip.channelbags:
                curves.extend(bag.fcurves)
    return curves


def export(path_glb: Path, path_blend: Path | None) -> None:
    path_glb.parent.mkdir(parents=True, exist_ok=True)
    if path_blend is not None:
        path_blend.parent.mkdir(parents=True, exist_ok=True)
        bpy.context.preferences.filepaths.save_version = 0  # no .blend1 backups
        bpy.ops.wm.save_as_mainfile(filepath=str(path_blend), compress=True)
    bpy.ops.export_scene.gltf(
        filepath=str(path_glb),
        export_format="GLB",
        export_yup=True,
        export_skins=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_force_sampling=True,
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
        export_image_format="AUTO",
        export_def_bones=False,
    )
