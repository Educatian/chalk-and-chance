# Chalk & Chance Item System Embedding Plan

## 1. Integration Principle

The item system should not sit beside the game as a separate inventory mini-game. It should become a thin layer that connects the systems already present:

- `GameState`: owns persistent inventory, loadout, item use history.
- `Hub`: shows progress, upgrades, and item preparation.
- `PreviewScenario`: explains mission objectives and lets the player choose a loadout.
- `Overworld`: uses classroom-management items such as Quiet Signal and Routine Card.
- `Encounter`, `LectureScene`, `GymEncounter`, `GroupCheckIn`: use moment-to-moment teaching support items.
- `Competency`: interprets item use as evidence of strategy, not as skill mastery by itself.
- `Telemetry`: logs every item equipped, used, blocked, and its before/after effect.
- `LLMClient`: receives item context only when the item affects student/coach interpretation.
- `TTSClient`: does not need item logic, except Coach Vee comments can still be voiced later.

Core rule:

> Items should modify the player's opportunity to make a good teaching decision, not replace the teaching decision.

## 2. Current System Map

Current gameplay flow:

```text
Login
  -> Hub
      -> PreviewScenario / ImportLesson
      -> Overworld
          -> Encounter / GroupCheckIn
      -> LectureScene
      -> GymEncounter
  -> Badge / XP / Upgrade / Telemetry
```

Item-embedded flow:

```text
Hub
  -> Item Inventory + Loadout
  -> Scenario Preview recommends field-aligned tools
  -> Mission starts with 0-2 equipped items
      -> Overworld items support classroom management
      -> Encounter items support noticing, wait time, recovery
      -> End-of-mission reflection items turn telemetry into next goals
  -> Rewards grant items, XP, badges, and upgrade points
```

## 3. Data Ownership

### `GameState.gd`

Add these persistent fields:

```gdscript
var inventory: Dictionary = {}
var mission_loadout: Array = []
var item_cooldowns: Dictionary = {}
var item_history: Array = []
```

Responsibilities:

- store item counts
- equip/unequip items before mission start
- consume items
- enforce stack limits
- enforce mission loadout limit
- expose item availability to scenes
- save/load item state

Suggested API:

```gdscript
func item_count(item_id: String) -> int
func can_equip_item(item_id: String, scenario: Dictionary) -> bool
func equip_item(item_id: String) -> bool
func unequip_item(item_id: String) -> bool
func can_use_item(item_id: String, scope: String) -> bool
func use_item(item_id: String, context: Dictionary = {}) -> Dictionary
func award_item(item_id: String, amount: int = 1, reason: String = "") -> void
```

`use_item()` should return a structured result:

```gdscript
{
  "ok": true,
  "item_id": "breathing_reset",
  "effect": {"composure_delta": 15},
  "message": "Composure restored. Your next move still matters."
}
```

## 4. Item Definition Layer

Create:

```text
data/items.json
```

Why JSON:

- consistent with existing scenario/persona data
- easy to edit without changing code
- can be imported into landing/guidebook later

Suggested structure:

```json
{
  "breathing_reset": {
    "name": "Breathing Reset",
    "type": "recovery",
    "scope": ["encounter", "lecture", "gym"],
    "max_stack": 3,
    "loadout_cost": 1,
    "consumable": true,
    "field_equivalent": "teacher self-regulation pause",
    "game_effect": "Restore 15 Composure once.",
    "classroom_meaning": "Pause before responding so your next move is deliberate, not reactive.",
    "blocks_win": false
  }
}
```

Fields:

| Field | Purpose |
|---|---|
| `name` | UI label |
| `type` | preparation, observation, recovery, reflection |
| `scope` | where it can be used |
| `max_stack` | inventory limit |
| `loadout_cost` | slot cost, normally 1 |
| `consumable` | whether count decreases |
| `field_equivalent` | real classroom mapping |
| `game_effect` | player-facing effect |
| `classroom_meaning` | transfer explanation |
| `blocks_win` | true only for items that give too much help; normally false |

