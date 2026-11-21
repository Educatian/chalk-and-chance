"""Chalk & Chance brand masters for the chosen logo, concept B "Think ring".

    python tools/art/brand_masters.py

Writes assets/brand/** (marks, lockups, ring-fill frames, icons 16-512, favicon,
splash, key art, store capsules) and docs/brand/{logo_sheet,icon_sizes,key_art}.png.
Everything is drawn in the locked palette at texel scale and only enlarged by whole
numbers (nearest neighbour). Concepts A and C stay in tools/art/brand.py.
"""
import math
import os
import sys
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from brand import GLYPHS, P, ROOT, new, put, rect, disc, text, text_w, upscale, hashf  # noqa: E402

OUT = os.path.join(ROOT, 'assets', 'brand')
DOCS = os.path.join(ROOT, 'docs', 'brand')
GALMURI = os.path.join(ROOT, 'ui', 'fonts', 'Galmuri11-Bold.ttf')
TAG_EN = "Practice the moments you can't plan."
TAG_KO = '계획대로 안 되는 순간까지, 미리 연습해요.'

# Colourways: (disc, ring fill, ring track, ampersand, dust) -- one-colour ways use one ink.
WAYS = {
    'color': ('navy', 'focus', 'slate', 'chalk', 'chalk_gy'),
    'light': ('wall_mod', 'yellow', 'tile_ln', 'ink', 'metal_dk'),
    'white': (None, 'chalk', None, 'chalk', None),
    'ink': (None, 'ink', None, 'ink', None),
}


def disc(img, cx, cy, r, key, ring=None):
    """Round disc without the cardinal bumps an integer radius test leaves."""
    for y in range(cy - r - 2, cy + r + 3):
        for x in range(cx - r - 2, cx + r + 3):
            d2 = (x - cx) ** 2 + (y - cy) ** 2
            if d2 <= (r + 0.5) ** 2:
                put(img, x, y, key)
            elif ring and d2 <= (r + 1.4) ** 2:
                put(img, x, y, ring)


def _amp(img, x0, y0, key, dust=None, k=2):
    for j, row in enumerate(GLYPHS['&']):
        for i, c in enumerate(row):
            if c == '#':
                for dy in range(k):
                    for dx in range(k):
                        kk = key
                        if dust and hashf(i * k + dx, j * k + dy, 3) % 23 == 0:
                            kk = dust
                        put(img, x0 + i * k + dx, y0 + j * k + dy, kk)


def mark(frac=0.75, way='color'):
    """32-texel master. frac = how full the think ring is (0..1). The fill carries a
    chalk-dust grain (from concept A) and sheds a few dust specks at its leading edge."""
    bg, fill, track, amp, dust = WAYS[way]
    m = new(32, 32)
    if bg:
        disc(m, 16, 16, 15, bg, ring='ink' if way == 'color' else None)
    lead = None
    for a10 in range(0, 3600, 15):
        a = a10 / 10.0
        r = math.radians(a - 90)
        on = a < 360 * frac
        for rr in (11, 12, 13):
            x = int(round(16 + rr * math.cos(r)))
            y = int(round(16 + rr * math.sin(r)))
            if on:
                k = fill
                if dust and hashf(x, y, 11) % 6 == 0:
                    k = 'yellow' if way == 'color' else dust
                put(m, x, y, k)
                lead = (x, y)
            elif track:
                put(m, x, y, track)
    if lead and dust and 0.05 < frac < 1.0:
        a = math.radians(360 * frac - 90)
        for i, (dr, da) in enumerate(((15, 0.10), (14, 0.22), (16, 0.30), (15, 0.40))):
            x = int(round(16 + dr * math.cos(a - da)))
            y = int(round(16 + dr * math.sin(a - da)))
            put(m, x, y, 'chalk' if i == 0 else dust)
    _amp(m, 9, 8, amp, dust if way == 'color' else None)
    return m


def mark16(way='color'):
    """Hand-drawn 16-texel mark: the ring and a small ampersand stay readable at 16 px."""
    bg, fill, track, amp, _ = WAYS[way]
    m = new(16, 16)
    if bg:
        disc(m, 8, 8, 7, bg)
    for a10 in range(0, 3600, 30):
        a = a10 / 10.0
        r = math.radians(a - 90)
        for rr in (5, 6):
            x = int(round(8 + rr * math.cos(r)))
            y = int(round(8 + rr * math.sin(r)))
            if a < 270:
                put(m, x, y, fill)
            elif track:
                put(m, x, y, track)
    small = [".##..", "#..#.", ".##..", "#.##.", "#..##", ".##.#"]
    for j, row in enumerate(small):
        for i, c in enumerate(row):
            if c == '#':
                put(m, 6 + i, 5 + j, amp)
    return m


