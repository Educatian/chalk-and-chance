# Chalk & Chance Beginner QA Audit

Date: 2026-06-01  
Build audited: `main`, local repo `C:\Users\jewoo\Projects\chalk-and-chance`  
Engine: Godot `4.6.3.stable.official`  
Perspective: first-time player with no teacher-education vocabulary and no prior knowledge of the project.

## Verification Run

- `SmokeTest`: PASS, including differentiated-win check for Deshawn.
- `GymTest`: PASS.
- `Playtest`: PASS, `12 / 12`, after Login skip and deterministic stub mode.
- Visual review covered: Login, Hub, Lecture, Overworld, Encounter, Free Text, Debrief, Gym, Import, Preview, Competency readout.

## Implementation Status

2026-06-01 revision pass:

- P0-1 addressed: Login now presents `Play demo` as the primary action before class sign-in.
- P0-2 addressed: Hub now orders playable missions first, marks the first open mission as `START HERE`, and explains badge meanings.
- P0-3 addressed: Encounter move buttons now preview plain-language examples on hover/focus.
- P0-4 addressed: Encounter and Lecture now show explicit `Wait 3s` readiness states.
- P0-5 addressed: Encounter, Lecture, and Gym now show action-result chips for meter changes and whether a move fit the student.
- P0-6 addressed: Offline free-text now uses a local rule classifier for common teacher utterances and telemetry records actual `input_mode` plus text.
- P0-7 addressed: Encounter success no longer auto-advances; a `Continue` button controls return to the overworld.
- P0-8 addressed: Overworld now shows live objective progress and interaction hints.
- P1-1 addressed: Encounter buttons are now split into two rows to reduce clipping, with hover/focus help.
- P1-2 addressed: Lecture makes the selected `Question` target explicit and shows action-result feedback.
- P1-3 addressed: Overworld now shows `Press Z to talk to <student>` when facing an interactable student.
- P1-4 addressed: Debrief misses now use `[MISS]` with targeted next-step tips.
- P1-6 addressed: Added generated SFX cues for click, correct move, wrong move, badge, and interruption.
- P1-7 addressed: Gym now shows current target, student need, and action-result feedback.
- P1-8 addressed: Preview now frames imported lessons as a scenario card with class, challenge, win condition, and first recommended move.

- P1-5 addressed: competency panel now explains the bars as live practice estimates, shows evidence count, and names a next practice focus.
- P2-3 addressed: reflection choices now adapt to missed objective type.
- P2-4 addressed for this slice: added Settings with audio, large text, reduced motion, and dialogue reveal controls; added WASD/Space input alternatives.
- P2-5 addressed: scenario preview now validates required fields, roster, objectives, and period length before enabling play.
- P3 addressed for this slice: added typewriter/instant dialogue reveal, scene wipe transitions with reduced-motion bypass, larger badge unlock card, existing scenario arrangement variety, teacher idle/walk support, and the settings menu.

## Executive Diagnosis

The game has a strong research-backed skeleton and a surprisingly broad feature set, but the beginner experience currently feels like a vertical-slice research prototype rather than a polished first playable. The main weakness is not missing content. It is missing **interpretive support**: players can press buttons and complete tests, but they are often not told clearly what the goal is, why a move worked, what changed numerically, or what to try next.

Using the 5-component filter:

- **Clarity: weak.** Many expert terms are exposed before the player has a mental model.
- **Response: medium.** Inputs work, but feedback is often delayed or too subtle.
- **Satisfaction: medium-low.** Badges and competency readouts exist, but success does not land strongly.
- **Motivation: medium.** The mission/badge structure is present, but locked paths and goals are not explained enough.
- **Fit: strong.** Pixel classroom, teacher rehearsal, and research framing fit the identity well.

## P0 Issues

### P0-1. First screen makes the player feel like they need credentials

**Where:** Login screen.  
**Observed:** The screen opens with class code, name, password, and a secondary "Skip - play as guest" button.  
**Beginner impact:** A casual player may assume they are not allowed to play without a class code.  
**Fix:** Make the primary CTA `Play demo` or `Play as guest`; move class login below it as `Class sign in`. Add one sentence: "No account needed for the demo."

### P0-2. Hub does not clearly say where to start