## 5. UI Embedding

### Hub

Current Hub already shows:

- title
- teacher level / XP
- upgrade button
- settings
- mission list

Add:

- `Items` button beside `Upgrade`
- item count summary: `Items: 4`
- current loadout preview: `Loadout: Lesson Map, Breathing Reset`

Hub item overlay:

```text
ITEMS
[Preparation] Student Profile Card x2
[Recovery] Breathing Reset x1
[Reflection] Practice Goal Card x1

Loadout Slots
[Slot 1] Lesson Map
[Slot 2] Breathing Reset
```

Design constraint:

- Do not put item management inside the mission list.
- Keep item management as a modal/overlay like Settings and Upgrades.

### PreviewScenario

Preview is the best place to connect items to the current mission.

Add:

```text
Mission Loadout
Recommended for this mission:
- Lesson Map: objective clarity
- Wait Meter Pin: wait-time discipline
```

If `Lesson Map` is equipped:

- objectives show clearer beginner language
- display one "Watch for..." line

If `Student Profile Card` is equipped:

- reveal one student asset/need
- never reveal the exact win move

### Overworld

Overworld receives the active mission loadout from `GameState`.

Add a compact item strip near HUD:

```text
Items: [Quiet Signal x1] [Routine Card active]
```

Use cases:

- `Quiet Signal`: reduce average off-task pressure once.
- `Routine Card`: starts the period with an Order/attention buffer.

Do not use the full inventory overlay during active Overworld play.

### Encounter / Lecture / Gym

Add a compact item row separate from the teaching move row.

Recommended placement:

- top-right or just above the bottom input row
- icon-style small buttons
- disabled when not usable

Example:

```text
[Lens] [Reset]
```

Interaction:

- click item
- item effect applies immediately
- result text explains both game and classroom meaning
- telemetry logs before/after

Important:

- teaching moves remain the primary buttons
- item row must not crowd `Mic / Say / Menu`

## 6. Scene-Specific Item Effects

### Hub / Preview

| Item | Integration Point | Effect |
|---|---|---|
| Lesson Map | PreviewScenario | expands objectives and pressure points |
| Student Profile Card | PreviewScenario | reveals one asset/need for one student |
| Practice Goal Card | Hub | shows next practice focus from weakest competency |

### Overworld

| Item | Integration Point | Effect |
|---|---|---|
| Quiet Signal | `Overworld._apply_noise()` path | reduces off-task levels slightly |
| Routine Card | lesson start | slows initial off-task rise or adds attention buffer |
| Seating Note | future planning phase | warns about adjacency/participation risk |

### Encounter

| Item | Integration Point | Effect |
|---|---|---|
| Breathing Reset | Composure meter | restores Composure, no Understanding change |
| Noticing Lens | student dialogue / coach result | highlights cue phrase or need category |
| Misconception Marker | dialogue/result text | marks misconception signal |
| Wait Meter Pin | wait label/bar | keeps threshold visible and clearer |

### LectureScene

| Item | Integration Point | Effect |
|---|---|---|
| Wait Meter Pin | wait label | stronger visual wait cue before Question |
| Quiet Signal | attention | small attention recovery, one use |
| Lesson Map | title/objective text | shows pacing warning |

### GymEncounter

| Item | Integration Point | Effect |
|---|---|---|
| Breathing Reset | Composure | buys recovery under pressure |
| Equity Snapshot | target selection | marks unresolved/unattended students |
| Noticing Lens | selected student | displays selected student's current need cue |

### GroupCheckIn

| Item | Integration Point | Effect |
|---|---|---|
| Equity Snapshot | member display | highlights low-participation group member |
| Misconception Marker | group dialogue | surfaces shared reasoning crack |
| Practice Goal Card | after leaving pod | suggests group-monitoring next step |

## 7. Reward Economy Integration

Current rewards:

