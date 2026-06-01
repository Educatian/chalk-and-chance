from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "ui" / "items"
CONTACT = ROOT / "tmp" / "imagegen" / "items" / "mvp_item_icons_contact.png"

SIZE = 64
SCALE = 4
W = SIZE * SCALE

NAVY = (16, 30, 55, 255)
CREAM = (255, 245, 218, 255)
PAPER_EDGE = (222, 201, 159, 255)
GREEN = (46, 139, 88, 255)
TEAL = (49, 150, 139, 255)
BLUE = (45, 105, 175, 255)
GOLD = (232, 174, 51, 255)
ORANGE = (204, 125, 43, 255)
RED = (197, 73, 85, 255)
GRAY = (92, 95, 98, 255)
WHITE = (255, 255, 255, 255)
TRANSPARENT = (0, 0, 0, 0)


def canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (W, W), TRANSPARENT)
    return img, ImageDraw.Draw(img)


def save_icon(img: Image.Image, name: str) -> Image.Image:
    icon = img.resize((SIZE, SIZE), Image.Resampling.NEAREST)
    icon.save(OUT_DIR / name)
    return icon


def rect(d: ImageDraw.ImageDraw, xy: tuple[int, int, int, int], fill, outline=NAVY, width=4) -> None:
    d.rounded_rectangle(xy, radius=4 * SCALE, fill=fill, outline=outline, width=width * SCALE)


def line(d: ImageDraw.ImageDraw, points, fill=NAVY, width=4) -> None:
    d.line([(x * SCALE, y * SCALE) for x, y in points], fill=fill, width=width * SCALE, joint="curve")


def thick_check(d: ImageDraw.ImageDraw, x: int, y: int, color=GREEN) -> None:
    line(d, [(x, y + 6), (x + 5, y + 11), (x + 15, y)], fill=NAVY, width=5)
    line(d, [(x, y + 6), (x + 5, y + 11), (x + 15, y)], fill=color, width=3)


def lesson_map() -> Image.Image:
    img, d = canvas()
    pts = [(8, 10), (22, 14), (32, 10), (42, 14), (56, 10), (56, 49), (42, 53), (32, 49), (22, 53), (8, 49)]
    d.polygon([(x * SCALE, y * SCALE) for x, y in pts], fill=NAVY)
    inner = [(11, 14), (23, 17), (32, 14), (41, 17), (53, 14), (53, 46), (41, 49), (32, 46), (23, 49), (11, 46)]
    d.polygon([(x * SCALE, y * SCALE) for x, y in inner], fill=CREAM)
    line(d, [(23, 17), (23, 49)], fill=PAPER_EDGE, width=2)
    line(d, [(41, 17), (41, 49)], fill=PAPER_EDGE, width=2)
    for y in (20, 30, 40):
        thick_check(d, 13, y - 4)
        line(d, [(30, y), (38, y)], fill=GRAY, width=3)
    line(d, [(46, 19), (39, 27), (45, 34), (34, 42)], fill=GOLD, width=3)
    d.ellipse((36 * SCALE, 38 * SCALE, 45 * SCALE, 47 * SCALE), fill=GOLD, outline=NAVY, width=3 * SCALE)
    return img


def breathing_reset() -> Image.Image:
    img, d = canvas()
    rect(d, (10 * SCALE, 12 * SCALE, 54 * SCALE, 52 * SCALE), CREAM)
    d.rectangle((49 * SCALE, 15 * SCALE, 54 * SCALE, 49 * SCALE), fill=TEAL)
    line(d, [(17, 29), (22, 24), (27, 29), (32, 34), (37, 29), (42, 24), (47, 29)], fill=BLUE, width=4)
    line(d, [(20, 40), (26, 43), (38, 43), (44, 40)], fill=(89, 174, 204, 255), width=3)
    line(d, [(23, 47), (32, 49), (41, 47)], fill=(89, 174, 204, 255), width=2)
    return img


