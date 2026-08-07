# Character Attributes

Single source of truth for the eight primary attributes, derived values, combat formulas, weapon mastery, and UI exposure. Cross-linked from [combat.md](combat.md), [progression.md](progression.md), and [equipment-economy.md](equipment-economy.md).

## Primary attributes

**Decided:** Eight primary attributes. All characters and design discussions use this set.

| Stat | Abbrev | Role |
|------|--------|------|
| **Strength** | STR | Physical weapon damage — melee and ranged (vs target Vitality); boosted by weapons |
| **Dexterity** | DEX | Physical hit chance; combo chance (with Luck); boosted by weapons |
| **Vitality** | VIT | HP, physical resistance, resist to physical ailments (poison, bleed) |
| **Agility** | AGI | CTB turn frequency; retreat attempts |
| **Intelligence** | INT | Spell damage multiplier (skill tier provides base power) |
| **Mind** | MND | Spell hit chance (vs target Resilience) |
| **Resilience** | RES | MP pool, spell resistance, resist to mental/magic ailments (fear, silence) |
| **Luck** | LUK | Global fudge on many rolls — hit, crit, retreat, combo, drops |

### Not an attribute

| Property | Rule |
|----------|------|
| **Movement range** | Fixed per character identity; **not** altered by base attributes. **Equipment** may modify tile count. See [combat.md](combat.md). |

## Derived values

| Derived | Source | Notes |
|---------|--------|-------|
| **HP** | Vitality (+ gear) | **TBD:** exact formula |
| **MP** | Resilience only | Mind affects spell hit, not pool size |
| **Physical hit %** | Attacker DEX vs defender DEX + LUK + base | Single roll per action; see Physical combat |
| **Spell hit %** | Caster Mind vs target Resilience | See Magic combat |
| **Physical resistance** | Vitality + gear | Stacks with gear; cap **TBD** |
| **Spell resistance** | Resilience + gear | Stacks with gear; cap **TBD** |

**TBD:** Numeric constants, floors/ceilings for hit%, resistance cap percentage.

## Physical combat

### Hit chance

**Decided:**

- Physical hit is a **percentage** check: attacker **Dexterity** vs defender **Dexterity + Luck**, plus a **base hit chance** component.
- **One hit roll per action** — if the attack hits, all combo hits from that action use the same hit result (no per-swing re-roll).

**TBD:** Base hit chance value, min/max hit %, Luck weight on defender side.

### Combo attacks (weapon mastery)

**Decided:**

- Each weapon belongs to a **weapon class** with **mastery levels 1–3** (earned through use — thresholds **TBD**).
- Mastery defines **combo potential** when an attack hits:

| Mastery | Hits per successful attack |
|---------|----------------------------|
| Level 1 | 1 |
| Level 2 | 1 or 2 |
| Level 3 | 1, 2, or 3 |

- **Combo proc chance:** **Dexterity + Luck** (how often multi-hit triggers within mastery band).
- Hit chance is **not** re-rolled per combo hit.

