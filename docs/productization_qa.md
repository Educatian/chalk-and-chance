# Chalk & Chance Product QA Gates

This checklist treats the game as a releasable educational product, not only a prototype.

## Gates

- Project load: Godot opens the project without parse errors.
- UI audit: no clipped/out-of-viewport controls, overlapping interactives, clipped Label text, undersized Button text, or tight dialogue-box padding on key screens, including Hub overlays for mission briefing, evidence journal, leaderboard, settings, upgrades, and items.
- Visual asset audit: required backdrops/item icons exist; visible TextureRects and Sprite2Ds have textures, render at usable size, and avoid unintended non-uniform sprite squash.
- Scenario/data integrity: every scenario has valid mission fields, objectives, badge unlocks, story/backdrop assets, roster persona/portrait links, persona overrides, and competency-model coverage for runtime evidence skills.
- Visual screenshots: login, hub, mission briefing, evidence journal, leaderboard, settings, upgrades, items, import, preview, encounter, lecture, gym, and group check-in are refreshed and inspected.
- Learning loop: encounter smoke test proves differentiated moves, badge reward, level progress, and competency evidence.
- Classroom formats: lecture, gym, overworld, group check-in, and imported lesson paths run.
- Evidence layer: telemetry/xAPI writes turn evidence and competency signals.
- Product motivation: Hub shows level progress, next upgrade XP, items, adaptive practice recommendation, and local leaderboard.
- Mission clarity: selecting a mission opens a briefing with scenario art, story hook, success conditions, evidence edge, reward, and first-move guidance before rehearsal starts.
- Learning evidence visibility: Hub includes an Evidence Journal showing competency estimates, evidence counts, uncertainty, research anchors, and recent run evidence.

## One Command

Run from the project root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_product_qa.ps1
```

The report is written to `tools/product_qa_report.txt`.
