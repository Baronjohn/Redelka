# Equipment and Economy

## Economy model

**Decided:** **Scavenge-only.** No currency, no shops, no vendors.

- Items are found in the environment, on enemies, in containers, or as fixed/secret rewards.
- Player manages **inventory limits** (**TBD** — slot count, weight, etc.).

## Weapons and attributes

**Decided:** See [attributes.md](attributes.md) for full rules.

- **Weapons directly boost primary attributes** (which stats per weapon type **TBD**).
- Each weapon belongs to one **weapon class** (e.g. sword, bow — list **TBD**).
- **Weapon class mastery** (levels 1–3) is earned through use; unlocks combo potential on physical attacks.
- **Equipment may modify movement range** (grid tiles) without changing base attributes.

## Melee weapons

**Decided:**

- Each melee weapon has **durability** defined by the item.
- Using the weapon in combat **reduces durability**.
- At **0 durability**, the weapon **breaks** and is removed or unusable until replaced/repaired (**TBD** repair rules).
- Mastery and combo behavior: [attributes.md — Weapon mastery](attributes.md#weapon-mastery).

**TBD:**

- Whether repair is possible at rest points with items
- Broken weapon salvage
- Durability cost per action (always 1 vs. heavy attacks costing more)

## Ranged weapons

**Decided:**

- Ranged weapons require **ammo** per shot (counterbalance to melee durability).
- Ammo is a **scavenged consumable** type tied to weapon category.
- Attribute boosts and mastery rules apply to ranged weapons the same as melee (STR damage, DEX hit/combo).

**TBD:**

- Ammo types and stack sizes
- Whether melee can use throwable consumables as ranged alternative

## Other equipment

**Decided:**

- Armor, accessories, and special gear are **quite rare**.
- Sources:
  - **Fixed drops** (guaranteed progression checks)
  - **Secret items** (optional power, exploration reward)
  - **Farmable** via respawning encounters to help players reach **expected power for a chapter stage**
- Gear may provide **damage affinities** and **resistances** (physical, fire, cold, wind, earth, holy, darkness).
- **Resistances stack** with Vitality (physical) and Resilience (spell) from [attributes.md](attributes.md), up to a **maximum cap (TBD)**.
- Characters have **no innate affinities** — only from gear and skills/spells.

**TBD:**

- Equipment slots (weapon, body, accessory, etc.)
- Set bonuses or unique passive effects
- Chapter-by-chapter power budget table

## Consumables

**Decided (implicit from other docs):**

- Healing and revival items exist for combat KO.
- Post-battle **treatment** may require specific items or rest (**TBD**).
- On **Hard**, a **save resource** is consumed to save — see [difficulty-saves.md](difficulty-saves.md).
- **Respec consumable** (rare) allows stat reallocation at rest points — see [attributes.md](attributes.md).

**TBD:**

- Full consumable list and rarity
- Crafting/combining items or strictly found loot

## Farming and respawn

**Decided:** **Room respawn** — enemies (and thus loot opportunities) return when **re-entering** an area/room after a defined condition.

- Supports optional farming without random encounters.
- Visible enemies in the world respawn in place or on a timer (**TBD**).

**TBD:**

- Exact respawn trigger (leave room, leave chapter, rest at save point)
- Whether bosses or unique enemies respawn
- Drop tables vs. fixed drops for farm targets

## Rarity tiers (suggested framework — confirm)

| Tier | Role |
|------|------|
| Common | Consumables, ammo, low-tier weapons with short durability |
| Uncommon | Standard chapter gear, reliable tools |
| Rare | Fixed drops, meaningful build choices |
| Secret | Optional exploration; can skip but rewards mastery |
| Unique | One-of-a-kind; story or boss linked |

**TBD:** Final tier names and color coding in UI.

## Open questions (TBD)

- Inventory management UI in combat vs. exploration only
- Whether duplicate rare items can exist for multiple party members
- Item descriptions as lore delivery (tie to [presentation.md](presentation.md))
- Which primary stats each weapon type boosts
