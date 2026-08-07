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

Phase 1 behaviour: [prototype.md](prototype.md).

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

## Combat ↔ exploration link

- Battles begin from **visible overworld enemies** or **scripted ambushes** (see [exploration.md](exploration.md)).
- **Phase 2** implements the full handoff; rules in [prototype.md](prototype.md#phase-2--exploration-and-combat-handoff).
- **Room respawn** can restore farmable enemies after leaving and re-entering an area (see [equipment-economy.md](equipment-economy.md)).

## Open questions (TBD)

- Grid camera: fixed angle per fight vs. rotatable view
- Transition animation from exploration to combat
- Whether CTB pauses for player menu or runs in real time
