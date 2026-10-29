"""Small .tscn writer and explore-scene helpers used by tools/generate_scenes.py.

Scenes are blocked out from boxes and cylinders plus the standard explore scaffolding
(ExploreController root, CameraRig/CameraZones, Doors, Interactables, Actors, UI).
"""

from __future__ import annotations

import math


def fmt(v: float) -> str:
    v = round(v, 6)
    if v == int(v):
        return str(int(v))
    return repr(v)


def vec3(v) -> str:
    return "Vector3(%s, %s, %s)" % tuple(fmt(c) for c in v)


def color(c) -> str:
    if len(c) == 3:
        c = (*c, 1.0)
    return "Color(%s, %s, %s, %s)" % tuple(fmt(x) for x in c)


def basis(yaw: float = 0.0, pitch: float = 0.0, roll: float = 0.0):
    """Row-major basis for R = Ry(yaw) @ Rx(pitch) @ Rz(roll), angles in degrees."""
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cx, sx = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    cz, sz = math.cos(math.radians(roll)), math.sin(math.radians(roll))
    ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    rx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    rz = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]

    def mul(a, b):
        return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]

    return mul(mul(ry, rx), rz)


def transform(pos=(0, 0, 0), yaw=0.0, pitch=0.0, roll=0.0) -> str:
    b = basis(yaw, pitch, roll)
    vals = [b[0][0], b[0][1], b[0][2], b[1][0], b[1][1], b[1][2], b[2][0], b[2][1], b[2][2], *pos]
    return "Transform3D(%s)" % ", ".join(fmt(v) for v in vals)


