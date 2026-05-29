from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]

NAVY = (22, 31, 54, 255)
INK = (34, 26, 24, 255)
CREAM = (246, 239, 219, 255)
CREAM_HI = (255, 249, 232, 255)
CREAM_SH = (225, 211, 184, 255)
OAK = (178, 112, 48, 255)
OAK_HI = (218, 154, 78, 255)
OAK_SH = (111, 66, 34, 255)
GREEN = (55, 112, 82, 255)
GREEN_DK = (33, 71, 55, 255)
BLUE = (93, 153, 201, 255)
BLUE_HI = (151, 205, 230, 255)
METAL = (180, 177, 164, 255)
METAL_HI = (235, 230, 204, 255)
METAL_SH = (92, 91, 94, 255)
GOLD = (227, 171, 62, 255)
WHITE = (255, 255, 248, 255)
TRANSPARENT = (0, 0, 0, 0)


def new(size, bg=TRANSPARENT):
    return Image.new("RGBA", size, bg)


def upscale_down(img, size):
    src = img.resize((size[0] * 4, size[1] * 4), Image.Resampling.NEAREST)
    return src.resize(size, Image.Resampling.NEAREST)


def save(img, rel):
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    final = upscale_down(img, img.size)
    final.save(path)
    return path


def draw_floor(size=(32, 32)):
    img = new(size, OAK)
    d = ImageDraw.Draw(img)
    for y in range(0, 32, 8):
        d.rectangle([0, y, 31, y], fill=OAK_SH)
        d.rectangle([0, y + 1, 31, y + 1], fill=OAK_HI)
    seam_sets = [(0, 16, 32), (8, 24, 40), (0, 12, 32), (20, 32, 44)]
    for band, xs in enumerate(seam_sets):
        y0 = band * 8
        for x in xs:
            if 0 <= x <= 31:
                d.line([(x, y0 + 1), (x, y0 + 7)], fill=OAK_SH)
                if x + 1 <= 31:
                    d.point((x + 1, y0 + 2), fill=OAK_HI)
        for x in range(2, 31, 7):
            color = OAK_HI if (x + band) % 2 else (156, 91, 39, 255)
            d.point((x, y0 + 4), fill=color)
            d.point(((x + 3) % 32, y0 + 6), fill=color)
    return img


def draw_wall():
    img = new((32, 32), CREAM)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 31, 4], fill=CREAM_HI)
    d.line([0, 5, 31, 5], fill=CREAM_SH)
    d.line([0, 31, 31, 31], fill=(214, 198, 170, 255))
    for p in [(5, 10), (18, 8), (27, 14), (9, 22), (22, 25), (13, 29)]:
        d.point(p, fill=(236, 225, 202, 255))
    return img


def draw_board():
    img = new((32, 32), GREEN)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 31, 4], fill=OAK_SH)
    d.rectangle([0, 1, 31, 2], fill=OAK_HI)
    d.rectangle([0, 27, 31, 31], fill=OAK_SH)
    d.rectangle([0, 27, 31, 28], fill=OAK_HI)
    d.rectangle([0, 5, 31, 26], fill=GREEN)
    d.line([0, 5, 31, 5], fill=GREEN_DK)
    d.line([0, 26, 31, 26], fill=GREEN_DK)
    for x, y in [(5, 10), (13, 8), (23, 14), (8, 21), (28, 19)]:
        d.point((x, y), fill=(115, 162, 129, 255))
    d.line([18, 23, 25, 23], fill=(210, 207, 180, 255))
    return img


def draw_desk():
    img = draw_floor()
    d = ImageDraw.Draw(img)
    d.rectangle([6, 8, 25, 23], fill=INK)
    d.rectangle([7, 7, 24, 21], fill=OAK_SH)
    d.rectangle([8, 8, 23, 20], fill=(188, 121, 54, 255))
    d.rectangle([8, 8, 23, 10], fill=OAK_HI)
    d.line([8, 20, 23, 20], fill=(126, 73, 38, 255))
    d.rectangle([13, 10, 21, 16], fill=(236, 232, 206, 255))
    d.line([17, 10, 17, 16], fill=(117, 143, 168, 255))
    d.point((15, 12), fill=(117, 143, 168, 255))
    d.point((20, 13), fill=(117, 143, 168, 255))
    d.rectangle([8, 22, 10, 24], fill=OAK_SH)
    d.rectangle([21, 22, 23, 24], fill=OAK_SH)
    return img


def draw_door():
    img = draw_wall()
    d = ImageDraw.Draw(img)
    d.rectangle([7, 3, 24, 31], fill=INK)
    d.rectangle([8, 4, 23, 31], fill=(136, 82, 40, 255))
    d.rectangle([10, 7, 21, 16], fill=OAK)
    d.rectangle([10, 19, 21, 28], fill=OAK)
    d.line([10, 7, 21, 7], fill=OAK_HI)
    d.line([10, 19, 21, 19], fill=OAK_HI)
    d.rectangle([20, 16, 21, 18], fill=GOLD)
    d.line([8, 5, 23, 5], fill=OAK_HI)
    return img


