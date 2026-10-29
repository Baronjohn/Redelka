# Combat

Replaces the former `mechanics.md` placeholder. All rules below are **decided** unless marked **TBD**. Attribute formulas live in **[attributes.md](attributes.md)**.

## Overview

Battles play out on a **shared 5×5 tile grid**. Allies and enemies occupy the same space; positioning is tight and intentional. Combat is **turn-based** with a **CTB (continuous timeline)** driven by **Agility** — faster units act more often; there are no fixed “rounds” where everyone acts once.

## Grid

| Rule | Detail |
|------|--------|
| Size | 5×5, shared by allies and enemies |
| Facing | **No facing.** Only tile occupancy, range, and AoE shapes matter |
| Bosses | May occupy multiple tiles (e.g. 2×2); **TBD** sizing per boss |
| Party size | 1–4 player-controlled characters per battle (story-dependent) |
| Enemy count | **1–4 elite enemies** per encounter |
| Presentation | **3D battleground** with area-matched texture ([prototype.md](prototype.md)) |

## Turn order (CTB)

- Each unit’s **Agility** feeds turn order ([attributes.md](attributes.md)).
- Turn order is **not real-time** — no gauges filling during player input.
- Higher **Agility** → acts **earlier**; sufficiently higher Agility may yield **extra turns** over time (exact formula **TBD**).
- When a unit’s turn arrives, they use the action economy (move + action or wait), then re-enter the order.
- Turn order is **not fixed** and can shift as stats change or effects apply.

Phase 1 behaviour: [prototype.md](prototype.md). **Note:** Phase 1 greybox uses a **6×6** grid for playtest spacing; launch target remains **5×5** unless revised after playtest.

**TBD:** CTB bar UI, initiative queue algorithm, haste/slow effects, tie-breaking

## Action economy (per character turn)

**Decided:** Each turn allows **both movement and one action**, in **either order**, unless the unit **Waits**.

| Main menu | Effect |
|-----------|--------|
| **Move** | Move on grid (range fixed per character; gear may modify) |
| **Action** | Opens submenu: Attack, Spell, Skill, Item, Retreat |
| **Wait** | Skip move **and** action; turn ends |

**Action submenu**

| Option | Effect |
|--------|--------|
| **Attack** | Weapon attack (physical) |
| **Spell** | Cast from global spell pool |
| **Skill** | Character-specific ability ([progression.md](progression.md)) |
| **Item** | Use consumable |
| **Retreat** | Attempt flee (see Retreat) |

**Decided:** **Wait** forfeits both move and action. Move and Action may be taken in either order the same turn. Movement range is **fixed per character** (identity), not Agility-derived. **Equipment** may modify tile count ([attributes.md](attributes.md)).

Phase 1 UI and greybox scope: [prototype.md](prototype.md).

**TBD:**

- Whether Retreat forfeits remaining movement if chosen before moving
- Exact tile counts per character archetype
- Defend and other actions for full game

## Hit model

**Decided:** **Classic RPG** — hit/evade chance plus damage variance; stats reduce but do not eliminate randomness.

### Physical attacks

