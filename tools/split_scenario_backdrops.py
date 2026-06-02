from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageEnhance


SCENARIOS = [
    "lecture_fractions",
    "independent_fractions",
    "discussion_fractions",
    "group_work_fractions",
    "reading_main_idea",
    "science_force_motion",
    "culturally_responsive_intro",
    "custom_comparing_decimals",
    "gym_capstone",
]


def _gutter_runs(values: list[float], threshold: float = 0.86) -> list[tuple[int, int]]:
    runs: list[tuple[int, int]] = []
    start = -1
    for i, v in enumerate(values):
        if v >= threshold and start < 0:
            start = i
        elif v < threshold and start >= 0:
            if i - start >= 3:
                runs.append((start, i))
            start = -1
    if start >= 0 and len(values) - start >= 3:
        runs.append((start, len(values)))
    return runs


def _panel_bounds(img: Image.Image) -> list[tuple[int, int, int, int]]:
    rgb = img.convert("RGB")
    w, h = rgb.size
    px = rgb.load()

    col_white: list[float] = []
    for x in range(w):
        white = 0
        for y in range(h):
            r, g, b = px[x, y]
            if r > 235 and g > 235 and b > 235:
                white += 1
        col_white.append(white / float(h))

    row_white: list[float] = []
    for y in range(h):
        white = 0
        for x in range(w):
            r, g, b = px[x, y]
            if r > 235 and g > 235 and b > 235:
                white += 1
        row_white.append(white / float(w))

    vruns = [r for r in _gutter_runs(col_white) if 20 < r[0] < w - 20]
    hruns = [r for r in _gutter_runs(row_white) if 20 < r[0] < h - 20]
    vcuts = [0] + [int((a + b) / 2) for a, b in vruns[:2]] + [w]
    hcuts = [0] + [int((a + b) / 2) for a, b in hruns[:2]] + [h]
    if len(vcuts) != 4 or len(hcuts) != 4:
        vcuts = [0, w // 3, (2 * w) // 3, w]
        hcuts = [0, h // 3, (2 * h) // 3, h]

    bounds: list[tuple[int, int, int, int]] = []
    pad = 5
    for row in range(3):
        for col in range(3):
            left = vcuts[col] + (pad if col > 0 else 0)
            right = vcuts[col + 1] - (pad if col < 2 else 0)
            top = hcuts[row] + (pad if row > 0 else 0)
            bottom = hcuts[row + 1] - (pad if row < 2 else 0)
            bounds.append((left, top, right, bottom))
    return bounds


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--out", default="assets/backdrops")
    args = parser.parse_args()

    source = Path(args.source)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    img = Image.open(source).convert("RGB")
    img.save(out / "scenario_backdrops_atlas.png")

    for name, box in zip(SCENARIOS, _panel_bounds(img)):
        crop = img.crop(box)
        crop.thumbnail((640, 360), Image.Resampling.LANCZOS)
        canvas = Image.new("RGB", (640, 360), (18, 22, 34))
        x = (640 - crop.width) // 2
        y = (360 - crop.height) // 2
        canvas.paste(crop, (x, y))
        canvas = ImageEnhance.Color(canvas).enhance(0.92)
        canvas = ImageEnhance.Contrast(canvas).enhance(0.95)
        canvas.save(out / f"{name}.png", optimize=True)
        thumb = canvas.resize((320, 180), Image.Resampling.LANCZOS)
        thumb.save(out / f"{name}_thumb.png", optimize=True)

    print(f"Wrote {len(SCENARIOS)} backdrops to {out}")


if __name__ == "__main__":
    main()
