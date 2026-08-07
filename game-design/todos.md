# Next Tasks

Prioritized work after Phase 2 core (exploration handoff, character menu, equipment, pickups, loot drops). See [prototype.md](prototype.md) for current build status.

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

**Status (Aug 2026):** JSON saves in `user://saves/` via `SaveManager`; main menu; shared save slot panel; difficulty chosen at New Game.

- [x] Serialize full run state to `user://` (party, inventory, equipment, defeated enemies, collected pickups, visited areas, level/XP, difficulty)
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

## Suggested order

1. **Later:** sanity/fear on Hard, full difficulty-tier parity per [difficulty-saves.md](difficulty-saves.md)
2. **Later:** additional authored chapters, ambush variety, puzzle pipeline
