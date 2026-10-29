# Next Tasks

Prioritized work after Phase 2.5 (narrative runtime + Chapter 1 Mira-only intro). See [prototype.md](prototype.md) for current build status.

---

## 1. XP and leveling (progression loop) — done

**Status (Aug 2026):** Implemented in `GameState` progression API, post-combat Level Up panel, read-only Status tab, and save/load persistence.

- [x] Add XP fields to enemy data (`data/enemies.json`) and parse in `EnemyData`
- [x] Store per-character level and XP on `PartyMemberSnapshot` / `GameState`
- [x] Award XP on battle victory (alongside existing loot roll in `resolve_battle`)
- [x] Define level-up curve and placeholder automatic stat growth per character
- [x] Apply level-up: recalculate max HP/MP from effective stats via `PartyStatsHelper`
- [x] Show XP gain and level-up on victory result panel
- [x] Stat allocation UI — Level Up panel with confirm-when-fully-allocated flow
- [x] Persist level/XP in disk save/load
- [x] Extend `combat_smoke_test.gd` for XP grant and level-up

**References:** [progression.md](progression.md), [attributes.md](attributes.md)

---

## 2. Persistent save/load to disk — done

**Status (Aug 2026):** JSON saves in `user://saves/` via `SaveManager`; main menu; shared save slot panel; difficulty chosen at New Game. Round-trip covers `protagonist_character_id`, `story_flags`, and `chapter1_intro_seen` added in Phase 2.5.

- [x] Serialize full run state to `user://` (party, inventory, equipment, defeated enemies, collected pickups, visited areas, level/XP, difficulty, **protagonist, story flags, intro seen**)
- [x] Save slot paths (`slot_01`–`slot_99`) and autosave (`autosave.json`); load from main menu
- [x] Manual save at checkpoint nodes (press **E** → save slot panel with overwrite confirm)
- [x] Autosave on door transition (**Easy** only; overwrites single autosave slot)
- [x] Main menu: **New Game** (difficulty picker), **Load Game**, Config, Quit
- [x] Defeat flow: Load Save, Load Autosave (Easy), Main Menu — session checkpoint respawn removed
- [x] Save slot list shows area, level, difficulty, and timestamp
- [x] Smoke tests for round-trip save/load, autosave rules, and slot metadata
- [x] Handle corrupt save files gracefully (corrupt/invalid slots labeled; load/save errors shown in UI)
- [x] Hard-tier save resource consumption at save points (`memory_tape` item; see [difficulty-saves.md](difficulty-saves.md))

**References:** [difficulty-saves.md](difficulty-saves.md), `scripts/data/save_manager.gd`, `Settings` autoload (`user://settings.cfg` pattern)

---

## 3. Small authored chapter (3–5 rooms) — done

**Status (Aug 2026):** Chapter 1 "The Hollowed Village" — 5-room hub layout with closet ambush key loop, locked cellar, mini-boss, checkpoints, and map tab layout.

- [x] Author 3–5 rooms in `data/areas.json` with scene paths, map layout, and connections
- [x] Place at least one locked door + key pickup loop (reuse `required_item_id` / `ExplorePickup` pattern)
- [x] Vary encounters per room (different enemy types, drop tables)
- [x] Place save checkpoint(s) at authored safe points
- [x] Add consumable/equipment pickups where appropriate
- [x] Verify map tab renders chapter layout and state (visited, cleared, current room)
- [x] Camera zones per room; playtest transitions and door spawn positions
- [x] Optional: scripted ambush trigger — closet in Weaver's Cottage (`ExploreCloset`)
- [x] Update [prototype.md](prototype.md) when chapter milestone is done

**References:** [exploration.md](exploration.md), [world.md](world.md)

---

## 4. Narrative runtime + Chapter 1 Mira-only intro — done

**Status (Aug 2026):** Reusable cutscene/dialog runtime shipped; Mira-only vertical slice plays end-to-end from new game to free explore in `village_square`. Owen/Bran/Elara intro vignettes deferred to Chapter 1.5.

- [x] `NarrativeDirector` autoload with cutscene step executor + dialog runner + busy flag
- [x] `CutscenePlayer`, `NarrativeActor`, `NarrativeTrigger` scripts and `DialogUI` scene
- [x] `data/cutscenes.json`, `data/dialogs.json`, `data/actors.json` content
- [x] `mira_intake_alcove.tscn` + `mira_woods_edge.tscn` scenes
- [x] Explore protagonist swapped to Mira via `GameState.protagonist_character_id`
- [x] `GameState.story_flags` + `chapter1_intro_seen` + `busy_narrative`; serialized in save/load
- [x] `SceneTransition.go_to_explore` routes new games to `INTRO_AREA_ID` until intro seen
- [x] Smoke tests in `scripts/test/narrative_smoke_test.gd`
- [x] Doc updates: [story.md](story.md), [presentation.md](presentation.md), [prototype.md](prototype.md)