- badge unlocks
- XP
- upgrade points
- competency estimates
- bond/relationship progress

Add item rewards without replacing those:

| Event | Reward |
|---|---|
| First mission clear | item tied to mission concept |
| Level up | choose upgrade point or item bundle |
| Replay improvement | reflection item |
| Imported lesson preview | Lesson Map |
| Low-composure recovery success | Breathing Reset earned later, not immediately |

Reward examples:

- Clearing Routine mission: `Routine Card`
- Clearing Echo mission: `Wait Meter Pin`
- Clearing Balance mission: `Equity Snapshot`
- Clearing Mirror mission: `Evidence Tagger`
- Clearing Insight mission: `Misconception Marker`

This creates conceptual coherence:

```text
Badge = mastered region concept
Item = reusable support tool from that concept
Upgrade = permanent teacher growth
```

## 8. LLM Integration

Most items should not require LLM calls.

Rule-based items:

- Breathing Reset
- Quiet Signal
- Routine Card
- Wait Meter Pin
- Equity Snapshot
- Lesson Map

LLM-context items:

- Student Profile Card
- Noticing Lens
- Misconception Marker
- Repair Prompt

For LLM-context items, include item state in payload:

```gdscript
"active_items": [
  {"id": "noticing_lens", "used_this_turn": true}
]
```

But the backend should still obey:

```text
Item may clarify cues.
Item may not declare the correct move.
Item may not force the student to agree.
```

## 9. Telemetry Integration

Every item event logs to `Telemetry.log_event()`.

Events:

| Event | When |
|---|---|
| `item_awarded` | item enters inventory |
| `item_equipped` | player puts item in loadout |
| `item_unequipped` | player removes item |
| `item_used` | effect applies |
| `item_blocked` | clicked but unavailable |
| `item_recommended` | system recommends item for scenario |

`item_used` schema:

```json
{
  "event": "item_used",
  "item_id": "quiet_signal",
  "scenario_id": "independent_fractions",
  "scene": "res://scenes/overworld/Overworld.tscn",
  "turn": 0,
  "before": {"average_offtask": 42},
  "after": {"average_offtask": 30},
  "field_equivalent": "class attention signal"
}
```

Research interpretation:

- item choice = planning evidence
- item timing = regulation/orchestration evidence
- item overuse = possible dependency signal
- item non-use = possible lack of strategy awareness

## 10. Competency Integration

Items should not directly increase competency estimates.

Correct:

- Item use logs as strategy context.
- The subsequent teaching move determines competency evidence.

Example:

```text
Player uses Noticing Lens.
Then player chooses Elicit.
Competency observes Elicit as usual.
Telemetry records that Elicit occurred after Noticing Lens.
```

Why:

- Competency should represent teaching enactment.
- Items represent scaffolds and strategy supports.
- This keeps measurement cleaner.

Exception:

Reflection items can influence next-practice recommendations, but not theta/prob directly.

## 11. Save / Load Behavior

Save these:

- inventory counts
- equipped loadout
- item history
- per-mission item use flags if necessary

Do not save:

- temporary item UI state
- active hover tooltips
- momentary cue highlights

When loading:

- validate item IDs against `data/items.json`
- drop unknown item IDs silently but log warning
- clamp counts to max stack

## 12. Anti-Abuse Rules

| Risk | Rule |
|---|---|
| Player stacks recovery items | only 1 recovery item per mission |
| Player uses item to reveal answer | items reveal cues, not best move |
| Player uses Quiet Signal instead of moving | limited use and weaker than proximity |
| Player treats items as score boosters | item use does not directly improve competency |
| Inventory becomes confusing | two loadout slots only |
| Items crowd UI | separate item row, icon buttons, disabled state |

## 13. Implementation Sequence

### Step 1: Data Foundation

Files:

- `data/items.json`
- `autoload/GameState.gd`
- `autoload/Telemetry.gd`

Build:

1. Item definitions loader.
2. Inventory persistence.
3. Equip/unequip/use API.
4. Telemetry events.

### Step 2: Hub + Preview Embedding

Files:

- `scenes/ui/Hub.gd`
- `scenes/ui/PreviewScenario.gd`

Build:

1. Items overlay in Hub.
2. Mission Loadout in Preview.
3. Recommendation text by scenario format.
4. Lesson Map effect.

### Step 3: First Functional Item

Files:

- `scenes/encounter/Encounter.gd`
- `scenes/encounter/LectureScene.gd`
- `scenes/encounter/GymEncounter.gd`

Build:

1. Item row.
2. `Breathing Reset`.
3. before/after telemetry.
4. result text with classroom meaning.

### Step 4: Overworld Item

Files:

- `scenes/overworld/Overworld.gd`

Build:

1. item HUD strip
2. `Quiet Signal`
3. off-task before/after telemetry

### Step 5: Learning Items

Files:

- `Encounter.gd`
- `GroupCheckIn.gd`
- backend prompt if needed

Build:

1. `Noticing Lens`
2. `Equity Snapshot`
3. `Practice Goal Card`

## 14. Minimum Viable Embedded Version

The smallest version worth shipping:

1. `data/items.json`
2. inventory + loadout saved in `GameState`
3. Hub `Items` overlay
4. Preview `Mission Loadout`
5. `Lesson Map`
6. `Breathing Reset`
7. telemetry for equip/use

This gives:

- planning
- real classroom mapping
- recovery
- persistence
- research data

## 15. Open Design Decisions

1. Should level-up offer "upgrade point OR item bundle", or always give both?
   - Recommended: always give upgrade point for early prototype; items come from mission clear.

2. Should items be consumed permanently?
   - Recommended: preparation/recovery items are consumable; reflection items are not consumed until used.

3. Should players buy items?
   - Recommended: no shop yet. Earn through practice to avoid game economy noise.

4. Should item loadout be per mission or global?
   - Recommended: global loadout for now; later per-scenario saved loadouts.

5. Should item use reduce score?
   - Recommended: no. Log it, but do not punish. Items are scaffolds, and scaffolding is part of learning.

## 16. Product Fit

The item system fits Chalk & Chance only if every item answers one of these questions:

- What should I notice?
- How should I prepare?
- How do I keep the room teachable?
- How do I recover after a poor move?
- What should I practice next?

If an item answers "How do I win instantly?", it does not belong in this game.

## 17. Image Generation Plan

Implementation status as of 2026-06-01: **P0 icons and the first playable item
system are now in the Godot project.** The accepted icon set is the clean 64x64
transparent PNG set in `assets/ui/items/`, generated by
`scripts/create_clean_item_icons.py`. These icons are wired into Hub inventory,
Preview loadout display, and Encounter/Lecture/Gym item rows.

The item system needs visuals at three levels:

1. **Small icons** for fast in-game recognition.
2. **Inventory cards** for explanation and classroom transfer.
3. **Use-feedback effects** for moment-to-moment satisfaction.

The images must match the existing Chalk & Chance visual language:

- 16-bit / Nintendo DS era pixel-art feeling
- warm institutional classroom palette
- crisp 1px outlines
- no gradients
- transparent PNG where possible
- readable at 32x32 and 48x48
- real teaching-tool metaphor, not fantasy magic

### A. Asset Families

| Asset Family | Use | Size | Folder | Priority |
|---|---|---:|---|---|
| Item icons | Hub inventory, Preview loadout, in-game item row | 64x64 source, 28-32px UI display | `assets/ui/items/` | P0 implemented |
| Item card art | larger inventory/guidebook cards | 96x96 or 128x96 | `assets/ui/items/cards/` | P1 |
| Use effect sprites | brief feedback when item is used | 48x48 or strip | `assets/ui/items/fx/` | P1 |
| Classroom tool illustrations | guidebook / landing explanation | 512x320 | `landing/img/items/` | P2 |
| Instructor dashboard icons | future analytics views | 24x24 | `assets/ui/items/dashboard/` | P3 |

