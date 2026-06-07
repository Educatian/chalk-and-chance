# SCENES NOTES

Scope: everything under `scenes/`.

## Overview

Scene scripts are the playable and product UI surfaces. `Main.tscn` bootstraps, `ui/` handles menus/import/preview, `overworld/` handles classroom movement, `encounter/` handles rehearsal modes, and `dev/` contains executable QA scenes.

## Where To Look

| Task | Location | Notes |
| --- | --- | --- |
| Bootstrap | `Main.gd` | Sets `SceneRouter` stack and routes to Login/Hub. |
| Hub and product menus | `ui/Hub.gd` | Mission cards, profile cycling, items, settings, evidence. |
| Login/offline entry | `ui/Login.gd` | Auth path and skippable offline route. |
| Lesson import/preview | `ui/ImportLesson.gd`, `ui/PreviewScenario.gd` | User lesson JSON/import flow. |
| One-student encounter | `encounter/Encounter.gd` | Core menu/free-text teacher move loop. |
| Lecture mode | `encounter/LectureScene.gd` | Rows/whole-class mode. |
| Gym capstone | `encounter/GymEncounter.gd` | Multi-student capstone mode. |
| Overworld | `overworld/Overworld.gd`, `overworld/Player.gd` | Grid classroom, NPCs, interaction, debrief. |
| QA scenes | `dev/` | Smoke, playtest, screenshot, audits. |

## Conventions

- Product scene changes should go through `SceneRouter.change_scene()`.
- Keep UI readable at 960x540; regenerate `tools/ui_*.png` after layout changes.
- Use explicit `position`, `size`, font overrides, wrapping, and `clip_text` deliberately.
- Keep the first playable path quick: Hub -> briefing -> playable scene.
- Preserve keyboard/gamepad-ish routes: arrows/WASD, Z/Enter/Space where existing scenes support them.

## Anti-Patterns

- Do not introduce hidden dependencies on a specific saved game state in scenes.
- Do not assume a Button label equals the mission title; the Hub uses card content plus action buttons.
- Do not add permanent dense HUD panels over the center of playable scenes.
- Do not broaden huge scene scripts unless the task includes refactoring.
