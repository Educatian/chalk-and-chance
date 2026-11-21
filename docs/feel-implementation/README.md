# Feel and layout pass: before / after

Plan: `docs/game-feel-upgrade-plan.md` (PR #2). Owner decisions applied: objectives collapsible, wrong-move feedback informative (not punitive), rotate prompt in phone portrait, web/Compatibility as the primary target, synth sounds kept plus 5 signature cues.

All screenshots come from web exports viewed in headless Chromium (SwiftShader, no visible window): `before/` from `main` at 93a890b, `after/` from this branch. Input was sent only into the headless page. Software rendering means frame timing in these runs says nothing about real frame rate.

| # | Screen | Before | After |
|---|---|---|---|
| 01 | Title (Enter now starts the demo) | [before](before/01_title.jpg) | [after](after/01_title.jpg) |
| 02 | Hub after pressing Down (list follows focus) | [before](before/02_hub_focus_after_down_arrow.jpg) | [after](after/02_hub_focus_after_down_arrow.jpg) |
| 03 | Classroom HUD (bands clear of students) | [before](before/03_classroom_hud.jpg) | [after](after/03_classroom_hud.jpg) |
| 04 | Objectives opened with O | — | [after](after/04_classroom_objectives_open.jpg) |
| 05 | Esc in the classroom (before: straight to hub) | [before](before/05_esc_in_classroom.jpg) | [after](after/05_esc_in_classroom.jpg) |
| 06 | Click on a student: walked up, facing them | — | [after](after/06_tap_to_walk_next_to_student.jpg) |
| 07 | Wrong move (Tell): NOT YET chip, deltas | [before](before/07_encounter_wrong_move.jpg) | [after](after/07_encounter_wrong_move.jpg) |
| 08 | Right move (Revoice): LANDED chip, deltas | [before](before/08_encounter_right_move.jpg) | [after](after/08_encounter_right_move.jpg) |
| 09 | Right idea, too early (Extend first): TOO EARLY | — | [after](after/09_encounter_too_early.jpg) |
| 10 | Session complete (fits its panel, rank-D: no confetti) | [before](before/10_session_complete.jpg) | [after](after/10_session_complete.jpg) |
| 11 | Interrupt card sized to its text | [before](before/11_interrupt_card.jpg) | [after](after/11_interrupt_card.jpg) |
| 12 | Lecture move with verdict chip and deltas | [before](before/12_lecture_move.jpg) | [after](after/12_lecture_move.jpg) |
| 13 | 20:9 classroom (centred, no grey bars) | [before](before/13_wide_20x9_classroom.jpg) | [after](after/13_wide_20x9_classroom.jpg) |
| 14 | 20:9 encounter | [before](before/14_wide_20x9_encounter.jpg) | [after](after/14_wide_20x9_encounter.jpg) |
| 15 | Phone portrait (rotate prompt) | [before](before/15_phone_portrait.jpg) | [after](after/15_phone_portrait.jpg) |

`.gdignore` keeps Godot from importing these images into the game.
