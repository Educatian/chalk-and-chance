# Chalk & Chance - imagegen2 Asset Prompt Sheet

Generate these with **Codex 5.5 + imagegen2**, then drop the PNGs into the paths below.
The game is already asset-aware (`scripts/Art.gd`): if the file exists it is used, else a
placeholder ColorRect is shown. No code change is needed after you add an image.

Art target (GAME_CONCEPT.md section 8): Pokemon Gen-3/Gen-4 16-bit pixel look,
top-down overworld, warm institutional palette, readable faces for affect.

## Global style preamble (prepend to EVERY prompt)

> 16-bit pixel art, Pokemon Gen-4 (Nintendo DS) style, clean limited palette,
> crisp 1px outlines, no anti-aliasing, no gradients, flat cel shading, centered
> subject on a fully transparent background, sprite-sheet game asset.

## Palette

Author against **Resurrect 32** (CC0). Warm institutional mood: oak/amber desks,
chalk-green front wall, cream walls, locker blue, desaturated teal-grey floors.

## Output and post-processing rules (apply to every asset)

1. Generate large (e.g. 1024x1024), then **downscale with nearest-neighbor** to the
   target pixel size listed per asset (do not bilinear-resample).
2. **Quantize** to the Resurrect 32 palette (snap colors).
3. Background must be **transparent** (alpha), not white.
4. Save as **PNG**. Keep the exact filename and folder given below.
5. In Godot the texture filter is already global Nearest; just open the editor once so
   the PNG imports, then re-run.

---

## A. Overworld sprites (priority 1, needed first)

### A1. Teacher (player) overworld sprite
- File: `assets/sprites/teacher_ow.png`
- Target size: **16x32** px (tall trainer; feet aligned to bottom)
- Prompt: *[global preamble]* a friendly early-career schoolteacher seen from a
  front-facing top-down RPG overworld angle, simple cardigan and slacks, short hair,
  warm approachable face, standing idle, full body, 16x32 pixel character sprite.

### A2. Noah (student) overworld sprite
- File: `assets/sprites/noah_g5_fractions_ow.png`
- Target size: **16x32** px
- Prompt: *[global preamble]* a shy 10-year-old boy student seen from a front-facing
  top-down RPG overworld angle, striped t-shirt, slightly hunched guarded posture,
  full body, 16x32 pixel character sprite.

(Later: a 48x128 sheet of 4 directions x 3 walk frames per character. For M1 a single
front idle frame is enough.)

---

## B. Noah affect portraits (priority 1, the emotional core)

Six 64x64 head-and-shoulders portraits, same boy, consistent design across all six,
only the expression changes. Files go in `assets/portraits/`. The encounter swaps them
by state automatically (`_affect_for()`), so expressions must read at a glance.

| Affect | File | Expression to draw |
|---|---|---|
| neutral | `noah_g5_fractions_neutral.png` | guarded, mouth flat, looking slightly away |
| confused | `noah_g5_fractions_confused.png` | brow furrowed, head tilted, puzzled |
| thinking | `noah_g5_fractions_thinking.png` | eyes up, finger near chin, working it out |
| frustrated | `noah_g5_fractions_frustrated.png` | tense, looking down, arms-crossed feel |
| withdrawn | `noah_g5_fractions_withdrawn.png` | shrinking back, eyes down, shut-down |
| excited | `noah_g5_fractions_excited.png` | bright eyes, small open-mouth "aha" smile |

- Target size: **64x64** px each
- Prompt template (fill EXPRESSION from the table): *[global preamble]* head and
  shoulders portrait of a shy 10-year-old boy student with short brown hair and a
  striped shirt, **EXPRESSION**, soft warm key light from the left, deep-navy vignette
  behind him, 64x64 pixel-art character portrait. Keep the face design identical across
  the set; change only the expression.

Tip: generate `neutral` first, then ask imagegen2 to keep the same character and only
change the expression for the other five (consistency).

---

## C. Classroom tileset (priority 2)

- File: `assets/tiles/classroom_16.png` (a 16x16 tile atlas)
- Target tiles: floor, wall + wall-top, desk, chair, chalk-green board, window, door
  (3-frame open), lockers, bookshelf, poster, plant, bin.
- Prompt: *[global preamble]* a 16x16 top-down RPG interior tileset atlas for a primary
  school classroom: wooden floor tile, cream wall and wall-top, oak student desk, chair,
  chalk-green chalkboard, window, wooden door, lockers, bookshelf, poster, potted plant,
  trash bin; arranged on a tidy grid, each tile self-contained.
- After generating, slice into a Godot TileSet in the editor (manual step; MCP is weak
  at TileSet authoring).

---

## D. UI / badges (priority 3)