class Scene:
    def __init__(self, root_name: str, uid: str) -> None:
        self.root_name = root_name
        self.uid = uid
        self.ext: list[tuple[str, str, str]] = []  # (type, path, id)
        self.subs: list[tuple[str, str, dict]] = []  # (type, id, props)
        self.nodes: list[tuple[str, str, str | None, dict, str | None]] = []
        self._sub_cache: dict[str, str] = {}
        self._counter = 0
        self.names: set[str] = set()

    # -- resources -------------------------------------------------------------
    def ext_res(self, res_type: str, path: str) -> str:
        for t, p, i in self.ext:
            if p == path:
                return i
        rid = f"{len(self.ext) + 1}_{path.rsplit('/', 1)[-1].split('.')[0]}"
        self.ext.append((res_type, path, rid))
        return rid

    def sub(self, res_type: str, props: dict, key: str | None = None) -> str:
        cache_key = key or (res_type + repr(sorted(props.items())))
        if cache_key in self._sub_cache:
            return self._sub_cache[cache_key]
        self._counter += 1
        rid = f"{res_type}_{self._counter}"
        self.subs.append((res_type, rid, props))
        self._sub_cache[cache_key] = rid
        return rid

    def material(self, albedo, *, emission=None, energy: float = 1.0, roughness: float = 0.95,
                 unshaded: bool = False) -> str:
        props = {"albedo_color": color(albedo), "roughness": fmt(roughness)}
        if emission is not None:
            props["emission_enabled"] = "true"
            props["emission"] = color(emission)
            props["emission_energy_multiplier"] = fmt(energy)
        if unshaded:
            props["shading_mode"] = "0"
        return self.sub("StandardMaterial3D", props)

    def box_mesh(self, size) -> str:
        return self.sub("BoxMesh", {"size": vec3(size)})

    def box_shape(self, size) -> str:
        return self.sub("BoxShape3D", {"size": vec3(size)})

    def cyl_mesh(self, radius: float, height: float, top: float | None = None, segments: int = 10) -> str:
        return self.sub("CylinderMesh", {"top_radius": fmt(radius if top is None else top),
                                         "bottom_radius": fmt(radius), "height": fmt(height),
                                         "radial_segments": str(segments), "rings": "1"})

    def sphere_shape(self, radius: float) -> str:
        return self.sub("SphereShape3D", {"radius": fmt(radius)})

    # -- nodes -----------------------------------------------------------------
    def node(self, name: str, node_type: str | None, parent: str | None, props: dict | None = None,
             instance: str | None = None) -> str:
        if parent is None:
            path = "."
        elif parent == ".":
            path = name
        else:
            path = f"{parent}/{name}"
        assert path not in self.names, path
        self.names.add(path)
        self.nodes.append((name, node_type, parent, props or {}, instance))
        return path

    def box(self, parent: str, name: str, pos, size, mat: str, *, collide: bool = False, yaw=0.0, pitch=0.0,
            roll=0.0) -> str:
        t = transform(pos, yaw, pitch, roll)
        if collide:
            body = self.node(name, "StaticBody3D", parent, {"transform": t})
            self.node("CollisionShape3D", "CollisionShape3D", body, {"shape": f'SubResource("{self.box_shape(size)}")'})
            mesh_name = "FloorMesh" if name == "Floor" else ("WallMesh" if name.startswith("Wall") else "Mesh")
            self.node(mesh_name, "MeshInstance3D", body, {
                "mesh": f'SubResource("{self.box_mesh(size)}")',
                "surface_material_override/0": f'SubResource("{mat}")'})
            return body
        return self.node(name, "MeshInstance3D", parent, {
            "transform": t,
            "mesh": f'SubResource("{self.box_mesh(size)}")',
            "surface_material_override/0": f'SubResource("{mat}")'})

    def blocker(self, parent: str, name: str, pos, size) -> str:
        """Invisible collision wall."""
        body = self.node(name, "StaticBody3D", parent, {"transform": transform(pos)})
        self.node("CollisionShape3D", "CollisionShape3D", body, {"shape": f'SubResource("{self.box_shape(size)}")'})
        return body

    def cyl(self, parent: str, name: str, pos, radius: float, height: float, mat: str, *, top=None,
            collide: bool = False, yaw=0.0, pitch=0.0, roll=0.0, segments: int = 10) -> str:
        t = transform(pos, yaw, pitch, roll)
        mesh = f'SubResource("{self.cyl_mesh(radius, height, top, segments)}")'
        if collide:
            body = self.node(name, "StaticBody3D", parent, {"transform": t})
            shape = self.sub("CylinderShape3D", {"radius": fmt(max(radius, top or 0)), "height": fmt(height)})
            self.node("CollisionShape3D", "CollisionShape3D", body, {"shape": f'SubResource("{shape}")'})
            self.node("Mesh", "MeshInstance3D", body, {"mesh": mesh, "surface_material_override/0": f'SubResource("{mat}")'})
            return body
        return self.node(name, "MeshInstance3D", parent, {
            "transform": t, "mesh": mesh, "surface_material_override/0": f'SubResource("{mat}")'})

    # -- output ----------------------------------------------------------------
    def write(self, path: str) -> None:
        out = [f'[gd_scene load_steps={len(self.ext) + len(self.subs) + 1} format=3 uid="{self.uid}"]', ""]
        for t, p, i in self.ext:
            out.append(f'[ext_resource type="{t}" path="{p}" id="{i}"]')
        out.append("")
        for t, i, props in self.subs:
            out.append(f'[sub_resource type="{t}" id="{i}"]')
            for k, v in props.items():
                out.append(f"{k} = {v}")
            out.append("")
        for name, node_type, parent, props, instance in self.nodes:
            head = f'[node name="{name}"'
            if node_type is not None:
                head += f' type="{node_type}"'
            if parent is not None:
                head += f' parent="{parent}"'
            if instance is not None:
                head += f' instance=ExtResource("{instance}")'
            out.append(head + "]")
            for k, v in props.items():
                out.append(f"{k} = {v}")
            out.append("")
        with open(path, "w") as fh:
            fh.write("\n".join(out).rstrip() + "\n")


def s(text: str) -> str:
    return '"%s"' % text.replace("\\", "\\\\").replace('"', '\\"')


def packed(lines: list[str]) -> str:
    return "PackedStringArray(%s)" % ", ".join(s(x) for x in lines)