### B. Required P0 Item Icons

These are now implemented as the current approved MVP set.

| Item ID | Filename | Visual Metaphor | Classroom Meaning |
|---|---|---|---|
| `lesson_map` | `assets/ui/items/item_lesson_map.png` | folded lesson plan with objective checkmarks | success criteria / pacing guide |
| `breathing_reset` | `assets/ui/items/item_breathing_reset.png` | calm pause card with small breath lines | teacher self-regulation |
| `student_profile_card` | `assets/ui/items/item_student_profile_card.png` | index card with small student silhouette and note lines | learner profile / interest inventory |
| `quiet_signal` | `assets/ui/items/item_quiet_signal.png` | raised hand or small chime card | class attention signal |
| `noticing_lens` | `assets/ui/items/item_noticing_lens.png` | magnifying glass over speech bubble | professional noticing |
| `equity_snapshot` | `assets/ui/items/item_equity_snapshot.png` | small participation tally grid | equitable participation |
| `wait_meter_pin` | `assets/ui/items/item_wait_meter_pin.png` | stopwatch pin with 3-second mark | wait-time discipline |
| `practice_goal_card` | `assets/ui/items/item_practice_goal_card.png` | goal card with arrow/check | coaching action plan |

### C. P1 Item Icons

| Item ID | Filename | Visual Metaphor |
|---|---|---|
| `routine_card` | `assets/ui/items/item_routine_card.png` | posted classroom routine checklist |
| `misconception_marker` | `assets/ui/items/item_misconception_marker.png` | pencil marking a thinking bubble |
| `repair_prompt` | `assets/ui/items/item_repair_prompt.png` | small Coach Vee note with curved retry arrow |
| `evidence_tagger` | `assets/ui/items/item_evidence_tagger.png` | rubric tag label with check mark |
| `coach_replay_token` | `assets/ui/items/item_coach_replay_token.png` | replay triangle on note card |
| `question_starter_pack` | `assets/ui/items/item_question_starter_pack.png` | stack of question stem cards |
| `seating_note` | `assets/ui/items/item_seating_note.png` | tiny seating chart with one highlighted desk |

### D. Style Contract For Item Icons

Item icons should feel like real classroom materials converted into game icons.

Do:

- use paper, cards, clipboards, sticky notes, tally marks, timers, magnifying glass, seating chart shapes
- use the same navy/cream/oak/chalk-green palette as the UI
- keep a single clear silhouette
- make the object fill 70-85% of the canvas
- add a dark navy outline for visibility

Avoid:

- potions, crystals, spell effects, lightning, fantasy runes
- realistic photos
- tiny unreadable text
- excessive symbolic clutter
- saturated neon colors outside effect sprites

### E. Global Prompt Template

Use this for every item icon:

```text
Use case: stylized-concept
Asset type: 32x32 pixel-art game UI item icon
Primary request: [ITEM VISUAL METAPHOR]
Style/medium: 16-bit pixel art, Pokemon Gen-4 Nintendo DS inspired classroom UI asset, crisp 1px dark navy outline, flat cel shading, no anti-aliasing, no gradients
Composition/framing: centered object, readable silhouette, object fills 75 percent of the canvas, transparent background, generous padding
Color palette: warm institutional classroom palette: deep navy outline, cream paper, oak amber, chalk green, muted teal, soft gold accent
Constraints: no text except simple unreadable note lines or check marks; no watermark; no photorealism; no fantasy magic; must remain readable at 32x32
Avoid: potion bottle, spell, crystal, lightning, neon glow, complex scene, hands covering the object
```

For built-in image generation, request a flat chroma-key background if transparency is not directly available, then remove the background locally.

### F. Item-Specific Prompt Seeds

Use these as the `Primary request` line.

