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

### Spells (per character)

**Decided:**

- **Spell unlock and tier progression are per character** — each ally tracks their own spell tiers independently.
- **Tier 0 = locked** — spells must be unlocked via story progress, encounter victory rewards, or other authored triggers before use.
- Unlocks are **not** bought from shops; discovery and progression gate access.
- Once unlocked (tier 1), a spell earns **+40 XP per use** in battle (on unleash resolve, hit or miss).
- Spells advance to **tier 3 max** with per-step thresholds: **1000 XP** (T1→T2), **2000 XP** (T2→T3).
- **Higher tiers** increase both **base power** and **MP cost** (see `scripts/data/mastery_constants.gd`).
- **Spell damage:** tier sets scaled base power; **Intelligence** is the multiplier ([attributes.md](attributes.md)).
- **MP pool:** from **Resilience** only; **Mind** affects spell hit.
- **v0:** All unlocked spells for a character appear in battle (no equip slot limit yet).

**TBD:**

- Cooldowns or CTB-based cast delay beyond existing delayed cast
- Full unlock trigger list per spell across all chapters
- Per-character spell slot limits (full-game loadout rules)

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

**Decided:** Separate from spell tiers — **weapon class mastery** levels 1–3 unlock combo potential (1 / 1–2 / 1–3 hits). Earned through weapon attacks (+40 XP per resolve). Per-character; starts at level 1 in all classes (`sword`, `bow`, `staff`, `dagger`). Level thresholds: **1000 XP per level**. See [attributes.md](attributes.md#weapon-mastery).

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