# -- shared explore scaffolding ------------------------------------------------------

def explore_root(sc: Scene, root: str, area_id: str) -> None:
    ctrl = sc.ext_res("Script", "res://scripts/explore/explore_controller.gd")
    sc.node(root, "Node3D", None, {"script": f'ExtResource("{ctrl}")', "area_id": s(area_id)})


def environment(sc: Scene, *, ambient, ambient_energy: float, fog_color, fog_density: float,
                fog_sky_affect: float = 0.0) -> None:
    env = sc.sub("Environment", {
        "background_mode": "1",
        "background_color": color((0.04, 0.045, 0.055)),
        "ambient_light_source": "2",
        "ambient_light_color": color(ambient),
        "ambient_light_energy": fmt(ambient_energy),
        "tonemap_mode": "2",
        "fog_enabled": "true",
        "fog_light_color": color(fog_color),
        "fog_light_energy": "1",
        "fog_density": fmt(fog_density),
        "fog_sky_affect": fmt(fog_sky_affect),
    })
    sc.node("WorldEnvironment", "WorldEnvironment", ".", {"environment": f'SubResource("{env}")'})


def sun(sc: Scene, *, yaw: float, pitch: float, energy: float, col) -> None:
    sc.node("DirectionalLight3D", "DirectionalLight3D", ".", {
        "transform": transform((0, 10, 0), yaw, pitch),
        "light_color": color(col),
        "light_energy": fmt(energy),
        "shadow_enabled": "true",
    })


def camera_rig(sc: Scene, default_zone: str) -> None:
    rig = sc.ext_res("Script", "res://scripts/explore/camera_rig.gd")
    sc.node("CameraRig", "Node3D", ".", {"script": f'ExtResource("{rig}")', "camera_path": 'NodePath("Camera")',
                                         "default_zone_path": f'NodePath("../CameraZones/{default_zone}")'})
    sc.node("Camera", "Camera3D", "CameraRig", {"transform": transform((0, 4, 8)), "fov": "60"})
    sc.node("CameraZones", "Node3D", ".")


def camera_zone(sc: Scene, name: str, pos, size, cam_offset, look_offset, track: float = 0.35) -> None:
    zone = sc.ext_res("Script", "res://scripts/explore/camera_zone.gd")
    path = sc.node(name, "Area3D", "CameraZones", {
        "transform": transform(pos), "script": f'ExtResource("{zone}")',
        "camera_position": vec3(cam_offset), "look_target_offset": vec3(look_offset),
        "track_strength": fmt(track)})
    sc.node("CollisionShape3D", "CollisionShape3D", path, {
        "transform": transform((0, size[1] * 0.5, 0)), "shape": f'SubResource("{sc.box_shape(size)}")'})


def door(sc: Scene, name: str, panel_pos, trigger_pos, *, target: str, spawn, rot_y: float, label: str,
         mat: str, flag: str = "", flag_prompt: str = "") -> None:
    script = sc.ext_res("Script", "res://scripts/explore/explore_door.gd")
    props = {"script": f'ExtResource("{script}")', "target_area_id": s(target), "target_spawn": vec3(spawn),
             "target_rotation_y": fmt(rot_y), "door_label": s(label)}
    if flag:
        props["required_story_flag"] = s(flag)
    if flag_prompt:
        props["flag_locked_prompt"] = s(flag_prompt)
    path = sc.node(name, "Node3D", "Doors", props)
    panel = sc.node("Panel", "StaticBody3D", path, {"transform": transform(panel_pos)})
    sc.node("CollisionShape3D", "CollisionShape3D", panel, {"shape": f'SubResource("{sc.box_shape((0.35, 2.4, 3.2))}")'})
    sc.node("DoorMesh", "MeshInstance3D", panel, {"mesh": f'SubResource("{sc.box_mesh((0.35, 2.4, 3.2))}")',
                                                 "surface_material_override/0": f'SubResource("{mat}")'})
    trig = sc.node("Trigger", "Area3D", path, {"transform": transform(trigger_pos)})
    sc.node("CollisionShape3D", "CollisionShape3D", trig, {"shape": f'SubResource("{sc.box_shape((1.6, 2.5, 3.5))}")'})


