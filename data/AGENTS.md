# DATA NOTES

Scope: everything under `data/`.

## Overview

Data files define scenarios, personas, competency evidence, and judge rubrics. They are authored game content and assessment logic inputs, not throwaway fixtures.

## Where To Look

| Task | Location | Notes |
| --- | --- | --- |
| Built-in missions | `scenarios/*.json` | Scenario IDs are used by Hub, routing, reports, and tests. |
| Student/persona behavior | `persona_library/*.json` | Hidden needs, moves, lines, assets, policy. |
| Scenario schema | `scenario_schema.json` | Import/validation contract. |
| Competency model | `competency_model.json` | ECD-style evidence model. |
| Judge rubric | `judge_rubric.json` | Move classification/evaluation rules. |

## Conventions

- Keep scenario and persona IDs stable.
- Prefer adding fields that degrade gracefully through `.get()` in scene code.
- Keep `badge`, `mode`, `format`, `roster`, `objectives`, and `story_hook` meaningful for UI cards and routing.
- Persona copy should support teacher-rehearsal authenticity, not generic chatbot flavor.

## Anti-Patterns

- Do not rename IDs casually; saves, screenshots, tests, and evidence records may reference them.
- Do not put secrets, real student data, or raw private transcripts in JSON fixtures.
- Do not weaken rubric/persona content into generic quiz answers.