def student_profile() -> Image.Image:
    img, d = canvas()
    rect(d, (9 * SCALE, 13 * SCALE, 55 * SCALE, 51 * SCALE), CREAM)
    rect(d, (15 * SCALE, 19 * SCALE, 29 * SCALE, 34 * SCALE), TEAL, width=3)
    d.ellipse((18 * SCALE, 21 * SCALE, 26 * SCALE, 29 * SCALE), fill=NAVY)
    d.rectangle((19 * SCALE, 29 * SCALE, 27 * SCALE, 34 * SCALE), fill=GREEN)
    line(d, [(35, 22), (49, 22)], fill=GRAY, width=3)
    line(d, [(35, 31), (49, 31)], fill=GRAY, width=3)
    d.polygon([(36 * SCALE, 42 * SCALE), (40 * SCALE, 38 * SCALE), (44 * SCALE, 42 * SCALE), (42 * SCALE, 47 * SCALE), (38 * SCALE, 47 * SCALE)], fill=RED)
    d.polygon([(48 * SCALE, 37 * SCALE), (50 * SCALE, 42 * SCALE), (55 * SCALE, 42 * SCALE), (51 * SCALE, 45 * SCALE), (53 * SCALE, 50 * SCALE), (48 * SCALE, 47 * SCALE), (43 * SCALE, 50 * SCALE), (45 * SCALE, 45 * SCALE), (41 * SCALE, 42 * SCALE), (46 * SCALE, 42 * SCALE)], fill=GOLD, outline=NAVY)
    return img


def quiet_signal() -> Image.Image:
    img, d = canvas()
    rect(d, (12 * SCALE, 10 * SCALE, 52 * SCALE, 54 * SCALE), CREAM)
    d.rectangle((24 * SCALE, 22 * SCALE, 38 * SCALE, 43 * SCALE), fill=(221, 155, 82, 255), outline=NAVY, width=3 * SCALE)
    for x in (18, 23, 29, 35, 40):
        d.rounded_rectangle((x * SCALE, 16 * SCALE, (x + 6) * SCALE, 33 * SCALE), radius=2 * SCALE, fill=(238, 180, 96, 255), outline=NAVY, width=2 * SCALE)
    line(d, [(42, 28), (49, 24), (53, 28)], fill=BLUE, width=3)
    d.polygon([(41 * SCALE, 43 * SCALE), (49 * SCALE, 43 * SCALE), (51 * SCALE, 51 * SCALE), (39 * SCALE, 51 * SCALE)], fill=GOLD, outline=NAVY)
    d.ellipse((43 * SCALE, 51 * SCALE, 47 * SCALE, 55 * SCALE), fill=NAVY)
    return img


def noticing_lens() -> Image.Image:
    img, d = canvas()
    d.rounded_rectangle((7 * SCALE, 21 * SCALE, 42 * SCALE, 47 * SCALE), radius=10 * SCALE, fill=WHITE, outline=NAVY, width=4 * SCALE)
    d.polygon([(20 * SCALE, 47 * SCALE), (17 * SCALE, 55 * SCALE), (29 * SCALE, 47 * SCALE)], fill=WHITE, outline=NAVY)
    d.ellipse((28 * SCALE, 17 * SCALE, 54 * SCALE, 43 * SCALE), fill=TEAL, outline=NAVY, width=4 * SCALE)
    d.ellipse((35 * SCALE, 24 * SCALE, 47 * SCALE, 36 * SCALE), fill=CREAM, outline=NAVY, width=2 * SCALE)
    d.ellipse((39 * SCALE, 28 * SCALE, 43 * SCALE, 32 * SCALE), fill=GREEN)
    line(d, [(49, 39), (57, 51)], fill=NAVY, width=6)
    line(d, [(49, 39), (57, 51)], fill=(143, 89, 43, 255), width=4)
    d.ellipse((13 * SCALE, 32 * SCALE, 17 * SCALE, 36 * SCALE), fill=GRAY)
    d.ellipse((22 * SCALE, 32 * SCALE, 26 * SCALE, 36 * SCALE), fill=GRAY)
    return img


