# Lesson-Plan Import - customize the sim to your own lesson

Yes, this works, and it is the natural capstone of the data-driven design: a scene is just a
JSON config, so importing a lesson plan = transforming the plan into one scenario JSON the
game already knows how to play. A teacher rehearses the exact lesson they are about to teach.

## Pipeline

1. **Input** the lesson plan: paste text, or pick a file (.txt / .md now; .docx / .pdf via the
   backend parser). In a desktop build this is a FileDialog; in the web build, a file input.
2. **Transform** the plan into a scenario JSON, schema-constrained. Two backends:
   - **LLM (recommended):** send the plan to an LLM with the scenario JSON schema + the mapping
     rules below; it returns a validated scenario. Reuses the same backend as the student
     dialogue (local Ollama or cloud), or the already-working `codex exec` path (no new key).
   - **Heuristic (offline):** a simple form/parser maps grade + subject + format + duration +
     objectives to a scenario; less rich but dependency-free.
3. **Validate** (arrangement enum, seat indices in range for the arrangement, metric enum,
   persona ids known); fall back to defaults on any bad field.
4. **Write** to `data/scenarios/custom_<slug>.json` (dev) or `user://scenarios/` (runtime). The
   **hub auto-discovers** it (Hub scans the scenarios folder), so it appears as a playable
   mission immediately.

## What the plan controls

| Lesson-plan element | Becomes in-game |
|---|---|
| Activity format (discussion / lecture / group / independent) | `arrangement` (U-shape / rows / clusters / rows) - seating by task |
| Duration (minutes) | `period_seconds` (scaled to a short round) |
| Learning objectives + success criteria | `objectives` (attention / equity / wait-time / composure / disruptions) |
| Subject + topic + anticipated misconception | `persona_overrides`: each student's opening_line / win_line / target_label rewritten to the lesson content |
| Grade | persona grade band |
| Pedagogical emphasis (questioning / management / equity / feedback / diagnosis) | `badge` (echo / routine / balance / mirror / insight) |

The **pedagogy stays universal** (each persona's `win_moves` - the move that works - are
fixed by the research); only the **content** (what the students say and misunderstand) and the
**format/objectives** change per lesson. That is exactly right: you rehearse the same
high-leverage moves against your own lesson's content.

## Status / demo

- Hub auto-discovery of `data/scenarios/*.json`: DONE.
- Per-scenario `persona_overrides` (content-specific student lines/targets): DONE
  (`Encounter._apply_scenario_overrides`).
- Converter spec + sample: `tools/lesson_to_scenario_prompt.txt` + `tools/sample_lesson_plan.md`;
  run via `codex exec` to generate `data/scenarios/custom_*.json`. (Demo: a 5th-grade
  "comparing decimals" number-talk plan -> a U-shape discussion scenario.)

## Production next steps

- In-game **FileDialog / paste box** + a "Import a lesson" button on the hub.
- Backend `/lesson_to_scenario` endpoint (FastAPI) with .docx/.pdf parsing (python-docx, pypdf).
- Write customs to `user://scenarios/` and scan that folder too (so it works in an exported
  build, not just from source).
- A confirmation/preview screen so the teacher can tweak the generated scenario before playing.