def word(way='color'):
    fg = {'color': 'chalk', 'light': 'ink', 'white': 'chalk', 'ink': 'ink'}[way]
    acc = {'color': 'focus', 'light': 'red', 'white': 'chalk', 'ink': 'ink'}[way]
    s = 'CHALK & CHANCE'
    w = new(text_w(s) + 4, 13)
    text(w, s, 2, 2, fg, amp_key=acc)
    rect(w, 2, 11, int(text_w(s) * 0.75), 1, acc)   # the underline fills like the ring
    return w


def lockup_h(way='color', frac=0.75):
    mk, wd = mark(frac, way), word(way)
    out = new(mk.width + 5 + wd.width, mk.height)
    out.alpha_composite(mk, (0, 0))
    out.alpha_composite(wd, (mk.width + 5, (mk.height - wd.height) // 2 + 1))
    return out


def lockup_v(way='color'):
    mk, wd = mark(0.75, way), word(way)
    out = new(max(mk.width, wd.width), mk.height + 4 + wd.height)
    out.alpha_composite(mk, ((out.width - mk.width) // 2, 0))
    out.alpha_composite(wd, ((out.width - wd.width) // 2, mk.height + 4))
    return out


def pixel_text(s, size, key):
    """Render text in Galmuri (pixel face, covers Hangul) without antialiasing."""
    f = ImageFont.truetype(GALMURI, size)
    box = f.getbbox(s)
    im = Image.new('1', (box[2] - box[0] + 2, box[3] - box[1] + 2), 0)
    d = ImageDraw.Draw(im)
    d.fontmode = '1'
    d.text((1 - box[0], 1 - box[1]), s, font=f, fill=1)
    out = new(im.width, im.height)
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y]:
                put(out, x, y, key)
    return out


def lockup_ko(way='color'):
    """Korean lockup: the English mark kept as is (one game everywhere), a Korean
    tagline set under the wordmark in the pixel face."""
    lk = lockup_h(way)
    tag = pixel_text(TAG_KO, 12, 'chalk_gy' if way == 'color' else 'slate')
    out = new(max(lk.width, 37 + tag.width), lk.height + 3 + tag.height)
    out.alpha_composite(lk, (0, 0))
    out.alpha_composite(tag, (37, lk.height + 3))
    return out


def save(img, rel, k=1):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    (upscale(img, k) if k > 1 else img).save(path)
    return path


# ---------------------------------------------------------------- key art
def key_art():
    """480x270-texel title art: the front of a classroom from the teacher's spot, a
    student with a hand up and the think ring filling above her: the moment you wait."""
    W, H = 480, 270
    art = new(W, H, 'navy')
    # back wall and whiteboard
    rect(art, 0, 0, W, 150, 'screen')
    for y in range(0, 150, 2):
        for x in range(0, W, 2):
            if hashf(x, y, 5) % 23 == 0:
                put(art, x, y, 'navy')
    bx, by, bw, bh = 238, 22, 226, 96   # right half: the left half belongs to the logo and menu
    rect(art, bx - 3, by - 3, bw + 6, bh + 6, 'metal_dk')
    rect(art, bx - 2, by - 2, bw + 4, bh + 4, 'metal')
    rect(art, bx, by, bw, bh, 'board_dk')
    # chalk work on the board: a comparison, a number line, a half-shaded circle
    chalk = pixel_text('3/4 > 2/3 ?', 24, 'chalk')
    art.alpha_composite(chalk, (bx + 14, by + 12))
    rect(art, bx + 14, by + 66, 144, 1, 'chalk')
    for i in range(7):
        rect(art, bx + 14 + i * 24, by + 62, 1, 9, 'chalk')
    for i, n in enumerate(['0', '', '', '1/2', '', '', '1']):
        if n:
            lab = pixel_text(n, 12, 'chalk_gy')
            art.alpha_composite(lab, (bx + 10 + i * 24, by + 74))
    cx, cy, cr = bx + 192, by + 52, 20
    disc(art, cx, cy, cr, 'board_dk', ring='chalk')
    for y in range(cy - cr, cy + cr):
        for x in range(cx - cr, cx):
            if (x - cx) ** 2 + (y - cy) ** 2 <= (cr - 1) ** 2 and (x + y) % 3 == 0:
                put(art, x, y, 'chalk_gy')
    rect(art, cx, cy - cr, 1, 2 * cr, 'chalk')
    # floor
    rect(art, 0, 150, W, H - 150, 'tile')
    for y in range(150, H, 12):
        rect(art, 0, y, W, 1, 'tile_ln')
    # students: back row small, front row big (seated sheet frames: 0 calm, 4 hand up)
    def student(pid, frame, x, y, k):
        sh = Image.open(os.path.join(ROOT, 'assets', 'v2', 'sprites', '%s_seated.png' % pid)).convert('RGBA')
        fr = sh.crop((frame * 16, 0, frame * 16 + 16, 24))
        art.alpha_composite(upscale(fr, k), (x, y))
        dk = Image.open(os.path.join(ROOT, 'assets', 'v2', 'room_us', 'desk.png')).convert('RGBA')
        art.alpha_composite(upscale(dk, k), (x - k, y + 15 * k))
    for x, (pid, fr) in zip((250, 300, 410, 452), (('noah_g5_fractions', 0), ('talia_dominator', 1),
                                                 ('deshawn_offtask', 5), ('diego_ell', 0))):
        student(pid, fr, x, 128, 2)   # a gap in the middle, behind the raised hand
    for x, (pid, fr) in zip((262, 344, 426), (('jordan_skeptic', 0), ('priya_quiet', 4), ('meilin_anxious', 0))):
        student(pid, fr, x, 168, 3)
    # the think ring over the raised hand, filling
    ring = upscale(mark(0.62, 'color'), 2)
    art.alpha_composite(ring, (344 + 24 - 32, 98))
    # left fade so the logo and menu read over the art
    fade = new(W, H)
    bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    for x in range(0, 250):
        t = 1.0 if x < 200 else max(0.0, 1.0 - (x - 200) / 50.0)   # ordered-dither fade
        for y in range(H):
            if t * 16 > bayer[y % 4][x % 4]:
                put(fade, x, y, 'navy')
    art.alpha_composite(fade)
    return art


def capsule(w, h, _unused=0, way='color', with_tag=False, logo=True):
    """Store art. Wide formats: the class scene on the right, the logo on clean navy on
    the left. Tall formats: logo on top, scene below. Tiny formats: logo only. The scene
    is enlarged by a whole number and cropped, never squashed."""
    scene = key_art().crop((236, 0, 480, 270))          # board + class, 244 x 270 texels
    out = Image.new('RGBA', (w, h), P['navy'])
    tall = h > w * 1.05
    tiny = h < 120
    if not tiny:
        if tall:
            k = max(1, (w + scene.width - 1) // scene.width)
            sc = upscale(scene, k)
            sx = (sc.width - w) // 2
            area_h = min(int(h * 0.62), sc.height - 92 * k)   # start just above the ring
            crop = sc.crop((sx, sc.height - area_h, sx + w, sc.height))
            out.alpha_composite(crop, (0, h - crop.height))
        else:
            k = max(1, (h + scene.height - 1) // scene.height)
            sc = upscale(scene, k)
            sw = min(sc.width, int(w * (0.52 if logo else 0.75)))
            crop = sc.crop((0, (sc.height - h) // 2, sw, (sc.height - h) // 2 + h))
            out.alpha_composite(crop, (w - sw, 0))
    if not logo:
        return out.convert('RGB')
    lk = lockup_h(way) if tiny else lockup_v(way)
    room_w = w * (0.86 if (tall or tiny) else 0.46)
    room_h = h * (0.30 if tall else 0.8)
    k = max(1, int(min(room_w / lk.width, room_h / lk.height)))
    lk = upscale(lk, k)
    if tall:
        lx, ly = (w - lk.width) // 2, int(h * 0.06)
    elif tiny:
        lx, ly = (w - lk.width) // 2, (h - lk.height) // 2
    else:
        lx, ly = int(w * 0.48 - lk.width) // 2, (h - lk.height) // 2 - (k * 5 if with_tag else 0)
    out.alpha_composite(lk, (lx, ly))
    if with_tag and not tiny:
        tg = pixel_text(TAG_EN, 12, 'chalk')
        tk = max(1, min(max(1, k // 2), int((w * (0.86 if tall else 0.46)) // tg.width)))
        tg = upscale(tg, tk)
        tx = (w - tg.width) // 2 if tall else max(4, int(w * 0.48 - tg.width) // 2)
        out.alpha_composite(tg, (tx, ly + lk.height + 6 * tk))
    return out.convert('RGB')


def main():
    # marks, frames, lockups
    for way in WAYS:
        save(mark(0.75, way), 'mark/mark_%s_32.png' % way)
        save(mark(0.75, way), 'mark/mark_%s_x8.png' % way, 8)
        save(lockup_h(way), 'lockup/horizontal_%s_x4.png' % way, 4)
        save(lockup_h(way), 'lockup/horizontal_%s_x1.png' % way)
        save(lockup_v(way), 'lockup/stacked_%s_x4.png' % way, 4)
        save(mark16(way), 'mark/mark16_%s.png' % way)
    save(lockup_ko('color'), 'lockup/korean_color_x4.png', 4)
    save(lockup_ko('light'), 'lockup/korean_light_x4.png', 4)
    save(word('color'), 'lockup/wordmark_color_x4.png', 4)
    for i in range(13):
        save(mark(i / 12.0, 'color'), 'anim/ring_%02d.png' % i)   # x1: the game scales by whole numbers
    save(word('color'), 'anim/wordmark.png')
    # icons
    icons = {}
    for sz in (16, 32, 48, 64, 128, 256, 512):
        ic = mark16('color') if sz == 16 else (upscale(mark16('color'), 2) if sz == 32 else None)
        if ic is None:
            k = sz // 32
            ic = upscale(mark(0.75, 'color'), k) if k * 32 == sz else mark(0.75, 'color').resize((sz, sz), Image.NEAREST)
        icons[sz] = ic
        save(ic, 'icon/icon_%d.png' % sz)
    icons[48].save(os.path.join(OUT, 'icon', 'favicon.ico'), sizes=[(16, 16), (32, 32), (48, 48)],
                   append_images=[icons[16], icons[32]])
    # splash (boot): stacked lockup on navy
    sp = new(480, 270, 'navy')
    lv = lockup_v('color')
    sp.alpha_composite(lv, ((480 - lv.width) // 2, (270 - lv.height) // 2 - 6))
    save(sp, 'splash/splash_960x540.png', 2)
    # key art + store
    ka = key_art()
    save(ka, 'keyart/key_art_960x540.png', 2)
    save(ka, 'keyart/key_art_1920x1080.png', 4)
    store = {
        'steam_header_460x215': (460, 215, 2, False), 'steam_capsule_small_231x87': (231, 87, 1, False),
        'steam_capsule_main_616x353': (616, 353, 3, True), 'steam_capsule_vertical_374x448': (374, 448, 3, False),
        'steam_library_600x900': (600, 900, 4, True), 'steam_library_hero_3840x1240': (3840, 1240, 12, False),
        'itch_cover_630x500': (630, 500, 3, True),
    }
    os.makedirs(os.path.join(OUT, 'store'), exist_ok=True)
    for name, (w, h, k, tag) in store.items():
        capsule(w, h, k, with_tag=tag, logo='hero' not in name).save(os.path.join(OUT, 'store', name + '.png'))
    # Steam draws its library logo over the hero: transparent lockup, 1280x720
    ll = new(1280, 720)
    lk = upscale(lockup_v('color'), 6)
    ll.alpha_composite(lk, ((1280 - lk.width) // 2, (720 - lk.height) // 2))
    ll.save(os.path.join(OUT, 'store', 'steam_library_logo_1280x720.png'))
    sheets()
    print('brand masters written to', OUT)


def sheets():
    os.makedirs(DOCS, exist_ok=True)
    try:
        body = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 18)
        head = ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf', 22)
    except OSError:
        body = head = ImageFont.load_default()
    S = Image.new('RGBA', (1500, 1180), P['wall_mod'])
    d = ImageDraw.Draw(S)
    d.text((24, 16), 'Chalk & Chance logo: Think ring. Masters, colourways, clear space, minimum size, Korean lockup.', font=head, fill=P['ink'])
    dk = Image.new('RGBA', (720, 250), P['ink'])
    lk = upscale(lockup_h('color'), 4)
    dk.alpha_composite(lk, ((720 - lk.width) // 2, (250 - lk.height) // 2))
    S.alpha_composite(dk, (24, 60))
    lt = upscale(lockup_h('light'), 4)
    S.alpha_composite(lt, (780 + (690 - lt.width) // 2, 60 + (250 - lt.height) // 2))
    d.text((24, 316), 'Horizontal: colour on dark, colour on light', font=body, fill=P['slate'])
    dk2 = Image.new('RGBA', (340, 300), P['ink'])
    lv = upscale(lockup_v('color'), 3)
    dk2.alpha_composite(lv, ((340 - lv.width) // 2, (300 - lv.height) // 2))
    S.alpha_composite(dk2, (24, 350))
    lw = upscale(lockup_h('white'), 2)
    blk = Image.new('RGBA', (500, 140), P['red'])
    blk.alpha_composite(lw, ((500 - lw.width) // 2, (140 - lw.height) // 2))
    S.alpha_composite(blk, (390, 350))
    li = upscale(lockup_h('ink'), 2)
    S.alpha_composite(li, (390 + (500 - li.width) // 2, 510 + (140 - li.height) // 2))
    d.text((24, 656), 'Stacked; one-colour white (on any strong colour); one-colour ink (print, fax, stamps)', font=body, fill=P['slate'])
    # clear space: a quarter of the mark height (8 texels) on every side
    cs = Image.new('RGBA', (560, 300), P['wall_mod'])
    lk3 = upscale(lockup_h('light'), 2)
    pad = 8 * 2
    ox, oy = (560 - lk3.width) // 2, (300 - lk3.height) // 2
    dd = ImageDraw.Draw(cs)
    dd.rectangle((ox - pad, oy - pad, ox + lk3.width + pad, oy + lk3.height + pad), outline=P['red'])
    dd.rectangle((ox, oy, ox + lk3.width, oy + lk3.height), outline=P['metal'])
    cs.alpha_composite(lk3, (ox, oy))
    S.alpha_composite(cs, (920, 350))
    d.text((920, 656), 'Clear space: 1/4 of the mark height on every side (red)', font=body, fill=P['slate'])
    # minimum sizes + Korean lockup
    y = 700
    d.text((24, y), 'Minimum size: mark 16 px (hand-drawn 16-texel version), wordmark 13 px tall (x1)', font=body, fill=P['slate'])
    m1 = Image.new('RGBA', (400, 60), P['ink'])
    m1.alpha_composite(mark16('color'), (10, 22))
    m1.alpha_composite(lockup_h('color'), (40, 14))
    S.alpha_composite(m1, (24, y + 34))
    ko = Image.new('RGBA', (980, 230), P['ink'])
    kl = upscale(lockup_ko('color'), 3)
    ko.alpha_composite(kl, ((980 - kl.width) // 2, (230 - kl.height) // 2))
    S.alpha_composite(ko, (24, y + 120))
    d.text((24, y + 360), 'Korean lockup (proposed): the same English mark everywhere, a Korean tagline in the pixel face (Galmuri, covers Hangul).',
           font=body, fill=P['slate'])
    d.text((24, y + 388), 'English tagline: ' + TAG_EN, font=body, fill=P['slate'])
    S.convert('RGB').save(os.path.join(DOCS, 'logo_sheet.png'))
    # icon sizes
    I = Image.new('RGBA', (1500, 640), P['wall_mod'])
    d = ImageDraw.Draw(I)
    d.text((24, 16), 'Icon sizes, actual pixels, on dark and light (16 and 32 use the hand-drawn 16-texel mark)', font=head, fill=P['ink'])
    x = 24
    for sz in (16, 32, 48, 64, 128, 256, 512):
        ic = Image.open(os.path.join(OUT, 'icon', 'icon_%d.png' % sz))
        if sz <= 256:
            for j, bgc in enumerate(('ink', 'tile')):
                t = Image.new('RGBA', (sz + 12, sz + 12), P[bgc])
                t.alpha_composite(ic, (6, 6))
                I.alpha_composite(t, (x, 70 + j * (sz + 24)))
            d.text((x, 70 + 2 * (sz + 24)), '%d' % sz, font=body, fill=P['slate'])
            x += sz + 30
        else:
            I.alpha_composite(ic.resize((256, 256), Image.NEAREST), (x, 70))
            d.text((x, 340), '512 (shown at half)', font=body, fill=P['slate'])
    I.convert('RGB').save(os.path.join(DOCS, 'icon_sizes.png'))
    upscale(key_art(), 2).convert('RGB').save(os.path.join(DOCS, 'key_art.png'))


if __name__ == '__main__':
    main()