def equity_snapshot() -> Image.Image:
    img, d = canvas()
    rect(d, (10 * SCALE, 12 * SCALE, 54 * SCALE, 52 * SCALE), CREAM)
    for x in (24, 38):
        line(d, [(x, 13), (x, 51)], fill=GRAY, width=2)
    for y in (26, 40):
        line(d, [(11, y), (53, y)], fill=GRAY, width=2)
    colors = [GREEN, BLUE, (126, 83, 166, 255), ORANGE]
    positions = [(16, 17), (31, 17), (16, 31), (31, 31)]
    for (x, y), color in zip(positions, colors):
        d.ellipse((x * SCALE, y * SCALE, (x + 7) * SCALE, (y + 7) * SCALE), fill=color, outline=NAVY, width=2 * SCALE)
        d.rectangle((x * SCALE, (y + 8) * SCALE, (x + 8) * SCALE, (y + 14) * SCALE), fill=color, outline=NAVY, width=2 * SCALE)
    d.rectangle((43 * SCALE, 32 * SCALE, 50 * SCALE, 46 * SCALE), outline=GOLD, width=3 * SCALE)
    return img


def wait_meter() -> Image.Image:
    img, d = canvas()
    d.polygon([(32 * SCALE, 57 * SCALE), (43 * SCALE, 45 * SCALE), (21 * SCALE, 45 * SCALE)], fill=TEAL, outline=NAVY)
    d.ellipse((17 * SCALE, 11 * SCALE, 47 * SCALE, 49 * SCALE), fill=CREAM, outline=NAVY, width=4 * SCALE)
    d.rectangle((25 * SCALE, 7 * SCALE, 39 * SCALE, 13 * SCALE), fill=GOLD, outline=NAVY, width=3 * SCALE)
    line(d, [(32, 18), (32, 33)], fill=NAVY, width=4)
    line(d, [(32, 33), (25, 37)], fill=NAVY, width=4)
    for x1, y1, x2, y2 in [(32, 43, 32, 47), (22, 36, 18, 38), (42, 36, 46, 38)]:
        line(d, [(x1, y1), (x2, y2)], fill=NAVY, width=3)
    return img


def practice_goal() -> Image.Image:
    img, d = canvas()
    rect(d, (9 * SCALE, 16 * SCALE, 55 * SCALE, 49 * SCALE), CREAM)
    d.rectangle((16 * SCALE, 23 * SCALE, 30 * SCALE, 37 * SCALE), fill=(168, 221, 150, 255), outline=NAVY, width=3 * SCALE)
    thick_check(d, 18, 24)
    line(d, [(36, 40), (49, 27)], fill=NAVY, width=6)
    line(d, [(36, 40), (49, 27)], fill=GOLD, width=4)
    d.polygon([(49 * SCALE, 21 * SCALE), (53 * SCALE, 32 * SCALE), (42 * SCALE, 28 * SCALE)], fill=GOLD, outline=NAVY)
    line(d, [(17, 44), (49, 44)], fill=GRAY, width=3)
    return img


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    CONTACT.parent.mkdir(parents=True, exist_ok=True)

    makers = [
        ("item_lesson_map.png", lesson_map),
        ("item_breathing_reset.png", breathing_reset),
        ("item_student_profile_card.png", student_profile),
        ("item_quiet_signal.png", quiet_signal),
        ("item_noticing_lens.png", noticing_lens),
        ("item_equity_snapshot.png", equity_snapshot),
        ("item_wait_meter_pin.png", wait_meter),
        ("item_practice_goal_card.png", practice_goal),
    ]
    icons = [save_icon(make(), name) for name, make in makers]

    contact = Image.new("RGBA", (4 * 88, 2 * 88), (35, 39, 47, 255))
    for index, icon in enumerate(icons):
        x = (index % 4) * 88 + 12
        y = (index // 4) * 88 + 12
        contact.alpha_composite(icon, (x, y))
    contact.save(CONTACT)


if __name__ == "__main__":
    main()
