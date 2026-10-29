# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Redelka is a Godot 4.7 (GDScript 2.0) folk-horror game. It combines fixed-camera 3D exploration with grid-based CTB (charge-time) tactical combat and a data-driven narrative layer. The main scene is `scenes/menu/main_menu.tscn`.

## Commands

```bash
# Run the game
godot --path .

# Headless smoke tests (exit code 0 = pass, 1 = fail; failures go to push_error)
godot --headless --path . --script res://scripts/test/combat_smoke_test.gd
godot --headless --path . --script res://scripts/test/narrative_smoke_test.gd

# Regenerate procedural audio (needs ffmpeg; writes .ogg into assets/audio/{bgm,sfx}); pass ids to limit
python3 tools/generate_bgm.py [intro_dawn intro_lane ...]
python3 tools/generate_sfx.py [bell_toll ...]

# Regenerate character/enemy models (needs Blender 4.2+; writes assets/models/<id>.glb), then reimport
blender --background --factory-startup --python tools/generate_models.py [-- bran hollow ...]
godot --headless --path . --import

# Regenerate the Chapter 1 intro explore scenes (writes scenes/explore/<area_id>.tscn), then reimport
python3 tools/generate_scenes.py [mira_chapel_lane ...]

# Monte Carlo balance check of the Chapter 1 fights for a solo Mira (reads data/*.json)
python3 tools/balance_sim.py [data_dir] [runs]

# Render every model (front, side, back, close-ups) to PNGs for a visual check
godot --path . res://scenes/tools/character_preview.tscn [-- <output_dir>]
```

There's no test framework. Each smoke test is an `extends SceneTree` script whose `_initialize()` runs a list of `_test_*()` functions, each returning a `PackedStringArray` of errors. To run one test case, comment out the others in `_initialize()`. When you change data files or system behavior, extend the matching smoke test. The tests assert on concrete data (for example, character and enemy counts and setup loadouts), so changes to `data/*.json` can break them.

## Architecture

### Data-driven content
Almost all content lives in `data/*.json`: characters, enemies, weapons, spells, skills, items (consumables, keys and ammo), encounters, areas, formation, progression, the new-game setup, audio and debug values, plus the narrative files `cutscenes.json`, `dialogs.json` and `actors.json`. `DataLoader` (`scripts/data/data_loader.gd`, a static `class_name`) parses these files into typed `RefCounted` classes in `scripts/data/`. Each class has a `static func from_dict()`, for example `WeaponData` and `EnemyData`. To add content, edit the JSON. You only need to change the loader or data classes when you add a new field.

### Autoloads (see `project.godot`)
- **GameState**: the single source of truth for runtime state. It holds the party (a new game starts with Mira alone; `add_party_member()` recruits), inventory, equipment, durability and ammo, story flags, defeated enemies and collected pickups, and the current or return area. It also builds save payloads and bridges explore and battle (`battle_source`, `return_area_id`/`return_position`, `last_battle_*`).
- **SceneTransition**: scene changes with a fade (`go_to_battle`, `go_to_explore`, `go_to_main_menu`). `go_to_explore()` resolves the target area. A new game goes to the Mira intro (`mira_intake_alcove`) until `chapter1_intro_seen` is set.
- **NarrativeDirector**: runs cutscenes as step lists from `cutscenes.json`. Step types include camera cut/blend, actor move/face/say, dialog, fade, `goto_area`, sfx, music and `hand_control_back`. It also runs branching dialogs from `dialogs.json` and stores story flags in `GameState`. Scene-side helpers live in `scripts/narrative/`; for example, `NarrativeTrigger` is an Area3D gated on flags, and `ExploreExaminable` (`scripts/explore/`) is a press-E examine point.
- **MusicManager / SfxManager / AudioSettings**: track and SFX ids are mapped to files in `data/audio.json`.
- **Settings**: saves to `user://settings.cfg`. **DebugSettings**: lighting and battle-speed values from `data/debug.json`.
- **Saves**: `SaveManager` (`scripts/data/save_manager.gd`) writes JSON slots and an autosave under `user://saves/`.

### Exploration (`scripts/explore/`, `scenes/explore/`)
Each area scene has an `ExploreController` with an `area_id` export that matches a row in `data/areas.json`. That row gives the scene path, spawns, map layout, enemies and pickups. At runtime the controller spawns the protagonist, overworld enemies and pickups. It also wires doors, checkpoints and closets, and opens the character menu (I) and the save panel. `CameraZone` areas drive the fixed-camera `CameraRig`. Touching an overworld enemy snapshots state into `GameState` and calls `SceneTransition.go_to_battle()`. The `test_room` and `adjacent_room` areas are legacy rooms kept for the smoke tests.

### Battle (`scripts/battle/`, `scenes/battle/battle.tscn`)
`BattleController` orchestrates a battle on `BattleGrid` (a logical grid with a 3D tile presentation). `TurnQueue` handles CTB order, `CombatResolver` handles hit and damage math, `EnemyAI` picks enemy actions from weighted action tables (chances must total 100), and `CombatUnit` holds unit state while `UnitView` draws it. The encounter definition sets the units and their starting positions. After victory, retreat or defeat, control returns to explore through `GameState` and `SceneTransition`.

### Visuals
Characters and enemies are skinned low-poly `.glb` models generated by a Blender script: `tools/generate_models.py` holds the designs, and `tools/model_kit.py` holds the mesh lofting, texture atlas, armature, animation baking and export. Every model shares one humanoid skeleton and the clips `idle`, `walk`, `attack`, `chant` and `chant_release`. Change a model by editing the generator, not the output. `assets/models/source/` holds the matching `.blend` file and atlas for inspection, and Godot ignores that folder. The scenes in `scenes/characters/` and `scenes/enemies/` (referenced by `model_path` in the data) wrap each `.glb` with `CharacterModel` (`scripts/assets/characters/character_model.gd`). `CharacterModel` plays the clips and swaps materials for the turn-highlight and KO states. Environment and battle materials come from `scripts/assets/*_materials.gd`.

## Design docs

`game-design/` is the design spec, with `README.md` as its index. `prototype.md` tracks what is implemented in each phase, and `todos.md` lists the next tasks. In these docs, **Decided** items are authoritative, and **TBD** items must not be filled in with assumed values during implementation. When you implement a feature, update `prototype.md` and `todos.md`. Doc filenames are lowercase with hyphens.

## Code conventions (from `.cursor/rules/godot.mdc`)

- Use strict static typing throughout. Use Godot 4 syntax only: `await`, `signal.emit()`, `signal.connect(callable)`, `@export`/`@onready`, `instantiate()`, `FileAccess`.
- Naming: snake_case for files, functions and signals; PascalCase for classes and nodes; CONSTANT_CASE for constants and enums. Write boolean logic with `and`/`or`/`not`.
- Call down, signal up. Prefer composition, and use static classes over autoloads unless node lifecycle is needed.
- Scripts often `preload()` other scripts into constants (`const FooScript = preload(...)`) instead of relying on `class_name`. Follow the existing pattern in the file you're editing.
- Keep the `.gd.uid` files next to their scripts and commit them together.

More detailed GDScript guidance is in `.cursor/skills/godot/` (SKILL.md and its references).
