# PROJECT KNOWLEDGE BASE

Generated: 2026-06-07
Mode: LazyCodex init-deep

## Overview

Chalk & Chance is a Godot 4 teacher-rehearsal game. The player practices classroom moves across hub, overworld, encounter, lecture, and gym/capstone scenes while telemetry, competency evidence, item loadouts, and local progression persist through autoloads.

## Structure

```
chalk-and-chance/
|-- project.godot       # Godot app config; launches scenes/Main.tscn
|-- autoload/           # global state, routing, items, telemetry, auth, LLM/TTS
|-- scenes/             # Main, UI, overworld, encounter, and dev QA scenes
|-- scripts/            # shared helpers: art, import, pixel UI, seating
|-- data/               # scenario JSON, persona JSON, competency/rubric data
|-- assets/             # sprites, portraits, backdrops, tiles, item icons
|-- tools/              # generated QA screenshots and sample lesson content
|-- docs/               # productization, screenshots, comparison notes
|-- landing/            # marketing/player-guide web assets
|-- cloudflare/         # deployment setup for related web surfaces
```

## Where To Look

| Task | Location | Notes |
| --- | --- | --- |
| Startup flow | `project.godot`, `scenes/Main.gd` | Main scene routes to Login or Hub. |
| Scene routing and transitions | `autoload/SceneRouter.gd` | Central `change_scene()` and branded wipe. |
| Persistent save/progression | `autoload/GameState.gd` | Badges, XP, settings, inventory, profile loadouts. |
| Item definitions and loadouts | `autoload/Items.gd` | Defaults, profile loadouts, badge rewards. |
| Scenario selection UI | `scenes/ui/Hub.gd` | Large UI surface; mission cards, modals, profile button. |
| Lesson preview/import | `scenes/ui/ImportLesson.gd`, `scenes/ui/PreviewScenario.gd` | Lesson-plan import and review flow. |
| Core one-student encounter | `scenes/encounter/Encounter.gd` | Persona loading, moves, item usage, LLM/stub evaluation. |
| Lecture/gym modes | `scenes/encounter/LectureScene.gd`, `scenes/encounter/GymEncounter.gd` | Multi-student mode variants. |
| Classroom movement | `scenes/overworld/Overworld.gd`, `scenes/overworld/Player.gd` | Grid movement, NPCs, interactions, debrief. |
| UI screenshots | `scenes/dev/UILayoutShots.gd`, `tools/ui_*.png` | Current visual QA evidence. |
| Product QA runner | `scripts/run_product_qa.ps1`, `scripts/validate_screenshots.ps1` | Regression and screenshot checks. |

## Commands

Run from this directory:

```powershell
& 'C:\Users\jewoo\godot\godot.exe' --path . --quit-after 3
& 'C:\Users\jewoo\godot\godot.exe' --headless --path . res://scenes/dev/Playtest.tscn
& 'C:\Users\jewoo\godot\godot.exe' --path . res://scenes/dev/UILayoutShots.tscn
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_screenshots.ps1 -Root .
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_product_qa.ps1
```

## Conventions

- Keep the game identity teacher-rehearsal first: classroom orchestration, differentiated student needs, and evidence-backed practice.
- Prefer small edits in existing Godot scripts; several scene scripts are large inherited surfaces.
- Keep text-heavy UI in Control nodes with explicit font sizes, wrapping, and screenshot QA.
- Use `GameState.ui_font_delta()` for large-text support.
- Use `GameState.get_setting("reduced_motion")` for non-essential transition/motion.
- Route scene changes through `SceneRouter.change_scene()` unless a dev scene is instantiating directly for tests.
- Route profile-specific defaults through `GameState.teacher_profile_id` and `Items.PROFILE_LOADOUTS`.
- Treat `data/scenarios/*.json` and `data/persona_library/*.json` as authored content; keep IDs stable.

## Anti-Patterns

- Do not assume the first mission is always lecture; `Game.SCENARIOS` currently starts with discussion/overworld.
- Do not use old assumptions in tests when Hub opens a briefing before launching a playable scene.
- Do not weaken the product into generic quiz/dashboard language.
- Do not edit generated `.godot/`, `dist_web/`, or QA PNGs by hand.
- Do not add broad rewrites to `Hub.gd`, `Encounter.gd`, `LectureScene.gd`, `GymEncounter.gd`, or `Overworld.gd` without a split plan.
- Do not bypass screenshot QA after visual, layout, HUD, or transition changes.

## Notes

- `tools/ui_*.png` are generated visual evidence, not disposable scratch files.
- `ObjectDB instances leaked at exit` can appear after forced quit/headless test exits; judge it with test output, not that warning alone.
- Live LLM/TTS paths exist, but dev QA usually forces stubs/offline behavior.
