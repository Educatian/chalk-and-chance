"""Builds every v2 art asset from code: tiles, furniture, characters, UI frames, icons.

    python tools/art/build_art.py            # writes assets/v2/** and a contact sheet

One locked palette (palette.py), one texel grid (16 texels per tile), one outline rule
(1 ink texel around every opaque shape), one light direction (top-left). The build fails
if any pixel uses a colour outside the palette, so the style cannot drift.
All art here is original to Chalk & Chance.
"""
import os
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from palette import PALETTE as P, SHADE  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'v2')
CLEAR = (0, 0, 0, 0)


# --------------------------------------------------------------------------- helpers

def new(w, h):
    return Image.new('RGBA', (w, h), CLEAR)


def put(img, x, y, key):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), P[key])


def rect(img, x, y, w, h, key):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            put(img, xx, yy, key)


def stamp(img, rows, x0, y0, cmap):
    """Draw a text grid. '.' = skip; other chars looked up in cmap (palette keys)."""
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == '.' or ch == ' ':
                continue
            key = cmap.get(ch)
            if key:
                put(img, x0 + i, y0 + j, key)


def outline(img):
    """1-texel ink outline around every opaque shape (4-neighbourhood)."""
    src = img.copy()
    ink = P['ink']
    for y in range(img.height):
        for x in range(img.width):
            if src.getpixel((x, y))[3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < img.width and 0 <= ny < img.height and src.getpixel((nx, ny))[3] != 0:
                    img.putpixel((x, y), ink)
                    break
    return img


def upscale(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def hstack(frames):
    w = sum(f.width for f in frames)
    out = new(w, max(f.height for f in frames))
    x = 0
    for f in frames:
        out.alpha_composite(f, (x, 0))
        x += f.width
    return out


def vstack(rows):
    out = new(max(r.width for r in rows), sum(r.height for r in rows))
    y = 0
    for r in rows:
        out.alpha_composite(r, (0, y))
        y += r.height
    return out


ALLOWED = set(P.values())


def check_palette(img, name):
    for px in img.getdata() if not hasattr(img, 'get_flattened_data') else img.get_flattened_data():
        if px[3] == 0:
            continue
        if px not in ALLOWED:
            raise SystemExit('palette violation in %s: %s' % (name, px))


WRITTEN = []


def save(img, rel):
    check_palette(img, rel)
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    WRITTEN.append((rel, img))


def hashf(*v):
    h = 2166136261
    for n in v:
        h = ((h ^ (n & 0xffffffff)) * 16777619) & 0xffffffff
    return h


# --------------------------------------------------------------------------- tiles

def floor_tile(variant):
    t = new(16, 16)
    rect(t, 0, 0, 16, 16, 'floor')
    joints = [(10, 4, 13, 7), (6, 12, 2, 9), (13, 3, 8, 11), (4, 9, 12, 1)][variant % 4]
    for row in range(4):
        y0 = row * 4
        base = 'floor_lt' if (row + variant) % 2 == 0 else 'floor'
        rect(t, 0, y0, 16, 3, base)
        rect(t, 0, y0 + 3, 16, 1, 'wood_lt')       # seam
        jx = joints[row]
        rect(t, jx, y0, 1, 3, 'wood_lt')           # butt joint
        h = hashf(variant, row)
        put(t, (h % 13) + 1, y0 + 1, 'floor_lt' if base == 'floor' else 'floor')
    return t


def wall_cap():
    """Top-down wall (side and back walls)."""
    t = new(16, 16)
    rect(t, 0, 0, 16, 16, 'wall_sh')
    rect(t, 1, 1, 14, 14, 'wall')
    rect(t, 1, 13, 14, 2, 'wall_sh')
    return t


def shelf_cap(variant):
    """Bookshelf seen from above, built into a side wall."""
    t = wall_cap()
    rect(t, 2, 1, 12, 14, 'wood_dk')
    cols = ['red', 'blue', 'yellow', 'green', 'purple', 'chalk', 'slate']
    for i in range(4):
        y = 2 + i * 3
        for x in range(3, 13):
            c = cols[hashf(variant, i, x // 2) % len(cols)]
            put(t, x, y, c)
            put(t, x, y + 1, SHADE.get(c, c))
    return t


def cubby_cap(variant):
    """Back-wall cubbies with coloured bins."""
    t = wall_cap()
    rect(t, 1, 3, 14, 12, 'wood')
    rect(t, 1, 3, 14, 1, 'wood_lt')
    bins = ['blue', 'yellow', 'red', 'green', 'purple']
    for i, bx in enumerate((2, 9)):
        c = bins[hashf(variant, i) % len(bins)]
        rect(t, bx, 6, 5, 7, c)
        rect(t, bx, 6, 5, 1, SHADE.get(c, c))
    return t


def side_window_cap():
    t = wall_cap()
    rect(t, 3, 1, 10, 14, 'wood_lt')
    rect(t, 4, 2, 8, 12, 'early')
    rect(t, 4, 2, 8, 1, 'blue')
    rect(t, 7, 2, 2, 12, 'wood_lt')
    put(t, 5, 5, 'chalk'); put(t, 6, 4, 'chalk')
    return t


def poster_cap(variant):
    t = wall_cap()
    col = ['early', 'ok', 'notyet', 'yellow'][variant % 4]
    rect(t, 3, 2, 10, 12, 'paper')
    rect(t, 3, 2, 10, 2, col)
    for i, y in enumerate((6, 8, 10)):
        rect(t, 5, y, 4 + (hashf(variant, i) % 4), 1, 'paper_ln')
    put(t, 4, 2, 'red'); put(t, 12, 2, 'red')     # pins
    return t


def plant_cap():
    t = wall_cap()
    rect(t, 5, 9, 6, 5, 'wood')
    rect(t, 5, 9, 6, 1, 'wood_lt')
    for (x, y) in [(7, 2), (8, 2), (6, 3), (9, 3), (5, 4), (8, 4), (10, 4), (6, 5), (7, 5), (9, 5), (4, 6), (7, 6),
                   (8, 6), (11, 6), (5, 7), (6, 7), (9, 7), (10, 7), (7, 8), (8, 8)]:
        put(t, x, y, 'green')
    for (x, y) in [(7, 3), (8, 5), (6, 6), (10, 6), (8, 7)]:
        put(t, x, y, 'ok')
    return t


def hooks_cap(variant):
    t = wall_cap()
    rect(t, 1, 2, 14, 1, 'wood')
    cols = ['red', 'blue', 'yellow', 'purple', 'green']
    for i, x in enumerate((3, 9)):
        put(t, x + 1, 3, 'ink')
        c = cols[hashf(variant, i) % len(cols)]
        rect(t, x, 4, 4, 7, c)                     # hanging backpack / coat
        rect(t, x, 4, 4, 1, SHADE.get(c, c))
        rect(t, x + 1, 7, 2, 2, SHADE.get(c, c))
    return t


def sink_cap():
    t = wall_cap()
    rect(t, 2, 3, 12, 10, 'chalk_gy')
    rect(t, 3, 4, 10, 8, 'chalk')
    rect(t, 5, 6, 6, 4, 'early')
    rect(t, 7, 2, 2, 3, 'neutral')
    return t


def rug_full(edge):
    l, r, tp, b = edge
    return rug_tile((l, r, tp, b))


def chair():
    """Empty chair behind an unoccupied desk (12x8 texels)."""
    c = new(12, 9)
    rect(c, 1, 0, 10, 4, 'wood')        # backrest
    rect(c, 1, 0, 10, 1, 'wood_lt')
    rect(c, 2, 4, 8, 2, 'wood_lt')      # seat
    rect(c, 2, 6, 1, 3, 'wood_dk')
    rect(c, 9, 6, 1, 3, 'wood_dk')
    return outline(pad(c, 1))


def backpack(variant):
    cols = ['red', 'blue', 'yellow', 'purple', 'green', 'slate']
    c = cols[variant % len(cols)]
    b = new(7, 7)
    rect(b, 1, 0, 5, 7, c)
    rect(b, 0, 2, 7, 5, c)
    rect(b, 1, 0, 5, 1, SHADE.get(c, c))
    rect(b, 2, 4, 3, 2, SHADE.get(c, c))
    put(b, 3, 1, 'chalk')
    return outline(pad(b, 1))


def floor_paper():
    p = new(6, 4)
    rect(p, 0, 0, 6, 4, 'paper')
    rect(p, 1, 1, 3, 1, 'paper_ln')
    return p


MOVE_ICONS = {
    'elicit': ["..XXXX..", ".X....X.", "......X.", "....XX..", "...X....", "........", "...X....", "........"],
    'extend': ["...XXXXX", "......XX", ".....X.X", "....X..X", "...X....", "..X.....", ".X......", "X......."],
    'revoice': ["..XXX...", ".X...X..", "X.XX..X.", "X.X.X.X.", "X..XX.X.", ".X...X..", "..XXX...", "........"],
    'tell': ["...XX...", "...XX...", "...XX...", "...XX...", "...XX...", "........", "...XX...", "...XX..."],
    'praise': ["...X....", "...X....", "XXXXXXX.", ".XXXXX..", "..XXX...", ".XX.XX..", ".X...X..", "........"],
    'connect': ["........", ".XX..XX.", "X..XX..X", "X......X", "X..XX..X", ".XX..XX.", "........", "........"],
    'redirect': ["....XX..", "...X..X.", "XXXX...X", ".XX....X", "..X...X.", "......X.", "....XX..", "........"],
    'wait': ["XXXXXXX.", ".X...X..", "..X.X...", "...X....", "..X.X...", ".X.X.X..", "XXXXXXX.", "........"],
    'type': ["........", "XXXXXXXX", "X.X.X.XX", "XXXXXXXX", "XX.X.X.X", "XXXXXXXX", ".XXXXXX.", "........"],
}


def move_icon(name):
    img = new(8, 8)
    stamp(img, MOVE_ICONS[name], 0, 0, {'X': 'navy'})
    return upscale(img, 2)


def encounter_backdrop():
    """480x270 setting behind the encounter panels: the front wall and floor of the room."""
    bd = new(480, 270)
    pieces = ['plain', 'window', 'plain', 'board0', 'board1', 'board2', 'board3', 'board4', 'board5', 'plain',
              'window', 'plain', 'clock', 'plain', 'door']
    x = 0
    i = 0
    while x < 480:
        k = pieces[i % len(pieces)]
        if k == 'plain':
            piece = plain_front()
        elif k == 'window':
            piece = window_piece()
        elif k == 'clock':
            piece = clock_piece()
        elif k == 'door':
            piece = door_piece()
        else:
            n = int(k[-1])
            piece = board_piece(['L', 'M', 'M', 'M', 'M', 'R'][n], n)
        bd.alpha_composite(upscale(piece, 2), (x, 0))
        x += 32
        i += 1
    for ty in range(64, 270, 16):
        for tx in range(0, 480, 16):
            bd.alpha_composite(floor_tile(hashf(tx, ty) % 4), (tx, ty))
    return bd


def front_wall_base():
    """Front wall face, 16x32: drawn one tile above the room and over row 0."""
    t = new(16, 32)
    rect(t, 0, 0, 16, 32, 'wall')
    rect(t, 0, 0, 16, 2, 'wood_dk')               # ceiling trim
    rect(t, 0, 2, 16, 1, 'wall_sh')
    for x in (3, 11):
        rect(t, x, 3, 1, 22, 'wall_sh')            # faint wall panel lines
    rect(t, 0, 25, 16, 1, 'wood_lt')               # chair rail / baseboard top
    rect(t, 0, 26, 16, 4, 'wood')
    rect(t, 0, 30, 16, 2, 'wood_dk')               # baseboard shadow
    return t


def board_piece(kind, idx):
    t = front_wall_base()
    x0 = 1 if kind == 'L' else 0
    x1 = 15 if kind == 'R' else 16
    rect(t, x0, 5, x1 - x0, 19, 'wood')            # frame
    ix0 = x0 + (1 if kind == 'L' else 0)
    ix1 = x1 - (1 if kind == 'R' else 0)
    rect(t, ix0, 6, ix1 - ix0, 17, 'board')
    rect(t, ix0, 6, ix1 - ix0, 1, 'board_lt')
    rect(t, x0, 23, x1 - x0, 1, 'wood_lt')         # chalk tray
    if kind == 'L':
        put(t, 3, 22, 'chalk')
        put(t, 4, 22, 'chalk')
    # original chalk content: a fraction circle, a number line, a few lines of notes
    if idx == 1:
        for (x, y) in [(6, 9), (7, 9), (8, 9), (5, 10), (9, 10), (4, 11), (10, 11), (4, 12), (10, 12),
                       (4, 13), (10, 13), (5, 14), (9, 14), (6, 15), (7, 15), (8, 15), (7, 10), (7, 11),
                       (7, 12), (7, 13), (7, 14), (5, 12), (6, 12), (8, 12), (9, 12)]:
            put(t, x, y, 'chalk')
        for (x, y) in [(5, 11), (6, 11), (5, 13), (6, 13), (6, 10), (6, 14)]:
            put(t, x, y, 'chalk_gy')
    elif idx == 2:
        rect(t, 1, 14, 14, 1, 'chalk')
        for x in (1, 5, 9, 13):
            rect(t, x, 13, 1, 3, 'chalk')
        put(t, 9, 11, 'yellow')
        put(t, 9, 10, 'yellow')
    else:
        for i, y in enumerate((9, 12, 15, 18)):
            ln = 6 + (hashf(idx, i) % 7)
            rect(t, 2, y, ln, 1, 'chalk_gy')
            if i == 0:
                rect(t, 2, y, 3, 1, 'chalk')
    return t


def window_piece():
    t = front_wall_base()
    rect(t, 2, 6, 12, 15, 'wood_lt')
    rect(t, 3, 7, 10, 13, 'early')
    rect(t, 3, 7, 10, 1, 'blue')
    rect(t, 7, 7, 2, 13, 'wood_lt')
    rect(t, 3, 13, 10, 1, 'wood_lt')
    for i in range(3):
        put(t, 4 + i, 12 - i, 'chalk')
        put(t, 10 + i % 2, 18 - i, 'chalk')
    rect(t, 1, 21, 14, 1, 'wood')
    return t


def door_piece():
    t = front_wall_base()
    rect(t, 2, 5, 12, 27, 'wood_dk')
    rect(t, 3, 6, 10, 26, 'wood')
    rect(t, 4, 8, 8, 7, 'wood_lt')
    rect(t, 5, 9, 6, 5, 'early')
    rect(t, 4, 18, 8, 8, 'wood_lt')
    rect(t, 5, 19, 6, 6, 'wood')
    put(t, 11, 18, 'yellow')
    put(t, 11, 17, 'yellow')
    return t


def clock_piece():
    t = front_wall_base()
    for (x, y) in [(6, 7), (7, 7), (8, 7), (9, 7), (5, 8), (10, 8), (4, 9), (11, 9), (4, 10), (11, 10),
                   (4, 11), (11, 11), (4, 12), (11, 12), (5, 13), (10, 13), (6, 14), (7, 14), (8, 14), (9, 14)]:
        put(t, x, y, 'ink')
    rect(t, 5, 9, 6, 4, 'chalk')
    rect(t, 6, 8, 4, 1, 'chalk')
    rect(t, 6, 13, 4, 1, 'chalk')
    put(t, 7, 9, 'ink'); put(t, 7, 10, 'ink'); put(t, 8, 11, 'ink'); put(t, 9, 11, 'ink')
    return t


def plain_front():
    return front_wall_base()


def rug_tile(edge):
    """Reading rug in front of the board; 3x3 nine-piece. edge = (left,right,top,bottom)."""
    t = new(16, 16)
    rect(t, 0, 0, 16, 16, 'slate')
    for y in range(16):
        for x in range(16):
            if (x // 4 + y // 4) % 2 == 0:
                put(t, x, y, 'blue')
    l, r, tp, b = edge
    if tp:
        rect(t, 0, 0, 16, 2, 'yellow')
    if b:
        rect(t, 0, 14, 16, 2, 'yellow')
    if l:
        rect(t, 0, 0, 2, 16, 'yellow')
    if r:
        rect(t, 14, 0, 2, 16, 'yellow')
    return t


def student_desk():
    """16x10, front view from slightly above. Sits on the bottom of the seat tile."""
    d = new(16, 10)
    rect(d, 1, 0, 14, 3, 'wood_lt')       # top surface
    rect(d, 1, 0, 14, 1, 'floor_lt')
    rect(d, 1, 3, 14, 1, 'wood')          # front edge
    rect(d, 2, 4, 12, 3, 'wood')          # apron
    rect(d, 2, 6, 12, 1, 'wood_dk')
    rect(d, 2, 7, 2, 3, 'wood_dk')        # legs
    rect(d, 12, 7, 2, 3, 'wood_dk')
    rect(d, 9, 1, 4, 2, 'paper')          # worksheet
    put(d, 10, 1, 'paper_ln'); put(d, 11, 2, 'paper_ln')
    put(d, 4, 1, 'yellow')                # pencil
    put(d, 5, 1, 'yellow'); put(d, 6, 1, 'red')
    return outline(pad(d, 1))


def teacher_desk():
    d = new(32, 14)
    rect(d, 0, 0, 32, 4, 'wood_lt')
    rect(d, 0, 0, 32, 1, 'floor_lt')
    rect(d, 0, 4, 32, 1, 'wood')
    rect(d, 1, 5, 30, 7, 'wood')
    rect(d, 1, 11, 30, 1, 'wood_dk')
    rect(d, 3, 6, 10, 4, 'wood_dk')       # drawer
    rect(d, 4, 7, 8, 2, 'wood_lt')
    put(d, 8, 7, 'yellow')
    rect(d, 1, 12, 3, 2, 'wood_dk')
    rect(d, 28, 12, 3, 2, 'wood_dk')
    rect(d, 4, 1, 7, 3, 'paper')          # papers
    rect(d, 5, 0, 7, 3, 'paper')
    rect(d, 6, 1, 4, 1, 'paper_ln')
    rect(d, 22, 0, 3, 3, 'red')           # mug
    put(d, 25, 1, 'red')
    put(d, 23, 0, 'chalk')
    rect(d, 15, 1, 4, 2, 'green')         # attendance book
    return outline(pad(d, 1))


def pad(img, n):
    out = new(img.width + 2 * n, img.height + 2 * n)
    out.alpha_composite(img, (n, n))
    return out


# --------------------------------------------------------------------------- characters
# Seated students: 14x22 interior + 1 texel outline = 16x24. Head rows 0-10, body 11-21.

HEADS = {
    'short': [
        "....HHHHHH....",
        "...HHHHHHHH...",
        "..HHHHHHHHHH..",
        "..HHHHHHHHHH..",
        "..HSHHSSHHSH..",
        "..SSSSSSSSSs..",
        "..SSESSSSESs..",
        "..SbSSSSSSbs..",
        "...SSSmmSSs...",
        "....sSSSSs....",
        ".....ssss.....",
    ],
    'curly': [
        "...HH.HH.HH...",
        "..HHHHHHHHHH..",
        ".HHHHHHHHHHHH.",
        ".HHHHHHHHHHHH.",
        ".HHSHSSHSHSHH.",
        "..SSSSSSSSSs..",
        "..SSESSSSESs..",
        "..SbSSSSSSbs..",
        "...SSSmmSSs...",
        "....sSSSSs....",
        ".....ssss.....",
    ],
    'spiky': [
        "..H.H..H.H....",
        "..HHHHHHHHH...",
        "..HHHHHHHHHH..",
        "..HHHHHHHHHH..",
        "..HSSHSSHSSH..",
        "..SSSSSSSSSs..",
        "..SSESSSSESs..",
        "..SbSSSSSSbs..",
        "...SSSmmSSs...",
        "....sSSSSs....",
        ".....ssss.....",
    ],
    'long': [
        "....HHHHHH....",
        "...HHHHHHHH...",
        "..HHHHHHHHHH..",
        "..HHHHHHHHHH..",
        ".HHSSHSSHSSHH.",
        ".HSSSSSSSSSsH.",
        ".HSSESSSSESsH.",
        ".HSbSSSSSSbsH.",
        ".HHSSSmmSSsHH.",
        ".hH.sSSSSs.Hh.",
        ".h...ssss...h.",
    ],
    'bob': [
        "....HHHHHH....",
        "...HHHHHHHH...",
        "..HHHHHHHHHH..",
        "..HHHHHHHHHA..",
        ".HHHHHHHHHHHH.",
        ".HSSSSSSSSSsH.",
        ".HSSESSSSESsH.",
        ".hSbSSSSSSbsh.",
        "..hSSSmmSSsh..",
        "....sSSSSs....",
        ".....ssss.....",
    ],
    'hood': [
        "...CCCCCCCC...",
        "..CCHHHHHHCC..",
        ".CCHHHHHHHHCC.",
        ".CHHHHHHHHHHC.",
        ".CHSSHSSHSSHC.",
        ".CSSSSSSSSSsC.",
        ".CSSESSSSESsC.",
        ".CSbSSSSSSbsC.",
        ".cCSSSmmSSsCc.",
        "..cCsSSSSsCc..",
        "...cCssssCc...",
    ],
}

BODY = [
    "...CCCCCCCC...",
    "..CCCCCCCCCC..",
    ".CCCCCCCCCCCC.",
    ".CCcCCCCCCcCC.",
    ".CCcCCCCCCcCC.",
    ".SScCCCCCCcSS.",
    "..scCCCCCCcs..",
    "..PPPPPPPPPP..",
    "..PPPPPPPPPP..",
    "..pP......Pp..",
    "..KK......KK..",
]

RAISED_ARM = [  # (x, y, key) overlay in interior coords for the hand-raise frame
    (12, 1, 'S'), (13, 1, 'S'), (12, 2, 'S'), (12, 3, 'C'), (13, 3, 'C'), (12, 4, 'C'), (13, 4, 'C'),
    (12, 5, 'C'), (13, 5, 'C'), (12, 6, 'C'), (13, 6, 'C'), (12, 7, 'C'), (13, 7, 'C'), (12, 8, 'C'),
    (13, 8, 'C'), (12, 9, 'C'), (13, 9, 'C'), (12, 10, 'C'), (13, 10, 'C'),
]

STUDENTS = {
    # persona_id: skin, hair colour, hair style, top colour, pattern, extras
    'talia_dominator': dict(skin='skin1', hair='hair_br', style='short', top='red', pattern='plain', extra='pony'),
    'diego_ell': dict(skin='skin2', hair='hair_dk', style='spiky', top='red', pattern='jersey', extra=None),
    'jordan_skeptic': dict(skin='skin3', hair='hair_br', style='curly', top='green', pattern='plaid', extra=None),
    'marcus_volatile': dict(skin='skin3', hair='hair_dk', style='short', top='yellow', pattern='plain', extra=None),
    'priya_quiet': dict(skin='skin3', hair='hair_dk', style='long', top='purple', pattern='plain', extra='glasses'),
    'meilin_anxious': dict(skin='skin1', hair='hair_dk', style='bob', top='green', pattern='cardigan', extra='glasses'),
    'deshawn_offtask': dict(skin='skin4', hair='hair_dk', style='hood', top='green', pattern='hoodie', extra=None),
    'noah_g5_fractions': dict(skin='skin1', hair='hair_br', style='spiky', top='blue', pattern='stripes', extra=None),
    'sam_withdrawn': dict(skin='skin2', hair='hair_dk', style='hood', top='slate', pattern='hoodie', extra=None),
    'riley_avoidant': dict(skin='skin1', hair='hair_gd', style='short', top='blue', pattern='hoodie', extra=None),
}


def char_map(spec):
    top = spec['top']
    return {
        'H': spec['hair'], 'h': SHADE[spec['hair']], 'A': 'yellow',
        'S': spec['skin'], 's': SHADE[spec['skin']], 'E': 'ink', 'b': 'notyet', 'm': SHADE[SHADE[spec['skin']]] if spec['skin'] != 'skin4' else 'ink',
        'C': top, 'c': SHADE[top], 'T': 'chalk',
        'P': 'slate' if top != 'slate' else 'blue', 'p': 'ink', 'K': 'ink',
    }


def student_frame(spec, frame):
    """frame: 0 neutral, 1 breathe, 2 look-left, 3 look-right, 4 hand-raise, 5 head-down, 6 blink."""
    img = new(14, 22)
    cmap = char_map(spec)
    head = [row for row in HEADS[spec['style']]]
    body = [row for row in BODY]
    head_dy = 1 if frame == 5 else 0
    body_dy = -1 if frame == 1 else 0
    stamp(img, body, 0, 11 + max(body_dy, 0), cmap)
    if body_dy:
        # breathe: shoulders rise one texel (legs stay)
        stamp(img, body[:7], 0, 11 + body_dy, cmap)
    # pattern on the top
    pat = spec['pattern']
    for y in range(11, 18):
        for x in range(1, 13):
            px = img.getpixel((x, y))
            if px != P[cmap['C']]:
                continue
            if pat == 'stripes' and y % 2 == 0:
                put(img, x, y, 'chalk')
            elif pat == 'plaid' and (x % 3 == 0 or y % 3 == 0):
                put(img, x, y, cmap['c'])
            elif pat == 'jersey' and y in (13, 14) and x in (6, 7):
                put(img, x, y, 'chalk')
            elif pat == 'hoodie' and y == 12 and x in (5, 8):
                put(img, x, y, 'chalk')
            elif pat == 'cardigan' and x in (6, 7):
                put(img, x, y, 'chalk')
    stamp(img, head, 0, head_dy, cmap)
    # eyes: look left/right, or down (closed) on the head-down frame
    if frame == 6:
        ey = 6
        for ex in (4, 9):
            put(img, ex, ey, cmap['s'])
    if frame in (2, 3, 5):
        dx = -1 if frame == 2 else (1 if frame == 3 else 0)
        ey = 6 + head_dy
        for ex in (4, 9):
            put(img, ex, ey, cmap['S'])
            if frame == 5:
                put(img, ex, ey, cmap['s'])
                put(img, ex + 1, ey, cmap['s'])
            else:
                put(img, ex + dx, ey, 'ink')
    if spec.get('extra') == 'glasses':
        # thin frames: rim above each eye and a bridge, eyes stay visible
        ey = 6 + head_dy
        for ex in (3, 8):
            rect(img, ex, ey - 1, 3, 1, 'slate')
            put(img, ex, ey, 'slate')
        put(img, 6, ey - 1, 'slate'); put(img, 7, ey - 1, 'slate')
    if spec.get('extra') == 'pony':
        for (x, y) in [(12, 3), (13, 4), (13, 5), (13, 6), (12, 7), (13, 7)]:
            put(img, x, y + head_dy, cmap['H'])
        put(img, 12, 3 + head_dy, 'notyet')
    if frame == 4:
        for (x, y, k) in RAISED_ARM:
            put(img, x, y, cmap[k])
    return outline(pad(img, 1))


def student_sheet(spec):
    return hstack([student_frame(spec, f) for f in range(7)])


# Teacher: 14x26 interior + outline = 16x28. Rows: down, left, right, up; 3 walk frames.
T_FRONT = [
    ".....HHHH.....",
    "....HHHHHH....",
    "...HHHHHHHH...",
    "...HHHHHHHH...",
    "...HSSSSSSH...",
    "...SSESSESs...",
    "...SSSSSSSs...",
    "...SbSmmSbs...",
    "....SSSSSs....",
    ".....ssss.....",
    "...CCTTTTCC...",
    "..CCCTTTTCCC..",
    "..CCCTTTTCCC..",
    ".CCcCTTTTCcCC.",
    ".CCcCTTTTCcCC.",
    ".CCcCTTTTCcCC.",
    ".CCcCCCCCCcCC.",
    ".SS.PPPPPP.SS.",
    "....PPPPPP....",
    "....PPPPPP....",
    "....PPppPP....",
    "....PP..PP....",
    "....PP..PP....",
    "....PP..PP....",
    "....Pp..Pp....",
    "...KKK..KKK...",
]
T_BACK = [
    ".....HHHH.....",
    "....HHHHHH....",
    "...HHHHHHHH...",
    "...HHHHHHHH...",
    "...HHHHHHHH...",
    "...HHHHHHHH...",
    "...hHHHHHHh...",
    "....hHHHHh....",
    "....SSSSSs....",
    ".....ssss.....",
    "...CCCCCCCC...",
    "..CCCCCCCCCC..",
    "..CCCCCCCCCC..",
    ".CCcCCCCCCcCC.",
    ".CCcCCCCCCcCC.",
    ".CCcCCCCCCcCC.",
    ".CCcCCCCCCcCC.",
    ".SS.PPPPPP.SS.",
    "....PPPPPP....",
    "....PPPPPP....",
    "....PPPPPP....",
    "....PP..PP....",
    "....PP..PP....",
    "....PP..PP....",
    "....Pp..Pp....",
    "...KKK..KKK...",
]
T_SIDE = [  # facing left
    ".......HHHH...",
    "......HHHHHH..",
    ".....HHHHHHHH.",
    ".....HHHHHHHH.",
    "....SSSHHHHHH.",
    "....SESSHHHH..",
    "...SSSSSsHH...",
    "....SmSSSs....",
    ".....SSSs.....",
    "......ss......",
    ".....CTTCC....",
    "....CCTTCCC...",
    "....CCTTCCC...",
    "....CCTTcCC...",
    "....CCTTcCC...",
    "....CCTTcCC...",
    "....CCCCcCC...",
    "....S.PPPPS...",
    "......PPPP....",
    "......PPPP....",
    "......PPpP....",
    "......PP.P....",
    "......PP.P....",
    "......PP.P....",
    "......Pp.p....",
    ".....KKK.KK...",
]

TEACHER = dict(skin='skin2', hair='hair_br', top='yellow')


def teacher_frame(rows, step, mirror=False):
    img = new(14, 26)
    cmap = {
        'H': TEACHER['hair'], 'h': SHADE[TEACHER['hair']], 'S': TEACHER['skin'], 's': SHADE[TEACHER['skin']],
        'E': 'ink', 'b': 'notyet', 'm': SHADE[SHADE[TEACHER['skin']]], 'C': TEACHER['top'],
        'c': SHADE[TEACHER['top']], 'T': 'chalk', 'P': 'board_lt', 'p': 'board', 'K': 'ink',
    }
    stamp(img, rows, 0, 0, cmap)
    if step != 1:
        # walking: lift one leg one texel (left leg on step 0, right leg on step 2)
        lx = range(0, 7) if step == 0 else range(7, 14)
        snap = img.copy()
        for y in range(20, 26):
            for x in lx:
                img.putpixel((x, y), CLEAR)
        for y in range(20, 26):
            for x in lx:
                px = snap.getpixel((x, y))
                if px[3]:
                    img.putpixel((x, y - 1), px)
    if mirror:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    return outline(pad(img, 1))


def teacher_sheet():
    rows = []
    for rows_src, mirror in ((T_FRONT, False), (T_SIDE, False), (T_SIDE, True), (T_BACK, False)):
        rows.append(hstack([teacher_frame(rows_src, s, mirror) for s in range(3)]))
    return vstack(rows)


# --------------------------------------------------------------------------- UI kit (drawn x2)

def frame_board():
    """Slim dark panel (HUD bands, dialogue, encounter panels): slate-navy fill, 1-texel
    light inner line, ink outline, no wood trim (modern direction, review note 3)."""
    f = new(24, 24)
    rect(f, 1, 0, 22, 24, 'ink')
    rect(f, 0, 1, 24, 22, 'ink')
    rect(f, 1, 1, 22, 22, 'navy')
    rect(f, 2, 2, 20, 1, 'slate')
    rect(f, 2, 2, 1, 20, 'slate')
    rect(f, 2, 21, 20, 1, 'screen')
    rect(f, 21, 2, 1, 20, 'screen')
    return upscale(f, 2)


def frame_paper():
    """Clean white card (briefings, results, documents): whiteboard face, metal rim."""
    f = new(24, 24)
    rect(f, 1, 0, 22, 24, 'ink')
    rect(f, 0, 1, 24, 22, 'ink')
    rect(f, 1, 1, 22, 22, 'metal')
    rect(f, 2, 2, 20, 19, 'whiteboard')
    rect(f, 2, 20, 20, 1, 'tile')
    return upscale(f, 2)


def button(state):
    b = new(16, 16)
    face = {'normal': 'whiteboard', 'hover': 'wall_mod', 'pressed': 'tile', 'disabled': 'tile_ln', 'focus': 'whiteboard'}[state]
    rim = 'tile_ln' if state == 'disabled' else 'metal'
    dy = 1 if state == 'pressed' else 0
    rect(b, 1, 0 + dy, 14, 16 - dy, 'ink')
    rect(b, 0, 1 + dy, 16, 14 - dy, 'ink')
    rect(b, 1, 1 + dy, 14, 14 - dy, rim)
    rect(b, 2, 2 + dy, 12, 11 - dy, face)
    if state == 'focus':
        f = new(16, 16)
        rect(f, 1, 0, 14, 16, 'focus')
        rect(f, 0, 1, 16, 14, 'focus')
        rect(f, 2, 2, 12, 12, 'ink')
        f2 = f.copy()
        for y in range(16):
            for x in range(16):
                if f.getpixel((x, y)) == P['ink']:
                    f2.putpixel((x, y), CLEAR)
        return upscale(f2, 2)
    return upscale(b, 2)


def board_button(state):
    """Dark (chalkboard) button for cards and lists that carry chalk-coloured text."""
    b = new(16, 16)
    face = {'normal': 'navy', 'hover': 'slate', 'pressed': 'screen', 'disabled': 'ink'}[state]
    dy = 1 if state == 'pressed' else 0
    rect(b, 1, 0 + dy, 14, 16 - dy, 'ink')
    rect(b, 0, 1 + dy, 16, 14 - dy, 'ink')
    rect(b, 1, 1 + dy, 14, 14 - dy, 'neutral' if state == 'disabled' else 'screen')
    rect(b, 2, 2 + dy, 12, 11 - dy, face)
    rect(b, 2, 2 + dy, 12, 1, 'slate' if state != 'disabled' else 'slate')
    return upscale(b, 2)


ICONS = {
    'ok': ["........", "......X.", ".....XX.", "X...XX..", "XX.XX...", ".XXX....", "..X.....", "........"],
    'early': ["..XXXX..", ".X....X.", "X...X..X", "X...X..X", "X...XXXX", "X......X", ".X....X.", "..XXXX.."],
    'notyet': ["........", "........", "........", ".XXXXXX.", ".XXXXXX.", "........", "........", "........"],
    'neutral': ["........", "........", "...XX...", "..XXXX..", "..XXXX..", "...XX...", "........", "........"],
    'attention': ["........", "..XXXX..", ".X....X.", "X..XX..X", "X..XX..X", ".X....X.", "..XXXX..", "........"],
    'composure': ["........", ".XX..XX.", "XXXXXXXX", "XXXXXXXX", ".XXXXXX.", "..XXXX..", "...XX...", "........"],
    'clock': ["..XXXX..", ".X....X.", "X...X..X", "X...X..X", "X...XX.X", "X......X", ".X....X.", "..XXXX.."],
}


def talk_bubble():
    """Small speech bubble with '!' shown beside a student who can be talked to."""
    b = new(9, 10)
    rect(b, 1, 0, 7, 7, 'chalk')
    rect(b, 0, 1, 9, 5, 'chalk')
    put(b, 2, 7, 'chalk'); put(b, 1, 8, 'chalk')
    rect(b, 4, 1, 1, 3, 'warn')
    put(b, 4, 5, 'warn')
    return outline(pad(b, 1))


def icon(name, key):
    img = new(8, 8)
    stamp(img, ICONS[name], 0, 0, {'X': key})
    return upscale(img, 2)


# --------------------------------------------------------------------------- build

def build():
    for v in range(4):
        save(floor_tile(v), 'tiles/floor_%d.png' % v)
    save(wall_cap(), 'tiles/wall_cap.png')
    for v in range(3):
        save(shelf_cap(v), 'tiles/shelf_%d.png' % v)
        save(cubby_cap(v), 'tiles/cubby_%d.png' % v)
    save(plain_front(), 'tiles/front_plain.png')
    for i, kind in enumerate(['L', 'M', 'M', 'M', 'M', 'R']):
        save(board_piece(kind, i), 'tiles/board_%d.png' % i)
    save(window_piece(), 'tiles/front_window.png')
    save(door_piece(), 'tiles/front_door.png')
    save(clock_piece(), 'tiles/front_clock.png')
    for name, edge in {
        'tl': (1, 0, 1, 0), 't': (0, 0, 1, 0), 'tr': (0, 1, 1, 0),
        'bl': (1, 0, 0, 1), 'b': (0, 0, 0, 1), 'br': (0, 1, 0, 1),
    }.items():
        save(rug_tile(edge), 'tiles/rug_%s.png' % name)
    save(student_desk(), 'furniture/student_desk.png')
    save(teacher_desk(), 'furniture/teacher_desk.png')
    for pid, spec in STUDENTS.items():
        save(student_sheet(spec), 'sprites/%s_seated.png' % pid)
    save(teacher_sheet(), 'sprites/teacher_walk.png')
    save(frame_board(), 'ui/frame_board.png')
    save(frame_paper(), 'ui/frame_paper.png')
    for st in ('normal', 'hover', 'pressed', 'disabled', 'focus'):
        save(button(st), 'ui/button_%s.png' % st)
    for st in ('normal', 'hover', 'pressed', 'disabled'):
        save(board_button(st), 'ui/button_board_%s.png' % st)
    for name, key in {'ok': 'ok', 'early': 'early', 'notyet': 'notyet', 'neutral': 'neutral',
                      'attention': 'chalk', 'composure': 'notyet', 'clock': 'chalk'}.items():
        save(icon(name, key), 'ui/icon_%s.png' % name)
    save(talk_bubble(), 'ui/talk_bubble.png')
    save(side_window_cap(), 'tiles/side_window.png')
    for v in range(4):
        save(poster_cap(v), 'tiles/poster_%d.png' % v)
    save(plant_cap(), 'tiles/plant.png')
    for v in range(3):
        save(hooks_cap(v), 'tiles/hooks_%d.png' % v)
    save(sink_cap(), 'tiles/sink.png')
    for name, edge in {'l': (1, 0, 0, 0), 'm': (0, 0, 0, 0), 'r': (0, 1, 0, 0)}.items():
        save(rug_full(edge), 'tiles/rug_%s.png' % name)
    save(chair(), 'furniture/chair.png')
    for v in range(6):
        save(backpack(v), 'furniture/backpack_%d.png' % v)
    save(floor_paper(), 'furniture/floor_paper.png')
    for name in MOVE_ICONS:
        save(move_icon(name), 'ui/move_%s.png' % name)
    save(encounter_backdrop(), 'ui/encounter_backdrop.png')
    import modern_room          # modern US/KR classroom set (imports this module's helpers)
    import build_art as _ba
    modern_room.build_modern()
    WRITTEN.extend(_ba.WRITTEN)
    contact_sheet()
    print('wrote %d assets to %s' % (len(WRITTEN), OUT))


def contact_sheet():
    pad_px = 4
    scale = 4
    items = [upscale(img, scale) if img.width <= 128 else img for _, img in WRITTEN]
    width = 1400
    x = y = 0
    row_h = 0
    placed = []
    for im in items:
        if x + im.width > width:
            x = 0
            y += row_h + pad_px
            row_h = 0
        placed.append((im, x, y))
        x += im.width + pad_px
        row_h = max(row_h, im.height)
    sheet = Image.new('RGBA', (width, y + row_h), (60, 60, 70, 255))
    for im, px, py in placed:
        sheet.alpha_composite(im, (px, py))
    out = os.path.join(ROOT, 'tools', 'art', 'contact_sheet.png')
    sheet.save(out)


if __name__ == '__main__':
    build()
