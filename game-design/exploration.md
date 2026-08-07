# Exploration

## Camera system

**Decided:** **Fixed camera positions with tracking** — not fully static slideshow cuts.

- Cameras are **authored per zone** (classic survival-horror framing).
- Within a zone, the camera **pans or tracks** the player to keep them readable.
- Dramatic moments may use **authored camera moves** (**TBD** frequency).

**TBD:**

- Number of camera zones per room
- Player visibility in tight corners (occlusion, transparency)
- Whether the player can manually swap angles in some rooms

## World structure

**Decided:** **Chapter-based** — 8–10 distinct locations, sequenced by story (12–20 hour target).

- Each chapter is a **self-contained explorable space** with its own puzzles, enemies, and beats.
- Backtracking within a chapter is expected; cross-chapter return **TBD**.

## Encounters

**Decided:** **Visible enemies plus scripted ambushes.**

| Type | Behavior |
|------|----------|
| **Visible** | Enemies exist in the 3D space; contact or engagement starts grid combat |
| **Ambush** | Scripted triggers (cutscene, door, trap) force battle with authored setup |

**Not used:** Pure random encounters without world presence.

**TBD:**

- Stealth or detection radius for visible enemies
- Whether engaging from behind grants combat advantage (no facing on grid, but overworld advantage possible)
- Re-engaging the same visible enemy after fleeing combat

## Avoidance

**Decided:** **Enemy avoidance** is a valid horror/exploration mechanic — some fights are better **dodged** than fought.

- Ties to resource pressure (durability, ammo, treatment).
- **TBD:** Whether avoidance is pure movement or uses a dedicated action (crouch, distract).

## Puzzles

**Decided:** **Environmental puzzles** gate progress — keys, riddles, machinery, ritual steps, etc.

**TBD:**

- Puzzle density per chapter
- Inventory-based vs. logic-only puzzles
- Fail states and hints for Easy vs. Hard

## Horror mechanics (exploration)

| Mechanic | Status |
|----------|--------|
| Environmental puzzles | **Decided** |
| Enemy avoidance | **Decided** |
| Sanity / fear system | **Possible on Hard only** — see [difficulty-saves.md](difficulty-saves.md) |
| Light/darkness management | **TBD** |
| Atmosphere-only horror | Always present via audio, camera, lore |

## Rest points and flow

**Decided (cross-doc):**

- Rest/safe rooms exist for **post-battle treatment**, **party banter**, and **saves** (rules vary by difficulty).
- Easy: autosave on room enter + classic save points.
- Normal: save points only.
- Hard: save points require consumable resource.

**TBD:**

- Map UI and fast travel (if any)
- Chapter select after completion

## Exploration ↔ combat transition

1. Player in 3D fixed-camera space.
2. Contact visible enemy, trigger ambush, or interact with fight trigger.
3. Transition to **5×5 grid** combat (see [combat.md](combat.md)).
4. On victory, defeat, or retreat — return to exploration state (**TBD** spawn rules; see [prototype.md](prototype.md#explore--combat-transition)).

## Open questions (TBD)

- Interactables list (examine, pick up, push, ritual)
- Verticality and ladders in 3D spaces
- Optional collectibles and completion tracking