def draw_window():
    img = draw_wall()
    d = ImageDraw.Draw(img)
    d.rectangle([5, 6, 26, 23], fill=NAVY)
    d.rectangle([7, 8, 24, 21], fill=BLUE)
    d.rectangle([8, 9, 15, 15], fill=BLUE_HI)
    d.rectangle([17, 9, 23, 15], fill=(118, 181, 219, 255))
    d.rectangle([8, 17, 15, 20], fill=(77, 133, 186, 255))
    d.rectangle([17, 17, 23, 20], fill=(71, 124, 176, 255))
    d.line([16, 8, 16, 21], fill=NAVY)
    d.line([7, 16, 24, 16], fill=NAVY)
    d.rectangle([4, 24, 27, 27], fill=OAK_SH)
    d.rectangle([5, 24, 26, 25], fill=OAK_HI)
    return img


def badge_base(fill):
    img = new((64, 64))
    d = ImageDraw.Draw(img)
    pts = [(32, 3), (46, 7), (57, 19), (58, 36), (48, 53), (32, 61), (16, 53), (6, 36), (7, 19), (18, 7)]
    d.polygon(pts, fill=NAVY)
    pts2 = [(32, 6), (45, 10), (54, 20), (55, 35), (46, 50), (32, 57), (18, 50), (9, 35), (10, 20), (19, 10)]
    d.polygon(pts2, fill=METAL_SH)
    pts3 = [(32, 9), (43, 13), (51, 22), (52, 34), (44, 47), (32, 53), (20, 47), (12, 34), (13, 22), (21, 13)]
    d.polygon(pts3, fill=METAL)
    pts4 = [(32, 13), (41, 16), (48, 24), (48, 33), (41, 43), (32, 49), (23, 43), (16, 33), (16, 24), (23, 16)]
    d.polygon(pts4, fill=fill)
    d.line([21, 14, 31, 10, 42, 14], fill=METAL_HI)
    d.point((18, 24), fill=METAL_HI)
    d.point((46, 42), fill=METAL_SH)
    return img


def draw_clock_badge():
    img = badge_base((80, 132, 142, 255))
    d = ImageDraw.Draw(img)
    d.ellipse([21, 18, 42, 39], outline=NAVY, width=3, fill=(236, 232, 198, 255))
    d.line([32, 28, 32, 21], fill=NAVY, width=2)
    d.line([32, 28, 38, 31], fill=NAVY, width=2)
    for x, y in [(24, 44), (24, 49), (24, 54)]:
        d.rectangle([x, y, x + 2, y + 2], fill=GOLD)
        d.line([29, y + 1, 42, y + 1], fill=WHITE)
    return img


def draw_echo_badge():
    img = badge_base((92, 137, 188, 255))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([18, 20, 45, 38], radius=5, fill=WHITE, outline=NAVY, width=3)
    d.polygon([(25, 38), (20, 47), (33, 38)], fill=WHITE)
    d.line([(25, 38), (20, 47), (33, 38)], fill=NAVY, width=3)
    d.rectangle([24, 27, 39, 29], fill=(92, 137, 188, 255))
    return img


def draw_balance_badge():
    img = badge_base((111, 150, 98, 255))
    d = ImageDraw.Draw(img)
    d.line([32, 18, 32, 43], fill=NAVY, width=3)
    d.line([20, 24, 44, 24], fill=NAVY, width=3)
    d.line([22, 24, 17, 35], fill=NAVY, width=2)
    d.line([22, 24, 27, 35], fill=NAVY, width=2)
    d.line([42, 24, 37, 35], fill=NAVY, width=2)
    d.line([42, 24, 47, 35], fill=NAVY, width=2)
    d.polygon([(15, 35), (29, 35), (26, 42), (18, 42)], fill=GOLD, outline=NAVY)
    d.polygon([(35, 35), (49, 35), (46, 42), (38, 42)], fill=GOLD, outline=NAVY)
    d.rectangle([26, 44, 38, 47], fill=NAVY)
    d.rectangle([28, 41, 36, 44], fill=GOLD)
    return img


def draw_mirror_badge():
    img = badge_base((160, 104, 145, 255))
    d = ImageDraw.Draw(img)
    d.ellipse([20, 14, 44, 38], fill=(190, 222, 231, 255), outline=NAVY, width=3)
    d.arc([24, 18, 40, 34], 200, 320, fill=WHITE, width=2)
    d.line([32, 38, 32, 50], fill=NAVY, width=4)
    d.rectangle([27, 49, 37, 53], fill=NAVY)
    d.rectangle([29, 47, 35, 50], fill=GOLD)
    return img


def draw_insight_badge():
    img = badge_base((83, 116, 173, 255))
    d = ImageDraw.Draw(img)
    d.polygon([(15, 30), (24, 22), (32, 20), (41, 22), (50, 30), (41, 38), (32, 40), (24, 38)], fill=WHITE, outline=NAVY)
    d.ellipse([25, 23, 39, 37], fill=(59, 116, 91, 255), outline=NAVY, width=2)
    d.ellipse([30, 28, 34, 32], fill=NAVY)
    d.ellipse([40, 11, 51, 22], fill=GOLD, outline=NAVY, width=2)
    d.rectangle([43, 22, 48, 26], fill=NAVY)
    d.point((45, 14), fill=WHITE)
    return img


