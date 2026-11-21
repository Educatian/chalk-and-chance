"""Mission thumbnails rendered from the v2 room art: each mission's own seat arrangement,
roster and the modern US room, cropped to 16:9.

    python tools/art/thumbs.py        # writes assets/v2/thumbs/<scenario_id>.png and <id>_kr.png

Seat coordinates mirror scripts/Seating.gd (keep the two in sync).
"""
import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import build_art as B  # noqa: E402
import modern_room as M  # noqa: E402
from PIL import Image  # noqa: E402

ROOT = B.ROOT
OUT = os.path.join(ROOT, 'assets', 'v2', 'thumbs')
CINE = os.path.join(ROOT, 'assets', 'v2', 'cinematic')   # empty rooms for the mission cinematics


def seats(arr):
    if arr == 'ushape':
        return [(4, 3), (4, 5), (4, 7), (8, 9), (11, 9), (14, 9), (18, 3), (18, 5), (18, 7)]
    if arr == 'ushape6':
        return [(7, 4), (7, 6), (10, 8), (13, 8), (16, 4), (16, 6)]
    if arr == 'clusters8':
        return [(7, 5), (9, 5), (7, 7), (9, 7), (14, 5), (16, 5), (14, 7), (16, 7)]
    if arr == 'rows8':
        return [(6, 5), (8, 5), (15, 5), (17, 5), (6, 8), (8, 8), (15, 8), (17, 8)]
    if arr == 'clusters':
        out = []
        for bx, by in [(4, 3), (15, 3), (4, 8), (15, 8)]:
            out += [(bx, by), (bx + 2, by), (bx, by + 2), (bx + 2, by + 2)]
        return out
    if arr == 'pairs':
        return [(x, y) for y in (3, 7) for x in (4, 5, 10, 11, 16, 17)]
    return [(x, y) for y in (3, 6, 9) for x in (4, 8, 12, 16, 20)]


def render(cfg, style='us', people=True):
    """style 'us' (modern US room) or 'kr' (Korean room: wood-look floor, sliding green
    board with TV, Korean door and desks); same seats, roster and teacher in both."""
    kr = style == 'kr'
    floor = M.floor_kr if kr else M.floor_us
    board = M.kr_board if kr else M.us_board
    T = 16
    W, H = 24 * T, 14 * T          # one extra tile row above for the front wall face
    img = Image.new('RGBA', (W, H), (0, 0, 0, 255))
    oy = T
    for x in range(1, 23):
        for y in range(1, 12):
            img.alpha_composite(floor((x * 7 + y * 3) % 4), (x * T, oy + y * T))
    for x in range(24):
        if 9 <= x <= 14:
            piece = board(x - 9)
        elif x == 1:
            piece = M.kr_door() if kr else M.us_door()
        elif x in (3, 5, 16, 18):
            piece = M.anchor_chart(x % 5)
        elif x == 20:
            piece = M.clock_speaker()
        else:
            piece = M.plain_modern()
        img.alpha_composite(piece, (x * T, 0))
    for y in range(1, 13):
        img.alpha_composite(M.cap_base(), (0, oy + y * T))
        img.alpha_composite(M.cap_base(), (23 * T, oy + y * T))
    for x in range(24):
        img.alpha_composite(M.cap_base(), (x * T, oy + 12 * T))
    desk = M.desk_modern(style)
    seat_list = seats(str(cfg.get('arrangement', 'rows')))
    roster = {int(r.get('seat', -1)): str(r.get('id', '')) for r in cfg.get('roster', [])}
    for i, (sx, sy) in enumerate(seat_list):
        pid = roster.get(i) if people else None
        px, py = sx * T, oy + sy * T
        if pid and pid in B.STUDENTS:
            stu = B.student_frame(B.STUDENTS[pid], 0)
            img.alpha_composite(stu, (px, py + T - stu.height))
        img.alpha_composite(desk, (px + (T - desk.width) // 2, py + T - desk.height + 1))
    if not people:
        # Cinematic backdrop: the empty room before the bell, the whole front wall in view
        # (the cinematic shows the class as its own portrait strip).
        return img.crop((0, 0, W, W * 9 // 16)).convert('RGB')
    teacher = B.teacher_frame(B.T_FRONT, 1)
    img.alpha_composite(teacher, (11 * T, oy + 2 * T + T - teacher.height))
    # crop 16:9 around the front wall and the seats
    xs = [s[0] for s in seat_list]
    cx = (min(xs) + max(xs) + 1) * T // 2
    cw, ch = 304, 171
    x0 = max(0, min(W - cw, cx - cw // 2))
    return img.crop((x0, 0, x0 + cw, ch)).convert('RGB')


def main():
    os.makedirs(OUT, exist_ok=True)
    n = 0
    for f in sorted(glob.glob(os.path.join(ROOT, 'data', 'scenarios', '*.json'))):
        cfg = json.load(open(f, encoding='utf8'))
        sid = os.path.splitext(os.path.basename(f))[0]
        render(cfg).save(os.path.join(OUT, sid + '.png'))
        render(cfg, 'kr').save(os.path.join(OUT, sid + '_kr.png'))   # Korean classroom look
        os.makedirs(CINE, exist_ok=True)
        render(cfg, 'us', people=False).save(os.path.join(CINE, sid + '.png'))
        render(cfg, 'kr', people=False).save(os.path.join(CINE, sid + '_kr.png'))
        n += 2
    print('wrote %d thumbnails to %s' % (n, OUT))


if __name__ == '__main__':
    main()
