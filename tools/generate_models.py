"""Generate Redelka's character and enemy models with Blender.

Run (all models, or only the listed ids):
    blender --background --factory-startup --python tools/generate_models.py
    blender --background --factory-startup --python tools/generate_models.py -- bran hollow

Writes assets/models/<id>.glb (skinned mesh, armature, idle/walk/attack/chant/
chant_release clips). The matching .blend file and texture atlas go to
assets/models/source/ for inspection; Godot ignores that folder. Re-running
overwrites both, so make lasting changes here rather than in the .blend.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from model_kit import (  # noqa: E402
    MATERIAL_GLOW,
    Atlas,
    Clip,
    FacePainter,
    MeshBuilder,
    Proportions,
    Ring,
    V,
    bake_clips,
    clamp,
    create_armature,
    create_material,
    create_mesh_objects,
    export,
    hex_color,
    humanoid_skeleton,
    mix,
    path_rings,
    reset_scene,
    resolve_weights,
    shade,
    sphere,
    tile_uv,
)
from mathutils import Matrix, Vector  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = ROOT / "assets" / "models"
SOURCE_DIR = OUTPUT_DIR / "source"

WHITE = (1.0, 1.0, 1.0)
EYE_WHITE = (0.82, 0.78, 0.7)

# Head silhouette relative to the Head joint: (dy, rx, rz, z offset).
HUMAN_HEAD = [
    (-0.028, 0.026, 0.026, 0.044),
    (0.0, 0.056, 0.06, 0.03),
    (0.03, 0.072, 0.08, 0.014),
    (0.065, 0.082, 0.09, 0.006),
    (0.1, 0.088, 0.094, 0.0),
    (0.135, 0.09, 0.096, -0.005),
    (0.17, 0.082, 0.089, -0.01),
    (0.2, 0.058, 0.066, -0.012),
]
HEAD_TOP = 0.222


def chain_y(segments: list[tuple[str, float]], half: float):
    """Weights along a vertical chain: segments are (bone, joint_y) top to bottom."""

    def fn(p: Vector) -> dict[str, float]:
        for i in range(len(segments) - 1):
            bone = segments[i][0]
            lower, joint_y = segments[i + 1]
            if p.y > joint_y + half:
                return {bone: 1.0}
            if p.y > joint_y - half:
                t = (joint_y + half - p.y) / (2.0 * half)
                return {bone: 1.0 - t, lower: t}
        return {segments[-1][0]: 1.0}

    return fn


def lerp_profile(profile: list[tuple[float, float, float, float]], dy: float) -> tuple[float, float, float]:
    if dy <= profile[0][0]:
        return profile[0][1:]
    for a, b in zip(profile, profile[1:]):
        if a[0] <= dy <= b[0]:
            t = (dy - a[0]) / (b[0] - a[0])
            return tuple(a[k] + (b[k] - a[k]) * t for k in (1, 2, 3))  # type: ignore[return-value]
    return profile[-1][1:]


def face_flat(theta: float) -> float:
    return 1.0 - 0.07 * max(0.0, math.cos(theta)) ** 6


def jagged(amount: float, freq: int, phase: float = 0.0):
    def fn(theta: float) -> float:
        return 1.0 + amount * (math.sin(theta * freq + phase) * 0.6 + math.sin(theta * freq * 2.3 + phase * 1.7) * 0.4)

    return fn


class Figure:
    """One model in progress: skeleton, mesh, atlas and animation tweaks."""

    def __init__(self, model_id: str, p: Proportions, seed: int, *, width: float = 1.0, depth: float = 1.0,
                 girth: float = 1.0, hip_width: float = 1.0) -> None:
        self.model_id = model_id
        self.p = p
        self.sk = humanoid_skeleton(p)
        self.mb = MeshBuilder()
        self.atlas = Atlas(seed)
        self.width = width
        self.depth = depth
        self.girth = girth
        self.hip_width = hip_width
        self.attack_style = "melee"
        self.walk_swing = 1.0
        self.bias: dict[str, tuple[float, float, float]] = {}
        self.hip_bias = V(0.0, 0.0, 0.0)
        self.floating = False
        self.glow = (0.6, 0.4, 0.9)
        self.head_profile = HUMAN_HEAD
        self.face: FacePainter | None = None

    # -- joints --------------------------------------------------------------
    def j(self, name: str) -> Vector:
        return self.sk.joint(name)

    @property
    def hips(self) -> Vector:
        return self.j("Hips")

    @property
    def spine(self) -> Vector:
        return self.j("Spine")

    @property
    def neck(self) -> Vector:
        return self.j("Neck")

    @property
    def head(self) -> Vector:
        return self.j("Head")

    # -- weights -------------------------------------------------------------
    def leg_w(self, s: str):
        return chain_y([("Hips", 0.0), ("UpperLeg" + s, self.j("UpperLeg" + s).y + 0.02),
                        ("LowerLeg" + s, self.j("LowerLeg" + s).y), ("Foot" + s, self.j("Foot" + s).y)], 0.04)

    def arm_w(self, s: str):
        return chain_y([("Spine", 0.0), ("UpperArm" + s, self.j("UpperArm" + s).y + 0.03),
                        ("ForeArm" + s, self.j("ForeArm" + s).y), ("Hand" + s, self.j("Hand" + s).y + 0.005)], 0.035)

    def torso_w(self):
        return chain_y([("Neck", 0.0), ("Spine", self.neck.y + 0.015), ("Hips", self.spine.y + 0.05)], 0.06)

    def skirt_w(self, follow: float = 0.55, reach: float = 0.35):
        hip_y = self.hips.y - 0.06
        torso = self.torso_w()

        def fn(p: Vector) -> dict[str, float]:
            if p.y > hip_y:
                return torso(p)
            t = clamp((hip_y - p.y) / reach, 0.0, 1.0) * follow * clamp(abs(p.x) / 0.07, 0.0, 1.0)
            return {"Hips": 1.0 - t, ("UpperLegL" if p.x < 0.0 else "UpperLegR"): t}

        return fn

    # -- body ----------------------------------------------------------------
    def legs(self, pants, *, thigh: float = 1.0, tile: str = "cloth") -> None:
        g = self.girth * thigh
        for s, side in (("L", -1.0), ("R", 1.0)):
            hip, knee, ankle = self.j("UpperLeg" + s), self.j("LowerLeg" + s), self.j("Foot" + s)
            x = hip.x
            rings = [
                Ring(V(x * 0.8, hip.y + 0.06, 0.0), 0.08 * g, 0.085 * g, pants),
                Ring(V(x, hip.y - 0.06, 0.0), 0.08 * g, 0.084 * g, pants),
                Ring(V(x, hip.y - (hip.y - knee.y) * 0.55, 0.004), 0.066 * g, 0.07 * g, shade(pants, 0.95)),
                Ring(V(x, knee.y + 0.03, 0.006), 0.054 * g, 0.06 * g, shade(pants, 0.9)),
                Ring(V(x, knee.y - 0.02, 0.0), 0.052 * g, 0.058 * g, shade(pants, 0.88)),
                Ring(V(x, knee.y - (knee.y - ankle.y) * 0.35, -0.008), 0.054 * g, 0.06 * g, shade(pants, 0.84)),
                Ring(V(x, ankle.y + 0.06, 0.0), 0.04 * g, 0.042 * g, shade(pants, 0.78)),
                Ring(V(x, ankle.y - 0.01, 0.0), 0.036 * g, 0.038 * g, shade(pants, 0.75)),
            ]
            self.mb.loft(rings, self.leg_w(s), sides=8, tile=tile, cap_top=False)

    def boots(self, col, *, shaft: float = 0.13, width: float = 1.0, toe: float = 0.13, tile: str = "leather",
              cuff: bool = True) -> None:
        for s in ("L", "R"):
            ankle = self.j("Foot" + s)
            x = ankle.x
            w = width * self.girth ** 0.3
            shaft_rings = [
                Ring(V(x, 0.03, -0.005), 0.05 * w, 0.056 * w, shade(col, 0.8)),
                Ring(V(x, ankle.y + 0.02, 0.0), 0.047 * w, 0.052 * w, col),
                Ring(V(x, ankle.y + shaft, 0.0), 0.054 * w, 0.058 * w, col),
            ]
            if cuff:
                shaft_rings.append(Ring(V(x, ankle.y + shaft + 0.025, 0.0), 0.058 * w, 0.062 * w, shade(col, 1.12)))
            self.mb.loft(shaft_rings, chain_y([("LowerLeg" + s, 0), ("Foot" + s, ankle.y + 0.03)], 0.03),
                         sides=8, tile=tile, cap_bottom=False, cap_top=False, two_sided=True)
            up = V(0.0, 1.0, 0.0)
            foot = [
                Ring(V(x, 0.045, -0.055), 0.042 * w, 0.045, shade(col, 0.75), az=up),
                Ring(V(x, 0.05, 0.0), 0.05 * w, 0.05, shade(col, 0.9), az=up),
                Ring(V(x, 0.04, toe * 0.55), 0.05 * w, 0.04, col, az=up),
                Ring(V(x, 0.03, toe), 0.04 * w, 0.03, shade(col, 0.95), az=up),
            ]
            for r in foot:
                r.ax = V(1.0, 0.0, 0.0)
            self.mb.loft(foot, "Foot" + s, sides=8, theta0=math.pi / 8, tile=tile, smooth=False,
                         cap_bottom=True, cap_top=V(x, 0.028, toe + 0.018))

    def pelvis(self, col, tile: str = "cloth") -> None:
        y = self.hips.y
        hw, w, d = self.hip_width * self.width, self.width, self.depth
        rings = [
            Ring(V(0, y - 0.17, 0.0), 0.05, 0.05, shade(col, 0.7)),
            Ring(V(0, y - 0.12, 0.0), 0.128 * hw, 0.096 * d, shade(col, 0.82)),
            Ring(V(0, y - 0.04, 0.0), 0.15 * hw, 0.108 * d, col),
            Ring(V(0, y + 0.07, 0.0), 0.134 * w, 0.098 * d, col),
        ]
        self.mb.loft(rings, self.skirt_w(follow=0.35, reach=0.12), sides=10, tile=tile, cap_top=False)

    def torso(self, col, *, chest: float = 1.0, belly: float = 1.0, tile: str = "cloth", sides: int = 12,
              upper_col=None) -> None:
        sy = self.spine.y
        w, d = self.width, self.depth
        sx = self.p.shoulder_x
        upper = upper_col or col
        squarish = lambda th: 1.0 + 0.05 * (1.0 - math.cos(4.0 * th)) * 0.5  # noqa: E731
        rings = [
            Ring(V(0, sy - 0.06, 0.0), 0.13 * w * belly, 0.096 * d * belly, shade(col, 0.82), fn=squarish),
            Ring(V(0, sy + 0.08, 0.004), 0.13 * w * belly, 0.098 * d * belly, shade(col, 0.9), fn=squarish),
            Ring(V(0, sy + 0.22, 0.008), 0.146 * w * chest, 0.11 * d * chest, mix(col, upper, 0.5), fn=squarish),
            Ring(V(0, sy + 0.33, 0.004), 0.158 * w * chest, 0.11 * d * chest, upper, fn=squarish),
            Ring(V(0, sy + self.p.shoulder_y + 0.01, -0.004), sx + 0.03, 0.094 * d, upper, fn=squarish),
            Ring(V(0, sy + self.p.torso - 0.02, -0.008), 0.1 * w, 0.074 * d, shade(upper, 0.95)),
            Ring(V(0, sy + self.p.torso + 0.01, -0.006), 0.058, 0.054, shade(upper, 0.9)),
        ]
        self.mb.loft(rings, self.torso_w(), sides=sides, tile=tile, cap_bottom=False, cap_top=False)

    def neck_mesh(self, col) -> None:
        n = self.neck
        rings = [
            Ring(V(0, n.y - 0.04, -0.006), 0.052, 0.05, shade(col, 0.78)),
            Ring(V(0, n.y + 0.04, 0.0), 0.046, 0.046, shade(col, 0.88)),
            Ring(V(0, self.head.y + 0.03, 0.004), 0.044, 0.046, col),
        ]
        self.mb.loft(rings, chain_y([("Head", 0), ("Neck", self.head.y + 0.01), ("Spine", n.y)], 0.03),
                     sides=8, tile="plain", cap_bottom=False, cap_top=False)

    def arms(self, sleeve, skin, *, tile: str = "cloth", cuff=None, thickness: float = 1.0) -> None:
        g = self.girth * thickness
        for s in ("L", "R"):
            sh, el, wr = self.j("UpperArm" + s), self.j("ForeArm" + s), self.j("Hand" + s)
            x = sh.x
            rings = [
                Ring(V(x, sh.y + 0.005, 0.0), 0.05 * g, 0.054 * g, sleeve),
                Ring(V(x, sh.y - 0.03, 0.0), 0.056 * g, 0.06 * g, sleeve),
                Ring(V(x, sh.y - 0.1, 0.0), 0.05 * g, 0.054 * g, shade(sleeve, 0.95)),
                Ring(V(x, el.y + 0.03, 0.0), 0.043 * g, 0.046 * g, shade(sleeve, 0.9)),
                Ring(V(x, el.y - 0.03, -0.006), 0.043 * g, 0.046 * g, shade(sleeve, 0.88)),
                Ring(V(x, el.y - 0.1, 0.0), 0.042 * g, 0.044 * g, shade(sleeve, 0.85)),
                Ring(V(x, wr.y + 0.025, 0.0), 0.034 * g, 0.036 * g, shade(sleeve, 0.8)),
                Ring(V(x, wr.y - 0.005, 0.0), 0.032 * g, 0.034 * g, shade(sleeve, 0.78)),
            ]
            self.mb.loft(rings, self.arm_w(s), sides=8, tile=tile, cap_top=V(x, sh.y + 0.03, 0.0), cap_bottom=False)
            if cuff is not None:
                self.mb.loft([
                    Ring(V(x, wr.y - 0.0, 0.0), 0.038 * g, 0.04 * g, shade(cuff, 0.85)),
                    Ring(V(x, wr.y + 0.075, 0.0), 0.04 * g, 0.043 * g, cuff),
                ], self.arm_w(s), sides=8, tile="leather", cap_bottom=False, cap_top=False, two_sided=True)
            self.hand(s, skin)

    def hand(self, s: str, skin, *, claw=None, claw_len: float = 0.0, scale: float = 1.0) -> None:
        wr = self.j("Hand" + s)
        x = wr.x
        k = scale
        inward = -1.0 if s == "R" else 1.0
        rings = [
            Ring(V(x, wr.y + 0.012, 0.0), 0.028 * k, 0.031 * k, shade(skin, 0.85)),
            Ring(V(x, wr.y - 0.025 * k, 0.006), 0.022 * k, 0.04 * k, skin),
            Ring(V(x, wr.y - 0.062 * k, 0.012), 0.021 * k, 0.038 * k, skin),
            Ring(V(x, wr.y - 0.088 * k, 0.016), 0.016 * k, 0.028 * k, shade(skin, 0.9)),
        ]
        self.mb.loft(rings, "Hand" + s, sides=8, tile="plain", cap_bottom=False,
                     cap_top=V(x, wr.y - 0.098 * k, 0.012))
        self.mb.box(V(x + inward * 0.012, wr.y - 0.04 * k, 0.04 * k), V(0.016, 0.042, 0.018) * k,
                    shade(skin, 0.92), "Hand" + s)
        if claw is not None:
            for i, dz in enumerate((-0.022, 0.0, 0.022)):
                base = V(x, wr.y - 0.085 * k, 0.014 + dz * k)
                tip = base + V(0.0, -claw_len, 0.03 + 0.01 * i)
                self.spike(base, tip, 0.009, claw, "Hand" + s)

    def spike(self, base: Vector, tip: Vector, radius: float, col, weights, sides: int = 4) -> None:
        axis = (tip - base).normalized()
        ref = V(1.0, 0.0, 0.0) if abs(axis.x) < 0.9 else V(0.0, 0.0, 1.0)
        ax = axis.cross(ref).normalized()
        az = ax.cross(axis).normalized()
        r = Ring(base, radius, radius, col, ax=ax, az=az)
        r2 = Ring(base - axis * radius, radius * 0.6, radius * 0.6, shade(col, 0.8), ax=ax, az=az)
        self.mb.loft([r2, r], weights, sides=sides, tile="plain", smooth=False, cap_bottom=True, cap_top=tip)

    # -- head ----------------------------------------------------------------
    def head_mesh(self, *, sides: int = 12, profile=None, nose: bool = True, ears: bool = True,
                  skin=None, ear_col=None) -> FacePainter:
        h = self.head
        if profile is not None:
            self.head_profile = profile
        prof = self.head_profile
        y0, y1 = h.y + prof[0][0] - 0.01, h.y + HEAD_TOP + 0.005
        self.face = FacePainter(self.atlas, y0, y1)

        def uv(p: Vector, u: float, v: float) -> tuple[float, float]:
            return tile_uv("face", u, (p.y - y0) / (y1 - y0))

        rings = [Ring(V(0.0, h.y + dy, z), rx, rz, WHITE, fn=face_flat) for dy, rx, rz, z in prof]
        self.mb.loft(rings, "Head", sides=sides, theta0=-math.pi, uv_fn=uv,
                     cap_bottom=V(0.0, h.y + prof[0][0] - 0.004, prof[0][3]),
                     cap_top=V(0.0, h.y + HEAD_TOP, prof[-1][3]))
        if nose and skin is not None:
            _, rz, z = lerp_profile(prof, 0.07)
            base_z = rz + z - 0.012
            nose_rings = [Ring(V(0.0, h.y + 0.078, base_z), 0.012, 0.018, shade(skin, 0.9), ax=V(1, 0, 0),
                               az=V(0, 1, 0))]
            self.mb.loft(nose_rings + [Ring(V(0.0, h.y + 0.062, base_z + 0.014), 0.013, 0.01, shade(skin, 0.84),
                                            ax=V(1, 0, 0), az=V(0, 1, 0))],
                         "Head", sides=4, theta0=math.pi / 4, tile="plain", smooth=False, cap_bottom=False,
                         cap_top=V(0.0, h.y + 0.058, base_z + 0.024))
        if ears and skin is not None:
            col = ear_col or shade(skin, 0.92)
            for side in (-1.0, 1.0):
                rx = lerp_profile(prof, 0.09)[0]
                self.mb.box(V(side * (rx + 0.004), h.y + 0.088, -0.008), V(0.016, 0.042, 0.03), col, "Head")
        return self.face

    def paint_face(self, skin, hair, *, eyes=(0.2, 0.15, 0.12), lips=None, brow: float = 1.0,
                   stubble: float = 0.0, freckles: bool = False, scar: bool = False, hairline: float = 0.17,
                   lashes: bool = False) -> None:
        f = self.face
        h = self.head.y
        self.atlas.fill_face(skin)
        f.band(h - 0.04, h + 0.01, shade(skin, 0.82), 0.45)
        f.band(h + hairline, h + 0.24, hair)
        f.band(h + 0.0, h + 0.24, hair, theta_from=-math.pi, theta_to=-2.0)
        f.band(h + 0.0, h + 0.24, hair, theta_from=2.0, theta_to=math.pi)
        f.ellipse(0.34, h + 0.097, 0.2, 0.014, shade(skin, 0.78), 0.55, mirror=True)
        f.ellipse(0.0, h + 0.07, 0.06, 0.03, shade(skin, 1.06), 0.4)
        f.ellipse(0.36, h + 0.098, 0.12, 0.0045, EYE_WHITE, 1.0, mirror=True)
        f.ellipse(0.33, h + 0.098, 0.05, 0.0045, eyes, 1.0, mirror=True)
        if lashes:
            f.ellipse(0.37, h + 0.103, 0.13, 0.0025, shade(hair, 0.6), 1.0, mirror=True)
        f.ellipse(0.37, h + 0.118, 0.15, 0.004 * brow, shade(hair, 0.85), 1.0, mirror=True)
        f.ellipse(0.0, h + 0.03, 0.17, 0.004, lips or shade(skin, 0.62), 1.0)
        f.ellipse(0.0, h + 0.02, 0.1, 0.006, shade(skin, 0.86), 0.5)
        f.ellipse(0.5, h + 0.055, 0.12, 0.02, shade(skin, 0.9), 0.35, mirror=True)
        if stubble > 0.0:
            f.speckle(0.0, h + 0.02, 0.95, 0.04, shade(hair, 0.9), stubble, 0.55)
        if freckles:
            f.speckle(0.0, h + 0.075, 0.55, 0.012, shade(skin, 0.72), 0.25, 0.6)
        if scar:
            for i in range(7):
                f.ellipse(-0.42 + i * 0.012, h + 0.125 - i * 0.012, 0.012, 0.003, shade(skin, 0.6), 0.9)

    def hair_cap(self, col, *, front_y: float = 0.135, back_y: float = 0.03, offset: float = 0.008,
                 rough: float = 0.03, long_back: float = 0.0, tile: str = "hair",
                 sides: int = 12) -> None:
        h = self.head
        prof = self.head_profile
        top = [(dy, *lerp_profile(prof, dy)) for dy in (front_y, 0.16, 0.185, 0.205)]
        rings = [Ring(V(0.0, h.y + dy, z), rx + offset, rz + offset, shade(col, 0.9 + i * 0.04),
                      fn=jagged(rough * 0.4, 9, 1.0)) for i, (dy, rx, rz, z) in enumerate(top)]
        self.mb.loft(rings, "Head", sides=sides, tile=tile, cap_bottom=False,
                     cap_top=V(0.0, h.y + HEAD_TOP + offset * 1.4, prof[-1][3]))
        back = []
        for dy in (back_y - long_back, back_y, (back_y + front_y) * 0.5, front_y + 0.01):
            rx, rz, z = lerp_profile(prof, max(dy, back_y))
            extra = 0.01 if dy < back_y else 0.0
            back.append(Ring(V(0.0, h.y + dy, z - extra), rx + offset + extra, rz + offset + extra,
                             shade(col, 0.82 if dy <= back_y else 0.95), fn=jagged(rough, 11)))
        self.mb.loft(back, "Head" if long_back <= 0.05 else chain_y([("Head", 0), ("Neck", h.y - 0.02)], 0.03),
                     sides=sides, arc=(1.05, 2.0 * math.pi - 1.05), tile=tile, two_sided=True)

    def hood(self, col, *, peak: float = 0.0, opening: float = 0.78, mantle: float = 0.17,
             tile: str = "cloth", pad: float = 0.028, overhang: float = 0.0, trim=None) -> None:
        """overhang pushes the upper hood forward so its brim shades the face; trim edges the opening."""
        h = self.head
        prof = self.head_profile
        close_y = 0.15  # the face opening stops at the brow; above it the hood is a closed shell

        def hood_ring(dy: float) -> Ring:
            rx, rz, z = lerp_profile(prof, dy)
            forward = overhang * clamp(dy / close_y, 0.0, 1.0)
            return Ring(V(0.0, h.y + dy, z - 0.01 + forward), rx + pad, rz + pad, shade(col, 0.85 + dy))

        weights = chain_y([("Head", 0.0), ("Neck", h.y - 0.0)], 0.04)
        sides_rows = [hood_ring(dy) for dy in (-0.02, 0.05, 0.11, close_y)]
        self.mb.loft(sides_rows, weights, sides=12, arc=(opening, 2.0 * math.pi - opening), tile=tile,
                     two_sided=True, inner_shade=0.35)
        top = h.y + HEAD_TOP + pad * 0.9
        crown = [hood_ring(close_y), hood_ring(0.19), Ring(V(0.0, top, -0.02), 0.035, 0.04, col)]
        apex = V(0.0, top + 0.012, -0.022)
        if peak > 0.0:
            crown.append(Ring(V(0.0, top + peak * 0.45, -0.045), 0.022, 0.024, shade(col, 0.92)))
            crown.append(Ring(V(0.0, top + peak * 0.8, -0.09), 0.009, 0.01, shade(col, 0.85)))
            apex = V(0.0, top + peak, -0.13)
        self.mb.loft(crown, weights, sides=12, theta0=-math.pi, tile=tile, cap_bottom=False, cap_top=apex,
                     two_sided=True, inner_shade=0.35)
        if trim is not None:
            def edge(r: Ring, theta: float) -> Vector:
                return r.c + r.ax * (math.sin(theta) * (r.rx + 0.003)) + r.az * (math.cos(theta) * (r.rz + 0.003))

            top_ring = sides_rows[-1]
            path = [edge(r, opening) for r in sides_rows]
            path += [edge(top_ring, opening * (1.0 - 2.0 * i / 6)) for i in range(1, 6)]
            path += [edge(r, -opening) for r in reversed(sides_rows)]
            self.mb.loft(path_rings(path, 0.008, 0.008, [trim], up_hint=V(0.0, 0.0, 1.0)), weights, sides=4,
                         tile="metal", smooth=False, cap_bottom=False, cap_top=False)
        # Mantle over the shoulders.
        sy = self.spine.y
        mantle_rings = [
            Ring(V(0.0, h.y - 0.0, -0.01), 0.1, 0.1, col),
            Ring(V(0.0, self.neck.y + 0.0, -0.005), 0.13 * self.width, 0.11 * self.depth, shade(col, 0.95)),
            Ring(V(0.0, sy + self.p.shoulder_y - 0.02, 0.0), self.p.shoulder_x + 0.045, 0.125 * self.depth,
                 shade(col, 0.88), fn=jagged(0.03, 7)),
            Ring(V(0.0, sy + self.p.shoulder_y - mantle, 0.0), self.p.shoulder_x + 0.06, 0.14 * self.depth,
                 shade(col, 0.78), fn=jagged(0.06, 7)),
        ]
        mantle_w = chain_y([("Head", 0.0), ("Neck", h.y - 0.01), ("Spine", self.neck.y)], 0.03)
        self.mb.loft(mantle_rings, mantle_w, sides=12, tile=tile, cap_bottom=False, cap_top=False, two_sided=True)
        if trim is not None:
            hem = mantle_rings[-1]
            band = [Ring(hem.c + V(0.0, dy, 0.0), hem.rx + 0.004, hem.rz + 0.004, trim, fn=hem.fn)
                    for dy in (0.0, 0.022)]
            self.mb.loft(band, mantle_w, sides=12, tile="metal", cap_bottom=False, cap_top=False, two_sided=True)

    def jacket(self, col, *, opening: float, pad: float = 0.014, tile: str = "cloth") -> None:
        """Open-fronted shell over the torso (coat, vest); opening is the half-angle of the front gap."""
        sy = self.spine.y
        w, d = self.width, self.depth
        squarish = lambda th: 1.0 + 0.05 * (1.0 - math.cos(4.0 * th)) * 0.5  # noqa: E731
        rings = [
            Ring(V(0, sy - 0.04, 0.004), 0.132 * w + pad, 0.098 * d + pad, shade(col, 0.85), fn=squarish),
            Ring(V(0, sy + 0.2, 0.01), 0.148 * w + pad, 0.112 * d + pad, col, fn=squarish),
            Ring(V(0, sy + 0.33, 0.004), 0.16 * w + pad, 0.112 * d + pad, col, fn=squarish),
            Ring(V(0, sy + self.p.shoulder_y + 0.01, -0.004), self.p.shoulder_x + 0.03 + pad, 0.096 * d + pad,
                 col, fn=squarish),
            Ring(V(0, sy + self.p.torso - 0.02, -0.008), 0.1 * w + pad, 0.076 * d + pad, shade(col, 1.05)),
        ]
        self.mb.loft(rings, self.torso_w(), sides=16, arc=(opening, 2.0 * math.pi - opening), tile=tile,
                     two_sided=True)

    def lapels(self, col, *, width: float = 0.06, depth_z: float = 0.13) -> None:
        sy = self.spine.y
        top, bottom = sy + self.p.shoulder_y + 0.02, sy + 0.22
        for side in (-1.0, 1.0):
            corners = [V(side * 0.035, top, depth_z - 0.02), V(side * (0.035 + width), top - 0.01, depth_z - 0.03),
                       V(side * 0.05, bottom, depth_z + 0.006), V(side * 0.022, bottom + 0.02, depth_z + 0.006)]
            if side > 0:
                corners.reverse()
            self.mb.quad(corners, shade(col, 1.08), self.torso_w(), tile="cloth")

    def belt(self, col, buckle=None, *, y: float | None = None, height: float = 0.05, pad: float = 0.012) -> None:
        y = self.spine.y - 0.01 if y is None else y
        w, d = self.width, self.depth
        rings = [Ring(V(0, y - height * 0.5, 0.004), 0.132 * w + pad, 0.098 * d + pad, shade(col, 0.85)),
                 Ring(V(0, y + height * 0.5, 0.004), 0.131 * w + pad, 0.097 * d + pad, col)]
        self.mb.loft(rings, self.torso_w(), sides=12, tile="leather", cap_bottom=False, cap_top=False,
                     two_sided=True)
        if buckle is not None:
            self.mb.box(V(0.0, y, 0.098 * d + pad + 0.006), V(0.04, height * 0.8, 0.012), buckle, "Hips",
                        tile="metal")

    def skirt(self, col, *, top_y: float, bottom_y: float, top_r: tuple[float, float], bottom_r: tuple[float, float],
              opening: float = 0.0, tile: str = "cloth", follow: float = 0.55, trim=None, rough: float = 0.0,
              rows: int = 4, back_push: float = 0.02, sides: int = 14) -> None:
        rings = []
        for i in range(rows):
            t = i / (rows - 1)
            y = top_y + (bottom_y - top_y) * t
            rx = top_r[0] + (bottom_r[0] - top_r[0]) * t
            rz = top_r[1] + (bottom_r[1] - top_r[1]) * t
            fn = jagged(rough * t, 9, 0.7) if rough > 0.0 else None
            rings.append(Ring(V(0.0, y, -back_push * t), rx, rz, shade(col, 1.0 - 0.25 * t), fn=fn))
        rings.reverse()
        arc = (opening, 2.0 * math.pi - opening) if opening > 0.0 else None
        self.mb.loft(rings, self.skirt_w(follow=follow, reach=abs(top_y - bottom_y)), sides=sides, arc=arc,
                     tile=tile, cap_bottom=False, cap_top=False, two_sided=True)
        if trim is not None:
            y = bottom_y
            pad = 0.004
            fn = jagged(rough, 9, 0.7) if rough > 0.0 else None
            trim_rings = [Ring(V(0, y, -back_push), bottom_r[0] + pad, bottom_r[1] + pad, trim, fn=fn),
                          Ring(V(0, y + 0.05, -back_push * 0.9), bottom_r[0] - 0.004 + pad,
                               bottom_r[1] - 0.004 + pad, trim, fn=fn)]
            self.mb.loft(trim_rings, self.skirt_w(follow=follow, reach=abs(top_y - bottom_y)), sides=sides, arc=arc,
                         tile="plain", cap_bottom=False, cap_top=False, two_sided=True)

    # -- props ---------------------------------------------------------------
    def in_hand(self, s: str, tilt_deg: float = 0.0, offset: Vector = V(0.0, -0.05, 0.014)) -> None:
        wr = self.j("Hand" + s)
        self.mb.xform = Matrix.Translation(wr + offset) @ Matrix.Rotation(math.radians(tilt_deg), 4, "X")

    def reset_xform(self) -> None:
        self.mb.xform = Matrix.Identity(4)

    def blade(self, s: str, length: float, width: float, metal, guard, grip, *, tilt: float = -14.0,
              guard_w: float = 0.11, pommel: bool = True) -> None:
        bone = "Hand" + s
        self.in_hand(s, tilt)
        self.mb.loft([Ring(V(0, -0.035, 0), 0.016, 0.016, grip), Ring(V(0, 0.06, 0), 0.014, 0.014, shade(grip, 1.2))],
                     bone, sides=6, tile="leather", cap_bottom=False, cap_top=False)
        if pommel:
            sphere(self.mb, V(0, 0.075, 0), V(0.022, 0.02, 0.022), guard, bone, lat=3, sides=6, tile="metal",
                   smooth=False)
        self.mb.box(V(0, -0.04, 0), V(guard_w, 0.018, 0.03), guard, bone, tile="metal")
        rings = [
            Ring(V(0, -0.045, 0), width, 0.008, metal, ax=V(0, 0, 1), az=V(1, 0, 0)),
            Ring(V(0, -0.045 - length * 0.75, 0), width * 0.9, 0.007, shade(metal, 0.92), ax=V(0, 0, 1),
                 az=V(1, 0, 0)),
        ]
        for r in rings:
            r.ax, r.az = V(0, 0, 1), V(1, 0, 0)
        self.mb.loft(rings, bone, sides=4, tile="metal", smooth=False, cap_bottom=True,
                     cap_top=V(0, -0.045 - length, 0))
        self.reset_xform()

    def finish(self, scale: float = 1.0) -> None:
        if scale != 1.0:
            m = Matrix.Scale(scale, 4)
            self.mb.verts = [m @ v for v in self.mb.verts]
            for bone in self.sk.bones:
                bone.head = m @ bone.head
                bone.tail = m @ bone.tail
            self.hip_bias = self.hip_bias * scale
        reset_scene()
        armature = create_armature(self.model_id, self.sk)
        SOURCE_DIR.mkdir(parents=True, exist_ok=True)
        image = self.atlas.save(SOURCE_DIR / f"{self.model_id}_atlas.png")
        body = create_material("Body", image)
        glow = create_material("Glow", image, glow=self.glow)
        create_mesh_objects("Body", self.mb, armature, [body, glow])
        bake_clips(armature, make_clips(self), self.j("Hips"))
        export(OUTPUT_DIR / f"{self.model_id}.glb", SOURCE_DIR / f"{self.model_id}.blend")
        tris = sum(len(f) - 2 for f in self.mb.faces)
        print(f"[models] {self.model_id}: {len(self.mb.verts)} verts, {tris} tris")


# --- Animation clips --------------------------------------------------------------
# Ported from the old procedural rig: Euler degrees per bone (Godot YXZ), Hips offsets.

def make_clips(fig: Figure) -> list[Clip]:
    sw = fig.walk_swing
    clips = [_idle(fig), _walk(sw, fig), _attack(fig.attack_style), _chant(), _chant_release()]
    for clip in clips:
        _apply_bias(clip, fig)
    return clips


def _apply_bias(clip: Clip, fig: Figure) -> None:
    for bone, offset in fig.bias.items():
        times, eulers = clip.rot.get(bone, ([0.0, clip.length], [(0.0, 0.0, 0.0)] * 2))
        clip.rot[bone] = (times, [(e[0] + offset[0], e[1] + offset[1], e[2] + offset[2]) for e in eulers])
    if fig.hip_bias.length > 0.0:
        times, offsets = clip.hips or ([0.0, clip.length], [V(0, 0, 0), V(0, 0, 0)])
        clip.hips = (times, [o + fig.hip_bias for o in offsets])


def _idle(fig: Figure) -> Clip:
    clip = Clip("idle", 3.2)
    t = [0.0, 1.6, 3.2]
    bob = 0.03 if fig.floating else -0.006
    clip.hips = (t, [V(0, 0, 0), V(0, bob, 0), V(0, 0, 0)])
    clip.track("Spine", t, [(0, 0, 0), (1.4, 0, 0), (0, 0, 0)])
    clip.track("Neck", t, [(0, 0, 0), (-1.2, 0, 0), (0, 0, 0)])
    clip.track("Head", t, [(0, 0, 0), (-0.8, 1.0, 0), (0, 0, 0)])
    clip.track("UpperArmL", t, [(0, 0, -5), (0, 0, -6.5), (0, 0, -5)])
    clip.track("UpperArmR", t, [(0, 0, 5), (0, 0, 6.5), (0, 0, 5)])
    clip.track("ForeArmL", t, [(-8, 0, 0), (-9, 0, 0), (-8, 0, 0)])
    clip.track("ForeArmR", t, [(-8, 0, 0), (-9, 0, 0), (-8, 0, 0)])
    return clip


def _walk(sw: float, fig: Figure) -> Clip:
    clip = Clip("walk", 0.8, interpolation="LINEAR")
    t = [0.0, 0.2, 0.4, 0.6, 0.8]
    if fig.floating:
        clip.track("Spine", t, [(6, 3, 0), (7, 0, 0), (6, -3, 0), (7, 0, 0), (6, 3, 0)])
        clip.hips = (t, [V(0, 0.0, 0), V(0, 0.015, 0), V(0, 0.0, 0), V(0, 0.015, 0), V(0, 0.0, 0)])
        clip.track("UpperArmL", t, [(10, 0, -8)] * 5)
        clip.track("UpperArmR", t, [(10, 0, 8)] * 5)
        clip.track("ForeArmL", t, [(-12, 0, 0)] * 5)
        clip.track("ForeArmR", t, [(-12, 0, 0)] * 5)
        return clip
    clip.track("UpperLegL", t, [(-26 * sw, 0, 0), (-6 * sw, 0, 0), (20 * sw, 0, 0), (4 * sw, 0, 0), (-26 * sw, 0, 0)])
    clip.track("LowerLegL", t, [(12 * sw, 0, 0), (6 * sw, 0, 0), (10 * sw, 0, 0), (42 * sw, 0, 0), (12 * sw, 0, 0)])
    clip.track("FootL", t, [(-6 * sw, 0, 0), (2 * sw, 0, 0), (4 * sw, 0, 0), (-10 * sw, 0, 0), (-6 * sw, 0, 0)])
    clip.track("UpperLegR", t, [(20 * sw, 0, 0), (4 * sw, 0, 0), (-26 * sw, 0, 0), (-6 * sw, 0, 0), (20 * sw, 0, 0)])
    clip.track("LowerLegR", t, [(10 * sw, 0, 0), (42 * sw, 0, 0), (12 * sw, 0, 0), (6 * sw, 0, 0), (10 * sw, 0, 0)])
    clip.track("FootR", t, [(4 * sw, 0, 0), (-10 * sw, 0, 0), (-6 * sw, 0, 0), (2 * sw, 0, 0), (4 * sw, 0, 0)])
    arm = 0.85 * sw
    clip.track("UpperArmL", t, [(14 * arm, 0, -5), (2 * arm, 0, -5), (-16 * arm, 0, -5), (-2 * arm, 0, -5), (14 * arm, 0, -5)])
    clip.track("UpperArmR", t, [(-16 * arm, 0, 5), (-2 * arm, 0, 5), (14 * arm, 0, 5), (2 * arm, 0, 5), (-16 * arm, 0, 5)])
    clip.track("ForeArmL", t, [(-8, 0, 0), (-5, 0, 0), (-18, 0, 0), (-9, 0, 0), (-8, 0, 0)])
    clip.track("ForeArmR", t, [(-18, 0, 0), (-9, 0, 0), (-8, 0, 0), (-5, 0, 0), (-18, 0, 0)])
    clip.track("Spine", t, [(2, 5 * sw, 0), (3, 0, 0), (2, -5 * sw, 0), (3, 0, 0), (2, 5 * sw, 0)])
    clip.track("Hips", t, [(0, -4 * sw, 0), (0, 0, 0), (0, 4 * sw, 0), (0, 0, 0), (0, -4 * sw, 0)])
    clip.hips = (t, [V(0, -0.012, 0), V(0, 0.012, 0), V(0, -0.012, 0), V(0, 0.012, 0), V(0, -0.012, 0)])
    clip.track("Head", [0.0], [(2, 0, 0)])
    return clip


def _attack(style: str) -> Clip:
    if style == "dagger":
        clip = Clip("attack", 0.42)
        t = [0.0, 0.14, 0.26, 0.42]
        clip.track("UpperArmR", t, [(0, 0, 5), (-92, -16, 8), (-70, -4, 5), (0, 0, 5)])
        clip.track("ForeArmR", t, [(-12, 0, 0), (-30, 0, 0), (-6, 0, 0), (-12, 0, 0)])
        clip.track("Spine", t, [(0, 0, 0), (4, 18, 0), (8, -14, 0), (0, 0, 0)])
        clip.hips = (t, [V(0, 0, 0), V(0, -0.02, 0.06), V(0, -0.012, 0.04), V(0, 0, 0)])
        return clip
    if style == "bow":
        clip = Clip("attack", 0.6)
        t = [0.0, 0.2, 0.44, 0.6]
        clip.track("UpperArmL", t, [(0, 0, -5), (-84, 6, -4), (-84, 6, -4), (0, 0, -5)])
        clip.track("UpperArmR", t, [(0, 0, 5), (-70, -14, 6), (-62, -6, 5), (0, 0, 5)])
        clip.track("ForeArmL", t, [(-8, 0, 0), (-4, 0, 0), (-4, 0, 0), (-8, 0, 0)])
        clip.track("ForeArmR", t, [(-10, 0, 0), (-55, 0, 0), (-12, 0, 0), (-10, 0, 0)])
        clip.track("Spine", t, [(0, 0, 0), (0, -10, 0), (0, -6, 0), (0, 0, 0)])
        return clip
    if style == "staff":
        clip = Clip("attack", 0.5)
        t = [0.0, 0.16, 0.3, 0.5]
        clip.track("UpperArmR", t, [(0, 0, 5), (-135, 0, 10), (-55, 0, 6), (0, 0, 5)])
        clip.track("ForeArmR", t, [(-10, 0, 0), (-20, 0, 0), (-4, 0, 0), (-10, 0, 0)])
        clip.track("Spine", t, [(0, 0, 0), (-8, 6, 0), (10, -6, 0), (0, 0, 0)])
        return clip
    if style == "claw":
        clip = Clip("attack", 0.5)
        t = [0.0, 0.18, 0.3, 0.5]
        clip.track("UpperArmR", t, [(0, 0, 5), (-120, -10, 30), (-40, 10, -10), (0, 0, 5)])
        clip.track("ForeArmR", t, [(-10, 0, 0), (-60, 0, 0), (-10, 0, 0), (-10, 0, 0)])
        clip.track("UpperArmL", t, [(0, 0, -5), (-30, 0, -20), (-60, -10, -5), (0, 0, -5)])
        clip.track("Spine", t, [(0, 0, 0), (-8, 20, 0), (14, -16, 0), (0, 0, 0)])
        clip.track("Head", t, [(0, 0, 0), (-10, 0, 0), (6, 0, 0), (0, 0, 0)])
        clip.hips = (t, [V(0, 0, 0), V(0, -0.01, -0.03), V(0, -0.02, 0.07), V(0, 0, 0)])
        return clip
    clip = Clip("attack", 0.55)
    t = [0.0, 0.16, 0.28, 0.55]
    clip.track("UpperArmR", t, [(0, 0, 5), (-155, -12, 12), (-50, 0, 5), (0, 0, 5)])
    clip.track("ForeArmR", t, [(-10, 0, 0), (-45, 0, 0), (-6, 0, 0), (-10, 0, 0)])
    clip.track("Spine", t, [(0, 0, 0), (-6, 16, 0), (8, -12, 0), (0, 0, 0)])
    clip.track("Head", t, [(0, 0, 0), (-6, 0, 0), (4, 0, 0), (0, 0, 0)])
    return clip


def _chant() -> Clip:
    clip = Clip("chant", 1.8)
    t = [0.0, 0.9, 1.8]
    clip.track("UpperArmL", t, [(-62, 0, 8), (-70, 0, 10), (-62, 0, 8)])
    clip.track("UpperArmR", t, [(-62, 0, -8), (-70, 0, -10), (-62, 0, -8)])
    clip.track("ForeArmL", t, [(-28, 0, 0), (-34, 0, 0), (-28, 0, 0)])
    clip.track("ForeArmR", t, [(-28, 0, 0), (-34, 0, 0), (-28, 0, 0)])
    clip.track("Head", t, [(-6, 0, 0), (-9, 0, 0), (-6, 0, 0)])
    clip.track("Spine", t, [(3, 0, 0), (5, 0, 0), (3, 0, 0)])
    return clip


def _chant_release() -> Clip:
    clip = Clip("chant_release", 0.4)
    t = [0.0, 0.14, 0.4]
    clip.track("UpperArmL", t, [(-70, 0, 10), (-115, 0, 4), (0, 0, -5)])
    clip.track("UpperArmR", t, [(-70, 0, -10), (-115, 0, -4), (0, 0, 5)])
    clip.track("ForeArmL", t, [(-30, 0, 0), (-8, 0, 0), (-8, 0, 0)])
    clip.track("ForeArmR", t, [(-30, 0, 0), (-8, 0, 0), (-8, 0, 0)])
    clip.track("Head", t, [(-8, 0, 0), (6, 0, 0), (0, 0, 0)])
    clip.track("Spine", t, [(4, 0, 0), (-8, 0, 0), (0, 0, 0)])
    return clip


# --- Survivors --------------------------------------------------------------------

def build_bran() -> None:
    """Bulky former prison guard in his forties (see assets/portraits/bran.png): weathered ochre leather
    greatcoat over a dark high-collared shirt, heavy black fur collar, cropped dark hair, short beard."""
    skin, hair = hex_color("b98c68"), hex_color("1c1814")
    coat, coat_dark = hex_color("654829"), hex_color("4a3520")
    shirt, pants, boots = hex_color("22252c"), hex_color("2c2925"), hex_color("1f1913")
    fur, belt, metal = hex_color("1b1714"), hex_color("2a2019"), hex_color("858a90")
    p = Proportions(shoulder_x=0.205, upper_arm=0.28)
    fig = Figure("bran", p, 11, width=1.12, depth=1.12, girth=1.15, hip_width=1.05)
    fig.attack_style = "melee"
    fig.walk_swing = 0.9

    fig.legs(pants, thigh=1.05)
    fig.boots(boots, shaft=0.16, width=1.05)
    fig.pelvis(coat_dark)
    fig.torso(shirt, chest=1.06, belly=1.04)
    fig.neck_mesh(skin)
    fig.arms(coat, skin, tile="leather", cuff=coat_dark, thickness=1.05)
    sy = fig.spine.y
    # Buttoned shirt front and its high collar.
    for y, z in ((0.12, 0.122), (0.21, 0.131), (0.3, 0.133)):
        fig.mb.box(V(0.0, sy + y, z), V(0.016, 0.016, 0.008), hex_color("3d3a36"), fig.torso_w(), tile="metal")
    n = fig.neck.y
    fig.mb.loft([Ring(V(0, n - 0.03, 0.0), 0.07, 0.066, shade(shirt, 0.9)),
                 Ring(V(0, n + 0.045, 0.004), 0.062, 0.06, shirt)],
                chain_y([("Neck", 0), ("Spine", n)], 0.03), sides=10, tile="cloth", cap_bottom=False,
                cap_top=False, two_sided=True)
    fig.jacket(coat, opening=0.42, pad=0.016, tile="leather")
    fig.belt(belt, hex_color("6e5a34"), pad=0.03)
    # Diagonal baldric strap for the sword.
    strap = [V(-0.13, sy + 0.38, 0.09), V(-0.02, sy + 0.25, 0.15), V(0.1, sy + 0.1, 0.145), V(0.16, sy + 0.0, 0.11)]
    fig.mb.loft(path_rings(strap, 0.022, 0.006, [belt]), fig.torso_w(), sides=4, tile="leather", smooth=False,
                cap_bottom=False, cap_top=False, two_sided=True)
    fig.skirt(coat, top_y=fig.spine.y + 0.02, bottom_y=fig.hips.y - 0.5, top_r=(0.15 * 1.12 + 0.016, 0.11 * 1.12 + 0.016),
              bottom_r=(0.22, 0.19), opening=0.36, tile="leather", rough=0.03, back_push=0.03)
    # Heavy fur collar over the shoulders.
    collar = [
        Ring(V(0, sy + 0.35, 0.0), 0.215, 0.145, shade(fur, 0.8), fn=jagged(0.14, 9)),
        Ring(V(0, sy + 0.45, -0.005), 0.18, 0.135, fur, fn=jagged(0.16, 11, 0.4)),
        Ring(V(0, sy + 0.53, -0.015), 0.11, 0.1, shade(fur, 1.2), fn=jagged(0.12, 7, 1.3)),
    ]
    fig.mb.loft(collar, fig.torso_w(), sides=14, tile="hair", cap_bottom=False, cap_top=False, two_sided=True)

    fig.head_mesh(skin=skin)
    fig.paint_face(skin, hair, eyes=(0.3, 0.22, 0.14), brow=1.4, stubble=0.35, hairline=0.155)
    # Short dark beard along the jaw plus a moustache, then the mouth on top.
    h = fig.head.y
    fig.face.speckle(0.0, h + 0.0, 1.05, 0.03, hair, 0.8, 0.85)
    fig.face.speckle(0.0, h + 0.044, 0.24, 0.007, hair, 0.85, 0.9)
    fig.face.ellipse(0.0, h + 0.03, 0.14, 0.0035, shade(skin, 0.55), 1.0)
    fig.hair_cap(hair, front_y=0.15, back_y=0.05, rough=0.06, offset=0.006)
    fig.blade("R", 0.5, 0.026, metal, hex_color("4a4038"), hex_color("2e241c"))
    fig.finish(1.05)


def build_mira() -> None:
    """Slim late-teen orphan (see assets/portraits/mira.png): weathered charcoal-brown hooded cloak,
    deep hood shading the face, crimson scarf, copper hair, knotted clasp, rusty iron dagger."""
    skin, hair = hex_color("dcc3ab"), hex_color("a2471f")
    tunic, cloak = hex_color("3d3530"), hex_color("51483f")
    pants, wraps, boots = hex_color("2e2a27"), hex_color("5e554b"), hex_color("231f1c")
    scarf, metal = hex_color("8c1d18"), hex_color("5f5249")
    p = Proportions(hip_y=0.86, upper_leg=0.39, lower_leg=0.33, torso=0.43, shoulder_x=0.165, shoulder_y=0.375,
                    upper_arm=0.25, fore_arm=0.23)
    fig = Figure("mira", p, 22, width=0.9, depth=0.88, girth=0.82, hip_width=0.98)
    fig.attack_style = "dagger"
    fig.walk_swing = 1.1

    fig.legs(pants)
    fig.boots(wraps, shaft=0.14, width=0.92, tile="cloth", cuff=False)
    fig.pelvis(pants)
    fig.torso(tunic, chest=0.98, upper_col=shade(tunic, 1.05))
    fig.neck_mesh(skin)
    fig.arms(tunic, skin, cuff=wraps, thickness=0.95)
    fig.belt(hex_color("3b2e22"), y=fig.spine.y + 0.0, pad=0.008)
    fig.skirt(tunic, top_y=fig.spine.y + 0.02, bottom_y=fig.hips.y - 0.2, top_r=(0.125, 0.092),
              bottom_r=(0.15, 0.12), opening=0.0, rough=0.04, follow=0.6)
    # Cloak hanging from the shoulders, open at the front.
    sy = fig.spine.y
    cloak_rings = [
        Ring(V(0, sy + 0.41, -0.01), 0.14, 0.11, cloak),
        Ring(V(0, sy + 0.3, -0.02), p.shoulder_x + 0.06, 0.13, shade(cloak, 0.95)),
        Ring(V(0, sy + 0.0, -0.045), 0.2, 0.15, shade(cloak, 0.85)),
        Ring(V(0, fig.hips.y - 0.34, -0.075), 0.235, 0.175, shade(cloak, 0.7), fn=jagged(0.14, 9, 0.6)),
    ]
    cloak_rings.reverse()

    def cloak_w(pt: Vector) -> dict[str, float]:
        if pt.y > sy + 0.05:
            return {"Spine": 1.0}
        t = clamp((sy + 0.05 - pt.y) / 0.4, 0.0, 1.0)
        return {"Spine": 1.0 - t, "Hips": t}

    fig.mb.loft(cloak_rings, cloak_w, sides=16, arc=(0.75, 2.0 * math.pi - 0.75), tile="cloth", two_sided=True)

    fig.head_mesh(skin=skin, profile=[(dy, rx * 0.96, rz * 0.97, z) for dy, rx, rz, z in HUMAN_HEAD])
    fig.paint_face(skin, hair, eyes=(0.42, 0.49, 0.45), lips=hex_color("a86e66"), freckles=True, lashes=True,
                   hairline=0.14)
    h = fig.head.y
    # The hood's shadow across brow and eyes.
    fig.face.band(h + 0.085, h + 0.16, shade(skin, 0.55), 0.5, theta_from=-1.2, theta_to=1.2)
    fig.hair_cap(hair, front_y=0.12, back_y=0.03, rough=0.1)
    # Loose copper strands falling over the cheeks.
    for side, z, length in ((-1.0, 0.04, 0.13), (1.0, 0.04, 0.12), (-1.0, 0.065, 0.09), (1.0, 0.07, 0.07)):
        x = side * (0.078 if z < 0.05 else 0.062)
        fig.mb.box(V(x, h + 0.135 - length * 0.5, z), V(0.016, length, 0.024), shade(hair, 0.95), "Head",
                   tile="hair", rot=Matrix.Rotation(side * math.radians(6.0), 3, "Z"))
    fig.hood(cloak, opening=0.8, mantle=0.13, pad=0.036, overhang=0.03)
    # Scarf wrapped over the hood's mantle, one end hanging down the chest.
    n = fig.neck.y
    fig.mb.loft([Ring(V(0, n - 0.045, 0.012), 0.15, 0.125, shade(scarf, 0.8), fn=jagged(0.05, 5)),
                 Ring(V(0, n + 0.0, 0.016), 0.135, 0.118, scarf, fn=jagged(0.06, 6, 1.0)),
                 Ring(V(0, n + 0.04, 0.012), 0.1, 0.095, shade(scarf, 1.08), fn=jagged(0.05, 5, 2.0))],
                chain_y([("Neck", 0), ("Spine", n)], 0.03), sides=12, tile="cloth", cap_bottom=False, cap_top=False,
                two_sided=True)
    tail = [V(0.05, n - 0.03, 0.13), V(0.06, n - 0.09, 0.135), V(0.055, n - 0.15, 0.13)]
    fig.mb.loft(path_rings(tail, 0.026, 0.008, [scarf, shade(scarf, 0.9), shade(scarf, 0.78)]), "Spine",
                sides=4, tile="cloth", smooth=False, cap_bottom=False, cap_top=True, two_sided=True)
    # Knotted iron clasp holding the cloak closed under the scarf.
    clasp = V(0.0, n - 0.1, 0.122)
    sphere(fig.mb, clasp, V(0.018, 0.018, 0.012), hex_color("4a4038"), "Spine", lat=3, sides=6, tile="metal",
           smooth=False)
    for side in (-1.0, 1.0):
        cord = [clasp, clasp + V(side * 0.05, 0.03, -0.01), clasp + V(side * 0.09, 0.05, -0.025)]
        fig.mb.loft(path_rings(cord, 0.005, 0.005, [hex_color("3a322a")]), "Spine", sides=3, tile="plain",
                    smooth=False, cap_bottom=False, cap_top=False)
    fig.blade("R", 0.21, 0.017, metal, shade(metal, 0.7), hex_color("2e2620"), tilt=-10.0, guard_w=0.05,
              pommel=False)
    fig.finish(0.95)


def build_owen() -> None:
    """Wiry hunter in his thirties (see assets/portraits/owen.png): worn olive field coat with lapels over a
    rust-brown laced vest and dark shirt, grey flat cap, dirty-blond hair, wide leather strap, short bow."""
    skin, hair = hex_color("c09b78"), hex_color("a28a5c")
    shirt, vest, coat = hex_color("3a3936"), hex_color("6e3f22"), hex_color("4f5433")
    pants, boots = hex_color("3d382e"), hex_color("2b241c")
    cap, satchel, strap = hex_color("5c5953"), hex_color("4a3520"), hex_color("5a3820")
    wood, string = hex_color("7c5e3a"), hex_color("cfc9b8")
    p = Proportions(shoulder_x=0.185)
    fig = Figure("owen", p, 33, width=0.98, depth=0.95, girth=0.92)
    fig.attack_style = "bow"

    fig.legs(pants)
    fig.boots(boots, shaft=0.15, width=0.98)
    fig.pelvis(pants)
    fig.torso(shirt)
    fig.neck_mesh(skin)
    fig.arms(coat, skin, cuff=shade(coat, 0.8), thickness=1.05)
    sy = fig.spine.y
    # Laced vest under an open coat.
    fig.jacket(vest, opening=0.16, pad=0.008, tile="leather")
    for i in range(4):
        y = sy + 0.12 + i * 0.06
        fig.mb.box(V(0.0, y, 0.122), V(0.04, 0.006, 0.006), hex_color("2a1d14"), fig.torso_w(),
                   rot=Matrix.Rotation(math.radians(25.0 if i % 2 else -25.0), 3, "Z"))
    fig.belt(hex_color("2a2118"), hex_color("6d5a30"), pad=0.012)
    fig.jacket(coat, opening=0.62, pad=0.024)
    fig.skirt(coat, top_y=sy - 0.02, bottom_y=fig.hips.y - 0.24, top_r=(0.158, 0.122), bottom_r=(0.19, 0.15),
              opening=0.55, rough=0.04, follow=0.5, rows=3)
    fig.lapels(coat, depth_z=0.135)
    n = fig.neck.y
    fig.mb.loft([Ring(V(0, n - 0.035, -0.01), 0.105, 0.09, coat), Ring(V(0, n + 0.035, -0.02), 0.09, 0.08,
                                                                       shade(coat, 1.1))],
                chain_y([("Neck", 0), ("Spine", n)], 0.03), sides=12, arc=(0.55, 2.0 * math.pi - 0.55),
                tile="cloth", two_sided=True)
    # Satchel on the right hip; wide strap over the left shoulder.
    fig.mb.box(V(0.19, fig.hips.y - 0.08, 0.03), V(0.06, 0.13, 0.15), satchel, "Hips", tile="leather")
    fig.mb.box(V(0.225, fig.hips.y - 0.04, 0.03), V(0.012, 0.06, 0.152), shade(satchel, 1.15), "Hips",
               tile="leather")
    strap_path = [V(0.19, fig.hips.y - 0.02, 0.03), V(0.15, sy + 0.1, 0.145), V(0.0, sy + 0.25, 0.15),
                  V(-0.12, sy + 0.39, 0.075), V(-0.11, sy + 0.41, -0.09), V(0.02, sy + 0.2, -0.145),
                  V(0.17, fig.hips.y - 0.0, -0.07)]
    fig.mb.loft(path_rings(strap_path, 0.028, 0.006, [strap]), fig.torso_w(), sides=4, tile="leather",
                smooth=False, cap_bottom=False, cap_top=False, two_sided=True)
    fig.mb.box(V(0.075, sy + 0.18, 0.152), V(0.03, 0.03, 0.01), hex_color("6d5a30"), fig.torso_w(), tile="metal")
    # Quiver on the back.
    fig.mb.xform = Matrix.Translation(V(-0.06, sy + 0.24, -0.15)) @ Matrix.Rotation(math.radians(-22), 4, "Z") \
        @ Matrix.Rotation(math.radians(-8), 4, "X")
    fig.mb.loft([Ring(V(0, -0.2, 0), 0.04, 0.035, shade(satchel, 0.8)), Ring(V(0, 0.16, 0), 0.046, 0.04, satchel)],
                "Spine", sides=8, tile="leather", cap_top=False)
    for i, dx in enumerate((-0.02, 0.0, 0.02, 0.01)):
        fig.mb.loft([Ring(V(dx, 0.1, 0.01 * i - 0.01), 0.004, 0.004, wood),
                     Ring(V(dx, 0.24, 0.01 * i - 0.01), 0.004, 0.004, wood)], "Spine", sides=3, smooth=False,
                    tile="plain", cap_bottom=False)
        fig.mb.box(V(dx, 0.255, 0.01 * i - 0.01), V(0.004, 0.05, 0.022), hex_color("b8b0a0"), "Spine")
    fig.reset_xform()

    fig.head_mesh(skin=skin)
    fig.paint_face(skin, hair, eyes=(0.36, 0.44, 0.48), stubble=0.65, hairline=0.15)
    fig.hair_cap(hair, front_y=0.11, back_y=0.02, rough=0.12)
    h = fig.head.y
    # Unkempt strands escaping the cap at the temples and nape.
    for side in (-1.0, 1.0):
        for dz, length in ((0.0, 0.07), (-0.04, 0.09)):
            fig.mb.box(V(side * 0.088, h + 0.115 - length * 0.5, dz), V(0.014, length, 0.03), hair, "Head",
                       tile="hair", rot=Matrix.Rotation(side * math.radians(10.0), 3, "Z"))
    cap_rings = [Ring(V(0, h + dy, z - 0.004), rx + 0.018, rz + 0.018, shade(cap, 0.9 + dy), fn=jagged(0.03, 5))
                 for dy, rx, rz, z in [(0.13, *lerp_profile(fig.head_profile, 0.13)),
                                       (0.17, *lerp_profile(fig.head_profile, 0.17)),
                                       (0.205, *lerp_profile(fig.head_profile, 0.205))]]
    fig.mb.loft(cap_rings, "Head", sides=12, tile="cloth", cap_bottom=False, cap_top=V(0, h + 0.236, 0.0),
                two_sided=True)
    fig.mb.box(V(0.0, h + 0.13, 0.12), V(0.16, 0.014, 0.085), shade(cap, 0.85), "Head", tile="cloth",
               rot=Matrix.Rotation(math.radians(12.0), 3, "X"))
    # Short recurve bow in the left hand: arc bulging forward, string behind.
    fig.in_hand("L", 0.0, V(0.0, -0.05, 0.02))
    radius, half = 0.36, math.radians(55.0)
    pts = []
    for i in range(11):
        a = -half + 2.0 * half * i / 10
        pts.append(V(0.0, radius * math.sin(a), radius * math.cos(a) - radius))
    cols = [shade(wood, 0.8 + 0.2 * math.cos(-half + 2 * half * i / 10)) for i in range(11)]
    fig.mb.loft(path_rings(pts, 0.012, 0.009, cols, up_hint=V(1, 0, 0)), "HandL", sides=4, tile="hair",
                smooth=False, cap_bottom=True, cap_top=True)
    fig.mb.box(V(0.0, 0.0, 0.0), V(0.026, 0.07, 0.026), hex_color("3a2c1e"), "HandL", tile="leather")
    tip_y, tip_z = radius * math.sin(half), radius * math.cos(half) - radius
    fig.mb.box(V(0.0, 0.0, tip_z), V(0.003, tip_y * 2.0, 0.003), string, "HandL")
    fig.reset_xform()
    fig.finish(1.0)


def build_elara() -> None:
    """Slight mage in her mid-twenties (see assets/portraits/elara.png): near-black purple robe with worn gold
    embroidery, black pointed hood edged in gold, pale face, long dark hair, gnarled staff, brass-bound book."""
    skin, hair = hex_color("e2cab6"), hex_color("19141a")
    hood, trim = hex_color("16131a"), hex_color("a8863a")
    boots, wood, book = hex_color("1a1620"), hex_color("5e4630"), hex_color("2c1f19")
    # Robe and sleeves use the painted "pattern" tile, so their vertex colours only carry shading.
    robe, sleeves = (1.0, 1.0, 1.0), (0.85, 0.85, 0.85)
    p = Proportions(hip_y=0.87, upper_leg=0.4, lower_leg=0.33, torso=0.44, shoulder_x=0.16, shoulder_y=0.38,
                    upper_arm=0.26, fore_arm=0.235)
    fig = Figure("elara", p, 44, width=0.9, depth=0.88, girth=0.8, hip_width=0.96)
    fig.attack_style = "staff"
    fig.walk_swing = 0.55
    fig.glow = (0.62, 0.48, 0.95)
    fig.atlas.paint_brocade(hex_color("281a37"), hex_color("5e4a2c"), cell=20)

    fig.legs(hex_color("231c30"))
    fig.boots(boots, shaft=0.1, width=0.9, cuff=False)
    fig.pelvis(robe, tile="pattern")
    fig.torso(robe, chest=0.98, tile="pattern")
    fig.neck_mesh(skin)
    fig.arms(sleeves, skin, thickness=0.95, tile="pattern")
    # Bell sleeves flaring from the elbow, gold bracelets at the wrists.
    for s in ("L", "R"):
        el, wr = fig.j("ForeArm" + s), fig.j("Hand" + s)
        x = el.x
        fig.mb.loft([
            Ring(V(x, el.y + 0.02, 0.0), 0.05, 0.052, sleeves),
            Ring(V(x, wr.y + 0.06, -0.004), 0.07, 0.074, shade(sleeves, 0.9)),
            Ring(V(x, wr.y + 0.01, -0.01), 0.085, 0.09, shade(sleeves, 0.8)),
        ], fig.arm_w(s), sides=10, tile="pattern", cap_bottom=False, cap_top=False, two_sided=True)
        fig.mb.loft([
            Ring(V(x, wr.y + 0.008, -0.01), 0.087, 0.092, trim),
            Ring(V(x, wr.y + 0.03, -0.008), 0.081, 0.086, trim),
        ], fig.arm_w(s), sides=10, tile="metal", cap_bottom=False, cap_top=False, two_sided=True)
        for dy in (-0.008, -0.022):
            fig.mb.loft([Ring(V(x, wr.y + dy - 0.005, 0.004), 0.031, 0.035, trim),
                         Ring(V(x, wr.y + dy + 0.005, 0.004), 0.031, 0.035, shade(trim, 1.1))],
                        "Hand" + s, sides=8, tile="metal", smooth=False, cap_bottom=False, cap_top=False)
    fig.skirt(robe, top_y=fig.spine.y + 0.04, bottom_y=0.04, top_r=(0.13, 0.1), bottom_r=(0.22, 0.2), rows=5,
              trim=trim, follow=0.5, back_push=0.03, sides=16, tile="pattern")
    fig.belt(trim, y=fig.spine.y + 0.03, height=0.04, pad=0.01)
    for dx, length in ((0.04, 0.3), (0.075, 0.24)):
        sash = [V(dx, fig.spine.y + 0.01, 0.112), V(dx + 0.01, fig.spine.y - 0.1, 0.13),
                V(dx + 0.015, fig.spine.y - length, 0.14)]
        fig.mb.loft(path_rings(sash, 0.016, 0.004, [trim]), fig.skirt_w(follow=0.3), sides=4, tile="metal",
                    smooth=False, cap_bottom=False, cap_top=False, two_sided=True)

    fig.head_mesh(skin=skin, profile=[(dy, rx * 0.95, rz * 0.96, z) for dy, rx, rz, z in HUMAN_HEAD])
    fig.paint_face(skin, hair, eyes=(0.26, 0.21, 0.2), lips=hex_color("a0585c"), lashes=True, hairline=0.14)
    h = fig.head.y
    fig.face.band(h + 0.09, h + 0.16, shade(skin, 0.6), 0.35, theta_from=-1.2, theta_to=1.2)
    fig.hair_cap(hair, front_y=0.12, back_y=0.0, rough=0.06, long_back=0.18)
    for side in (-1.0, 1.0):
        lock = [V(side * 0.068, h + 0.13, 0.05), V(side * 0.08, h + 0.04, 0.05), V(side * 0.09, h - 0.1, 0.04)]
        fig.mb.loft(path_rings(lock, 0.022, 0.012, [hair, shade(hair, 0.9)]),
                    chain_y([("Head", 0), ("Neck", h - 0.02)], 0.03), sides=4, tile="hair", smooth=False,
                    cap_bottom=False, cap_top=True)
    fig.hood(hood, peak=0.19, opening=0.78, mantle=0.16, pad=0.034, overhang=0.025, trim=trim)
    # Gnarled staff in the right hand with a glowing orb in a forked head.
    fig.in_hand("R", 0.0, V(0.0, -0.05, 0.026))
    knots = [(-0.55, 0.012, 0.0), (-0.3, 0.015, 0.006), (-0.05, 0.014, -0.004), (0.2, 0.016, 0.005),
             (0.42, 0.015, -0.006), (0.55, 0.018, 0.0)]
    fig.mb.loft([Ring(V(dx, y, 0), r, r, shade(wood, 0.8 + 0.3 * (y + 0.55))) for y, r, dx in knots], "HandR",
                sides=6, tile="hair", smooth=False)
    for y in (-0.38, -0.12, 0.3):
        sphere(fig.mb, V(0.0, y, 0.0), V(0.021, 0.026, 0.021), shade(wood, 0.9), "HandR", lat=3, sides=5,
               tile="hair", smooth=False)
    for a in (0.0, 2.1, 4.2):
        base = V(0.0, 0.55, 0.0)
        tip = V(math.sin(a) * 0.045, 0.66, math.cos(a) * 0.045)
        fig.spike(base, tip, 0.01, shade(wood, 1.15), "HandR", sides=3)
    sphere(fig.mb, V(0, 0.615, 0), V(0.032, 0.032, 0.032), (1.0, 1.0, 1.0), "HandR", lat=4, sides=8,
           material=MATERIAL_GLOW)
    fig.reset_xform()
    # Brass-bound book held against the left hip.
    fig.in_hand("L", 20.0, V(0.0, -0.06, 0.03))
    brass = hex_color("8a6a34")
    fig.mb.box(V(0, 0, 0), V(0.034, 0.14, 0.105), book, "HandL", tile="leather")
    fig.mb.box(V(0.0, 0.0, 0.006), V(0.03, 0.13, 0.098), hex_color("cfc4a8"), "HandL")
    for dy in (-0.062, 0.062):
        fig.mb.box(V(0.0, dy, 0.045), V(0.038, 0.018, 0.018), brass, "HandL", tile="metal")
    fig.mb.box(V(0.0, 0.0, 0.054), V(0.038, 0.024, 0.006), brass, "HandL", tile="metal")
    fig.reset_xform()
    fig.finish(0.97)


# --- Enemies ----------------------------------------------------------------------

def build_hollow() -> None:
    """Gaunt, hunched corpse-thing with bone claws and empty eye sockets."""
    flesh, dark = hex_color("a39e8c"), hex_color("6e6a5c")
    bone, rag = hex_color("c8bfa6"), hex_color("3e3428")
    p = Proportions(hip_y=0.95, upper_leg=0.44, lower_leg=0.4, torso=0.44, shoulder_x=0.16, shoulder_y=0.39,
                    upper_arm=0.32, fore_arm=0.31, hand=0.1)
    fig = Figure("hollow", p, 55, width=0.78, depth=0.72, girth=0.66, hip_width=0.85)
    fig.attack_style = "claw"
    fig.walk_swing = 0.75
    fig.bias = {"Spine": (24, 0, 0), "Neck": (14, 0, 0), "Head": (-22, 0, 0), "UpperArmL": (-6, 0, -4),
                "UpperArmR": (-6, 0, 4), "ForeArmL": (-14, 0, 0), "ForeArmR": (-14, 0, 0),
                "UpperLegL": (-10, 0, 0), "UpperLegR": (-10, 0, 0), "LowerLegL": (18, 0, 0),
                "LowerLegR": (18, 0, 0), "FootL": (-8, 0, 0), "FootR": (-8, 0, 0)}
    fig.hip_bias = V(0.0, -0.012, 0.0)

    fig.legs(flesh, tile="flesh")
    for s in ("L", "R"):
        ankle = fig.j("Foot" + s)
        x = ankle.x
        foot = [Ring(V(x, 0.03, -0.05), 0.03, 0.03, dark, az=V(0, 1, 0)),
                Ring(V(x, 0.04, 0.02), 0.04, 0.03, flesh, az=V(0, 1, 0)),
                Ring(V(x, 0.02, 0.12), 0.042, 0.016, shade(flesh, 0.85), az=V(0, 1, 0))]
        fig.mb.loft(foot, chain_y([("LowerLeg" + s, 0), ("Foot" + s, ankle.y)], 0.03), sides=6, tile="flesh",
                    smooth=False, cap_top=V(x, 0.015, 0.15))
        fig.mb.loft([Ring(V(x, 0.02, 0.0), 0.034, 0.034, dark), Ring(V(x, ankle.y + 0.04, 0.0), 0.034, 0.036, flesh)],
                    chain_y([("LowerLeg" + s, 0), ("Foot" + s, ankle.y + 0.02)], 0.03), sides=6, tile="flesh",
                    cap_bottom=False, cap_top=False)
        for dz in (-0.025, 0.0, 0.025):
            fig.spike(V(x + dz, 0.015, 0.13), V(x + dz * 1.4, 0.004, 0.18), 0.008, bone, "Foot" + s, sides=3)
    fig.pelvis(dark, tile="flesh")
    sy = fig.spine.y
    # Ribcage: alternating light/dark bands give the starved look.
    rib = lambda i: shade(flesh, 0.72) if i % 2 else flesh  # noqa: E731
    ribs = [Ring(V(0, sy - 0.06, 0.0), 0.095, 0.07, shade(dark, 0.9))]
    for i, y in enumerate((0.04, 0.1, 0.15, 0.2, 0.25, 0.3, 0.35)):
        ribs.append(Ring(V(0, sy + y, 0.01 + 0.012 * math.sin(i)), 0.1 + 0.008 * i, 0.08 + 0.005 * i, rib(i)))
    ribs += [Ring(V(0, sy + p.shoulder_y, -0.005), p.shoulder_x + 0.02, 0.08, flesh),
             Ring(V(0, sy + p.torso - 0.02, -0.01), 0.08, 0.06, shade(flesh, 0.9)),
             Ring(V(0, sy + p.torso + 0.01, -0.006), 0.045, 0.042, shade(flesh, 0.85))]
    fig.mb.loft(ribs, fig.torso_w(), sides=10, tile="flesh", cap_bottom=False, cap_top=False)
    for i in range(6):
        y = sy + 0.04 + i * 0.065
        fig.spike(V(0, y, -0.06), V(0, y + 0.01, -0.1), 0.016, bone, fig.torso_w(), sides=4)
    fig.neck_mesh(flesh)
    fig.arms(flesh, flesh, tile="flesh", thickness=0.85)
    for s in ("L", "R"):
        fig.hand(s, flesh, claw=bone, claw_len=0.11, scale=1.15)
    fig.skirt(rag, top_y=fig.spine.y - 0.02, bottom_y=fig.hips.y - 0.28, top_r=(0.105, 0.08), bottom_r=(0.15, 0.12),
              rough=0.25, follow=0.6, tile="cloth", rows=3)

    profile = [(-0.035, 0.022, 0.022, 0.05), (0.0, 0.05, 0.055, 0.036), (0.03, 0.058, 0.07, 0.02),
               (0.065, 0.07, 0.08, 0.008), (0.1, 0.082, 0.09, 0.0), (0.14, 0.088, 0.094, -0.008),
               (0.175, 0.082, 0.088, -0.016), (0.205, 0.058, 0.064, -0.02)]
    fig.head_mesh(profile=profile, skin=flesh, ears=False)
    f = fig.face
    h = fig.head.y
    fig.atlas.fill_face(flesh, noise=0.12)
    f.band(h - 0.04, h + 0.02, shade(flesh, 0.7), 0.6)
    f.ellipse(0.0, h + 0.135, 0.9, 0.03, shade(flesh, 0.82), 0.4)
    for side in (-1.0, 1.0):
        f.ellipse(side * 0.34, h + 0.095, 0.24, 0.024, (0.03, 0.025, 0.03), 1.0)
        f.ellipse(side * 0.32, h + 0.097, 0.04, 0.004, (0.85, 0.82, 0.7), 1.0)
        f.ellipse(side * 0.55, h + 0.05, 0.12, 0.03, shade(flesh, 0.65), 0.6)
    f.ellipse(0.0, h + 0.025, 0.28, 0.022, (0.08, 0.04, 0.04), 1.0)
    for i in range(-5, 6):
        f.ellipse(i * 0.045, h + 0.035, 0.012, 0.007, bone, 1.0)
        f.ellipse(i * 0.045, h + 0.012, 0.012, 0.006, bone, 1.0)
    f.speckle(0.0, h + 0.16, 2.5, 0.06, shade(flesh, 0.55), 0.06, 0.8)
    for i in range(5):
        f.ellipse(-2.6 + i * 0.03, h + 0.16 - i * 0.02, 0.02, 0.004, (0.15, 0.1, 0.1), 0.9)
    for theta in (-0.6, 0.15, 0.9, 2.4):
        fig.spike(V(math.sin(theta) * 0.07, h + 0.19, math.cos(theta) * 0.07 - 0.02),
                  V(math.sin(theta) * 0.1, h + 0.05, math.cos(theta) * 0.1 - 0.04), 0.004, hex_color("4a4440"),
                  "Head", sides=3)
    fig.finish(1.0)


def build_wretch() -> None:
    """Small crouched feral thing in rags with long ears, a mane and red eyes."""
    hide, dark = hex_color("6e5446"), hex_color("4a372e")
    rag, rag2 = hex_color("5a4632"), hex_color("74432c")
    bone, mane = hex_color("b9ad92"), hex_color("2e2420")
    p = Proportions(hip_y=0.6, upper_leg=0.26, lower_leg=0.25, torso=0.34, shoulder_x=0.15, shoulder_y=0.3,
                    upper_arm=0.24, fore_arm=0.24, hand=0.08, neck=0.06)
    fig = Figure("wretch", p, 66, width=0.95, depth=1.0, girth=0.95, hip_width=0.95)
    fig.attack_style = "dagger"
    fig.walk_swing = 1.2
    fig.glow = (1.0, 0.25, 0.12)
    fig.bias = {"Spine": (34, 0, 0), "Neck": (14, 0, 0), "Head": (-38, 0, 0), "UpperArmL": (-18, 0, -8),
                "UpperArmR": (-18, 0, 8), "ForeArmL": (-24, 0, 0), "ForeArmR": (-24, 0, 0),
                "UpperLegL": (-30, 0, -6), "UpperLegR": (-30, 0, 6), "LowerLegL": (46, 0, 0),
                "LowerLegR": (46, 0, 0), "FootL": (-16, 0, 0), "FootR": (-16, 0, 0)}
    fig.hip_bias = V(0.0, -0.045, -0.03)

    fig.legs(dark, tile="flesh", thigh=1.15)
    for s in ("L", "R"):
        ankle = fig.j("Foot" + s)
        x = ankle.x
        foot = [Ring(V(x, 0.03, -0.04), 0.036, 0.03, dark, az=V(0, 1, 0)),
                Ring(V(x, 0.035, 0.03), 0.045, 0.03, hide, az=V(0, 1, 0)),
                Ring(V(x, 0.02, 0.1), 0.046, 0.018, shade(hide, 0.85), az=V(0, 1, 0))]
        fig.mb.loft(foot, chain_y([("LowerLeg" + s, 0), ("Foot" + s, ankle.y)], 0.03), sides=6, tile="flesh",
                    smooth=False, cap_top=V(x, 0.015, 0.13))
        for dz in (-0.025, 0.0, 0.025):
            fig.spike(V(x + dz, 0.015, 0.11), V(x + dz * 1.5, 0.004, 0.16), 0.008, bone, "Foot" + s, sides=3)
    fig.pelvis(rag)
    sy = fig.spine.y
    torso = [
        Ring(V(0, sy - 0.06, 0.0), 0.13, 0.11, shade(rag, 0.8), fn=jagged(0.05, 6)),
        Ring(V(0, sy + 0.1, 0.0), 0.14, 0.13, rag, fn=jagged(0.06, 5, 1.0)),
        Ring(V(0, sy + 0.22, -0.02), 0.16, 0.15, rag2, fn=jagged(0.07, 7, 0.3)),
        Ring(V(0, sy + p.shoulder_y, -0.03), p.shoulder_x + 0.03, 0.13, shade(rag2, 0.9), fn=jagged(0.05, 6)),
        Ring(V(0, sy + p.torso - 0.01, -0.02), 0.09, 0.08, hide),
        Ring(V(0, sy + p.torso + 0.02, -0.01), 0.05, 0.05, hide),
    ]
    fig.mb.loft(torso, fig.torso_w(), sides=10, tile="cloth", cap_bottom=False, cap_top=False)
    fig.skirt(rag, top_y=sy - 0.02, bottom_y=fig.hips.y - 0.2, top_r=(0.135, 0.115), bottom_r=(0.17, 0.15),
              rough=0.3, follow=0.6, rows=3)
    fig.neck_mesh(hide)
    fig.arms(hide, hide, tile="flesh", thickness=1.0)
    for s in ("L", "R"):
        fig.hand(s, hide, claw=bone, claw_len=0.08, scale=1.2)
        wr = fig.j("Hand" + s)
        fig.mb.loft([Ring(V(wr.x, wr.y + 0.0, 0), 0.045, 0.048, rag2, fn=jagged(0.1, 5)),
                     Ring(V(wr.x, wr.y + 0.09, 0), 0.05, 0.052, rag2, fn=jagged(0.1, 5, 1))], fig.arm_w(s),
                    sides=7, tile="cloth", cap_bottom=False, cap_top=False, two_sided=True)

    # Snouted head: the face pushes forward into a muzzle.
    profile = [(-0.02, 0.03, 0.05, 0.07), (0.01, 0.05, 0.085, 0.06), (0.04, 0.06, 0.1, 0.045),
               (0.075, 0.075, 0.1, 0.03), (0.11, 0.084, 0.092, 0.0), (0.145, 0.082, 0.085, -0.012),
               (0.18, 0.066, 0.07, -0.02), (0.205, 0.04, 0.046, -0.025)]
    fig.head_mesh(profile=profile, skin=hide, ears=False, nose=False)
    f = fig.face
    h = fig.head.y
    fig.atlas.fill_face(hide, noise=0.14)
    f.band(h - 0.03, h + 0.03, shade(hide, 0.75), 0.6)
    f.ellipse(0.0, h + 0.055, 0.12, 0.012, (0.1, 0.06, 0.05), 1.0)
    f.ellipse(0.0, h + 0.018, 0.5, 0.008, (0.12, 0.05, 0.05), 1.0)
    for i in range(-4, 5):
        f.ellipse(i * 0.08, h + 0.024, 0.014, 0.008, bone, 1.0)
    f.ellipse(0.3, h + 0.105, 0.18, 0.016, shade(hide, 0.55), 0.8, mirror=True)
    f.speckle(0.0, h + 0.2, math.pi, 0.05, mane, 0.55, 0.9)
    f.band(h + 0.0, h + 0.24, mane, 0.85, theta_from=-math.pi, theta_to=-2.4)
    f.band(h + 0.0, h + 0.24, mane, 0.85, theta_from=2.4, theta_to=math.pi)
    for i, theta in enumerate((-2.6, -1.9, -1.2, 1.2, 1.9, 2.6, math.pi)):
        base = V(math.sin(theta) * 0.06, h + 0.17 - 0.02 * (i % 2), math.cos(theta) * 0.06 - 0.02)
        fig.spike(base, base + V(math.sin(theta) * 0.05, 0.05, math.cos(theta) * 0.05 - 0.03), 0.014, mane,
                  "Head", sides=3)
    for side in (-1.0, 1.0):
        fig.mb.box(V(side * 0.032, h + 0.105, 0.088), V(0.022, 0.012, 0.012), (1.0, 1.0, 1.0), "Head",
                   material=MATERIAL_GLOW)
        ear = [V(side * 0.07, h + 0.13, -0.02), V(side * 0.14, h + 0.14, -0.05), V(side * 0.21, h + 0.1, -0.09)]
        fig.mb.loft(path_rings(ear, 0.038, 0.007, [hide, shade(hide, 0.85), dark], up_hint=V(0, 0, 1)), "Head",
                    sides=4, tile="flesh", smooth=False, cap_bottom=False, cap_top=True, two_sided=True)
    mane_rings = [
        Ring(V(0, sy + p.torso - 0.08, -0.06), 0.11, 0.1, shade(mane, 0.8), fn=jagged(0.2, 9)),
        Ring(V(0, fig.neck.y + 0.03, -0.03), 0.085, 0.085, mane, fn=jagged(0.25, 11, 0.5)),
        Ring(V(0, h + 0.17, -0.03), 0.07, 0.07, shade(mane, 1.1), fn=jagged(0.3, 7, 1.0)),
    ]
    fig.mb.loft(mane_rings, chain_y([("Head", 0), ("Neck", h), ("Spine", fig.neck.y)], 0.04), sides=10,
                arc=(1.2, 2.0 * math.pi - 1.2), tile="hair", two_sided=True)
    fig.finish(1.0)


def build_shade() -> None:
    """Floating hooded wraith: tattered robe trailing into wisps, glowing violet eyes."""
    robe, robe_dark = hex_color("3b3149"), hex_color("1c1724")
    mist, hand = hex_color("4f4466"), hex_color("8c8494")
    p = Proportions(hip_y=1.0, upper_leg=0.42, lower_leg=0.38, torso=0.46, shoulder_x=0.17, shoulder_y=0.4,
                    upper_arm=0.3, fore_arm=0.3, hand=0.1)
    fig = Figure("shade", p, 77, width=0.9, depth=0.85, girth=0.8)
    fig.attack_style = "staff"
    fig.floating = True
    fig.glow = (0.7, 0.4, 1.0)
    fig.bias = {"Spine": (8, 0, 0), "Head": (-6, 0, 0), "UpperArmL": (-12, 0, -10), "UpperArmR": (-12, 0, 10),
                "ForeArmL": (-20, 0, 0), "ForeArmR": (-20, 0, 0)}

    sy = fig.spine.y
    body = [
        Ring(V(0, sy + p.torso + 0.01, -0.01), 0.06, 0.055, robe),
        Ring(V(0, sy + p.torso - 0.03, -0.01), 0.11, 0.085, robe),
        Ring(V(0, sy + p.shoulder_y, -0.005), p.shoulder_x + 0.04, 0.11, robe),
        Ring(V(0, sy + 0.2, 0.0), 0.15, 0.115, shade(robe, 0.9)),
        Ring(V(0, sy - 0.05, -0.01), 0.15, 0.12, shade(robe, 0.8)),
        Ring(V(0, fig.hips.y - 0.35, -0.04), 0.19, 0.16, shade(robe, 0.65), fn=jagged(0.08, 7)),
        Ring(V(0, fig.hips.y - 0.66, -0.08), 0.23, 0.19, shade(robe_dark, 1.0), fn=jagged(0.18, 9, 0.8)),
        Ring(V(0, fig.hips.y - 0.82, -0.1), 0.14, 0.12, robe_dark, fn=jagged(0.35, 9, 0.8)),
    ]

    def body_w(pt: Vector) -> dict[str, float]:
        return fig.torso_w()(pt)

    fig.mb.loft(body, body_w, sides=14, tile="cloth", cap_top=False, cap_bottom=False, two_sided=True,
                inner_shade=0.3)
    # Trailing wisps.
    for i, (x, z) in enumerate(((-0.12, -0.08), (0.1, -0.12), (0.0, -0.16), (-0.05, 0.1), (0.13, 0.05))):
        y0 = fig.hips.y - 0.6
        pts = [V(x, y0, z), V(x * 1.3, y0 - 0.18, z * 1.4 - 0.05), V(x * 1.5, y0 - 0.32, z * 1.6 - 0.12)]
        fig.mb.loft(path_rings(pts, 0.035, 0.006, [robe_dark, mist, shade(mist, 0.6)]), "Hips", sides=4,
                    tile="cloth", smooth=False, cap_bottom=False, cap_top=True, two_sided=True)
    for s in ("L", "R"):
        sh, el, wr = fig.j("UpperArm" + s), fig.j("ForeArm" + s), fig.j("Hand" + s)
        x = sh.x
        fig.mb.loft([
            Ring(V(x, sh.y + 0.04, 0), 0.05, 0.05, robe),
            Ring(V(x, sh.y - 0.04, 0), 0.06, 0.062, robe),
            Ring(V(x, el.y, 0), 0.06, 0.064, shade(robe, 0.9)),
            Ring(V(x, wr.y + 0.04, -0.01), 0.085, 0.09, shade(robe, 0.75), fn=jagged(0.12, 7)),
            Ring(V(x, wr.y - 0.01, -0.02), 0.095, 0.1, robe_dark, fn=jagged(0.2, 7, 1.0)),
        ], fig.arm_w(s), sides=10, tile="cloth", cap_bottom=False, cap_top=V(x, sh.y + 0.06, 0), two_sided=True)
        fig.hand(s, hand, claw=hex_color("504858"), claw_len=0.09, scale=1.1)

    profile = [(dy, rx * 0.9, rz * 0.9, z - 0.01) for dy, rx, rz, z in HUMAN_HEAD]
    fig.head_mesh(profile=profile, ears=False, nose=False)
    fig.atlas.fill_face((0.02, 0.015, 0.03), noise=0.0)
    h = fig.head.y
    for side in (-1.0, 1.0):
        fig.mb.box(V(side * 0.03, h + 0.1, 0.074), V(0.024, 0.01, 0.01), (1.0, 1.0, 1.0), "Head",
                   material=MATERIAL_GLOW)
    fig.hood(robe, peak=0.1, opening=0.7, mantle=0.2)
    fig.finish(1.0)


def build_pale_warden() -> None:
    """Towering knight in corroded pale plate, tattered cape and a heavy glaive."""
    plate, plate_dark = hex_color("767c80"), hex_color("464a4f")
    rust, cape, cloth = hex_color("6e4630"), hex_color("1e1c22"), hex_color("3a3436")
    wood = hex_color("3b2c22")
    p = Proportions(hip_y=1.0, upper_leg=0.45, lower_leg=0.41, torso=0.52, shoulder_x=0.24, shoulder_y=0.44,
                    upper_arm=0.3, fore_arm=0.28, hand=0.1)
    fig = Figure("pale_warden", p, 88, width=1.3, depth=1.2, girth=1.3, hip_width=1.1)
    fig.attack_style = "melee"
    fig.walk_swing = 0.7
    fig.glow = (0.75, 0.88, 1.0)

    fig.legs(cloth, thigh=1.0)
    # Greaves, knee cops and sabatons.
    for s in ("L", "R"):
        knee, ankle = fig.j("LowerLeg" + s), fig.j("Foot" + s)
        hip = fig.j("UpperLeg" + s)
        x = knee.x
        fig.mb.loft([Ring(V(x, ankle.y - 0.02, 0), 0.07, 0.075, plate_dark),
                     Ring(V(x, knee.y - 0.12, 0.005), 0.08, 0.088, plate),
                     Ring(V(x, knee.y - 0.02, 0.008), 0.072, 0.08, shade(plate, 0.95))],
                    fig.leg_w(s), sides=8, tile="metal", smooth=False, cap_bottom=False, cap_top=False)
        sphere(fig.mb, V(x, knee.y, 0.035), V(0.06, 0.05, 0.05), plate, "LowerLeg" + s, lat=3, sides=6,
               tile="metal", smooth=False)
        fig.mb.loft([Ring(V(x, hip.y - 0.03, 0.0), 0.09, 0.095, plate),
                     Ring(V(x, knee.y + 0.08, 0.008), 0.08, 0.088, shade(plate, 0.9))],
                    fig.leg_w(s), sides=8, tile="metal", smooth=False, cap_bottom=False, cap_top=False)
    fig.boots(plate_dark, shaft=0.06, width=1.25, toe=0.16, tile="metal", cuff=False)
    fig.pelvis(cloth)
    sy = fig.spine.y
    w, d = fig.width, fig.depth
    ridge = lambda th: 1.0 + 0.1 * max(0.0, math.cos(th)) ** 8  # noqa: E731
    cuirass = [
        Ring(V(0, sy - 0.05, 0.0), 0.14 * w, 0.105 * d, plate_dark, fn=ridge),
        Ring(V(0, sy + 0.08, 0.008), 0.138 * w, 0.106 * d, shade(plate, 0.9), fn=ridge),
        Ring(V(0, sy + 0.24, 0.016), 0.152 * w, 0.12 * d, plate, fn=ridge),
        Ring(V(0, sy + 0.36, 0.01), 0.16 * w, 0.118 * d, plate, fn=ridge),
        Ring(V(0, sy + p.shoulder_y, -0.004), p.shoulder_x + 0.02, 0.1 * d, shade(plate, 0.95)),
        Ring(V(0, sy + p.torso - 0.02, -0.01), 0.1, 0.085, plate_dark),
        Ring(V(0, sy + p.torso + 0.02, -0.006), 0.065, 0.06, plate_dark),
    ]
    fig.mb.loft(cuirass, fig.torso_w(), sides=12, tile="metal", smooth=False, cap_bottom=False, cap_top=False)
    fig.belt(hex_color("2a2220"), plate_dark, y=sy - 0.02, pad=0.03, height=0.06)
    # Faulds/tassets: segmented plate skirt over a cloth tabard.
    fig.skirt(cloth, top_y=sy - 0.04, bottom_y=fig.hips.y - 0.42, top_r=(0.17, 0.13), bottom_r=(0.2, 0.17),
              rough=0.12, follow=0.5, rows=3, opening=0.0)
    fig.skirt(plate, top_y=sy - 0.02, bottom_y=fig.hips.y - 0.2, top_r=(0.19, 0.145), bottom_r=(0.215, 0.175),
              tile="metal", follow=0.4, rows=2, opening=0.5)
    # Cape.
    cape_rings = [
        Ring(V(0, sy + p.torso - 0.04, -0.06), 0.16, 0.12, cape),
        Ring(V(0, sy + 0.2, -0.12), 0.27, 0.17, shade(cape, 0.9)),
        Ring(V(0, fig.hips.y - 0.3, -0.18), 0.3, 0.2, shade(cape, 0.8), fn=jagged(0.05, 6)),
        Ring(V(0, 0.18, -0.24), 0.32, 0.22, shade(cape, 0.65), fn=jagged(0.14, 9, 0.7)),
    ]
    cape_rings.reverse()

    def cape_w(pt: Vector) -> dict[str, float]:
        if pt.y > sy + 0.1:
            return {"Spine": 1.0}
        t = clamp((sy + 0.1 - pt.y) / 0.5, 0.0, 1.0)
        return {"Spine": 1.0 - t, "Hips": t}

    fig.mb.loft(cape_rings, cape_w, sides=12, arc=(1.6, 2.0 * math.pi - 1.6), tile="cloth", two_sided=True,
                inner_shade=0.6)
    fig.neck_mesh(plate_dark)
    fig.arms(cloth, plate_dark, tile="cloth", thickness=0.9)
    for s, side in (("L", -1.0), ("R", 1.0)):
        sh, el, wr = fig.j("UpperArm" + s), fig.j("ForeArm" + s), fig.j("Hand" + s)
        x = sh.x
        # Layered pauldron.
        for i in range(3):
            y = sh.y + 0.05 - i * 0.045
            fig.mb.loft([Ring(V(x + side * 0.01 * i, y - 0.06, 0), 0.1 + 0.005 * i, 0.105, shade(plate, 0.88)),
                         Ring(V(x, y + 0.02, 0), 0.085 + 0.005 * i, 0.09, plate)],
                        chain_y([("UpperArm" + s, 0.0)], 0.01), sides=8, tile="metal", smooth=False,
                        cap_bottom=False, cap_top=V(x - side * 0.03, y + 0.055 - 0.01 * i, 0), two_sided=True)
        fig.mb.loft([Ring(V(x, el.y - 0.02, 0), 0.058, 0.062, plate),
                     Ring(V(x, wr.y + 0.01, 0), 0.06, 0.064, shade(plate, 0.85)),
                     Ring(V(x, wr.y - 0.04, 0.0), 0.05, 0.055, plate_dark)],
                    fig.arm_w(s), sides=8, tile="metal", smooth=False, cap_bottom=False, cap_top=False, two_sided=True)
        sphere(fig.mb, V(x, el.y, -0.03), V(0.05, 0.05, 0.045), plate, "ForeArm" + s, lat=3, sides=6,
               tile="metal", smooth=False)
        fig.hand(s, plate_dark, scale=1.2)

    # Great helm: the head mesh is the helm, the face texture paints the visor.
    profile = [(-0.04, 0.07, 0.075, 0.01), (0.0, 0.09, 0.098, 0.012), (0.06, 0.098, 0.106, 0.012),
               (0.12, 0.1, 0.108, 0.006), (0.17, 0.098, 0.104, 0.0), (0.2, 0.08, 0.088, -0.004),
               (0.215, 0.045, 0.05, -0.006)]
    fig.head_mesh(profile=profile, nose=False, ears=False, sides=10)
    f = fig.face
    h = fig.head.y
    fig.atlas.fill_face(plate, noise=0.1)
    f.band(h - 0.06, h + 0.0, shade(plate, 0.75), 0.8)
    f.band(h + 0.085, h + 0.105, (0.03, 0.03, 0.04), 1.0, theta_from=-0.75, theta_to=0.75)
    f.band(h + 0.105, h + 0.115, shade(plate, 1.1), 0.7, theta_from=-0.8, theta_to=0.8)
    f.band(h + 0.01, h + 0.08, (0.05, 0.05, 0.06), 0.6, theta_from=-0.06, theta_to=0.06)
    for i in range(-6, 7):
        f.ellipse(0.25 * i, h + 0.005, 0.03, 0.005, shade(plate, 1.15), 1.0)
    for i in range(-4, 5, 2):
        f.ellipse(0.12 * i, h + 0.05, 0.02, 0.004, (0.03, 0.03, 0.04), 1.0)
    f.speckle(0.0, h + 0.05, 3.0, 0.1, rust, 0.08, 0.7)
    f.ellipse(0.4, h + 0.06, 0.05, 0.05, rust, 0.6)
    for side in (-1.0, 1.0):
        fig.mb.box(V(side * 0.032, h + 0.095, 0.098), V(0.02, 0.008, 0.008), (1.0, 1.0, 1.0), "Head",
                   material=MATERIAL_GLOW)
    crest = [V(0, h + 0.2, 0.06), V(0, h + 0.25, 0.0), V(0, h + 0.24, -0.1), V(0, h + 0.14, -0.2),
             V(0, h + 0.02, -0.24)]
    fig.mb.loft(path_rings(crest, 0.012, 0.03, [rust, shade(rust, 0.9), shade(rust, 0.8), shade(rust, 0.7)],
                           up_hint=V(1, 0, 0)), chain_y([("Head", 0), ("Neck", h - 0.0)], 0.06), sides=4, tile="hair",
                smooth=False, cap_bottom=True, cap_top=True)
    # Glaive in the right hand.
    fig.in_hand("R", -6.0, V(0.0, -0.06, 0.03))
    fig.mb.loft([Ring(V(0, -0.85, 0), 0.016, 0.016, shade(wood, 0.8)), Ring(V(0, 0.75, 0), 0.02, 0.02, wood)],
                "HandR", sides=6, tile="hair", smooth=False)
    fig.mb.box(V(0, 0.76, 0), V(0.05, 0.05, 0.05), plate_dark, "HandR", tile="metal")
    blade = [Ring(V(0, 0.78, 0.0), 0.006, 0.05, plate, ax=V(1, 0, 0), az=V(0, 0, 1)),
             Ring(V(0, 1.0, 0.035), 0.005, 0.07, shade(plate, 0.95), ax=V(1, 0, 0), az=V(0, 0, 1))]
    fig.mb.loft(blade, "HandR", sides=4, tile="metal", smooth=False, cap_bottom=True, cap_top=V(0, 1.18, 0.0))
    fig.spike(V(0, 0.82, -0.04), V(0, 0.86, -0.15), 0.014, plate_dark, "HandR", sides=4)
    fig.reset_xform()
    fig.finish(1.0)


BUILDERS = {
    "bran": build_bran,
    "mira": build_mira,
    "owen": build_owen,
    "elara": build_elara,
    "hollow": build_hollow,
    "wretch": build_wretch,
    "shade": build_shade,
    "pale_warden": build_pale_warden,
}


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ids = argv or list(BUILDERS)
    unknown = [model_id for model_id in ids if model_id not in BUILDERS]
    if unknown:
        raise SystemExit(f"Unknown model ids: {unknown}. Known: {list(BUILDERS)}")
    for model_id in ids:
        BUILDERS[model_id]()
    (SOURCE_DIR / ".gdignore").touch()


main()