def rounded_rect(d, box, radius, fill, outline=None, width=1):
    x0, y0, x1, y1 = box
    d.rectangle([x0 + radius, y0, x1 - radius, y1], fill=fill)
    d.rectangle([x0, y0 + radius, x1, y1 - radius], fill=fill)
    d.pieslice([x0, y0, x0 + 2 * radius, y0 + 2 * radius], 180, 270, fill=fill)
    d.pieslice([x1 - 2 * radius, y0, x1, y0 + 2 * radius], 270, 360, fill=fill)
    d.pieslice([x1 - 2 * radius, y1 - 2 * radius, x1, y1], 0, 90, fill=fill)
    d.pieslice([x0, y1 - 2 * radius, x0 + 2 * radius, y1], 90, 180, fill=fill)
    if outline:
        for i in range(width):
            d.arc([x0 + i, y0 + i, x0 + 2 * radius - i, y0 + 2 * radius - i], 180, 270, fill=outline, width=1)
            d.arc([x1 - 2 * radius + i, y0 + i, x1 - i, y0 + 2 * radius - i], 270, 360, fill=outline, width=1)
            d.arc([x1 - 2 * radius + i, y1 - 2 * radius + i, x1 - i, y1 - i], 0, 90, fill=outline, width=1)
            d.arc([x0 + i, y1 - 2 * radius + i, x0 + 2 * radius - i, y1 - i], 90, 180, fill=outline, width=1)
            d.line([x0 + radius, y0 + i, x1 - radius, y0 + i], fill=outline)
            d.line([x0 + radius, y1 - i, x1 - radius, y1 - i], fill=outline)
            d.line([x0 + i, y0 + radius, x0 + i, y1 - radius], fill=outline)
            d.line([x1 - i, y0 + radius, x1 - i, y1 - radius], fill=outline)


def draw_bubble_9slice():
    img = new((96, 96))
    d = ImageDraw.Draw(img)
    rounded_rect(d, [5, 5, 90, 90], 14, (252, 248, 235, 255), NAVY, 3)
    d.rectangle([8, 20, 87, 75], fill=(252, 248, 235, 255))
    d.rectangle([20, 8, 75, 87], fill=(252, 248, 235, 255))
    rounded_rect(d, [5, 5, 90, 90], 14, (252, 248, 235, 255), NAVY, 3)
    return img


def draw_tail():
    img = new((24, 24))
    d = ImageDraw.Draw(img)
    d.polygon([(3, 3), (21, 7), (7, 22)], fill=NAVY)
    d.polygon([(6, 6), (17, 8), (8, 18)], fill=(252, 248, 235, 255))
    return img


def draw_emote(kind):
    img = new((48, 48))
    d = ImageDraw.Draw(img)
    rounded_rect(d, [7, 6, 38, 32], 7, WHITE, NAVY, 2)
    d.polygon([(18, 31), (14, 41), (27, 32)], fill=WHITE)
    d.line([(18, 31), (14, 41), (27, 32)], fill=NAVY, width=2)
    if kind == "exclaim":
        d.rectangle([22, 13, 25, 24], fill=NAVY)
        d.rectangle([22, 27, 25, 30], fill=NAVY)
    elif kind == "question":
        d.rectangle([20, 13, 28, 16], fill=NAVY)
        d.rectangle([27, 17, 30, 22], fill=NAVY)
        d.rectangle([23, 22, 27, 25], fill=NAVY)
        d.rectangle([23, 27, 26, 30], fill=NAVY)
    else:
        for x in [17, 23, 29]:
            d.rectangle([x, 23, x + 3, 26], fill=NAVY)
    return img


def main():
    assets = {
        "assets/tiles/floor.png": draw_floor(),
        "assets/tiles/wall.png": draw_wall(),
        "assets/tiles/desk.png": draw_desk(),
        "assets/tiles/board.png": draw_board(),
        "assets/tiles/door.png": draw_door(),
        "assets/tiles/window.png": draw_window(),
        "assets/ui/badge_routine.png": draw_clock_badge(),
        "assets/ui/badge_echo.png": draw_echo_badge(),
        "assets/ui/badge_balance.png": draw_balance_badge(),
        "assets/ui/badge_mirror.png": draw_mirror_badge(),
        "assets/ui/badge_insight.png": draw_insight_badge(),
        "assets/ui/bubble_9slice.png": draw_bubble_9slice(),
        "assets/ui/bubble_tail.png": draw_tail(),
        "assets/ui/emote_exclaim.png": draw_emote("exclaim"),
        "assets/ui/emote_question.png": draw_emote("question"),
        "assets/ui/emote_dots.png": draw_emote("dots"),
    }
    for rel, img in assets.items():
        save(img, rel)
        print(f"{rel}: {img.size[0]}x{img.size[1]}")


if __name__ == "__main__":
    main()
