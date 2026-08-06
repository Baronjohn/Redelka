# Difficulty and Saves

## Difficulty tiers

**Decided:** Three tiers — **Easy**, **Normal**, **Hard** — selected at new game (change rules **TBD**).

| Tier | Save system | Extra mechanics |
|------|-------------|-----------------|
| **Easy** | **Autosave** slot on **room enter** + classic **save points** | Standard horror/exploration |
| **Normal** | **Save points only** | Standard horror/exploration |
| **Hard** | Save points require a **consumable save resource** found in the world | Optional **sanity / fear system** |

## Save points (all tiers where applicable)

**Decided:**

- **Classic save points** exist in the world (authored locations, often at rest/safe rooms).
- On **Hard**, interacting with a save point **consumes one save resource** from inventory.

**TBD:**

- Save resource name, rarity, and max carry
- Whether Easy autosave and manual save at the same point can conflict
- Autosave slot count (single rolling vs. multiple)
- Death/load behavior: reload last save vs. retry room

## Easy — autosave

**Decided:** Autosave triggers when **entering a new room** (in addition to manual save points).

**TBD:**

- Definition of “room” for autosave boundaries
- Whether autosave overwrites one slot or keeps a chain
- UI indicator when autosave occurs

## Hard — save resource

**Decided:** Saving is a **resource decision** — tension between saving now and saving the item for later.

- Resource is **found through scavenging** (no shops).
- Same save points as Normal; only the **cost** differs.

**TBD:**

- How many save resources exist per chapter (minimum guaranteed?)
- Whether Hard allows any autosave (recommended: **no**)

## Hard — sanity / fear system (optional)

**Decided:** **Possible for Hard mode only** — not confirmed for Easy/Normal.

**TBD:**

- What sanity affects (accuracy, CTB, hallucinations, puzzle changes, UI distortion)
- Recovery methods (rest, items, story)
- Whether it is cut if scope is tight

## Difficulty ↔ combat and economy

**TBD (recommended to define later):**

| Aspect | Easy | Normal | Hard |
|--------|------|--------|------|
| Enemy damage / HP | **TBD** | Baseline | **TBD** |
| Durability / ammo drain | **TBD** | Baseline | **TBD** |
| Retreat success | **TBD** | Baseline | **TBD** |
| Treatment requirements | **TBD** | Baseline | **TBD** |

Baseline values live in [combat.md](combat.md) and [equipment-economy.md](equipment-economy.md) once balanced.

## Difficulty selection UX

**TBD:**

- Show tier descriptions at new game
- Mid-game difficulty change allowed or locked
- Achievement/trophy tied to Hard clear

## Open questions (TBD)

- Ironman mode (delete save on death) as separate flag or part of Hard
- Chapter replay with difficulty inherited from save
- Accessibility options independent of difficulty (subtitle size, QTE skip, etc.)