**Where:** Mission hub.  
**Observed:** The top mission is locked, while the first playable mission is the second row. Several rows are locked with badge names that are not yet meaningful.  
**Beginner impact:** The player sees "locked" before they understand progression.  
**Fix:** Put the first playable mission at the top or add a `Start here` marker to `Intro to Fractions`. Add a badge legend or line: "Earn Routine in Intro to Fractions to unlock classroom missions."

### P0-3. Teaching move labels are expert vocabulary

**Where:** Encounter move row: `Elicit`, `Extend`, `Revoice`, `Connect`, `Redirect`, `Wait`.  
**Observed:** The terms are pedagogically correct but not self-explanatory.  
**Beginner impact:** A player guesses based on word vibes instead of learning the practice.  
**Fix:** On hover/focus, show a short example sentence and expected use case. Example: `Elicit: Ask how the student got that answer.` For keyboard/gamepad, show this preview when a button has focus.

### P0-4. Wait-Time mechanic is under-telegraphed

**Where:** Encounter and Lecture.  
**Observed:** There is a Wait-Time bar, but it is not obvious that the player must pause about 3 seconds before acting.  
**Beginner impact:** Players may press `Wait` immediately and fail without understanding the timing rule.  
**Fix:** Change the bar label to `Wait 3s before choosing`. Add color states: gray = too soon, green = ready. When too early, show `Too soon: hold the pause longer`.

### P0-5. Actions do not show clear cause-and-effect deltas

**Where:** Encounter, Lecture, Gym.  
**Observed:** Bars move, but there is no explicit `+Engagement`, `-Trust`, `Understanding +12%`, or "wrong for this student" marker next to the action.  
**Beginner impact:** The player cannot build a model of why the choice worked.  
**Fix:** Add short floating result chips after each move: `Understanding +12`, `Rapport +10`, `This helped Talia`, `This did not address Noah's misconception`.

### P0-6. Free-text mode promises more than offline mode can deliver

**Where:** Encounter free text.  
**Observed:** UI says the player can type what they say, but the deterministic stub only reads `menu_tag`; free-text classification depends on the live backend. Telemetry also records `input_mode: "menu"` in `Encounter.gd` even for typed input.  
**Beginner impact:** A demo player may type a good teacher utterance and get generic or misleading feedback.  
**Fix:** Either disable/label free text in offline mode (`Live AI required`) or add a local keyword/rule classifier for common beginner utterances. Also log actual input mode in telemetry.

### P0-7. Encounter win readout auto-advances too quickly

**Where:** Encounter success and competency panel.  
**Observed:** The game returns to overworld after a timer.  
**Beginner impact:** Players may miss the badge, competency explanation, and why they succeeded.  
**Fix:** Replace auto-return with a `Continue` button. Keep timer only as a fallback after a much longer delay.

### P0-8. Overworld objectives are hidden during the lesson

**Where:** Overworld.  
**Observed:** HUD shows attention, disruptions, period, composure, and engaged count, but not the exact objectives needed to win the mission.  
**Beginner impact:** The player cannot tell what "good enough" means until debrief.  
**Fix:** Add collapsible objective checklist: `Attention >= 65`, `Engage 6/6`, `Use wait time 3x`, etc. Mark live progress.

## P1 Issues

### P1-1. Some button labels are cramped or clipped

**Where:** Encounter move row.  
**Observed:** At screenshot scale, `Revoice`, `Connect`, and `Redirect` visually crowd the bottom bar.  
**Fix:** Use two rows, icon+short label, or wider buttons with responsive text. Recommended first pass: two rows of 4 buttons plus a separate `Type` toggle.

### P1-2. Selected student in Lecture mode is easy to miss

**Where:** Lecture mode.  
**Observed:** The selected student is highlighted, and `Question` acts on that student, but this dependency is not prominent.  
**Beginner impact:** The player may think `Question` is generic.  
**Fix:** Add text near the button row: `Question asks: Jordan`. Add left/right or tab controls to switch students.

### P1-3. Overworld interaction affordance is too implicit

**Where:** Classroom overworld.  
**Observed:** Students have emote bubbles, but the player still needs to know adjacency plus `Z`.  
**Beginner impact:** First-time players may stand near a student but not know whether they are in range.  
**Fix:** When adjacent, show `Press Z to talk to Talia` above the HUD. Highlight the facing tile.

### P1-4. Debrief uses `[ -- ]` instead of a readable miss state

