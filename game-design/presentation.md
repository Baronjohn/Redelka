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

### Narrative delivery — implementation

**Aug 2026 build:** A small reusable runtime powers cutscenes and dialogs:

| Piece | Path | Role |
|---|---|---|
| `NarrativeDirector` | `scripts/autoload/narrative_director.gd` (autoload) | Owns the active cutscene script, dialog UI, theater overlay, and busy flag. Emits `cutscene_started/ended` and `dialog_started/ended` signals. |
| `CutscenePlayer` | `scripts/narrative/cutscene_player.gd` | Per-scene node that drives a single `cutscene_id`. Auto-plays if `auto_play = true`. |
| `NarrativeActor` | `scripts/narrative/actor_node.gd` | Lightweight in-scene actor referenced by `actor_id`; exposes `move_to`, `face_to`, `face_actor`, `show_actor`, `hide_actor`. |
| `NarrativeTrigger` | `scripts/narrative/narrative_trigger.gd` | `Area3D` that fires a cutscene or dialog when the player enters. One-shot, flag-gated. |
| `NarrativeDialogUI` | `scenes/narrative/dialog_ui.tscn` | Dialog panel: portrait, name, line, continue prompt, choice box. Advances on E / click / Space. |
| `NarrativeDialogChoiceBox` | (in scene tree) | Floating choice row above the dialog panel. |
| Data files | `data/cutscenes.json`, `data/dialogs.json`, `data/actors.json` | All chapter content as data — no scene-side scripts for dialog or cutscenes. |

**Cutscene step types:** `wait`, `camera_cut`, `camera_blend`, `actor_move`, `actor_face`, `actor_show`, `actor_hide`, `actor_reset`, `actor_say` (one-shot line shown as a subtitle; speaker `internal` renders as Mira's thought in italics), `play_dialog`, `flag_set`, `flag_branch`, `fade`, `hand_control_back`, `goto_area`, `sfx`, `music` (`stop: true` fades out), `title_card` (gothic chapter card), `play_cutscene` (inlines another cutscene's steps), `set_objective`, `give_item`, `party_join`.

**Dialog structure:** `lines` array of `{speaker, text}`. Optional `choices: [{after_line, options: [{id, label, flag, next}]}]`: the choice row appears after line `after_line`, and `flag` records the pick as a story flag. A dialog may continue into another with `next`.

**Examine points:** `ExploreExaminable` (under an area's `Interactables`) shows internal lines on E, or starts a dialog or cutscene. It is gated by `story_flag_required` / `hide_when_flag`.

**Title cards (Decided, Oct 2026):** gothic. UnifrakturMaguntia blackletter with an IM FELL English overline (both OFL, in `assets/fonts/`).

**Explore suspension:** While a cutscene or dialog runs, `GameState.busy_narrative = true`. `ExploreController._process` flips `_player.movement_enabled = false`, and `_unhandled_input` ignores menu/mouse input. `ExploreController` listens to `cutscene_ended` to re-engage camera tracking and snap the camera to its authored anchor.

**State:** `GameState.protagonist_character_id` (default `"ally_2"` = Mira) and `GameState.story_flags` (Dictionary[String, bool]) are persisted. `GameState.chapter1_intro_seen` gates routing — see `SceneTransition.go_to_explore()`.

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
- Credits style