def actor(sc: Scene, name: str, actor_id: str, pos, yaw: float = 0.0, *, model: str | None = None,
          start_hidden: bool = False, hide_when_flag: str = "") -> str:
    script = sc.ext_res("Script", "res://scripts/narrative/actor_node.gd")
    props = {"transform": transform(pos, yaw), "script": f'ExtResource("{script}")', "actor_id": s(actor_id)}
    if model:
        props["model_scene"] = f'ExtResource("{sc.ext_res("PackedScene", model)}")'
    if start_hidden:
        props["start_hidden"] = "true"
    if hide_when_flag:
        props["hide_when_flag"] = s(hide_when_flag)
    return sc.node(name, "Node3D", "Actors", props)


def examinable(sc: Scene, name: str, pos, label: str, *, lines: list[str] | None = None, verb: str = "examine",
               speaker: str = "internal", dialog: str = "", cutscene: str = "", requires: str = "",
               hide_when: str = "", sets: str = "", radius: float = 1.0) -> None:
    script = sc.ext_res("Script", "res://scripts/explore/explore_examinable.gd")
    props = {"transform": transform(pos), "script": f'ExtResource("{script}")', "label": s(label)}
    if verb != "examine":
        props["prompt_verb"] = s(verb)
    if speaker != "internal":
        props["speaker"] = s(speaker)
    if lines:
        props["lines"] = packed(lines)
    for key, value in (("dialog_id", dialog), ("cutscene_id", cutscene), ("story_flag_required", requires),
                       ("hide_when_flag", hide_when), ("story_flag_set", sets)):
        if value:
            props[key] = s(value)
    props["radius"] = fmt(radius)
    sc.node(name, "Area3D", "Interactables", props)


def trigger(sc: Scene, name: str, pos, radius: float, *, cutscene: str = "", dialog: str = "",
            requires: str = "") -> None:
    script = sc.ext_res("Script", "res://scripts/narrative/narrative_trigger.gd")
    props = {"transform": transform(pos), "script": f'ExtResource("{script}")', "trigger_id": s(name.lower())}
    if cutscene:
        props["cutscene_id"] = s(cutscene)
    if dialog:
        props["dialog_id"] = s(dialog)
    if requires:
        props["story_flag_required"] = s(requires)
    path = sc.node(name, "Area3D", ".", props)
    sc.node("CollisionShape3D", "CollisionShape3D", path, {"shape": f'SubResource("{sc.sphere_shape(radius)}")'})


def cutscene_player(sc: Scene, cutscene: str) -> None:
    script = sc.ext_res("Script", "res://scripts/narrative/cutscene_player.gd")
    sc.node("CutscenePlayer", "Node", ".", {"script": f'ExtResource("{script}")', "cutscene_id": s(cutscene),
                                           "auto_play": "true"})


def explore_ui(sc: Scene) -> None:
    sc.node("UI", "CanvasLayer", ".")
    sc.node("ExploreUI", "Control", "UI", {"layout_mode": "3", "anchors_preset": "15", "anchor_right": "1.0",
                                           "anchor_bottom": "1.0", "grow_horizontal": "2", "grow_vertical": "2",
                                           "mouse_filter": "2"})
    sc.node("PromptLabel", "Label", "UI/ExploreUI", {"layout_mode": "0", "offset_left": "20.0",
                                                     "offset_top": "16.0", "offset_right": "700.0",
                                                     "offset_bottom": "44.0", "text": s("WASD to move")})
    sc.node("MessageLabel", "Label", "UI/ExploreUI", {"layout_mode": "0", "offset_left": "20.0",
                                                      "offset_top": "48.0", "offset_right": "800.0",
                                                      "offset_bottom": "76.0", "text": s("")})
