# Progression

## Character attributes

**Decided:** Full attribute system documented in **[attributes.md](attributes.md)** — eight primaries (STR, DEX, VIT, AGI, INT, MND, RES, LUK), physical/magic formulas, weapon mastery, and UI rules.

Summary of growth rules (detail in attributes doc):

| Rule | Value |
|------|-------|
| Allocation | **Hybrid:** 4 player points per level + small automatic growth per character |
| Level cap | 99 (~50 expected for final boss) |
| Respec | Rare consumable at rest points |
| New recruits | Individual base kit + scaled to average party level on join |

## Spells and skills

Progression treats **spells** and **skills** as separate systems.

### Spells (global pool)

**Decided:**

- **All characters share one global spell pool** — unlock once, available to the whole party (any character who can cast may equip/use an unlocked spell; loadout rules **TBD**).
- **Every spell must be unlocked** before use — e.g. story progress, defeating specific foes, finding key items, or other authored triggers (**TBD** per spell).
- Unlocks are **not** bought from shops; discovery and progression gate the pool.
- Once unlocked, a spell earns **XP through use** in battle.
- Spells **level a capped number of times**, unlocking **stronger tiers** (e.g. tier 1 → tier 2 → tier 3).
- **Spell damage:** tier sets base power; **Intelligence** is the multiplier ([attributes.md](attributes.md)).
- **MP pool:** from **Resilience** only; **Mind** affects spell hit.

**TBD:**

- Max tier per spell and XP thresholds
- MP cost per spell, cooldowns, or CTB-based cast delay
- Full-game per-character spell slot limits (v0: all unlocked spells usable — [prototype.md](prototype.md))
- Full unlock trigger list per spell

### Skills (character-specific)

**Decided:**

- **Skills are per character** — not part of the global spell pool.
- Each playable character has their own skill set (identity, kit, or class flavor).

**TBD:**

- How skills are acquired (innate, level-up, story, etc.)
- Whether skills use MP, consume turns only, have cooldowns, or differ from spells mechanically
- Skill leveling (use-XP like spells, fixed tiers, or no growth)
- Relationship to weapon arts, items, or grid actions

## Weapon mastery

**Decided:** Separate from spell tiers — **weapon class mastery** levels 1–3 unlock combo potential (1 / 1–2 / 1–3 hits). Earned through weapon use. See [attributes.md](attributes.md#weapon-mastery).

**TBD:** Mastery XP thresholds, full weapon class list.

## Roster and party selection

**Decided:**

| Dimension | Rule |
|-----------|------|
| Total cast | 5–7 playable characters |
| Battle party | 1–4 members |
| Selection | Story locks composition in key moments; otherwise player chooses lineup |

**TBD:**

- When recruitment happens per chapter
- Whether benched characters gain XP
- Guest characters or temporary allies

## Progression ↔ equipment

- Power also comes from **rare gear** (fixed drops, secrets, farming) — see [equipment-economy.md](equipment-economy.md).
- **Weapons boost primary attributes** and tie to weapon classes for mastery.
- Gear is **scavenge-only**; no shops. Progression must not assume buying upgrades.

## Progression ↔ difficulty

- Save rules and optional **sanity system on Hard** may affect effective progression pressure — see [difficulty-saves.md](difficulty-saves.md).

## Open questions (TBD)

- New Game+ and carry-over rules
- Achievement/meta progression (if any)
- Respec consumable item design (name, rarity, one-time vs. stackable)
