"""Generate the Chapter 1 intro explore scenes (see game-design/chapter-1-intro.md).

Run (all scenes, or only the listed area ids):
    python3 tools/generate_scenes.py
    python3 tools/generate_scenes.py mira_chapel_lane

Writes scenes/explore/<area_id>.tscn. Re-running overwrites the scene, so make lasting
layout changes here rather than in the editor. Then reimport: godot --headless --path . --import
"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from scene_kit import (  # noqa: E402
    Scene,
    actor,
    camera_rig,
    camera_zone,
    color,
    cutscene_player,
    door,
    environment,
    examinable,
    explore_root,
    explore_ui,
    sun,
    transform,
    trigger,
)

SCENE_DIR = Path(__file__).resolve().parent.parent / "scenes" / "explore"


def build_mira_intake_alcove() -> Scene:
    """Abandoned Doorway (mira_intake_alcove): see game-design/chapter-1-intro.md, Area 1."""
    sc = Scene("MiraIntakeAlcove", "uid://redelka_mira_intake_alcove")
    explore_root(sc, "MiraIntakeAlcove", "mira_intake_alcove")
    environment(sc, ambient=(0.42, 0.46, 0.56), ambient_energy=0.6, fog_color=(0.2, 0.22, 0.26), fog_density=0.03)
    sun(sc, yaw=-140.0, pitch=-24.0, energy=0.35, col=(0.72, 0.78, 0.9))

    stone = sc.material((0.27, 0.25, 0.23))
    stone_dark = sc.material((0.19, 0.18, 0.17))
    plaster = sc.material((0.33, 0.31, 0.28))
    wood = sc.material((0.3, 0.21, 0.14))
    wood_dark = sc.material((0.2, 0.14, 0.1))
    board = sc.material((0.36, 0.27, 0.18))
    canvas = sc.material((0.36, 0.2, 0.17))
    blanket_mira = sc.material((0.4, 0.3, 0.23))
    blanket_lily = sc.material((0.33, 0.28, 0.36))
    sacking = sc.material((0.42, 0.37, 0.27))
    chalk = sc.material((0.82, 0.8, 0.74), emission=(0.3, 0.3, 0.28), energy=0.15)
    tin = sc.material((0.4, 0.41, 0.42), roughness=0.5)
    iron = sc.material((0.16, 0.16, 0.17), roughness=0.6)
    ice = sc.material((0.62, 0.7, 0.76), roughness=0.15)
    shoe = sc.material((0.24, 0.17, 0.12))
    window_warm = sc.material((0.5, 0.34, 0.16), emission=(0.95, 0.6, 0.28), energy=0.55)
    roof = sc.material((0.17, 0.15, 0.15))

    sc.node("Room", "Node3D", ".")
    R = "Room"
    sc.box(R, "Floor", (0, -0.2, 0), (14, 0.4, 14), stone, collide=True)
    # Shop front (north) and the side walls. The west wall has a gap at z 0..2 for the lane exit.
    sc.box(R, "WallBack", (0, 2.25, -7.2), (14, 4.5, 0.4), plaster, collide=True)
    sc.box(R, "WallEast", (7.2, 2.0, -2.75), (0.4, 4.0, 8.5), plaster, collide=True)
    sc.box(R, "WallWestNorth", (-7.2, 2.0, -3.5), (0.4, 4.0, 7.0), plaster, collide=True)
    sc.box(R, "WallWestSouth", (-7.2, 2.0, 4.6), (0.4, 4.0, 5.2), plaster, collide=True)
    sc.blocker(R, "SouthEdge", (0, 1.5, 7.3), (14.8, 3.0, 0.4))

    props = sc.node("Props", "Node3D", R)
    # Doorway recess: pillars, lintel, boarded door.
    sc.box(props, "PillarWest", (-1.1, 1.5, -6.6), (0.45, 3.0, 0.8), stone_dark, collide=True)
    sc.box(props, "PillarEast", (1.1, 1.5, -6.6), (0.45, 3.0, 0.8), stone_dark, collide=True)
    sc.box(props, "Lintel", (0, 3.1, -6.6), (2.7, 0.35, 0.8), stone_dark)
    sc.box(props, "ShopDoor", (0, 1.35, -6.92), (1.75, 2.7, 0.1), wood_dark)
    for i, (y, roll) in enumerate(((0.7, 8.0), (1.45, -6.0), (2.2, 10.0))):
        sc.box(props, f"Board{i + 1}", (0, y, -6.84), (1.95, 0.22, 0.05), board, roll=roll)
    # Chalk birds on the west pillar: little "v" marks.
    for i, (y, z) in enumerate(((0.9, -6.2), (1.15, -6.2), (0.7, -6.2))):
        x = -1.1 + (i - 1) * 0.12
        sc.box(props, f"ChalkBird{i + 1}a", (x - 0.03, y, z - 0.005), (0.08, 0.015, 0.01), chalk, roll=28.0)
        sc.box(props, f"ChalkBird{i + 1}b", (x + 0.03, y, z - 0.005), (0.08, 0.015, 0.01), chalk, roll=-28.0)
    # Awning: sagging canvas on two posts.
    sc.box(props, "Awning", (0, 2.95, -5.3), (7.2, 0.08, 3.6), canvas, pitch=-9.0)
    # Cold grey daylight pooling under the awning so the sleeping spots read.
    sc.node("AwningFill", "OmniLight3D", props, {"transform": transform((-0.6, 2.4, -4.6)),
                                                 "light_color": color((0.62, 0.68, 0.82)), "light_energy": "0.45",
                                                 "omni_range": "6.0"})
    sc.cyl(props, "AwningPostWest", (-3.4, 1.35, -3.65), 0.06, 2.7, wood)
    sc.cyl(props, "AwningPostEast", (3.4, 1.35, -3.65), 0.06, 2.7, wood)
    # Sleeping spots.
    sc.box(props, "BlanketMira", (-0.2, 0.04, -5.3), (0.95, 0.08, 1.7), blanket_mira, yaw=4.0)
    sc.box(props, "BlanketMiraFold", (-0.25, 0.1, -6.0), (0.9, 0.1, 0.35), blanket_mira, yaw=4.0)
    sc.box(props, "BlanketLily", (-2.2, 0.035, -5.25), (0.8, 0.07, 1.3), blanket_lily, yaw=-14.0)
    sc.box(props, "BlanketLilyPushed", (-2.05, 0.09, -4.6), (0.75, 0.12, 0.32), blanket_lily, yaw=-20.0)
    sc.box(props, "LilyShoeLeft", (-1.68, 0.04, -4.45), (0.09, 0.08, 0.19), shoe, yaw=8.0)
    sc.box(props, "LilyShoeRight", (-1.52, 0.04, -4.5), (0.09, 0.08, 0.19), shoe, yaw=-4.0)
    sc.box(props, "MiraTin", (0.55, 0.05, -5.85), (0.2, 0.1, 0.13), tin, yaw=12.0)
    sc.cyl(props, "LanternBase", (1.15, 0.12, -6.1), 0.12, 0.24, iron)
    sc.cyl(props, "LanternGlass", (1.15, 0.36, -6.1), 0.09, 0.24, sc.material((0.22, 0.22, 0.2), roughness=0.3))
    sc.cyl(props, "LanternCap", (1.15, 0.52, -6.1), 0.02, 0.08, iron, top=0.13)
    # Tom and Elsa's nest of sacking against the chandler's crates.
    sc.box(props, "Sacking", (3.4, 0.04, -5.2), (1.8, 0.08, 1.4), sacking, yaw=6.0)
    sc.box(props, "CrateA", (4.7, 0.35, -6.3), (0.7, 0.7, 0.7), wood, collide=True, yaw=5.0)
    sc.box(props, "CrateB", (5.5, 0.35, -6.2), (0.7, 0.7, 0.7), wood, collide=True, yaw=-8.0)
    sc.box(props, "CrateC", (5.0, 1.05, -6.3), (0.65, 0.65, 0.65), wood, yaw=14.0)
    # Rain barrel with the first ice of the year.
    sc.cyl(props, "RainBarrel", (-4.6, 0.45, -6.0), 0.38, 0.9, wood_dark, collide=True, segments=12)
    sc.cyl(props, "BarrelIce", (-4.6, 0.86, -6.0), 0.34, 0.02, ice, segments=12)

    # Holt's house front across the cobbles (south-east).
    holt = sc.node("HoltHouse", "Node3D", R)
    sc.box(holt, "Walls", (5.6, 2.0, 4.3), (3.2, 4.0, 5.8), plaster, collide=True)
    sc.box(holt, "Roof", (5.4, 4.15, 4.3), (3.8, 0.3, 6.4), roof)
    sc.box(holt, "Door", (3.97, 1.05, 4.0), (0.08, 2.1, 1.0), wood_dark)
    sc.box(holt, "DoorFrame", (3.96, 2.18, 4.0), (0.12, 0.14, 1.2), wood)
    sc.box(holt, "WindowFrame", (3.96, 1.65, 2.6), (0.1, 0.9, 1.0), wood)
    sc.box(holt, "Bench", (3.6, 0.25, 5.8), (0.45, 0.5, 1.4), wood, collide=True)
    # The far side of the cobbles: a shuttered row of house fronts closing the space.
    sc.box(R, "HousesSouth", (-1.6, 2.4, 8.0), (11.2, 4.8, 1.2), plaster)
    sc.box(R, "HousesSouthRoof", (-1.6, 4.95, 8.1), (11.6, 0.3, 1.8), roof)
    for i, x in enumerate((-6.0, -3.4, -0.8, 1.8)):
        sc.box(R, f"SouthShutter{i + 1}", (x, 1.7, 7.38), (0.9, 1.0, 0.05), wood_dark)

    sc.node("Enemies", "Node3D", ".")
    sc.node("Pickups", "Node3D", ".")
    sc.node("Interactables", "Node3D", ".")
    sc.node("Doors", "Node3D", ".")
    sc.node("Actors", "Node3D", ".")

    camera_rig(sc, "ZoneDoorway")
    camera_zone(sc, "ZoneDoorway", (0, 0, -4.5), (14, 4, 5), (3.5, 4.2, 8.0), (-0.8, 0.4, -1.0))
    camera_zone(sc, "ZoneHolt", (0, 0, 2.5), (14, 4, 9), (-4.0, 4.4, -5.0), (2.5, 0.6, 1.5))

    door(sc, "DoorWestLane", (-7.2, 1.2, 1.0), (-6.45, 1.0, 1.0), target="mira_chapel_lane", spawn=(0, 0, 11.5),
         rot_y=math.pi, label="Chapel Lane", mat=wood_dark, flag="intro_lane_open",
         flag_prompt="A handcart blocks the gap. Not yet.")

    actor(sc, "OrphanTom", "orphan_tom", (2.6, 0, -4.3), -95.0, model="res://scenes/characters/orphan_tom.tscn")
    actor(sc, "OrphanElsa", "orphan_elsa", (3.7, 0, -5.3), -40.0, model="res://scenes/characters/orphan_elsa.tscn")
    actor(sc, "NeighborHolt", "neighbor_holt", (3.4, 0, 4.0), -90.0, model="res://scenes/characters/neighbor_holt.tscn",
          hide_when_flag="intro_testimony_seen")
    light = actor(sc, "HoltWindowLight", "holt_window_light", (3.92, 1.65, 2.6), hide_when_flag="intro_testimony_seen")
    sc.box(light, "Pane", (0, 0, 0), (0.04, 0.7, 0.8), window_warm)
    sc.node("Glow", "OmniLight3D", light, {"transform": transform((-0.6, 0, 0)), "light_color": color((1.0, 0.7, 0.38)),
                                           "light_energy": "1.4", "omni_range": "4.5", "shadow_enabled": "true"})
    cart = actor(sc, "Handcart", "handcart", (-6.0, 0, 1.0), 0.0, hide_when_flag="intro_lane_open")
    sc.box(cart, "Bed", (0, 0.65, 0), (1.0, 0.35, 1.7), wood)
    sc.box(cart, "Sacks", (0.05, 0.98, 0.2), (0.8, 0.3, 0.9), sacking)
    sc.box(cart, "HandleA", (0.35, 0.6, -1.25), (0.06, 0.06, 1.0), wood_dark, pitch=12.0)
    sc.box(cart, "HandleB", (-0.35, 0.6, -1.25), (0.06, 0.06, 1.0), wood_dark, pitch=12.0)
    sc.cyl(cart, "WheelA", (0.58, 0.38, 0.3), 0.38, 0.08, wood_dark, roll=90.0, segments=12)
    sc.cyl(cart, "WheelB", (-0.58, 0.38, 0.3), 0.38, 0.08, wood_dark, roll=90.0, segments=12)

    cutscene_player(sc, "mira_dawn")
    trigger(sc, "BlanketLilyTrigger", (-1.9, 0.6, -4.6), 1.0, cutscene="mira_finds_empty_spot",
            requires="intro_orphans_talked")
    trigger(sc, "NeighborHoltTrigger", (2.5, 0.6, 4.0), 1.5, cutscene="mira_holt", requires="intro_empty_spot_seen")

    I = "Interactables"
    examinable(sc, "TalkTom", (2.6, 0.8, -4.3), "Tom", verb="talk to", cutscene="mira_talk_tom",
               requires="intro_dawn_seen", sets="intro_orphans_talked", speaker="orphan_tom",
               lines=["Go on, Mira. Look."], radius=1.3)
    examinable(sc, "ElsaBeforeTom", (3.7, 0.8, -5.3), "Elsa", verb="talk to", speaker="orphan_elsa",
               lines=["Tom's been up since dark. Ask him."], requires="intro_dawn_seen", hide_when="intro_orphans_talked",
               radius=1.1)
    examinable(sc, "ElsaBeforeCorner", (3.7, 0.8, -5.3), "Elsa", verb="talk to", speaker="orphan_elsa",
               lines=["Go and look."], requires="intro_orphans_talked", hide_when="intro_empty_spot_seen", radius=1.1)
    examinable(sc, "ElsaAfter", (-0.4, 0.8, -3.7), "Elsa", verb="talk to", speaker="orphan_elsa",
               lines=["Go and find her."], requires="intro_empty_spot_seen", radius=1.1)
    examinable(sc, "MiraBlanket", (-0.2, 0.3, -5.6), "your blanket",
               lines=["Mine. Wool, mostly. I wake if a rat crosses the cobbles."], radius=0.8)
    examinable(sc, "MiraTinSpot", (0.55, 0.3, -5.85), "your tin",
               lines=["Two coppers, a needle, my whittling knife. Everything I own fits in a tin."], radius=0.6)
    examinable(sc, "Lantern", (1.15, 0.4, -6.1), "the lantern",
               lines=["Out of oil. Lily likes it lit. I said tomorrow."], radius=0.6)
    examinable(sc, "ChalkBirds", (-1.1, 0.8, -6.0), "the chalk marks",
               lines=["Lily draws birds on everything. Says they keep watch."], radius=0.7)
    examinable(sc, "BoardedDoor", (0.0, 0.8, -6.4), "the boarded door",
               lines=["The chandler's. He went in the spring. Nobody asked where."], radius=0.6)
    examinable(sc, "LilyShoes", (-1.6, 0.3, -4.5), "Lily's shoes", lines=["Too small for anyone but her."],
               requires="intro_empty_spot_seen", radius=0.7)
    examinable(sc, "Barrel", (-4.6, 0.6, -5.4), "the rain barrel", lines=["Ice on top. First this year."], radius=1.0)
    examinable(sc, "HandcartSpot", (-5.4, 0.6, 1.0), "the handcart", lines=["Not yet."],
               hide_when="intro_lane_open", radius=1.0)
    examinable(sc, "HoltDoor", (3.4, 0.8, 4.0), "Holt's door", lines=["He won't open again. Not for me."],
               requires="intro_testimony_seen", radius=1.0)

    explore_ui(sc)
    return sc


def build_mira_chapel_lane() -> Scene:
    """Chapel Lane (mira_chapel_lane): see game-design/chapter-1-intro.md, Area 2."""
    random.seed(3)
    sc = Scene("MiraChapelLane", "uid://redelka_mira_chapel_lane")
    explore_root(sc, "MiraChapelLane", "mira_chapel_lane")
    environment(sc, ambient=(0.34, 0.38, 0.48), ambient_energy=0.42, fog_color=(0.17, 0.19, 0.23), fog_density=0.06)
    sun(sc, yaw=-160.0, pitch=-18.0, energy=0.22, col=(0.66, 0.72, 0.86))

    cobble = sc.material((0.24, 0.23, 0.22))
    house = sc.material((0.27, 0.25, 0.22))
    house_dark = sc.material((0.2, 0.19, 0.17))
    roof = sc.material((0.14, 0.13, 0.13))
    wood = sc.material((0.27, 0.19, 0.13))
    wood_dark = sc.material((0.17, 0.12, 0.09))
    wall_stone = sc.material((0.25, 0.25, 0.24))
    grave = sc.material((0.33, 0.33, 0.32))
    grave_dark = sc.material((0.22, 0.22, 0.22))
    chapel = sc.material((0.2, 0.19, 0.22))
    glass_cold = sc.material((0.5, 0.55, 0.62), emission=(0.45, 0.52, 0.62), energy=0.6)
    paper = sc.material((0.62, 0.58, 0.5))
    milk = sc.material((0.6, 0.58, 0.52), roughness=0.4)
    scratch = sc.material((0.5, 0.47, 0.42))
    bread = sc.material((0.52, 0.38, 0.22))
    salt = sc.material((0.85, 0.84, 0.8))
    frost = sc.material((0.5, 0.54, 0.6), roughness=0.9)
    print_bare = sc.material((0.14, 0.14, 0.15))
    print_boot = sc.material((0.1, 0.1, 0.11))
    candle = sc.material((0.7, 0.66, 0.55))
    earth = sc.material((0.15, 0.13, 0.11))

    sc.node("Room", "Node3D", ".")
    R = "Room"
    sc.box(R, "Floor", (0, -0.2, 0), (6, 0.4, 28), cobble, collide=True)
    sc.box(R, "Graveyard", (-6.5, -0.21, 0), (7.4, 0.4, 28), earth)
    # Low graveyard wall on the west, split for the lychgate at z = 0.
    sc.box(R, "WallGraveNorth", (-2.75, 0.55, -7.0), (0.45, 1.1, 12.0), wall_stone, collide=True)
    sc.box(R, "WallGraveSouth", (-2.75, 0.55, 7.0), (0.45, 1.1, 12.0), wall_stone, collide=True)
    # Invisible height on top of the low wall so Mira can't climb into the graves.
    sc.blocker(R, "GraveWallBlockN", (-2.75, 2.0, -7.0), (0.45, 2.0, 12.0))
    sc.blocker(R, "GraveWallBlockS", (-2.75, 2.0, 7.0), (0.45, 2.0, 12.0))
    sc.blocker(R, "LychgateBlock", (-3.4, 1.5, 0.0), (0.3, 3.0, 2.0))
    # East side: three house backs.
    for name, z, length, height in (("HouseA", 8.5, 5.0, 4.2), ("HouseB", 2.0, 6.0, 4.6), ("HouseC", -5.5, 7.0, 4.0)):
        sc.box(R, "Wall" + name, (3.9, height * 0.5, z), (2.8, height, length), house, collide=True)
        sc.box(R, "Roof" + name, (3.7, height + 0.15, z), (3.4, 0.3, length + 0.3), roof)
    sc.box(R, "WallGapAB", (3.9, 1.6, 5.5), (2.8, 3.2, 1.0), house_dark, collide=True)
    sc.box(R, "WallGapBC", (3.9, 1.6, -1.5), (2.8, 3.2, 1.0), house_dark, collide=True)
    sc.box(R, "WallNorthEnd", (3.9, 1.6, -11.5), (2.8, 3.2, 5.0), house_dark, collide=True)
    sc.blocker(R, "SouthEdge", (0, 1.5, 13.6), (6.4, 3.0, 0.4))

    props = sc.node("Props", "Node3D", R)
    # Back doors, the marked door and the milk step.
    sc.box(props, "DoorA", (2.47, 1.0, 9.6), (0.06, 2.0, 0.9), wood_dark)
    sc.box(props, "StepA", (2.3, 0.08, 9.6), (0.4, 0.16, 1.0), wall_stone)
    sc.cyl(props, "MilkJug", (2.3, 0.3, 9.25), 0.09, 0.28, milk, top=0.06)
    sc.box(props, "DoorB", (2.47, 1.0, 2.0), (0.06, 2.0, 0.9), wood_dark)
    for i, (dy, roll) in enumerate(((0.0, 0.0), (0.0, 90.0), (0.12, 45.0))):
        sc.box(props, f"DoorMark{i + 1}", (2.43, 1.45 + dy, 2.0), (0.01, 0.34, 0.025), scratch, yaw=0.0, pitch=roll)
    sc.cyl(props, "DoorMarkRing", (2.43, 1.45, 2.0), 0.16, 0.01, scratch, top=0.16, roll=90.0, segments=12)
    sc.box(props, "ShutterLeft", (2.45, 1.9, -5.3), (0.05, 0.9, 0.42), wood)
    sc.box(props, "ShutterRight", (2.45, 1.9, -4.86), (0.05, 0.9, 0.42), wood)
    # Notice board on house A.
    sc.box(props, "NoticeBoard", (2.44, 1.5, 11.0), (0.06, 0.8, 1.0), wood)
    sc.box(props, "Notice", (2.4, 1.48, 10.9), (0.02, 0.42, 0.32), paper, yaw=0.0, pitch=4.0)
    sc.box(props, "NoticeTorn", (2.4, 1.72, 11.2), (0.02, 0.12, 0.2), paper, pitch=-12.0)
    # The well with its cut rope.
    sc.cyl(props, "WellWall", (-1.4, 0.4, 6.8), 0.7, 0.8, wall_stone, collide=True, segments=12)
    sc.cyl(props, "WellPostA", (-2.0, 1.1, 6.8), 0.06, 1.4, wood)
    sc.cyl(props, "WellPostB", (-0.8, 1.1, 6.8), 0.06, 1.4, wood)
    sc.cyl(props, "WellWinch", (-1.4, 1.65, 6.8), 0.08, 1.3, wood_dark, roll=90.0)
    sc.cyl(props, "WellRope", (-1.4, 1.45, 6.8), 0.012, 0.35, sc.material((0.45, 0.4, 0.3)))
    # Lychgate: two posts, a little roof, a gate standing open.
    sc.box(props, "LychPostN", (-2.75, 1.2, -0.95), (0.25, 2.4, 0.25), wood_dark)
    sc.box(props, "LychPostS", (-2.75, 1.2, 0.95), (0.25, 2.4, 0.25), wood_dark)
    sc.box(props, "LychRoofA", (-2.45, 2.6, 0.0), (0.9, 0.08, 2.6), roof, roll=-30.0)
    sc.box(props, "LychRoofB", (-3.05, 2.6, 0.0), (0.9, 0.08, 2.6), roof, roll=30.0)
    sc.box(props, "LychGate", (-3.4, 0.6, -0.4), (0.9, 1.0, 0.05), wood, yaw=-70.0)
    sc.box(props, "Bread", (-2.6, 1.1, 1.05), (0.14, 0.06, 0.1), bread)
    sc.cyl(props, "Salt", (-2.85, 1.08, 1.05), 0.04, 0.03, salt)
    # Graves and the chapel's back wall beyond the low wall.
    for i in range(14):
        gx = -4.2 - random.random() * 4.0
        gz = -11.0 + i * 1.7 + random.random() * 0.6
        if -1.6 < gz < 1.6 and gx > -5.2:
            continue
        lean = random.uniform(-9.0, 9.0)
        sc.box(props, f"Grave{i + 1}", (gx, 0.42, gz), (0.12, 0.85, 0.5), grave if i % 3 else grave_dark,
               yaw=random.uniform(-8, 8), pitch=lean)
    sc.box(props, "ChapelBack", (-9.4, 3.5, -1.0), (2.0, 7.0, 9.0), chapel)
    sc.box(props, "ChapelWindow", (-8.38, 2.6, -1.0), (0.05, 1.4, 0.7), glass_cold)
    for i, dz in enumerate((-0.22, 0.0, 0.2)):
        sc.cyl(props, f"Candle{i + 1}", (-8.25, 1.95, -1.0 + dz), 0.025, 0.06 + 0.03 * i, candle)
    sc.node("ChapelGlow", "OmniLight3D", props, {"transform": transform((-7.6, 2.6, -1.0)),
                                                 "light_color": color((0.55, 0.62, 0.78)), "light_energy": "0.5",
                                                 "omni_range": "4.0"})
    # Frost strip and the footprints near the north end.
    sc.box(props, "Frost", (0, 0.005, -9.8), (5.2, 0.01, 5.0), frost)
    for i in range(6):
        z = -7.8 - i * 0.55
        side = -1 if i % 2 else 1
        sc.box(props, f"BarePrint{i + 1}", (-0.55 + side * 0.09, 0.012, z), (0.07, 0.01, 0.15), print_bare,
               yaw=side * 4.0)
    for i in range(4):
        z = -7.6 - i * 0.95
        side = -1 if i % 2 else 1
        sc.box(props, f"BootPrint{i + 1}", (0.35 + side * 0.13, 0.013, z), (0.12, 0.01, 0.33), print_boot,
               yaw=side * 3.0)
    # Field gate at the north end.
    sc.box(props, "GatePostW", (-1.7, 0.75, -13.3), (0.2, 1.5, 0.2), wood_dark)
    sc.box(props, "GatePostE", (1.7, 0.75, -13.3), (0.2, 1.5, 0.2), wood_dark)

    sc.node("Enemies", "Node3D", ".")
    sc.node("Pickups", "Node3D", ".")
    sc.node("Interactables", "Node3D", ".")
    sc.node("Doors", "Node3D", ".")
    sc.node("Actors", "Node3D", ".")

    camera_rig(sc, "ZoneSouth")
    camera_zone(sc, "ZoneSouth", (0, 0, 8.75), (6, 4, 9.5), (1.0, 3.6, 4.2), (0, 0.6, -7.0))
    camera_zone(sc, "ZoneMid", (0, 0, 0.5), (6, 4, 7.0), (2.0, 2.7, 4.6), (-2.6, 0.9, -1.5), track=0.45)
    camera_zone(sc, "ZoneNorth", (0, 0, -8.5), (6, 4, 11.0), (0.8, 2.0, 8.0), (0, 1.0, -5.0))

    door(sc, "DoorSouthDoorway", (0, 1.2, 13.4), (0, 1.0, 12.6), target="mira_intake_alcove", spawn=(-5.2, 0, 1.0),
         rot_y=math.pi / 2.0, label="the doorway", mat=wood_dark)
    door(sc, "DoorNorthPines", (0, 1.2, -13.4), (0, 1.0, -12.6), target="mira_woods_edge", spawn=(0, 0, 6.0),
         rot_y=math.pi, label="the pines", mat=wood)

    gap = actor(sc, "LaneShutterGap", "lane_shutter_gap", (2.4, 1.9, -5.08), start_hidden=True)
    sc.box(gap, "Light", (0, 0, 0), (0.03, 0.8, 0.06), sc.material((0.9, 0.7, 0.4), emission=(1.0, 0.7, 0.4),
                                                                    energy=1.2))

    cutscene_player(sc, "mira_lane_enter")
    trigger(sc, "ShutterTrigger", (1.0, 0.6, -4.6), 1.4, cutscene="mira_lane_shutter")
    trigger(sc, "FootprintsTrigger", (0.0, 0.6, -8.0), 1.6, cutscene="mira_lane_footprints")

    examinable(sc, "Notice", (1.8, 0.8, 11.0), "the notice",
               lines=["\"Gone since the turning of the month. Any word, to the chapel.\"",
                      "Somebody tore the name off."], radius=1.0)
    examinable(sc, "Well", (-0.5, 0.8, 6.8), "the well", lines=["Rope's cut. Clean, not frayed."], radius=1.0)
    examinable(sc, "MilkJugSpot", (1.8, 0.6, 9.3), "the milk jug", lines=["Yesterday's milk. Nobody took it in."],
               radius=0.8)
    examinable(sc, "DoorMarkSpot", (1.8, 0.8, 2.0), "the door", lines=["Scratched in. Fresh. Not a child's."],
               radius=1.0)
    examinable(sc, "Lychgate", (-2.0, 0.8, 1.1), "the gatepost",
               lines=["Bread and salt. Fresh. Someone's paying the dead to look away."], radius=0.9)
    examinable(sc, "ChapelWindowSpot", (-2.0, 0.8, -1.0), "the chapel window",
               lines=["Candles burned to nothing. Who prays all night?"], radius=0.9)

    explore_ui(sc)
    return sc


def build_mira_woods_edge() -> Scene:
    """Pine Edge (mira_woods_edge): see game-design/chapter-1-intro.md, Area 3."""
    random.seed(11)
    sc = Scene("MiraWoodsEdge", "uid://redelka_mira_woods_edge")
    explore_root(sc, "MiraWoodsEdge", "mira_woods_edge")
    environment(sc, ambient=(0.26, 0.3, 0.38), ambient_energy=0.32, fog_color=(0.2, 0.23, 0.27), fog_density=0.05)
    sun(sc, yaw=180.0, pitch=-12.0, energy=0.2, col=(0.64, 0.7, 0.82))

    grass = sc.material((0.25, 0.27, 0.2))
    frost_grass = sc.material((0.42, 0.46, 0.44))
    needles = sc.material((0.17, 0.13, 0.1))
    path = sc.material((0.24, 0.2, 0.16))
    bark = sc.material((0.07, 0.06, 0.05))
    bark_light = sc.material((0.1, 0.08, 0.07))
    pine = sc.material((0.035, 0.05, 0.04))
    pine_dark = sc.material((0.02, 0.03, 0.025))
    rail = sc.material((0.3, 0.25, 0.18))
    rail_new = sc.material((0.5, 0.42, 0.3))
    stump = sc.material((0.34, 0.26, 0.17))
    stump_top = sc.material((0.52, 0.42, 0.3))
    bird = sc.material((0.66, 0.54, 0.36))

    sc.node("Room", "Node3D", ".")
    R = "Room"
    sc.box(R, "Floor", (0, -0.2, -1.0), (20, 0.4, 22), grass, collide=True)
    sc.box(R, "FrostField", (0, 0.004, 6.0), (20, 0.01, 8.0), frost_grass)
    sc.box(R, "NeedleBed", (0, 0.005, -6.0), (20, 0.01, 10.0), needles)
    sc.box(R, "Path", (0.1, 0.008, 0.0), (1.6, 0.01, 20.0), path)
    sc.blocker(R, "WallWest", (-10.2, 1.5, -1.0), (0.4, 3.0, 22))
    sc.blocker(R, "WallEast", (10.2, 1.5, -1.0), (0.4, 3.0, 22))
    sc.blocker(R, "WallSouth", (0, 1.5, 9.9), (20.4, 3.0, 0.4))
    sc.blocker(R, "TreeLineBlock", (0, 1.5, -3.4), (20.4, 3.0, 0.4))

    props = sc.node("Props", "Node3D", R)
    # Split-rail fence along z = 2 with a gap for the path; the east run has been mended.
    for side, x0 in ((-1, -1.2), (1, 1.2)):
        for i in range(4):
            x = x0 + side * (1.0 + i * 2.0)
            sc.box(props, f"FencePost{'W' if side < 0 else 'E'}{i + 1}", (x, 0.55, 2.0), (0.14, 1.1, 0.14), rail)
        mat = rail if side < 0 else rail_new
        for j, y in enumerate((0.45, 0.85)):
            sc.box(props, f"FenceRail{'W' if side < 0 else 'E'}{j + 1}", (x0 + side * 4.0, y, 2.0), (8.0, 0.08, 0.08),
                   mat, roll=side * 2.0 * (j - 0.5))
    # The stump beside the path, and the wooden bird set on it (an actor, so it can vanish).
    sc.cyl(props, "Stump", (0.5, 0.26, 0.0), 0.3, 0.52, stump, top=0.27, collide=True, segments=9)
    sc.cyl(props, "StumpTop", (0.5, 0.525, 0.0), 0.27, 0.01, stump_top, segments=9)
    # Two rows of close pines, leaving the path line open into the dark.
    trees = []
    for row, z0 in enumerate((-4.2, -6.8, -9.2)):
        x = -9.6
        while x < 9.6:
            if abs(x - 0.3) < 1.1 and row < 2:
                x += 1.3
                continue
            trees.append((x + random.uniform(-0.35, 0.35), z0 + random.uniform(-0.6, 0.6), row))
            x += random.uniform(1.4, 2.1)
    for i, (x, z, row) in enumerate(trees):
        h = random.uniform(7.0, 9.5)
        r = random.uniform(0.18, 0.3)
        name = f"Pine{i + 1:02d}"
        sc.cyl(props, name + "Trunk", (x, h * 0.5, z), r, h, bark if i % 3 else bark_light, top=r * 0.6,
               collide=row == 0, segments=7)
        for k, (y, cr) in enumerate(((h * 0.45, 1.5), (h * 0.65, 1.15), (h * 0.85, 0.7))):
            sc.cyl(props, f"{name}Bough{k + 1}", (x, y, z), cr * random.uniform(0.85, 1.1), h * 0.28,
                   pine if k % 2 == 0 else pine_dark, top=0.05, segments=7)
    # A trunk for the tall man to stand half behind.
    sc.cyl(props, "HidingTrunk", (0.2, 4.5, -6.5), 0.32, 9.0, bark, top=0.2, segments=7)

    sc.node("Enemies", "Node3D", ".")
    sc.node("Pickups", "Node3D", ".")
    sc.node("Interactables", "Node3D", ".")
    sc.node("Doors", "Node3D", ".")
    sc.node("Actors", "Node3D", ".")

    camera_rig(sc, "ZoneField")
    camera_zone(sc, "ZoneField", (0, 0, 5.4), (20, 4, 9.0), (2.4, 2.6, 6.2), (-0.4, 1.0, -9.0))
    camera_zone(sc, "ZoneStump", (0, 0, -1.3), (20, 4, 4.4), (1.3, 1.6, -1.6), (0.0, 0.6, 4.0), track=0.5)

    door(sc, "DoorSouthLane", (0, 1.2, 9.6), (0, 1.0, 8.8), target="mira_chapel_lane", spawn=(0, 0, -11.5),
         rot_y=0.0, label="the lane", mat=rail)

    actor(sc, "TallMan", "tall_man", (0.85, 0, -7.0), 180.0, model="res://scenes/characters/tall_man.tscn",
          start_hidden=True)
    bird_actor = actor(sc, "WoodenBird", "wooden_bird", (0.5, 0.53, 0.0), 180.0, hide_when_flag="intro_bird_found")
    sc.box(bird_actor, "Body", (0, 0.07, 0), (0.1, 0.1, 0.22), bird)
    sc.box(bird_actor, "Head", (0, 0.16, 0.1), (0.08, 0.08, 0.08), bird)
    sc.box(bird_actor, "Beak", (0, 0.16, 0.155), (0.025, 0.025, 0.05), stump)
    sc.box(bird_actor, "Tail", (0, 0.1, -0.14), (0.07, 0.02, 0.1), bird, pitch=-20.0)
    sc.box(bird_actor, "Base", (0, 0.012, 0), (0.12, 0.024, 0.16), stump)

    cutscene_player(sc, "mira_woods_hook")

    examinable(sc, "StumpBird", (0.5, 0.6, 0.0), "the stump", cutscene="mira_finds_bird", requires="intro_tall_man_seen",
               sets="intro_bird_found", lines=["Just a stump now."], radius=1.1)
    examinable(sc, "PineTrunk", (-2.2, 0.8, -3.0), "the pines", lines=["No birds. Not one."], radius=1.2)
    examinable(sc, "MendedFence", (3.0, 0.8, 2.6), "the fence",
               lines=["Somebody's mended it. Recently.", "Which way are they keeping things?"], radius=1.2)
    examinable(sc, "BlockedPath", (0.3, 0.8, -2.9), "the path", lines=["Not alone. Not in the dark."], radius=1.0)

    explore_ui(sc)
    return sc


BUILDERS = {
    "mira_intake_alcove": build_mira_intake_alcove,
    "mira_chapel_lane": build_mira_chapel_lane,
    "mira_woods_edge": build_mira_woods_edge,
}


def main() -> None:
    ids = sys.argv[1:] or list(BUILDERS)
    unknown = [area_id for area_id in ids if area_id not in BUILDERS]
    if unknown:
        raise SystemExit(f"Unknown area ids: {unknown}. Known: {list(BUILDERS)}")
    for area_id in ids:
        path = SCENE_DIR / f"{area_id}.tscn"
        BUILDERS[area_id]().write(str(path))
        print(f"[scenes] wrote {path}")


if __name__ == "__main__":
    main()