**Where:** Debrief overlay.  
**Observed:** Missed objectives appear as `[ -- ]`.  
**Beginner impact:** It reads like debug output, not coaching.  
**Fix:** Use `[MISS]` or `Not yet`, followed by a targeted next step: `Confer with every student: 0/8 reached`.

### P1-5. Competency panel lacks explanation

**Where:** Encounter success panel.  
**Observed:** It shows skill bars and `n=`, but not what `n` means or how to improve.  
**Beginner impact:** It looks like an assessment dashboard, not a learning aid.  
**Fix:** Add small labels: `Evidence count`, `Strong evidence`, `Try next: wait time`. Consider showing one sentence per low skill.

### P1-6. Audio and tactile feedback are missing from the player loop

**Where:** Whole game.  
**Observed:** Visual feedback exists, but no reliable SFX/BGM in local play.  
**Beginner impact:** Correct and incorrect moves feel flatter than they should.  
**Fix:** Add minimum SFX pass: button click, meter up/down, misconception hit, badge earned, interruption sting, footsteps.

### P1-7. Gym mode is mechanically interesting but visually dense

**Where:** Gym encounter.  
**Observed:** Four students, two bars each, target label, coach text, and seven actions all compete for attention.  
**Beginner impact:** It is hard to parse who is urgent and why.  
**Fix:** Add priority cues: pulse the most urgent student, label each student's need in plain language, and show `Current target: Deshawn` beside the action row.

### P1-8. Import/Preview flow is useful but feels like a tool, not a game

**Where:** Import lesson and Preview screen.  
**Observed:** Clear enough for instructors, but dry for a first-time game player.  
**Fix:** Add a generated scenario card with `Your class`, `Your challenge`, `Win condition`, and `First recommended move`. Keep the raw details in an expandable panel.

## P2 Issues

### P2-1. Locked-mission copy should explain the learning arc

Current copy names required badges but does not explain why the player needs them. Add one-line region descriptions: `Routine = manage pacing`, `Echo = surface reasoning`, `Balance = distribute attention`.

### P2-2. Class attention and off-task bars need a legend

The small bars over students are visible but unexplained. Add a one-time overlay: `Green means focused; red means drifting. Move closer to lower it.`

### P2-3. Reflection prompt is conceptually strong but too abstract

`What stays with you?` is good for teacher education, but a game beginner may not know how to choose. Add scenario-specific reflection options based on missed objectives.

### P2-4. Accessibility needs an explicit pass

Current UI relies on small pixel text, color bars, and keyboard assumptions. Add settings for larger font, reduced motion, remappable keys, and colorblind-safe bar patterns.

### P2-5. Scenario schema validation should become user-facing

The import feature can generate custom scenarios. If a scenario is malformed, the player should see a clear error instead of fallback behavior or silent weirdness.

## P3 Polish

- Add typewriter text reveal, but allow instant-skip.
- Add Pokemon-style wipe between overworld and encounters.
- Add badge fanfare and a large badge card on unlock.
- Add more classroom visual variety: posters, subject-specific objects, different rooms.
- Add small idle animations for the teacher in all scenes, not just students.
- Add a settings menu: text speed, audio, keybindings, font size.

## Recommended Next Sprint

1. Rework first-run onboarding: `Play demo` primary, `Start here` mission, badge explanation.
2. Add move tooltips/examples and wait-time ready/not-ready states.
3. Add per-action result chips for meter deltas and whether the move targeted the student's need.
4. Add live objective checklist in overworld and clearer debrief misses.
5. Fix free-text offline behavior or label it as live-AI-only; correct telemetry `input_mode`.
6. Replace encounter auto-return with a `Continue` button.
7. Add minimum SFX pass for click, correct move, wrong move, badge, interruption.

## Code Hotspots

- `scenes/ui/Login.gd`: first-screen CTA hierarchy.
- `scenes/ui/Hub.gd`: start-here marker, badge legend, lock explanation.
- `scenes/overworld/Overworld.gd`: objective checklist, nearby interaction prompt, debrief wording.
- `scenes/encounter/Encounter.gd`: move tooltips, wait-time states, result chips, free-text telemetry, continue button.
- `scenes/encounter/LectureScene.gd`: selected-student affordance and result feedback.
- `scenes/encounter/GymEncounter.gd`: urgency cues and target explanation.
- `autoload/LLMClient.gd`: local free-text classifier fallback if live backend unavailable.
- `autoload/TTSClient.gd`: audio fallback and SFX integration.