```text
Lesson Map:
a folded paper lesson plan with three tiny checkmarks and a small route line, like a teacher's objective map

Breathing Reset:
a calm pause card with a small breathing wave symbol and two soft blue air lines, teacher self-regulation tool

Student Profile Card:
an index card with a small student silhouette, two note lines, and a tiny heart/star asset marker

Quiet Signal:
a classroom attention signal card with a raised hand icon and a small quiet chime mark

Noticing Lens:
a magnifying glass over a speech bubble with one highlighted cue dot

Equity Snapshot:
a small participation tally grid with four student dots and one highlighted empty turn

Wait Meter Pin:
a stopwatch-shaped pin showing a clear three-second tick mark

Practice Goal Card:
a coaching goal card with a check mark, small upward arrow, and one blank practice line

Routine Card:
a posted classroom routine checklist on cream paper with three check boxes

Misconception Marker:
a pencil marking a thinking bubble with a small question notch

Repair Prompt:
a Coach Vee sticky note with a curved retry arrow and a tiny speech bubble

Evidence Tagger:
a rubric tag label with a check mark and tiny coding ticks

Coach Replay Token:
a replay triangle on a small note card with a circular arrow

Question Starter Pack:
a stack of question stem cards with question mark and speech bubble icons

Seating Note:
a tiny seating chart with one highlighted desk and a small caution dot
```

### G. Larger Inventory Card Art

Inventory cards should be larger than icons and can show context.

File pattern:

```text
assets/ui/items/cards/card_<item_id>.png
```

Target:

- 128x96 PNG
- transparent background or navy card-safe background
- object plus tiny classroom context
- no readable text inside the image
- the UI will render the actual text separately

Prompt template:

```text
Use case: stylized-concept
Asset type: 128x96 pixel-art inventory card illustration
Primary request: [ITEM NAME] shown as a real teacher tool on a classroom desk
Scene/backdrop: simple warm classroom desk surface, no busy background
Style/medium: 16-bit pixel art, Pokemon Gen-4 inspired, crisp outlines, flat cel shading, no gradients
Composition/framing: item centered with small contextual props only if they clarify use; leave clean negative space around edges
Color palette: deep navy, cream paper, oak amber, chalk green, muted teal, soft gold accent
Constraints: no readable text, no watermark, no fantasy effects, no photorealism
```

P1 card art should be created only after icons are approved, because cards inherit icon metaphors.

### H. Use-Feedback Effects

Items need small visual feedback so use feels deliberate.

| Effect | File | Used By | Visual |
|---|---|---|---|
| Calm pulse | `assets/ui/items/fx/fx_calm_pulse.png` | Breathing Reset | soft blue/cream expanding ring |
| Attention ping | `assets/ui/items/fx/fx_quiet_signal.png` | Quiet Signal | small chime/raised hand pulse |
| Cue highlight | `assets/ui/items/fx/fx_noticing_highlight.png` | Noticing Lens, Misconception Marker | gold rectangle/spark underline |
| Goal stamp | `assets/ui/items/fx/fx_goal_stamp.png` | Practice Goal Card | check mark stamp pop |
| Equity ping | `assets/ui/items/fx/fx_equity_ping.png` | Equity Snapshot | four dots lighting in sequence |

Effect prompt template:

```text
Use case: stylized-concept
Asset type: small pixel-art UI feedback effect sprite
Primary request: [EFFECT VISUAL]
Style/medium: 16-bit pixel-art UI effect, crisp 1px pixels, transparent background, simple readable shape
Composition/framing: centered effect, no object clutter, designed to animate by scaling/fading in Godot
Color palette: limited palette, soft gold/cream/teal/blue accents, no neon
Constraints: no text, no watermark, no photorealism, no complex scene
```

### I. Guidebook / Landing Illustrations

These are not in-game icons. They explain how the item system maps to real classroom practice.

Folder:

```text
landing/img/items/
```

Recommended images:

