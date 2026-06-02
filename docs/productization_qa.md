# Chalk & Chance Product QA Gates

This checklist treats the game as a releasable educational product, not only a prototype.

## Gates

- Project load: Godot opens the project without parse errors.
- UI audit: no clipped/out-of-viewport controls, overlapping interactives, clipped Label text, undersized Button text, or tight dialogue-box padding on key screens in both normal and large-text modes, including long dialogue stress cases, Hub overlays, completion panels, reflection prompts, and the overworld final debrief.
- Visual asset audit: required backdrops/item icons exist; visible TextureRects, Button icons, and Sprite2Ds have textures, render at usable size, and avoid unintended non-uniform sprite/TextureRect squash.
- Learning surface content audit: Hub, Evidence Journal, mission briefing, click-feedback notices, and leaderboard keep the differentiating learning text visible, including adaptive coaching, practice target, research edge, unlock guidance, and leaderboard evidence.
- Scenario/data integrity: every scenario has valid mission fields, objectives, badge unlocks, story/backdrop assets, roster persona/portrait links, persona overrides, and competency-model coverage for runtime evidence skills.
- Visual screenshots: login, hub, click-feedback notices for locked/temporarily unavailable functions, mission briefing, evidence journal, leaderboard, settings, upgrades, items, import, preview, encounter, lecture, gym, group check-in, reflection, and overworld debrief are refreshed, then validated for expected dimensions, non-tiny file size, pixel variety, and luminance range so blank or broken captures cannot silently pass.
- Learning loop: encounter smoke test proves differentiated moves, badge reward, level progress, and competency evidence.
- Classroom formats: lecture, gym, overworld, group check-in, independent work, and imported lesson paths run.
- Evidence layer: telemetry/xAPI writes turn evidence and competency signals.
- Product motivation: Hub shows level progress, next upgrade XP, items, adaptive practice recommendation, and local leaderboard.
- Mission clarity: selecting a mission opens a briefing with scenario art, story hook, success conditions, evidence edge, reward, and first-move guidance before rehearsal starts.
- Learning evidence visibility: Hub includes an Evidence Journal showing competency estimates, evidence counts, uncertainty, research anchors, recent run evidence, and an evidence-backed next practice target.
- Debrief consistency: encounter, lecture, gym, group check-in, and overworld lesson endings show explicit score drivers, next focus, reward/progression information where applicable, and player-controlled Continue/replay actions.

## One Command

Run from the project root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_product_qa.ps1
```

The report is written to `tools/product_qa_report.txt`.