**References:** [story.md](story.md), [presentation.md](presentation.md#narrative-delivery--implementation)

---

## 4a. Chapter 1 intro expansion — done

**Status (Oct 2026):** The intro is now an 8–12 minute prologue (doorway → Chapel Lane → Pine Edge). See [chapter-1-intro.md](chapter-1-intro.md).

- [x] Full script: cutscenes, dialogs with flagged flavour choices, examine lines
- [x] `ExploreExaminable`, on-screen objective, subtitles and gothic title cards, `play_cutscene` / `set_objective` / `give_item` / `party_join` steps
- [x] New area `mira_chapel_lane`; alcove and woods rebuilt
- [x] Dedicated intro music and SFX
- [x] Party starts with Mira only; recruits join through `GameState.add_party_member()`
- [ ] Rebalance the post-intro Chapter 1 hub for a solo Mira (or place recruitment before it). Its encounters were tuned for four allies, and the chapel's Pale Warden + Shade fight has no retreat.
- [ ] Encounter `spell_unlocks` for characters not yet in the party are skipped. Decide whether to defer them until the character joins.

## 4b. Character and enemy models — done

**Status (Oct 2026):** The procedural box/lathe models are replaced by Blender-generated, skinned low-poly models (“modern PS1”: ~1.7–2.9k tris, vertex colours + small pixel atlas).

- [x] `tools/generate_models.py` + `tools/model_kit.py`: reproducible Blender pipeline (mesh, atlas, armature, clips, `.glb` export)
- [x] Survivors: Bran, Mira, Owen, Elara; enemies: Hollow, Wretch, Shade, Pale Warden
- [x] `CharacterModel` wrapper used by battle `UnitView`, explore protagonist, overworld enemies and narrative actors
- [x] Overworld enemies show their encounter's first enemy (previously every overworld enemy rendered as a Hollow)
- [x] Smoke test checks every model scene loads with all clips and a plausible height
- [x] Dedicated models for the narrative NPCs: Tom, Elsa, Mr. Holt and the tall man (Oct 2026)

---

## 5. Weapon durability & ammo

**Why now:** Closes a documented resource-pressure mechanic that ties into the "enemy avoidance" horror pillar ([exploration.md](exploration.md)); currently weapons are permanent/infinite.

**Goal:** Melee weapons track durability and break at 0; ranged weapons consume ammo from inventory and are unusable when empty.

**Tasks:**

- [x] Add `durability_max` (melee) / `ammo_item_id` (ranged) fields to `data/weapons.json`; parse in `scripts/data/weapon_data.gd`
- [x] Track current durability per equipped weapon (new per-character state, since `owned_equipment` only counts by id today)
- [x] Consume 1 durability or 1 ammo per weapon attack in `scripts/battle/battle_controller.gd`
- [x] On break/empty: unequip weapon, fall back to unarmed stats, log a battle message; disable ranged attack option in `battle_ui.gd` when ammo is empty
- [x] Add ammo/durability-repair pickups to explore data (`data/items.json`, `data/areas.json`)
- [x] Show durability/ammo counts in `scripts/menu/tabs/equipment_tab.gd`
- [x] Persist durability/ammo in save data (`GameState.to_save_state_dict` / `apply_save_dict`, `SaveManager`)
- [x] Extend `combat_smoke_test.gd` for break-on-zero-durability and ammo depletion

**References:** [equipment-economy.md](equipment-economy.md), [attributes.md](attributes.md#weapon-mastery), `scripts/data/weapon_data.gd`, `scripts/battle/battle_controller.gd`

---

## 5. Weapon mastery & combo system

**Why now:** Attributes doc locks a combo system (mastery levels 1–3 → 1/1–2/1–3 hits, DEX+LUK proc, no hit re-roll) that combat currently skips entirely (single hit only).

**Goal:** Weapon-class mastery grows through use and unlocks multi-hit combos on successful physical attacks.

**Tasks:**

- [x] Decide and document mastery scope (per-character vs. shared per weapon class) — default to per-character unless revised
- [x] Add mastery level + use-XP tracking (e.g. `PartyMemberSnapshot.weapon_mastery: Dictionary` keyed by weapon class)
- [x] Add placeholder mastery XP thresholds in a new `scripts/data/mastery_constants.gd` (mirrors `progression_constants.gd` pattern)
- [x] Award mastery XP on weapon attacks in `scripts/battle/combat_resolver.gd` / `battle_controller.gd`
- [x] Implement DEX+LUK combo proc roll and apply 1–3 hits per successful attack (no re-rolling the original hit chance)
- [x] Surface mastery level in Status tab / equipment tab; show combo hit count in the battle log (e.g. "Bran hits Wretch x2!")
- [x] Persist mastery levels/XP in save data
- [x] Extend `combat_smoke_test.gd` for mastery XP gain and combo resolution
- [x] Per-character spell tiers (0=locked, 1–3), unlock rewards, tier-scaled power/MP, and battle integration

**References:** [attributes.md](attributes.md#weapon-mastery), [progression.md](progression.md#weapon-mastery), `scripts/battle/combat_resolver.gd`, `scripts/data/progression_constants.gd`

---

## Suggested order

1. **Owen / Bran / Elara intro vignettes (Chapter 1.5)** — finishes the "before the party forms" beats from [story.md](story.md#chapter-15--the-four-placeholder); uses the existing `NarrativeDirector` runtime.
2. **Authored chapters 2–N** — expand exploration + combat encounters beyond Chapter 1 hub.
3. **Sanity / fear on Hard** — close difficulty-tier parity gap per [difficulty-saves.md](difficulty-saves.md).
4. **Banter triggers per rest point** — fill out `rest_point_dialog` per chapter.
5. **Voice acting scope** — text-only v1; revisit when art + audio budget allows.
6. **Ambush variety, puzzle pipeline** — additional scripted triggers, environmental puzzles.
