from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tmp" / "imagegen" / "items" / "mvp_item_sheet_raw.png"
OUT_DIR = ROOT / "assets" / "ui" / "items"
CONTACT = ROOT / "tmp" / "imagegen" / "items" / "mvp_item_icons_contact.png"

NAMES = [
    "item_lesson_map.png",
    "item_breathing_reset.png",
    "item_student_profile_card.png",
    "item_quiet_signal.png",
    "item_noticing_lens.png",
    "item_equity_snapshot.png",
    "item_wait_meter_pin.png",
    "item_practice_goal_card.png",
]

CROP_BOXES = [
    (60, 55, 480, 430),
    (500, 55, 900, 430),
    (900, 65, 1320, 430),
    (1320, 65, 1690, 455),
    (60, 500, 480, 890),
    (500, 460, 900, 890),
    (880, 410, 1260, 915),
    (1260, 495, 1715, 890),
]


def is_background_green(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, _a = pixel
    return g > 100 and g > r * 1.35 and g > b * 1.35


def remove_connected_chroma(cell: Image.Image) -> Image.Image:
    img = cell.convert("RGBA")
    width, height = img.size
    px = img.load()
    visited = [[False for _ in range(width)] for _ in range(height)]
    q: deque[tuple[int, int]] = deque()

    def enqueue_if_bg(x: int, y: int) -> None:
        if not visited[y][x] and is_background_green(px[x, y]):
            visited[y][x] = True
            q.append((x, y))

    for x in range(width):
        enqueue_if_bg(x, 0)
        enqueue_if_bg(x, height - 1)
    for y in range(height):
        enqueue_if_bg(0, y)
        enqueue_if_bg(width - 1, y)

    while q:
        x, y = q.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < width and 0 <= ny < height:
                enqueue_if_bg(nx, ny)

    for y in range(height):
        for x in range(width):
            if visited[y][x]:
                r, g, b, _a = px[x, y]
                px[x, y] = (r, g, b, 0)

    return img


def crop_to_square_icon(img: Image.Image, size: int = 32) -> Image.Image:
    alpha = img.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return Image.new("RGBA", (size, size), (0, 0, 0, 0))

    left, top, right, bottom = bbox
    pad = max(right - left, bottom - top) // 12
    left = max(0, left - pad)
    top = max(0, top - pad)
    right = min(img.width, right + pad)
    bottom = min(img.height, bottom + pad)

    content = img.crop((left, top, right, bottom))
    side = max(content.width, content.height)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.alpha_composite(content, ((side - content.width) // 2, (side - content.height) // 2))
    return square.resize((size, size), Image.Resampling.NEAREST)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    CONTACT.parent.mkdir(parents=True, exist_ok=True)

    sheet = Image.open(SOURCE).convert("RGBA")
    icons: list[Image.Image] = []

    for index, name in enumerate(NAMES):
        cell = sheet.crop(CROP_BOXES[index])
        transparent = remove_connected_chroma(cell)
        icon = crop_to_square_icon(transparent, 32)
        icon.save(OUT_DIR / name)
        icons.append(icon)

    contact = Image.new("RGBA", (4 * 80, 2 * 80), (35, 39, 47, 255))
    for index, icon in enumerate(icons):
        preview = icon.resize((64, 64), Image.Resampling.NEAREST)
        x = (index % 4) * 80 + 8
        y = (index // 4) * 80 + 8
        contact.alpha_composite(preview, (x, y))
    contact.save(CONTACT)


if __name__ == "__main__":
    main()