See [attributes.md — Physical combat](attributes.md#physical-combat):

- **Hit:** attacker DEX vs defender DEX + LUK + base hit chance (one roll per action).
- **Combo:** weapon mastery 1–3 may yield 1 / 1–2 / 1–3 hits; proc chance from DEX + LUK.
- **Damage:** rolled range, STR vs target VIT (melee and ranged); crits, weaknesses, and damage types modify final value.

### Magic attacks

See [attributes.md — Magic combat](attributes.md#magic-combat):

- **Hit:** caster Mind vs target Resilience.
- **Damage:** skill tier base × Intelligence; damage-type affinities (including holy, darkness) from gear/spell vs resistances.

**TBD:**

- Critical hit formula (Luck involved — see attributes doc)
- Friendly fire (if any AoE)
- Full status effect list and durations

## Melee and ranged in combat

| Type | Combat note |
|------|-------------|
| Melee | Uses weapon; consumes **durability** per use; STR vs VIT damage, DEX for hit/combo; weapon boosts stats and weapon-class mastery ([equipment-economy.md](equipment-economy.md), [attributes.md](attributes.md)) |
| Ranged | Uses weapon; consumes **ammo** per shot; STR vs VIT damage, DEX for hit/combo; weapon boosts stats and weapon-class mastery ([equipment-economy.md](equipment-economy.md), [attributes.md](attributes.md)) |
| Magic | **Spells:** global pool, tier + INT damage, MP from Resilience. **Skills:** character-specific — mechanics **TBD** ([progression.md](progression.md), [attributes.md](attributes.md)) |

## KO and treatment

**Decided:**

- At **0 HP**, a character is **KO’d**.
- KO’d allies can be **revived during battle** with items or skills.
- After battle, KO’d or critically injured characters **must be treated** before they are fully functional again (rest, item, or story beat — **TBD**).

**TBD:**

- Penalties while untreated (stat debuff, narrative, blocked skills)
- Whether protagonist KO triggers game over immediately or only on “true” death

## Retreat

**Decided:**

- Player attempts **retreat** from the **Action submenu**.
- Success is **chance-based**, influenced by **Agility** and **Luck** ([attributes.md](attributes.md)).
- **Some fights cannot be retreated from** (bosses, story-mandatory battles).

**TBD:**

- Exact retreat formula and failure consequences (damage, item loss, forced fight)
- Whether retreat is whole-party or per-character
- UI for non-retreat fights

## Enemy design principles

- **Small and elite:** each enemy should threaten the grid, not fill it with fodder.
- **Positional pressure:** AI should exploit the 5×5 (block lanes, focus KO’d targets, zone control).
- **Hidden stats:** enemies use a simplified internal stat block; **no stat sheet shown to the player** ([attributes.md](attributes.md#enemy-attributes)).
- **Ambush encounters:** scripted starts may place enemies or allies at authored positions (**TBD**).

## Solo balance (Chapter 1)

**Decided (Oct 2026):** Mira fights Chapter 1 alone (see [story.md](story.md)), so the hub's encounters are tuned for one knife-fighter. The numbers come from a Monte Carlo pass, `python3 tools/balance_sim.py`, which mirrors the battle rules and plays the hub as a route.

**Targets:**

- **Regular fights** are always winnable and cost about 10–40% HP, so potions and durability matter but no fight is a wall.
- **The Pale Warden** is the chapter's resource check. On the intended route it should be won almost always, at a cost of one or two potions.
- **Skipping preparation hurts.** Skipping the cellar (chain mail, an extra level) cuts the boss win rate to about 70–75%. Walking into the chapel fresh is effectively a loss, and Mira's warning line tells the player to come back later.
- **Debuffs stay small.** Howl and Wail stack permanently for the whole battle, so with no party to carry her a −3 per use spiralled Mira down to 1 damage. Chapter 1 debuffs are −1, and the Warden's is −2.
- **One or two enemies per fight** while Mira is alone (the global rule allows 1–4).

**Changes:**

| | Before | After |
|---|---|---|
| Hollow | HP 45, VIT 8, Claw 5–9, Howl 25% −3 | HP 38, VIT 6, Claw 10–14, Howl 20% −1 |
| Wretch | HP 38, VIT 6, Scratch 4–8, Howl 20% −2 | HP 30, VIT 5, Scratch 7–11, Howl 15% −1 |
| Shade | HP 40, VIT 7, Bolt 6–10, Wail 35% −3 | HP 32, VIT 5, Bolt 8–12, Wail 25% −1 |
| Pale Warden | HP 95, DEX 9, VIT 12, Crush 9–14, Howl 30% −3 | HP 180, DEX 12, VIT 8, Crush 25–31, Backhand 18–23, Howl 20% −2 |
| Cellar Guard | Hollow | Hollow + Wretch (it guards the chain mail) |
| Granary | 6 arrows | **Skinning Knife** (dagger, durability 40). The rusty dagger's 30 uses cannot cover the chapter alone. |
| Chapel | — | A one-time warning on entry (`mira_chapel_warning`) while the Warden lives |

**Simulated results (Normal):**

| Fight | Win | Avg. damage taken | Mira's attacks |
|---|---|---|---|
| Square Scuffle (L1) | 100% | 12 | 5 |
| Closet Ambush (L1, no retreat) | 100% | 27 | 12 |
| Granary Patrol (L1) | 100% | 40 | 12 |
| Loft Ambush (L2) | 100% | 9 | 7 |
| Cellar Guard (L2) | 100% | 11 | 7 |
| Pale Warden (L3, intended route) | ~99% | 130 (~1.4 potions) | 27 |
| Pale Warden (L1, fresh) | ~0% | — | — |

**TBD:** Per-difficulty scaling (see [difficulty-saves.md](difficulty-saves.md)). The legacy `test_*` encounters are left untouched for the smoke tests.

## Combat ↔ exploration link

- Battles begin from **visible overworld enemies** or **scripted ambushes** (see [exploration.md](exploration.md)).
- **Phase 2** implements the full handoff; rules in [prototype.md](prototype.md#phase-2--exploration-and-combat-handoff).
- **Room respawn** can restore farmable enemies after leaving and re-entering an area (see [equipment-economy.md](equipment-economy.md)).

## Open questions (TBD)

- Grid camera: fixed angle per fight vs. rotatable view
- Transition animation from exploration to combat
- Whether CTB pauses for player menu or runs in real time
