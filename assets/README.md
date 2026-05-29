# assets/

Pixel-art assets for Chalk & Chance. Generate per `../ASSET_PROMPTS.md` with
Codex 5.5 + imagegen2, then place files here using the exact filename contract.

```
sprites/    teacher_ow.png, <persona_id>_ow.png            (16x32 overworld)
portraits/  <persona_id>_<affect>.png                       (64x64 encounter faces)
tiles/      classroom_16.png                                (16x16 atlas, slice in editor)
ui/         badge_*.png, capstone_seal.png, dialogue_frame.png
```

The game falls back to placeholder ColorRects when a file is missing (`scripts/Art.gd`),
so you can add art incrementally. Open the project in the Godot editor once after adding
PNGs so they import, then run. Texture filter is global Nearest (set in project.godot).
