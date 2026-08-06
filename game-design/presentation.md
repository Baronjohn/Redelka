# Presentation

## Art direction

**Decided:** **Retro-inspired but more modern than the original *Koudelka*.**

- **3D environments** with fixed-camera exploration (see [exploration.md](exploration.md)).
- Evoke PS1-era horror: low-poly readability, strong silhouettes, moody lighting — but with **modern rendering** (better lighting, effects, resolution, animation).
- Not photoreal; **stylized gothic / folk horror** palette and materials.

**TBD:**

- Target resolution and aspect ratio
- Character model fidelity vs. environment fidelity
- UI style (diegetic vs. minimal overlay)
- Combat grid visual language (tile highlights, timeline UI)

## Audio direction

**Decided:** **Adaptive audio.**

| Context | Direction |
|---------|-----------|
| Exploration | Sparse ambient beds, environmental sound foregrounded |
| Rising danger | Layers add percussion, drones, or motifs |
| Combat | Dynamic combat mix; may stem from exploration themes |
| Key story beats | Full musical statements where authored |

Honors the original’s restraint while allowing **modern dynamic mixing** and clearer combat feedback.

**TBD:**

- Composer/style references (folk instruments, choir, silence)
- Voice acting scope (full VO vs. partial vs. text-only)
- Localization and lip sync

## Narrative delivery

**Decided:** All methods below are in scope.

### Cutscenes

- **Real-time staged scenes** using the **fixed-camera system** — same visual language as exploration.
- **TBD:** In-engine only vs. pre-rendered; skippable on repeat

### Dialogue choices

- Branching or flavor dialogue during conversations.
- **TBD:** Which choices affect outcomes vs. tone only; relationship flags

### Environmental storytelling

- Notes, documents, environmental details, **item descriptions** as lore vectors.
- Ties to folk horror themes in [world.md](world.md).

### Party banter

- Optional **character conversations** at rest points or when examining objects together.
- Reinforces medium cast (5–7) without mandatory cutscene bloat.

## UI and readability

**TBD:**

- Combat: CTB timeline, grid cursor, action menu layout
- Exploration: interaction prompts, inventory, map
- Subtitles for all dialogue; horror-appropriate font choices

## Platform presentation

**Decided:**

- Godot 4.7+, GDScript
- PC-first assumptions (**TBD** console/controller glyphs)

## Open questions (TBD)

- Colorblind-safe grid and UI highlights
- Photo mode or replay theater
- Credits and chapter title cards style
