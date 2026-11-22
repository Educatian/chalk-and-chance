# Open items after the #3–#7 merge: evidence

All runs were offline. Shots came from headless Chromium driving a local debug export through `tools/qa/web_run.py`, and every run reported `NETWORK blocked=0`. Suites ran in headless Godot. Nothing was deployed, and nothing called the hosted Worker.

## Before and after

`before_after.jpg` shows items 1, 3, 4 and 5 in both languages at 1280x720. The individual frames are in `before/` (main as of 1a3d60f) and `after/` (this branch).

| item | before | after |
|---|---|---|
| 1 cinematic | `before/1_cinematic_{en,ko}.png`: painterly wood-and-chalkboard room; "▸▸" drawn as boxes. `before/1_cinematic_flat_{en,ko}.png`: the first redraw, a flat near-empty room | `after/1_cinematic_{en,ko}.png`: composed front-of-class title frame, title on its own band; `after/1_cinematic_chapter1_beats_{en,ko}.png`: every beat of chapter 1 in game; `cinematic_frames_{us,kr}.png`: all 124 frames |
| 3 objectives panel | `before/3_objectives_{en,ko}.png`: wrapped lines fall back to the left edge | `after/3_objectives_{en,ko}.png`: two-column rows keep their indent; the plate fits the text |
| 4 preview units | `before/4_preview_ko.png`: "- 15s / + 15s" | `after/4_preview_ko.png`: "-15초 / +15초"; Korean room picture |
| 5 instructor panel | `before/5_leaderboard_{en,ko}.png`: "Class" / "반 전체" dashboard button for everyone | `after/5_leaderboard_{en,ko}.png`: no button for a learner or the public demo |

Design pass (follow-up review):
| screen | before | after |
|---|---|---|
| coach card | `before/11_coach_card_*.png`: fixed tall card, mostly empty | `after/11_coach_card_*.png`: sized to content, a good first move when no moves were made |
| debrief review / results | `before/11_debrief_review_*.png`: fixed slots, empty band | `after/11_debrief_review_*.png`, `after/11_results_sa_*.png`: flows and centres |
| gym | `before/12_gym_*.png`: empty dialogue panel, "Redir." | `after/12_gym_*.png`: opens on the student's line, "Redirect" |
| group check-in | `before/12_group_checkin_*.png`: flat dark screen, small faces | `after/12_group_checkin_*.png`: the room behind, the group large at a table |

Item 10 evidence (fixes found in the review pass):
- `after/10_interrupt_outcome_{en,ko}.png`: the interrupt's coaching line stays up.
- `after/10_import_sample_{en,ko}.png`: "Use sample" works, and Korean mode loads a Korean sample.

## Checks added

- **Item 2.** FeelCheck "O closes … stays closed when an objective flips": 10 tries in headless Godot.
  - Before the fix: 10 of 10 tries reopened the panel.
  - After the fix: 0 of 10.
  - In the browser, 24 runs × 8 presses (Korean look, independent and discussion rooms, under parallel load): 192 of 192 correct after the fix, against 5 of 12 runs mismatching before.
- **Item 5.**
  - FeelCheck role table (4 cases) and the leaderboard Class button for the public demo, a learner and an instructor.
  - ProductContentAudit fails if a non-instructor sees Class.
- **Item 6.** `node --test cloudflare/test/`: 9 cases against a stubbed fetch that refuses any other host.
- **Item 7.** `python -I tools/ops/test_telemetry_scripts.py`. The fixture dry run is in `telemetry_scripts_dryrun.txt`.
- **Item 10.**
  - FeelCheck: the coaching line stays; Esc closes the objectives panel.
  - ImportTest: Korean plan; samples are in the export.
  - ScenarioIntegrity and VisualAsset audits now require both room pictures and both cinematic rooms.
