# Next Tasks

Prioritized work after Phase 2 core (exploration handoff, character menu, equipment, pickups, loot drops). See [prototype.md](prototype.md) for current build status.

---

## 1. XP and leveling (progression loop)

**Why now:** Combat drops loot but grants no XP. Victories do not change party power over time, so fights lack long-term payoff.

**Goal:** Wire a minimal progression loop so defeating enemies makes the party stronger.

**Tasks:**

- [ ] Add XP fields to enemy data (`data/enemies.json`) and parse in `EnemyData`
- [ ] Store per-character level and XP on `PartyMemberSnapshot` / `GameState`
- [ ] Award XP on battle victory (alongside existing loot roll in `resolve_battle`)
- [ ] Define level-up curve and placeholder automatic stat growth per character (see [progression.md](progression.md) — hybrid: 4 player points + small auto growth)
- [ ] Apply level-up: recalculate max HP/MP from effective stats via existing `PartyStatsHelper` / derived values
- [ ] Show XP gain and level-up on victory result panel (next to loot lines)
- [ ] Stat allocation UI — extend Status tab or add level-up flow when unspent points remain
- [ ] Persist level/XP in checkpoint save/load
- [ ] Extend `combat_smoke_test.gd` for XP grant and level-up

**References:** [progression.md](progression.md), [attributes.md](attributes.md)

---

## 2. Persistent save/load to disk

**Why now:** All run state is in memory; quitting loses progress. Checkpoint already snapshots the right data.

**Goal:** Save and load the full run from disk so playtests span multiple sessions.

**Tasks:**

- [ ] Serialize checkpoint + session state to `user://` (reuse `ExploreCheckpointData` shape: party, inventory, equipment, defeated enemies, collected pickups, visited areas, level/XP when added)
- [ ] Add save slot path(s) and load on game start / continue from main menu
- [ ] Manual save at existing checkpoint nodes (already press **E** — persist to disk on save)
- [ ] Optional: autosave on room enter (Easy tier preview — see [difficulty-saves.md](difficulty-saves.md))
- [ ] Main menu or explore flow: **Continue** vs **New Game** (reset via existing `reset_party_to_default`)
- [ ] Handle corrupt/missing save gracefully
- [ ] Smoke tests for round-trip save/load

**References:** [difficulty-saves.md](difficulty-saves.md), `scripts/data/explore_checkpoint_data.gd`, `Settings` autoload (`user://settings.cfg` pattern)

---

## 3. Small authored chapter (3–5 rooms)

**Why now:** Pickups, keys, locked doors, drop tables, and map tab exist but only two test rooms exercise them.

**Goal:** A short connected chapter that stress-tests exploration systems and encounter pacing.

**Tasks:**

- [ ] Author 3–5 rooms in `data/areas.json` with scene paths, map layout, and connections
- [ ] Place at least one locked door + key pickup loop (reuse `required_item_id` / `ExplorePickup` pattern)
- [ ] Vary encounters per room (different enemy types, drop tables)
- [ ] Place save checkpoint(s) at authored safe points
- [ ] Add consumable/equipment pickups where appropriate
- [ ] Verify map tab renders chapter layout and state (visited, cleared, current room)
- [ ] Camera zones per room; playtest transitions and door spawn positions
- [ ] Optional: scripted ambush trigger (deferred in [prototype.md](prototype.md) Phase 2)
- [ ] Update [prototype.md](prototype.md) when chapter milestone is done

**References:** [exploration.md](exploration.md), [world.md](world.md)

---

## Suggested order

1. **XP and leveling** — closes the reward loop; makes combat meaningful beyond loot
2. **Persistent save/load** — needed to playtest progression across sessions
3. **Authored chapter** — validates all exploration/content systems together
