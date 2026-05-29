from __future__ import annotations

from collections import Counter
from pathlib import Path
from typing import Iterable

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]


ASSETS = [
    ("tmp/imagegen/teacher_ow_source.png", "assets/sprites/teacher_ow.png", (16, 32), True),
    ("tmp/imagegen/noah_ow_source.png", "assets/sprites/noah_g5_fractions_ow.png", (16, 32), True),
    ("tmp/imagegen/noah_neutral_source.png", "assets/portraits/noah_g5_fractions_neutral.png", (64, 64), False),
    ("tmp/imagegen/noah_confused_source.png", "assets/portraits/noah_g5_fractions_confused.png", (64, 64), False),
    ("tmp/imagegen/noah_thinking_source.png", "assets/portraits/noah_g5_fractions_thinking.png", (64, 64), False),
    ("tmp/imagegen/noah_frustrated_source.png", "assets/portraits/noah_g5_fractions_frustrated.png", (64, 64), False),
    ("tmp/imagegen/noah_withdrawn_source.png", "assets/portraits/noah_g5_fractions_withdrawn.png", (64, 64), False),
    ("tmp/imagegen/noah_excited_source.png", "assets/portraits/noah_g5_fractions_excited.png", (64, 64), False),
]


# Compact game-ready palette based on the Resurrect family, with the ramps needed for
# skin, hair, navy portrait accents, muted classroom blues, and warm clothing.
PALETTE = [
    (46, 34, 47),
    (62, 53, 70),
    (98, 85, 101),
    (150, 108, 108),
    (171, 148, 122),
    (110, 39, 39),
    (179, 56, 49),
    (234, 79, 54),
    (245, 125, 74),
    (251, 185, 84),
    (76, 62, 36),
    (103, 102, 51),
    (162, 169, 71),
    (213, 224, 75),
    (22, 90, 76),
    (35, 144, 99),
    (30, 188, 115),
    (49, 54, 56),
    (55, 78, 74),
    (84, 126, 100),
    (146, 169, 132),
    (178, 186, 144),
    (11, 94, 101),
    (14, 175, 155),
    (50, 51, 83),
    (72, 74, 119),
    (77, 101, 180),
    (77, 155, 230),
    (143, 211, 255),
    (123, 60, 84),
    (207, 101, 127),
    (255, 255, 255),
]


def palette_image() -> Image.Image:
    pal = Image.new("P", (1, 1))
    flat: list[int] = []
    for rgb in PALETTE:
        flat.extend(rgb)
    flat.extend([0, 0, 0] * (256 - len(PALETTE)))
    pal.putpalette(flat)
    return pal


def border_pixels(img: Image.Image, width: int = 24) -> Iterable[tuple[int, int, int]]:
    rgb = img.convert("RGB")
    w, h = rgb.size
    px = rgb.load()
    for y in range(h):
        for x in range(w):
            if x < width or x >= w - width or y < width or y >= h - width:
                yield px[x, y]


def estimate_key(img: Image.Image) -> tuple[int, int, int]:
    rounded = Counter((r // 8 * 8, g // 8 * 8, b // 8 * 8) for r, g, b in border_pixels(img))
    key = rounded.most_common(1)[0][0]
    return key


def chroma_to_alpha(img: Image.Image) -> Image.Image:
    rgba = img.convert("RGBA")
    key = estimate_key(rgba)
    out = Image.new("RGBA", rgba.size)
    src = rgba.load()
    dst = out.load()
    kr, kg, kb = key
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = src[x, y]
            dist = ((r - kr) ** 2 + (g - kg) ** 2 + (b - kb) ** 2) ** 0.5
            green_bias = g - max(r, b)
            if dist < 85 or (green_bias > 70 and g > 120):
                dst[x, y] = (0, 0, 0, 0)
            else:
                dst[x, y] = (r, g, b, a)
    return out


def crop_and_letterbox(img: Image.Image, target: tuple[int, int], feet_bottom: bool) -> Image.Image:
    bbox = img.getbbox()
    if bbox is None:
        raise ValueError("image became fully transparent after chroma-key removal")

    w, h = img.size
    pad = max(4, min(w, h) // 64)
    left = max(0, bbox[0] - pad)
    top = max(0, bbox[1] - pad)
    right = min(w, bbox[2] + pad)
    bottom = min(h, bbox[3] + pad)
    cropped = img.crop((left, top, right, bottom))

    cw, ch = cropped.size
    target_ratio = target[0] / target[1]
    current_ratio = cw / ch
    if current_ratio < target_ratio:
        canvas_w = int(round(ch * target_ratio))
        canvas_h = ch
    else:
        canvas_w = cw
        canvas_h = int(round(cw / target_ratio))

    canvas_w = max(canvas_w, cw)
    canvas_h = max(canvas_h, ch)
    boxed = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    x = (canvas_w - cw) // 2
    y = canvas_h - ch if feet_bottom else (canvas_h - ch) // 2
    boxed.alpha_composite(cropped, (x, y))
    return boxed


def quantize_rgba(img: Image.Image) -> Image.Image:
    alpha = img.getchannel("A")
    rgb = Image.new("RGB", img.size, (0, 0, 0))
    rgb.paste(img.convert("RGB"), mask=alpha)
    q = rgb.quantize(palette=palette_image(), dither=Image.Dither.NONE).convert("RGBA")
    q.putalpha(alpha.point(lambda a: 255 if a >= 128 else 0))
    return q


def process(src: Path, dst: Path, target: tuple[int, int], feet_bottom: bool) -> None:
    img = Image.open(src)
    alpha = chroma_to_alpha(img)
    boxed = crop_and_letterbox(alpha, target, feet_bottom)
    resized = boxed.resize(target, Image.Resampling.NEAREST)
    final = quantize_rgba(resized)
    dst.parent.mkdir(parents=True, exist_ok=True)
    final.save(dst)


def main() -> None:
    failures: list[str] = []
    for src_rel, dst_rel, target, feet_bottom in ASSETS:
        src = ROOT / src_rel
        dst = ROOT / dst_rel
        try:
            process(src, dst, target, feet_bottom)
            with Image.open(dst) as check:
                print(f"WROTE {dst_rel} {check.size[0]}x{check.size[1]} {check.mode}")
        except Exception as exc:
            failures.append(f"FAILED {dst_rel}: {exc}")

    for failure in failures:
        print(failure)
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
