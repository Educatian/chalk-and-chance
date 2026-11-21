# Two-language screen pass (2026-11-21)

One contact sheet per language per size: `en_1280x720.jpg`, `ko_1280x720.jpg`, and the same for 1560x720, 1024x768 and 390x844. Each tile is labelled `run/shot`.

## How the shots were taken

- **Off-screen and offline.** The shots come from headless Chromium running a local debug web export through `tools/qa/web_run.py`. Every non-local request is aborted. Every run in these sheets logged `NETWORK blocked=0` (144 of 144 final runs; every run, including failed attempts and re-runs, reported 0 blocked requests).
- **Each shot proves its screen.** A shot is saved only after an `expect` step finds that screen's marker: the scene path or a visible text, read from `window.__cc_state` (debug web builds only).
  - Navigation uses `press` with the button's English text, which also matches the shown Korean.
  - A wrong screen fails the run (exit 4) instead of producing a tile.
- **Debug hooks that set up a screen:**
  - `dev_room`, `dev_quiet`, `dev_korean=0|1` (the classroom look);
  - `dev_interrupt=N`, `dev_end`, `dev_group`, `dev_retry`;
  - `dev_win` with `dev_moves`, `dev_t0`, `dev_hold` and `dev_bond`;
  - `dev_screen=import|preview`.
- **Unasserted tiles.** The boot splash and the loading tile are taken before the engine runs, so they have no marker.
- **Portrait (390x844).** In portrait the game shows only the rotate prompt and pauses, so that size has the rotate prompt over the title and over a classroom, plus the boot frames.

## Screens covered (both languages, each landscape size)

- **Start:** title, language switch, sign-in form.
- **Hub:** hub with locked cards, settings, skill notebook, upgrade (no points), items, leaderboard, profile cycled, briefing.
- **Lesson start:** mission cinematic, then the lecture (start and later).
- **Classrooms:** discussion U-shape, independent rows and group clusters, each in both the US look and the Korean look. Each one shows the room, the objectives panel open and the Esc leave prompt.
- **Retry focus** objectives on a second attempt.
- **Interrupts:** all five interrupt cards, each with its outcome.
- **Encounter:**
  - the noticing strip and the moves;
  - the think ring (think → let it land → your move);
  - cut-off;
  - results C/D and results S/A (A, with a seeded bond).
- **Other modes:** gym, group check-in.
- **Debrief:** reflect, then review (classroom results), then the coach card.
- **Lesson tools:** import, import with the sample loaded, preview.

## Findings

| # | Found | Where | Status |
|---|---|---|---|
| 1 | Rotate prompt English in Korean | portrait, any screen | **Fixed.** The catalogue loads before `set_locale`. |
| 2 | Encounter delta line "Understanding +13 · Engagement +4 · Rapport +2" in English | encounter, Korean | **Fixed.** The parts are translated before they are joined. |
| 3 | Objectives panel title and skill names in English | classroom, Korean | **Fixed** |
| 4 | Esc leave prompt in English | classroom, Korean | **Fixed:** "수업을 여기서 끝낼까요? 지금 나가면 이번 시도는 기록되지 않아요." |
| 5 | Coach card "Coach Vee · no moves recorded" and "NEXT ROUND FOCUS" in English | debrief, Korean | **Fixed** |
| 6 | Preview summary all English, with English student names | preview, Korean | **Fixed.** The template is translated, names come from the localized persona, and the format, seating and badge names are translated. |
| 7 | Stiff wording: noticing "…거기에 맞춰 봐요/그걸로 답해요" and moment reason "(진단하고 파고들기)" | encounter, Korean | **Fixed:** "…쪽이에요. 그걸 골라 봐요." and "'진단하고 파고들기' 흐름에 딱 맞는 수였어요." |
| 8 | Objectives panel: wrapped lines lose their indent | classroom, both | **Left.** Cosmetic and pre-existing; nothing clips. |
| 9 | Preview "-15s / +15s" keep the Latin unit | preview, Korean | **Left.** Minor. |
| 10 | The O key (objectives) was sometimes ignored in the independent-work room: 3 of 12 runs, all `_kr` look; never in the other rooms. Those tiles come from re-runs that passed. | classroom, independent rows | **Left.** Needs a look at what holds `_unhandled_key_input` there. |
| 11 | Instructor panels and hosted-AI student answers stay English in Korean mode | instructor dashboard, live LLM | **Left.** Known; needs a decision and server-side prompts. |

These are not checkable from screenshots and need a human playtest:
- whether the Korean dialogue sounds like real children;
- the speech levels in long conversations;
- whether the think-ring timing feels right;
- whether the interrupt choices read as fair.
