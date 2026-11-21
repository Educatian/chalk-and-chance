"""Chalk & Chance brand: three logo concepts (wordmark + compact mark), drawn as pixel art
in the locked palette, plus a comparison sheet on dark/light grounds and at small sizes.

    python tools/art/brand.py concepts      -> assets/brand/concepts/*.png, docs/brand/logo_concepts.png

Original marks only. Letterforms are a custom bitmap capital set (no font file), so the
wordmark has none of the pixel face's ambiguous glyphs.
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from palette import PALETTE as P  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CLEAR = (0, 0, 0, 0)

# 6x8 capitals (texels). '#' = ink of the stroke.
GLYPHS = {
    'C': [".####.", "##..##", "##....", "##....", "##....", "##....", "##..##", ".####."],
    'H': ["##..##", "##..##", "##..##", "######", "######", "##..##", "##..##", "##..##"],
    'A': ["..##..", ".####.", "##..##", "##..##", "######", "##..##", "##..##", "##..##"],
    'L': ["##....", "##....", "##....", "##....", "##....", "##....", "######", "######"],
    'K': ["##..##", "##.##.", "####..", "###...", "####..", "##.##.", "##..##", "##..##"],
    'N': ["##..##", "###.##", "######", "##.###", "##..##", "##..##", "##..##", "##..##"],
    'E': ["######", "##....", "##....", "#####.", "##....", "##....", "##....", "######"],
    '&': [".###..", "##.##.", "##.##.", ".###..", "####.#", "##.###", "##..##", ".###.#"],
    ' ': ["...", "...", "...", "...", "...", "...", "...", "..."],
}


def new(w, h, bg=None):
    return Image.new('RGBA', (w, h), P[bg] if bg else CLEAR)


def put(img, x, y, key):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), P[key] if isinstance(key, str) else key)


def rect(img, x, y, w, h, key):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            put(img, xx, yy, key)


def hashf(*v):
    h = 2166136261
    for n in v:
        h = ((h ^ (n & 0xffffffff)) * 16777619) & 0xffffffff
    return h


def text(img, s, x, y, key, dust=None, skip_amp=False, amp_key=None):
    """Draw a string in the bitmap capitals. dust: palette key sprinkled into strokes (chalk)."""
    cx = x
    for ch in s:
        g = GLYPHS[ch]
        if ch == '&' and skip_amp:
            cx += len(g[0]) + 2
            continue
        for j, row in enumerate(g):
            for i, c in enumerate(row):
                if c == '#':
                    k = amp_key if (ch == '&' and amp_key) else key
                    if dust and hashf(cx + i, y + j, 7) % 7 == 0:
                        k = dust
                    put(img, cx + i, y + j, k)
        cx += len(g[0]) + 1
    return cx


def text_w(s):
    return sum(len(GLYPHS[c][0]) + 1 for c in s) - 1


def upscale(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def disc(img, cx, cy, r, key, ring=None):
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            d2 = (x - cx) ** 2 + (y - cy) ** 2
            if d2 <= r * r:
                put(img, x, y, key)
            elif ring and d2 <= (r + 1) ** 2:
                put(img, x, y, ring)


# ------------------------------------------------------------------- concept A: the roll
def mark_a(fg='chalk', bg='board', dust='chalk_gy', face='board_dk'):
    """A chalk-drawn die mid-roll on a board square: the pips are chalk dots and a chalk
    stroke trails out of the tumble (the craft line drawn from the chance moment)."""
    m = new(32, 32)
    rect(m, 1, 1, 30, 30, bg)
    rect(m, 0, 2, 32, 28, bg)
    rect(m, 2, 0, 28, 32, bg)
    die = new(17, 17)
    rect(die, 1, 0, 15, 17, fg)
    rect(die, 0, 1, 17, 15, fg)
    rect(die, 2, 2, 13, 13, face)
    for (px, py) in ((4, 4), (11, 4), (7, 7), (4, 11), (11, 11)):   # five
        rect(die, px, py, 2, 2, fg)
    rot = die.rotate(18, resample=Image.NEAREST, expand=True)
    m.alpha_composite(rot, (8, 3))
    # the stroke: a chalk line swept out from under the die, fading to dust
    path = [(6, 25), (8, 26), (10, 27), (12, 27), (14, 27), (16, 27), (18, 26), (20, 26), (22, 25), (24, 25)]
    for i, (x, y) in enumerate(path):
        k = fg if i < 6 else dust
        put(m, x, y, k)
        put(m, x, y + 1, k if i < 4 else dust)
    for (x, y) in ((26, 24), (28, 24), (27, 22)):
        put(m, x, y, dust)
    # motion ticks (the roll)
    for (x, y) in ((4, 7), (3, 9), (4, 11)):
        put(m, x, y, dust)
    return m


def word_a(fg='chalk', dust='chalk_gy', amp='focus'):
    s = 'CHALK & CHANCE'
    w = new(text_w(s) + 4, 12)
    text(w, s, 2, 2, fg, dust=dust, amp_key=amp)
    return w


# ------------------------------------------------------------------- concept B: think ring
def mark_b(ring='focus', track='slate', fg='chalk', bg='navy'):
    """The think-time ring from the game itself, three-quarters full, with a chalk
    ampersand inside: the pause (craft) before the answer you cannot predict (chance)."""
    m = new(32, 32)
    disc(m, 16, 16, 15, bg)
    import math
    for a in range(0, 360, 2):
        r = math.radians(a - 90)
        for rr in (11, 12, 13):
            x = int(round(16 + rr * math.cos(r)))
            y = int(round(16 + rr * math.sin(r)))
            put(m, x, y, ring if a < 270 else track)
    # spark at the leading edge of the fill
    for (x, y) in ((3, 13), (2, 15), (4, 15), (3, 17)):
        put(m, x, y, 'chalk')
    g = GLYPHS['&']
    # the ampersand at 2x inside the ring
    amp = new(6, 8)
    for j, row in enumerate(g):
        for i, c in enumerate(row):
            if c == '#':
                put(amp, i, j, fg)
    m.alpha_composite(upscale(amp, 2), (10, 8))
    return m


def word_b(fg='chalk', amp='focus'):
    s = 'CHALK & CHANCE'
    w = new(text_w(s) + 4, 12)
    text(w, s, 2, 2, fg, amp_key=amp)
    # underline that fills like the ring
    rect(w, 2, 11, int(text_w(s) * 0.75), 1, amp)
    return w


# ------------------------------------------------------------------- concept C: hand up
def mark_c(card='paper', edge='paper_ln', fg='board', accent='focus'):
    """A card dealt from the deck (chance) carrying a raised hand drawn on it (the
    classroom moment you answer with craft). No suit, no question mark."""
    m = new(32, 32)
    # tilted card: draw upright 20x28 then rotate a few degrees by shearing columns
    c = new(22, 28)
    rect(c, 1, 0, 20, 28, card)
    rect(c, 0, 1, 22, 26, card)
    for x in range(1, 21):
        put(c, x, 0, edge)
        put(c, x, 27, edge)
    for y in range(1, 27):
        put(c, 0, y, edge)
        put(c, 21, y, edge)
    # raised open hand: four separated fingers, palm, thumb out to the side
    for (x0, top) in ((6, 6), (9, 4), (12, 5), (15, 8)):
        rect(c, x0, top, 2, 13 - top, fg)
    rect(c, 6, 12, 11, 8, fg)
    rect(c, 7, 20, 9, 3, fg)
    for i in range(4):
        rect(c, 3 + i, 15 - i, 2, 2, fg)   # thumb
    # corner indices: a small chalk dot cluster (the 'pip' of this deck)
    for (x, y) in ((3, 3), (4, 3), (3, 4), (18, 23), (17, 24), (18, 24)):
        put(c, x, y, accent)
    rot = c.rotate(-8, resample=Image.NEAREST, expand=True)
    m.alpha_composite(rot, ((32 - rot.width) // 2, (32 - rot.height) // 2))
    return m


def word_c(top='chalk', bottom='focus'):
    w1, w2 = 'CHALK', '& CHANCE'
    w = new(max(text_w(w1), text_w(w2)) + 4, 21)
    text(w, w1, 2, 1, top)
    text(w, w2, 2, 11, bottom)
    return w


CONCEPTS = [
    ('A', 'The roll', 'A chalk die mid-tumble on a board square, a chalk stroke trailing out of the roll: the craft line drawn from the chance moment.',
     lambda dark: mark_a() if dark else mark_a(fg='ink', bg='wall_mod', dust='metal_dk', face='wall_mod'),
     lambda dark: word_a() if dark else word_a(fg='ink', dust='slate', amp='red')),
    ('B', 'Think ring', "The game's own think-time ring, three-quarters full, holding the ampersand: the pause you hold before an answer you cannot predict.",
     lambda dark: mark_b() if dark else mark_b(track='tile_ln', fg='ink', bg='wall_mod'),
     lambda dark: word_b() if dark else word_b(fg='ink', amp='yellow')),
    ('C', 'Hand up', 'A card dealt mid-lesson with a raised hand on it: every classroom moment arrives by chance, and you answer it with craft.',
     lambda dark: mark_c() if dark else mark_c(card='wall_mod', edge='ink'),
     lambda dark: word_c() if dark else word_c(top='ink', bottom='red')),
]


def lockup(mark, word, k=4, gap=4):
    h = max(mark.height, word.height)
    out = new(mark.width + gap + word.width, h)
    out.alpha_composite(mark, (0, (h - mark.height) // 2))
    out.alpha_composite(word, (mark.width + gap, (h - word.height) // 2))
    return upscale(out, k)


def concepts():
    out_dir = os.path.join(ROOT, 'assets', 'brand', 'concepts')
    os.makedirs(out_dir, exist_ok=True)
    font = ImageFont.truetype(os.path.join(ROOT, 'ui', 'fonts', 'PixelifySans.ttf'), 22)
    try:
        body = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 20)
        head = ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf', 24)
    except OSError:
        body = head = ImageFont.load_default()
    rows = []
    for cid, name, why, mk, wd in CONCEPTS:
        for dark in (True, False):
            m, w = mk(dark), wd(dark)
            tag = 'dark' if dark else 'light'
            upscale(m, 8).save(os.path.join(out_dir, 'concept_%s_mark_%s.png' % (cid, tag)))
            lockup(m, w).save(os.path.join(out_dir, 'concept_%s_lockup_%s.png' % (cid, tag)))
        W, H = 1500, 300
        row = Image.new('RGBA', (W, H), P['wall_mod'])
        dk = Image.new('RGBA', (690, 200), P['ink'])
        lk = lockup(mk(True), wd(True), k=4)
        dk.alpha_composite(lk, ((690 - lk.width) // 2, (200 - lk.height) // 2))
        row.alpha_composite(dk, (20, 50))
        lt = Image.new('RGBA', (500, 200), P['wall_mod'])
        lk2 = lockup(mk(False), wd(False), k=3)
        lt.alpha_composite(lk2, ((500 - lk2.width) // 2, (200 - lk2.height) // 2))
        row.alpha_composite(lt, (720, 50))
        # small sizes: 16 / 32 / 64 px icons on dark and light
        x = 1240
        for sz in (16, 32, 64):
            for j, dark in enumerate((True, False)):
                ic = mk(dark).resize((sz, sz), Image.NEAREST if sz % 32 == 0 else Image.BOX)
                tile = Image.new('RGBA', (sz + 8, sz + 8), P['ink'] if dark else P['tile'])
                tile.alpha_composite(ic, (4, 4))
                row.alpha_composite(tile, (x, 60 + j * 90))
            x += sz + 20
        d = ImageDraw.Draw(row)
        d.text((20, 12), 'Concept %s:  %s' % (cid, name), font=head, fill=P['ink'])
        d.text((20, 258), why, font=body, fill=P['slate'])
        rows.append(row)
    sheet = Image.new('RGBA', (1500, 300 * len(rows) + 60), P['wall_mod'])
    d = ImageDraw.Draw(sheet)
    d.text((20, 16), 'Chalk & Chance: logo concepts. Dark ground, light ground, icons at 16 / 32 / 64 px.', font=head, fill=P['ink'])
    for i, r in enumerate(rows):
        sheet.alpha_composite(r, (0, 60 + i * 300))
    dst = os.path.join(ROOT, 'docs', 'brand', 'logo_concepts.png')
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    sheet.convert('RGB').save(dst)
    print('wrote', dst)


if __name__ == '__main__':
    {'concepts': concepts}[sys.argv[1] if len(sys.argv) > 1 else 'concepts']()