| File | Purpose | Scene |
|---|---|---|
| `items_teacher_toolkit.png` | landing section hero | teacher desk with item cards as classroom tools |
| `items_plan_enact_reflect.png` | guidebook diagram | four-stage cycle: Plan, Enact, Notice, Reflect |
| `items_equity_tracker_example.png` | guidebook example | participation tally beside classroom discussion |
| `items_recovery_example.png` | guidebook example | teacher pause card before responding |

Style:

- animation-style classroom illustration
- consistent with landing character art
- not pixel-art unless embedded as in-game screenshot
- no generated text; HTML overlays all labels

Prompt template:

```text
Use case: scientific-educational
Asset type: guidebook illustration for an educational game
Primary request: [SCENE PURPOSE]
Scene/backdrop: warm elementary classroom or teacher planning desk
Subject: real teacher tools represented as cards, notes, timers, and participation tracker
Style/medium: polished animation-style illustration matching a friendly educational game website, clean shapes, warm natural classroom lighting
Composition/framing: wide 16:9 image with clear negative space for HTML labels, no text inside the image
Color palette: warm classroom colors, navy accents, cream paper, chalk green, oak wood, muted teal
Constraints: no readable text, no logos, no watermark, no fantasy objects, no dark blurred stock-photo look
```

### J. Asset Filename Contract

All item icons:

```text
assets/ui/items/item_<item_id>.png
```

All card art:

```text
assets/ui/items/cards/card_<item_id>.png
```

All effects:

```text
assets/ui/items/fx/fx_<effect_id>.png
```

Guidebook/landing:

```text
landing/img/items/<purpose>.png
```

Do not reference generated files in code until they are copied into these folders.

### K. Post-Processing Pipeline

1. Generate at high resolution.
2. Choose the cleanest version.
3. Remove chroma-key background if needed.
4. Downscale with nearest-neighbor:
   - icon: 32x32
   - card: 128x96
   - effect: 48x48
5. Quantize to the project palette where possible.
6. Validate against:
   - readable at 32x32
   - transparent corners
   - no generated text
   - consistent outline weight
   - clear classroom-tool metaphor
7. Save to the exact filename contract.
8. Open Godot once or run export so `.import` files are generated.

### L. Generation Priority

Batch 1, MVP:

1. `item_lesson_map.png`
2. `item_breathing_reset.png`
3. `item_student_profile_card.png`
4. `item_quiet_signal.png`
5. `item_noticing_lens.png`
6. `item_equity_snapshot.png`
7. `item_wait_meter_pin.png`
8. `item_practice_goal_card.png`

Batch 2, expanded item set:

1. `item_routine_card.png`
2. `item_misconception_marker.png`
3. `item_repair_prompt.png`
4. `item_evidence_tagger.png`
5. `item_coach_replay_token.png`
6. `item_question_starter_pack.png`
7. `item_seating_note.png`

Batch 3, polish:

1. card art for MVP items
2. use-feedback effects
3. guidebook/landing illustrations

### M. Quality Gates

An item asset is accepted only if:

- a beginner can guess its general use within 3 seconds
- it still reads at 32x32
- it looks like a teacher/classroom tool
- it does not imply magic or cheating
- it matches the navy/cream/chalk/oak palette
- it has a transparent or cleanly removable background
- it contains no hallucinated readable text

Rejected if:

- the object is visually ambiguous
- the icon uses fantasy metaphors
- the image contains readable fake text
- the edge is blurry after downscaling
- the icon cannot be distinguished from an existing badge

### N. Code Integration After Images Exist

Once icons are generated:

1. Add paths to `data/items.json`.
2. Add `Art.tex(item.icon_path)` loading in Hub item overlay.
3. Add item strip rendering in Preview and active scenes.
4. Use the same icon path in guidebook/landing pages.
5. Log selected item icon IDs in telemetry only as item IDs, not image paths.

This keeps visuals data-driven and prevents item images from being hardcoded into every scene.
