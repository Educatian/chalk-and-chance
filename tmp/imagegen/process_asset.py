import argparse
from pathlib import Path

from PIL import Image


def parse_key(value: str) -> tuple[int, int, int]:
    value = value.strip().lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def remove_key(im: Image.Image, key: tuple[int, int, int], threshold: int) -> Image.Image:
    im = im.convert("RGBA")
    pixels = im.load()
    kr, kg, kb = key
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = pixels[x, y]
            distance = abs(r - kr) + abs(g - kg) + abs(b - kb)
            green_key = key == (0, 255, 0) and g > 180 and r < 90 and b < 120
            magenta_key = key == (255, 0, 255) and r > 180 and b > 180 and g < 100
            green_fringe = key == (0, 255, 0) and g > 70 and g > r + 28 and g > b + 28
            magenta_fringe = key == (255, 0, 255) and r > g + 35 and b > g + 35 and min(r, b) > 70
            if distance <= threshold or green_key or magenta_key or green_fringe or magenta_fringe:
                pixels[x, y] = (r, g, b, 0)
    return im


def expanded_crop_box(im: Image.Image, ratio: float, pad_frac: float) -> tuple[int, int, int, int]:
    bbox = im.getchannel("A").getbbox() or (0, 0, im.width, im.height)
    left, top, right, bottom = bbox
    width = right - left
    height = bottom - top
    pad = int(max(width, height) * pad_frac)
    left = max(0, left - pad)
    top = max(0, top - pad)
    right = min(im.width, right + pad)
    bottom = min(im.height, bottom + pad)

    cx = (left + right) / 2
    cy = (top + bottom) / 2
    width = right - left
    height = bottom - top
    if width / height < ratio:
        width = height * ratio
    else:
        height = width / ratio

    left = int(round(cx - width / 2))
    right = int(round(cx + width / 2))
    top = int(round(cy - height / 2))
    bottom = int(round(cy + height / 2))

    if left < 0:
        right -= left
        left = 0
    if top < 0:
        bottom -= top
        top = 0
    if right > im.width:
        left -= right - im.width
        right = im.width
    if bottom > im.height:
        top -= bottom - im.height
        bottom = im.height

    return max(0, left), max(0, top), min(im.width, right), min(im.height, bottom)


def save_sheet(src: Path, out: Path, key: tuple[int, int, int]) -> None:
    im = remove_key(Image.open(src), key, threshold=42)
    im = im.crop(expanded_crop_box(im, 96 / 256, 0.035))
    im = im.resize((96, 256), Image.Resampling.NEAREST)
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    print(f"{out} {im.width}x{im.height} {im.mode}")


def save_portraits(src: Path, prefix: Path, key: tuple[int, int, int]) -> None:
    im = remove_key(Image.open(src), key, threshold=42)
    im = im.crop(expanded_crop_box(im, 3.0, 0.025))
    im = im.resize((384, 128), Image.Resampling.NEAREST)
    names = ["neutral", "thinking", "excited"]
    prefix.parent.mkdir(parents=True, exist_ok=True)
    for i, name in enumerate(names):
        out = prefix.with_name(f"{prefix.name}_{name}.png")
        tile = im.crop((i * 128, 0, (i + 1) * 128, 128))
        tile.save(out)
        print(f"{out} {tile.width}x{tile.height} {tile.mode}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["sheet", "portraits"])
    parser.add_argument("src")
    parser.add_argument("out")
    parser.add_argument("--key", default="00ff00")
    args = parser.parse_args()

    key = parse_key(args.key)
    if args.mode == "sheet":
        save_sheet(Path(args.src), Path(args.out), key)
    else:
        save_portraits(Path(args.src), Path(args.out), key)


if __name__ == "__main__":
    main()
