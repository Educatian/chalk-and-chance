# DEV SCENE NOTES

Scope: everything under `scenes/dev/`.

## Overview

Dev scenes are executable QA and audit harnesses. They instantiate product scenes, force deterministic settings, generate screenshots, and print pass/fail transcripts.

## Where To Look

| Task | Location | Notes |
| --- | --- | --- |
| End-to-end interaction | `Playtest.gd` | Boots Main, drives Hub, Overworld, Encounter. |
| UI screenshot set | `UILayoutShots.gd` | Writes `tools/ui_*.png`. |
| Basic smoke | `SmokeTest.gd` | Encounter and persona checks. |
| Product/content audit | `ProductContentAudit.gd`, `ScenarioIntegrityAudit.gd` | Data and product-surface checks. |
| Visual asset audit | `VisualAssetAudit.gd` | Asset presence/quality checks. |
| Standalone shots | `Shot.gd`, `ShotEnc.gd` | Product screenshot generation. |

## Commands

```powershell
& 'C:\Users\jewoo\godot\godot.exe' --headless --path . res://scenes/dev/Playtest.tscn
& 'C:\Users\jewoo\godot\godot.exe' --path . res://scenes/dev/UILayoutShots.tscn
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_screenshots.ps1 -Root .
```

## Conventions

- Keep dev scenes deterministic: stub LLM, disable TTS/audio where existing tests do.
- Do not depend on live network, microphone, or real credentials.
- Update tests when product UX changes; avoid stale assumptions about mission order or button text.
- Screenshot QA should use the normal renderer when visual output matters.

## Anti-Patterns

- Do not treat a headless scene-load pass as visual QA.
- Do not delete failing checks to make a run green; update the check to match real UX or fix the product behavior.
- Do not save private test content into generated screenshots or logs.
