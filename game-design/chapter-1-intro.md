# Chapter 1 Intro — Script and Areas

**Status:** Implemented (Oct 2026). Expands the original Mira-only intro ([story.md — Chapter 1](story.md#chapter-1--the-missing)) into an 8–12 minute prologue across three areas. See [Implementation](#implementation) for where each piece lives.

## Decisions (from design interview, Oct 2026)

**Decided:**

- **Length:** ~8–12 minutes from New Game to free explore in `village_square`. Three areas: Abandoned Doorway → Chapel Lane (new) → Pine Edge.
- **Season:** late autumn. Grey dawn, frost on the cobbles, low mist that thickens toward the woods.
- **Woods hook:** the tall man stands among the pines, and a cut later he is gone. Mira finds Lily's **carved wooden bird** set on a stump. No combat.
- **The tall man:** human but too tall, with slightly wrong proportions. He wears a long coat and a wide hat, and his face is never shown.
- **Mr. Holt:** ambiguous and quietly complicit. His account has small wrongs that the player can catch. Chapter 1 never confirms anything.
- **Tom** (~10) is eager and idolises Mira. **Elsa** (~14) is wary and blames Mira for Lily.
- **Choices** are flavour only, but each one is recorded as a story flag for later chapters.
- **New features:** examinable objects (E), title cards wired before the dawn scene, the wooden bird as a key item, an on-screen objective line, and dedicated models for Tom, Elsa, Holt and the tall man.
- **Title cards** are gothic: blackletter title (UnifrakturMaguntia) over a small-caps overline (IM FELL English), with a thin red rule.
- **Music:** the intro gets its own tracks (`intro` for the doorway, `intro_lane` for the lane). The woods are silent.
- **Mira may be harsh.** Elsa's "So were you." option stays.
- **Party:** Mira is the only party member until others join through the story (the `party_join` cutscene step).

**Placeholders (rename freely):** the door-mark symbol in Chapel Lane, the display names "Abandoned Doorway", "Chapel Lane" and "Pine Edge", and the dead chandler. Names for the cult, the rite and village institutions stay **TBD** ([story.md](story.md#open-questions-tbd), [world.md](world.md)). The script deliberately avoids naming them.

## Flow overview

| # | Where | Beat | Kind | Sets flag |
|---|-------|------|------|-----------|
| 1 | Doorway | Title cards → Mira wakes; Lily's spot is empty | cutscene (auto) | `intro_dawn_seen` |
| 2 | Doorway | Tom and Elsa: bread run, "Is Lily coming?" | dialog (talk to Tom) | `intro_orphans_talked`, `intro_morning_choice_*` |
| 3 | Doorway | Free examine: Mira's things, the lantern, Lily's drawings | examinables | — |
| 4 | Doorway | Lily's blanket: her shoes are still there | cutscene (trigger) | `intro_empty_spot_seen` |
| 5 | Doorway | Elsa: "You were supposed to watch her." | dialog (chained) | `intro_elsa_choice_*` |
| 6 | Doorway | Holt's testimony: tall man, "boots on", chapel lane | dialog (trigger) | `intro_testimony_seen`, `intro_holt_choice_*` |
| 7 | Doorway | Holt shuts his door. The lane exit opens | cutscene | objective set |
| 8 | Chapel Lane | Free explore: notice, well, offerings, voice behind a shutter | examinables + dialog | — |
| 9 | Chapel Lane | Footprints in frost: small and bare, beside a long stride | cutscene (trigger) | `intro_footprints_seen` |
| 10 | Pine Edge | The tall man among the pines, then gone | cutscene (auto) | `intro_tall_man_seen` |
| 11 | Pine Edge | The wooden bird on a stump | examine → cutscene | `intro_bird_found` |
| 12 | Pine Edge | The trees go silent. Mira backs off → village square | cutscene | `intro_complete`, `chapter1_intro_seen` |

The intro ends in `village_square` with the objective **"Find out who the tall man is."**

---

## Area 1 — Abandoned Doorway (`mira_intake_alcove`)

### Environment

- **What it is:** the recessed doorway of a dead chandler's shop on the back edge of the market. The shop door is boarded, and a canvas market awning sags overhead. Mira, Lily, Tom and Elsa sleep in the dry strip under it.
- **Layout (14 × 14 m, existing footprint):** the doorway sits at the north wall. West of it is Lily's corner, and Mira's spot is in the centre. To the east, Tom and Elsa's nest is made of sacking against crates. Across the cobbles to the south-east is **Holt's house front**: a low door, a single lit window and a bench. The exit to Chapel Lane is a gap between houses on the west side, closed off by a handcart until beat 7.
- **Props:** two blankets (Mira's and Lily's), Lily's small shoes beside her blanket, Mira's tin, the cold lantern, chalk birds on the doorway stones, boards across the door, the chandler's crates, a rain barrel with a skin of ice, the handcart, and Holt's lamp-lit window.
- **Lighting:** cold blue-grey ambient, with a low sun hidden behind the houses. The only warm light is Holt's window, which draws the eye to him early. Light ground mist hangs over the cobbles.
- **Audio:** the `intro` track: open fifths, a lone fiddle line in D dorian, wind in the canvas and a far-off bell. **No birdsong**, an early cue for the sickening land.
- **Cameras:** the existing single zone is split in two. **ZoneDoorway** is a high three-quarter view over the sleeping spots. **ZoneHolt** looks back across the cobbles toward Holt's door with the doorway in the foreground.

### Beat 1 — Title cards and dawn (`title_redelka` → `title_chapter` → `mira_dawn`)

Black. White serif text, centred: **Redelka**. Fade. **Chapter 1 — The Missing**. Fade to the doorway, wide and from high up, with mist on the cobbles.

> **Mira** *(internal)*: Same doorway. Same awning. Same cold.

The camera blends low across Mira's blanket to Lily's corner. The second blanket is pushed back and empty.

> **Mira** *(internal)*: Lily's up before me. That's new.

Control is handed back. Objective: **"Talk to Tom."**

### Beat 2 — Tom and Elsa (`orphan_morning_chat`, talk to Tom with E)

> **Tom:** Mira. Mira. Baker's back door's open.
> **Elsa:** He'll hear you in the next valley, Tom.
> **Tom:** Burnt ends. He throws them out at first light. If we're quick.
> **Mira:** You're always quick. That's why you're thin.
> **Tom:** Is Lily coming? She likes the crusts.

**Choice** (flag `intro_morning_choice_<id>`):

| Option | Follow-up |
|--------|-----------|
| "She's up already." (`up_already`) | **Tom:** No she's not. I looked. |
| "Ask her yourself." (`ask_her`) | **Tom:** I did. She's not anywhere. |

Both options converge:

> **Elsa:** Her blanket's still down. Go and look.

Objective: **"Check Lily's corner."**

### Beat 3 — Examinables (optional, any order)

| Object | Mira *(internal)* |
|--------|-------------------|
| Mira's blanket | Mine. Wool, mostly. I wake if a rat crosses the cobbles. |
| Mira's tin | Two coppers, a needle, my whittling knife. Everything I own fits in a tin. |
| Cold lantern | Out of oil. Lily likes it lit. I said tomorrow. |
| Chalk birds | Lily draws birds on everything. Says they keep watch. |
| Boarded door | The chandler's. He went in the spring. Nobody asked where. |
| Rain barrel | Ice on top. First this year. |
| Handcart *(before beat 7)* | Not yet. |

The blanket line is a deliberate plant. Holt says later that she "sleeps like the dead".

### Beat 4 — The empty spot (`mira_finds_empty_spot`, trigger at Lily's corner)

The camera cuts low to Lily's blanket. Two small shoes sit side by side on the stones.

> **Mira** *(internal)*: Her blanket. She doesn't leave her blanket.
> **Mira** *(internal)*: Her shoes. It's frost out.

Mira kneels. The bird she always sleeps with is not there.

> **Mira** *(internal)*: The bird's gone. Only the bird.

Elsa steps into frame behind her, and the cutscene chains into beat 5.

### Beat 5 — Elsa (`elsa_blame`, chained from beat 4)

> **Elsa:** She doesn't go anywhere without you.
> **Elsa:** You were supposed to watch her. You said you would.

**Choice** (flag `intro_elsa_choice_<id>`):

| Option | Follow-up |
|--------|-----------|
| "I know." (`accept`) | **Elsa:** …Then go and find her. |
| "I'm not her mother." (`deflect`) | **Elsa:** No. You're all she had. |
| "So were you." (`lash`) | **Elsa:** … **Tom:** Stop it. Both of you. |

All three converge:

> **Tom:** Mr. Holt's lamp was on all night. I saw it when I got up.
> **Mira:** Holt doesn't burn oil for nothing.

Objective: **"Talk to Mr. Holt."**

### Beat 6 — Holt's testimony (`neighbor_testimony`, trigger at Holt's door)

Holt is already standing in his doorway in a coat over his nightshirt, lamp still in his hand.

> **Holt:** Mira. You look like you've been looking.
> **Mira:** Lily. Small. Dark hair. You know her.
> **Holt:** I know her.
> **Holt:** Late last night. I couldn't sleep. The dogs wouldn't settle.
> **Holt:** A tall man. Not from here. He walked that lane like he'd walked it before.
> **Holt:** Your girl went beside him. Boots on, shawl up. Quiet. Like she'd been told to.
> **Mira:** Where.
> **Holt:** Down the chapel lane. Past the graves. Into the pines.

**Choice** (flag `intro_holt_choice_<id>`):

| Option | Follow-up |
|--------|-----------|
| "Why didn't you wake me?" (`blame`) | **Holt:** I called out. Twice. You sleep like the dead, child. **Holt:** By the time I had my boots on, they were gone. |
| "Which way, exactly?" (`direction`) | **Holt:** Through the lychgate path. North, where the pines crowd close. **Mira:** You know that path well. **Holt:** Sixty years here. I know all the paths. |
| "Who was he?" (`who`) | **Holt:** Nobody I'd know. **Holt:** Nobody you'd want to, either. |

All three converge:

> **Holt:** Wait in your doorway. Children wander. She'll turn up.
> **Mira:** They don't turn up, Holt. Not lately.

**The small wrongs** are never pointed out in Chapter 1:

- He says "boots on", but her shoes are by the blanket.
- He "called out twice", but Mira wakes for rats.
- He is precise about a path he says he didn't follow.
- His lamp burned all night.

### Beat 7 — Holt shuts the door (`mira_after_holt`)

Holt steps back and the door closes. A beat later his window goes dark. The camera holds on the dark window.

> **Mira** *(internal)*: Chapel lane.

Mira shoves the handcart aside (fade cut). The west gap opens as a door to Chapel Lane. Objective: **"Follow the chapel lane north."**

---

## Area 2 — Chapel Lane (`mira_chapel_lane`, new)

### Environment

- **What it is:** a narrow cobbled lane, about 4 m wide and 24 m long, running north from the market. Shuttered house backs line the east side. The west side is the chapel graveyard's low stone wall, with the chapel's rear wall and a lychgate partway along. The lane ends in a field gate that opens onto the path into the pines.
- **Mood:** the lane feels like the village has turned its back. Every shutter is closed, and the mist thickens with each step north. It should feel slightly too long.
- **Props:** a well with a winch, three house backs (one with a milk jug on the step, one with the placeholder door mark, one with a shutter that cracks open), a notice board, the lychgate with bread and salt on its post, the chapel's back window with candle stubs on the sill, frost-rimed cobbles with the **footprint strip** near the north end, and the field gate.
- **Lighting:** cooler and darker than the doorway. Fog density ramps along the lane (or use stacked fog volumes). The chapel window has a faint, cold glow.
- **Audio:** the `intro_lane` track: a low tritone drone, a slow heartbeat that thins out, and the chapel bell. A single real toll (`bell_toll` sfx) plays the first time Mira enters. The shutter ends on `shutter_slam`.
- **Cameras:** three zones. **ZoneSouth** looks down the lane from above the entry. **ZoneMid** is side-on along the graveyard wall, framing the lychgate. **ZoneNorth** is low behind Mira, looking up the lane into the mist toward the gate.
- **No enemies, no pickups.** The lane is a dread corridor. Avoid any combat tutorial here.

### Examinables

| Object | Mira *(internal)* |
|--------|-------------------|
| Notice board | "Gone since the turning of the month. Any word, to the chapel." Somebody tore the name off. |
| Well | Rope's cut. Clean, not frayed. |
| Milk jug on step | Yesterday's milk. Nobody took it in. |
| Door mark *(placeholder symbol)* | Scratched in. Fresh. Not a child's. |
| Lychgate post | Bread and salt. Fresh. Someone's paying the dead to look away. |
| Chapel back window | Candles burned to nothing. Who prays all night? |

### Voice behind a shutter (`lane_shutter`, trigger mid-lane)

A shutter cracks open on the east side. The speaker is never seen (actor `lane_voice`, displayed as "Behind a shutter").

> **Behind a shutter:** Go home, girl.
> **Mira:** A tall man came down here last night. With a little girl.
> **Behind a shutter:** I sleep at night. Like decent folk.
> **Behind a shutter:** You should try it.

*(shutter slams; sfx)*

### Beat 9 — Footprints (`mira_lane_footprints`, trigger at north end)

The camera tilts down to the frost. One set of small bare prints runs beside one set of long, deep boot prints.

> **Mira** *(internal)*: Bare feet. In this.
> **Mira** *(internal)*: His stride's half again mine.
> **Mira** *(internal)*: Holt said boots.

Objective unchanged. The field gate is the exit to Pine Edge.

---

## Area 3 — Pine Edge (`mira_woods_edge`)

### Environment

- **What it is:** where the field path meets the pines. There is a strip of frosted grass, a split-rail fence, an old cut stump beside the path, and a wall of close, dark trunks. The path goes on into the trees but is blocked to the player.
- **Layout:** the player enters from the south (the field gate). The stump sits about 3 m short of the tree line, on the path. The tall man stands about 6 m inside the trees, partly behind a trunk.
- **Props:** a denser tree line (12–20 trunks in two depth rows rather than the current five box trees), fallen needles, the fence, the stump, and **the wooden bird standing upright on the stump**.
- **Lighting:** the darkest of the three areas. The sky is a pale band over the field behind Mira, and the woods ahead are near-black with heavy fog. The tall man reads only as a silhouette against slightly lighter fog.
- **Audio:** wind across the field behind her and **dead silence from the trees**. In beat 12, the field wind cuts out too.
- **Cameras:** **ZoneField** is wide from the field side, looking at the tree line. **ZoneStump** is close, behind the stump, looking back at Mira.
- **Blocked path:** an invisible wall with the message *"Not alone. Not in the dark."*

### Beat 10 — The tall man (`mira_woods_hook`, auto on enter)

The music cuts. The view goes wide from the field: mist and trunks. One trunk is not a trunk. The camera blends slowly closer. The figure is too tall, in a long coat and a wide hat. His back is half-turned, and his hands hang a little too low.

> **Mira** *(internal)*: He's not moving. He knows I'm here.

The camera cuts to Mira's face, then back to the tree line. He is gone.

> **Mira** *(internal)*: …No.

Control is handed back. Objective: **"Search the edge of the woods."**

### Examinables

| Object | Mira *(internal)* |
|--------|-------------------|
| Pine trunk | No birds. Not one. |
| Fence | Somebody's mended it. Recently. Which way are they keeping things? |
| Path into trees *(blocked)* | Not alone. Not in the dark. |

### Beat 11 — The bird (`mira_finds_bird`, examine the stump)

The view is close behind the stump. The small pine bird stands upright, facing Mira, set down with care. The player receives the key item **Carved Wooden Bird**.

> **Mira** *(internal)*: I made this for her. She sleeps with it in her fist.
> **Mira** *(internal)*: She didn't drop it. Somebody set it here.
> **Mira** *(internal)*: For me.

### Beat 12 — The silence (`mira_woods_exit`, chained)

The field wind behind her stops. A single branch cracks somewhere deep in the trees. Mira steps back once, then twice.

> **Mira** *(internal)*: Not like this.
> **Mira** *(internal)*: Someone in this village knows.

Fade to black. `goto_area village_square`. Objective: **"Find out who the tall man is."**

**Key item text:**

- **Carved Wooden Bird:** A small bird whittled from pine. Mira made it for Lily. Lily slept holding it.

---

## NPC models (Blender generator)

All four use the shared humanoid skeleton and clips. Heights are approximate.

| Id | Look | Height |
|----|------|--------|
| `orphan_tom` | Small, thin boy. Oversized patched coat with rolled sleeves, a flat cap, bare shins. | ~1.35 m |
| `orphan_elsa` | Lanky girl. Dark shawl over the head and shoulders, a long braid, a sack skirt, wrapped feet. | ~1.55 m |
| `neighbor_holt` | Stooped man in his 60s. Long nightshirt under an open coat, a bald crown with grey sides, a carried lamp (prop). | ~1.70 m |
| `tall_man` | Long dark coat to the ankles and a wide-brim hat. His face is a shadow void, with no features modelled. Arms are ~10% too long. Narrative-only, with no battle stats. | ~2.30 m |

Lily is never shown in Chapter 1.

## Resolved (Oct 2026)

- **Title card style:** gothic (see Decisions).
- **Music:** dedicated tracks, generated by `tools/generate_bgm.py intro_dawn intro_lane`.
- **Elsa's lash option:** kept. Mira is allowed to be harsh.

## Implementation

| Piece | Where |
|-------|-------|
| Script content | `data/cutscenes.json`, `data/dialogs.json`, `data/actors.json`; the bird is in `data/keys.json` |
| Areas | `data/areas.json` rows plus `scenes/explore/mira_intake_alcove.tscn`, `mira_chapel_lane.tscn`, `mira_woods_edge.tscn`, generated by `tools/generate_scenes.py` (helpers in `tools/scene_kit.py`) |
| Examinables | `ExploreExaminable` (`scripts/explore/explore_examinable.gd`): lines, or a dialog/cutscene, gated by `story_flag_required` / `hide_when_flag` |
| Subtitles and title cards | `NarrativeCaptions` (`scripts/narrative/narrative_captions.gd`), owned by `NarrativeDirector` |
| New cutscene steps | `title_card`, `play_cutscene` (inlines another cutscene), `set_objective`, `give_item`, `party_join`, `music` with `stop` |
| Dialog features | options carry a `flag`; a dialog can chain on with `next`; `after_line` is the last line shown before the choice row |
| Gating | `ExploreDoor.required_story_flag`; `NarrativeActor.hide_when_flag` |
| Objective | `GameState.current_objective` (saved), drawn top right by `ExploreController` |
| Party | `setup.json` starts with Mira only; `GameState.add_party_member()` applies the recruit's `loadouts` and `join_inventory` |
| Models | `tools/generate_models.py` (`orphan_tom`, `orphan_elsa`, `neighbor_holt`, `tall_man`) plus `scenes/characters/*.tscn` wrappers |
| Audio | `intro_dawn`, `intro_lane` (BGM); `bell_toll`, `shutter_slam`, `branch_snap` (SFX) |
| Tests | `scripts/test/narrative_smoke_test.gd`: content links, scene wiring, Mira-only party and recruiting, objective save/load, `play_cutscene`, choice flags and chaining, examinable gating |
