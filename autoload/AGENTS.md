# AUTOLOAD NOTES

Scope: everything under `autoload/`.

## Overview

Autoloads are global game services. They own save state, routing, item economy, telemetry, competency estimates, auth, LLM/TTS, audio, and voice input.

## Where To Look

| Task | Location | Notes |
| --- | --- | --- |
| Save data and settings | `GameState.gd` | Badges, XP, upgrades, inventory, profile, relationships. |
| Scene switching | `SceneRouter.gd` | `change_scene()`, active scene tracking, branded wipe. |
| Scenario catalog and labels | `Game.gd` | Scenario order, signatures, recommendation copy. |
| Item definitions | `Items.gd` | Inventory defaults, profile loadouts, badge rewards. |
| Competency model runtime | `Competency.gd` | Session competency estimates. |
| Event logging | `Telemetry.gd` | Turn/session records and upload hooks. |
| Offline/LLM judging | `LLMClient.gd` | Stub/live model boundary. |
| Audio/TTS/voice | `Sfx.gd`, `TTSClient.gd`, `VoiceInput.gd` | Respect settings and web support. |

## Conventions

- Keep `GameState` as the single source for persisted player/session state.
- Save after state mutations that should survive restart.
- Use `Items.has_item()` before storing or equipping item IDs.
- Keep profile-specific default equipment in `Items.PROFILE_LOADOUTS`; do not scatter profile constants in scenes.
- Respect `reduced_motion`, `large_text`, and audio settings from `GameState`.

## Anti-Patterns

- Do not make scenes own save schema.
- Do not route directly with `get_tree().change_scene_to_file()` from product scenes.
- Do not log raw private content, secrets, or full LLM payloads into persistent local notes.
- Do not require network availability for dev tests; use stubs where QA scenes already do.