- Files in `assets/ui/`: `badge_routine.png`, `badge_echo.png`, `badge_balance.png`,
  `badge_mirror.png`, `badge_insight.png`, `capstone_seal.png` (32x32 each), and a
  `dialogue_frame.png` 9-slice box (navy fill, cream 1px border).
- Badge prompt template: *[global preamble]* a small 32x32 pixel-art achievement badge
  icon for a teaching skill called **NAME**, gym-badge shape, metallic rim, single clear
  emblem (Routine=clock/checklist, Echo=speech-bubble, Balance=scales, Mirror=hand-mirror,
  Insight=eye/lightbulb), transparent background.

---

## E. Item icons (priority 4, item system)

Detailed system plan: `ITEM_SYSTEM_EMBEDDING_PLAN.md` section 17.

Status: **P0 accepted and implemented.** The current official MVP icons are the clean
64x64 transparent PNGs generated by `scripts/create_clean_item_icons.py`. Keep these
as the in-game source set unless a later art pass explicitly replaces the whole set.

All item icons:

- Folder: `assets/ui/items/`
- Current MVP source size: **64x64** px
- Minimum readable display size: **32x32** px
- Background: transparent PNG
- Style: same pixel-art UI style as badges, but less metallic and more like real teacher tools.
- Constraint: classroom-tool metaphor, not fantasy/magic.

Global item icon prompt:

> 16-bit pixel art, Pokemon Gen-4 Nintendo DS inspired classroom UI item icon,
> crisp 1px dark navy outline, flat cel shading, no anti-aliasing, no gradients,
> centered object on transparent background, readable at 32x32, warm institutional
> classroom palette: cream paper, oak amber, chalk green, muted teal, soft gold accent.
> No readable text, no watermark, no potion, no spell, no crystal, no neon magic.

MVP item icons:

| Item | File | Prompt subject |
|---|---|---|
| Lesson Map | `assets/ui/items/item_lesson_map.png` | folded paper lesson plan with three tiny checkmarks and a small route line |
| Breathing Reset | `assets/ui/items/item_breathing_reset.png` | calm pause card with a small breathing wave symbol and two soft blue air lines |
| Student Profile Card | `assets/ui/items/item_student_profile_card.png` | index card with a small student silhouette, two note lines, and a tiny heart/star asset marker |
| Quiet Signal | `assets/ui/items/item_quiet_signal.png` | classroom attention signal card with a raised hand icon and a small quiet chime mark |
| Noticing Lens | `assets/ui/items/item_noticing_lens.png` | magnifying glass over a speech bubble with one highlighted cue dot |
| Equity Snapshot | `assets/ui/items/item_equity_snapshot.png` | participation tally grid with four student dots and one highlighted empty turn |
| Wait Meter Pin | `assets/ui/items/item_wait_meter_pin.png` | stopwatch-shaped pin showing a clear three-second tick mark |
| Practice Goal Card | `assets/ui/items/item_practice_goal_card.png` | coaching goal card with a check mark, small upward arrow, and one blank practice line |

Expanded item icons:

| Item | File | Prompt subject |
|---|---|---|
| Routine Card | `assets/ui/items/item_routine_card.png` | posted classroom routine checklist on cream paper with three check boxes |
| Misconception Marker | `assets/ui/items/item_misconception_marker.png` | pencil marking a thinking bubble with a small question notch |
| Repair Prompt | `assets/ui/items/item_repair_prompt.png` | Coach Vee sticky note with a curved retry arrow and a tiny speech bubble |
| Evidence Tagger | `assets/ui/items/item_evidence_tagger.png` | rubric tag label with a check mark and tiny coding ticks |
| Coach Replay Token | `assets/ui/items/item_coach_replay_token.png` | replay triangle on a small note card with a circular arrow |
| Question Starter Pack | `assets/ui/items/item_question_starter_pack.png` | stack of question stem cards with question mark and speech bubble icons |
| Seating Note | `assets/ui/items/item_seating_note.png` | tiny seating chart with one highlighted desk and a small caution dot |

---

## Filename contract (must match the code exactly)

```
assets/sprites/teacher_ow.png                 16x32   player overworld
assets/sprites/noah_g5_fractions_ow.png       16x32   Noah overworld   (= <persona_id>_ow.png)
assets/portraits/noah_g5_fractions_<affect>.png  64x64  affect in {neutral,confused,thinking,frustrated,withdrawn,excited}
assets/tiles/classroom_16.png                 atlas   (manual TileSet slice)
assets/ui/badge_<name>.png                     32x32
assets/ui/items/item_<item_id>.png             32x32   item icon
```

`<persona_id>` is the JSON key in `data/persona_library/` (Noah = `noah_g5_fractions`).
Add a new student by dropping `<id>_ow.png` + six `<id>_<affect>.png` portraits.