See [Weapon mastery](#weapon-mastery) and [equipment-economy.md](equipment-economy.md).

### Damage

**Decided:**

- Applies to **melee and ranged** physical weapon attacks.
- Damage uses a **rolled range** per weapon/action (e.g. 6–10).
- Core matchup: attacker **Strength** vs defender **Vitality**.
- **Dexterity** does not scale physical damage — it governs hit chance and combo proc only.
- Final value modified by **crits**, **weaknesses**, and **damage type resistances**.

**TBD:** Crit formula (Luck involvement), exact STR/VIT scaling, per-weapon damage ranges.

### Damage types

**Decided:** Internal damage types include at minimum:

- **Physical**
- **Fire**, **cold**, **wind**, **earth** (elemental)
- **Holy**, **darkness**

Gear and skills/spells carry affinity tags; characters have **no innate affinities**. Resistances stack from Vitality (physical) or Resilience (spell) plus gear, up to a **maximum cap (TBD)**. Skill **tier does not affect affinity**.

## Magic combat

Spells use the rules below. **Character-specific skills** are separate; mechanics **TBD** ([progression.md](progression.md)).

### Spell hit

**Decided:** Caster **Mind** vs target **Resilience**.

### Spell damage

**Decided:**

- **Skill tier** sets base spell power (see [progression.md](progression.md)).
- **Intelligence** acts as a **multiplier** on that base.
- **Damage-type affinities** on gear and the spell (fire, cold, wind, earth, holy, darkness, etc.) modify final damage vs target resistances.

**TBD:** INT multiplier curve per tier; MP cost per spell tier.

### MP

**Decided:** Maximum MP derived from **Resilience only**. Mind does not contribute to pool size.

## Status ailments

**Decided:** Resistance split by ailment category.

| Category | Examples | Resisted by |
|----------|----------|-------------|
| **Physical ailments** | Poison, bleed | Vitality (+ gear where applicable) |
| **Mental / magic ailments** | Fear, silence | Resilience (+ gear where applicable) |

**TBD:** Full status list, inflict formulas, Luck role on inflict/resist, duration rules ([combat.md](combat.md)).

## Weapon mastery

**Decided:**

- Weapons are tied to one **weapon class** (e.g. sword, bow — full list **TBD**).
- Mastery levels **1–3** unlocked through **use in combat** (XP thresholds **TBD**).
- Mastery gates **combo potential** only; it does not directly boost raw damage (weapon stats and STR/DEX do).

| Level | Combo behavior |
|-------|----------------|
| 1 | 1 hit on hit |
| 2 | 1–2 hits (DEX + LUK for proc) |
| 3 | 1–3 hits (DEX + LUK for proc) |

**TBD:** Mastery XP per weapon class, whether mastery is per-character or shared, ranged weapon mastery rules.

## Equipment interaction

**Decided:**

- **Weapons** directly **boost primary attributes** (which stats per weapon **TBD**).
- **Armor and accessories** may boost attributes and/or provide **damage-type resistances** and **affinities**.
- **Gear resistances stack** with Vitality (physical) and Resilience (spell) up to a **maximum cap (TBD)**.
- **Equipment may modify movement range** (tiles) without changing base attributes.

Details: [equipment-economy.md](equipment-economy.md).

## Level growth

**Decided:**

| Rule | Value |
|------|-------|
| Player-assigned points | **4 per level** |
| Automatic growth | **Small, fixed, predetermined per character** (archetype curves) |
| Level cap | **99** |
| Expected level for final boss | **~50** (reasonable challenge) |
| Optional content | May require **>50** |
| Stat hard cap | **Yes** — numeric value **TBD** |
| Respec | **Rare consumable** at rest points |
| New recruits | **Individual base stat kit** + **scaled to average party level** on join |

**TBD:** Per-character automatic growth tables, respec item name/rarity, XP curve to level 50 vs 99.

## Enemy attributes

**Decided:**

- Enemies use a **simplified internal stat block** (not the full eight-stat sheet exposed to players).
- **No enemy stat UI** — players do not see STR/DEX/VIT etc. on foes.
- **Design goal:** preserve fear and uncertainty when facing new enemy types; player judges readiness through experience, not stat comparison.

**TBD:** Internal enemy stat schema, whether bosses use hidden “tier” labels in debug only.

## UI exposure

**Decided:**

| Context | What the player sees |
|---------|----------------------|
| **Combat** | Minimal — HP, MP, status effects only |
| **Gear / Equipment screen** | Current stats; **highlighted deltas** when previewing equipment changes |
| **Status menu** | Full tabbed view: 8 primaries, derived stats, weapon mastery levels, etc. |

**TBD:** Tab names, order, whether combo/mastery preview shows proc % or qualitative labels.

## Luck (global fudge)

**Decided:** Luck applies as a **small bonus across many rolls**, including:

- Physical hit (defender side and/or attacker — weight **TBD**)
- Critical hits
- Retreat success (with Agility)
- Combo proc chance (with Dexterity)
- Rare loot / find rolls (**TBD** extent)

Not a dump stat — it touches many systems lightly rather than one dominant role.

## Open questions (TBD)

- Hard cap value per primary stat
- Exact formulas: HP, MP, hit %, STR vs VIT damage, INT multiplier
- Base hit chance and hit % floor/ceiling
- Critical hit formula and crit damage multiplier
- Resistance stack cap (e.g. 75% max)
- Weapon mastery XP thresholds and weapon class list
- Ranged vs melee: same STR/DEX/mastery rules; differentiate via ammo vs durability only
- Whether untreated injury applies temporary stat debuffs (see [combat.md](combat.md))
- CTB Agility formula constants (timeline tick rate)
