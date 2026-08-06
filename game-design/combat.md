# Combat

Replaces the former `mechanics.md` placeholder. All rules below are **decided** unless marked **TBD**.

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

## Turn order (CTB)

- Each unit has an **Agility** stat that feeds the timeline.
- When a unit’s turn arrives, they take **one turn**, then re-enter the timeline based on Agility (exact formula **TBD**).
- Turn order is **not fixed** and can shift as stats change or effects apply.
- **TBD:** CTB bar UI, haste/slow effects, tie-breaking

## Action economy (per character turn)

On a character’s turn they may use **movement and one action**, in **either order**:

1. Move, then act — or —
2. Act, then move

**Additional options:**

| Option | Behavior |
|--------|----------|
| **Wait** | Skip movement and action; re-enter timeline (benefit **TBD**, e.g. CTB bonus) |
| **Retreat** | Attempt to flee the battle (see Retreat) |

**Decided:** Movement range is **fixed per character** (identity stat), not uniform and not Agility-derived for distance.

**TBD:**

- Exact tile counts per character archetype
- Whether “move” is optional (can act without moving)
- Action types: Attack, Skill, Item, Defend, etc.

## Hit model

**Decided:** **Classic RPG** — hit/evade chance plus damage variance; stats reduce but do not eliminate randomness.

**TBD:**

- Hit/evade formulas
- Critical hit rules
- Damage types and resistances
- Friendly fire (if any AoE)

## Melee and ranged in combat

| Type | Combat note |
|------|-------------|
| Melee | Uses weapon; consumes **durability** per use (see [equipment-economy.md](equipment-economy.md)) |
| Ranged | Uses weapon; consumes **ammo** per shot |
| Magic | Skills unlocked via progression; level through use (see [progression.md](progression.md)) |

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

- Player can attempt **retreat** as a turn option.
- Success is **chance-based**, influenced by **Agility** and **Luck** (and possibly other factors).
- **Some fights cannot be retreated from** (bosses, story-mandatory battles).

**TBD:**

- Exact retreat formula and failure consequences (damage, item loss, forced fight)
- Whether retreat is whole-party or per-character
- UI for non-retreat fights

## Enemy design principles

- **Small and elite:** each enemy should threaten the grid, not fill it with fodder.
- **Positional pressure:** AI should exploit the 5×5 (block lanes, focus KO’d targets, zone control).
- **Ambush encounters:** scripted starts may place enemies or allies at authored positions (**TBD**).

## Combat ↔ exploration link

- Battles begin from **visible overworld enemies** or **scripted ambushes** (see [exploration.md](exploration.md)).
- **Room respawn** can restore farmable enemies after leaving and re-entering an area (see [equipment-economy.md](equipment-economy.md)).

## Open questions (TBD)

- Grid camera: fixed angle per fight vs. rotatable view
- Transition animation from exploration to combat
- Status effect list and duration rules
- Whether CTB pauses for player menu or runs in real time
