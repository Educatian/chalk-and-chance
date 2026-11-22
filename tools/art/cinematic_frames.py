"""Mission cinematics, one composed frame per story beat, in both classroom looks.

    python tools/art/cinematic_frames.py      # writes assets/v2/cinematic/<scenario>/<frame>[_kr].png
                                              # and docs/qa/open-items/cinematic_frames_{us,kr}.png

Same approach as the title key art (tools/art/brand_masters.py key_art): front-of-class
framing from the teacher's spot, the board readable and carrying that lesson's work,
depth from rows (back row x2, front row x3), large characters. Each beat gets its own
shot chosen from who speaks and what the line is about:
  wide      the class in its seating, eyes front           (narrator, title)
  student   the speaking student large in the foreground, at their desk, the think ring
            around them, the class dimmed behind              (a persona speaks)
  adult     Coach Vee / Mr. Hollis / Principal Reyes large on the right; students the
            line names are ringed in the class               (vee, hollis, reyes)
  you       over your shoulder: you large from behind, the class looking at you (inner voice)
The bottom of every frame (texels 160+) holds only desks and floor: the cinematic puts the
title, captions and dialogue on a band there, never over a face. 480x270 texels, shown x2.
All drawing is code in the locked palette; sprites and portraits are the game's own v2 art.
"""
import json
import math
import os
import re
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import build_art as B          # noqa: E402
import modern_room as M        # noqa: E402
from brand_masters import pixel_text   # noqa: E402

ROOT = B.ROOT
OUT = os.path.join(ROOT, 'assets', 'v2', 'cinematic')
W, H = 480, 270
FACE_LINE = 160          # nothing that matters below this texel row
P = B.P


def new(w=W, h=H):
    return Image.new('RGBA', (w, h), (0, 0, 0, 0))


def rect(img, x, y, w, h, key):
    B.rect(img, int(x), int(y), int(w), int(h), key)


def up(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def sprite(pid, frame):
    sh = Image.open(os.path.join(ROOT, 'assets', 'v2', 'sprites', '%s_seated.png' % pid)).convert('RGBA')
    return sh.crop((frame * 16, 0, frame * 16 + 16, 24))


def portrait(pid, mood):
    for m in (mood, 'neutral'):
        p = os.path.join(ROOT, 'assets', 'v2', 'portraits', '%s_%s.png' % (pid, m))
        if os.path.exists(p):
            return Image.open(p).convert('RGBA')
    return None


def dim(img, amount=0.45):
    """Darken towards navy (keeps the palette feel; used for the class behind a focus)."""
    nv = P['navy']
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (int(r + (nv[0] - r) * amount), int(g + (nv[1] - g) * amount), int(b + (nv[2] - b) * amount), a)
    return img


# --------------------------------------------------------------------- the room

def room(look):
    """Back wall, board (US whiteboard + flat panel / KR sliding green board + TV) and floor."""
    kr = look == 'kr'
    img = new()
    rect(img, 0, 0, W, 132, 'wall_mod')
    rect(img, 0, 0, W, 30, 'ceiling')
    rect(img, 0, 128, W, 4, 'metal_dk')                     # cove base
    # floor with perspective: rows of tiles / planks get taller towards the camera
    y, k = 132, 0
    while y < H:
        hgt = 6 + k * 3
        if kr:
            rect(img, 0, y, W, hgt, 'maple_lt' if k % 2 else 'maple')
            for x in range((k * 23) % 40, W, 40 + k * 6):
                rect(img, x, y, 1, hgt, 'maple_sh')
        else:
            rect(img, 0, y, W, hgt, 'tile_lt' if k % 2 else 'tile')
            rect(img, 0, y, W, 1, 'tile_ln')
            n = 10 + k * 2
            for i in range(-n, n + 1):          # tile seams converge on the board
                x = W // 2 + i * (W // (2 * n) + k * 4)
                rect(img, x, y, 1, hgt, 'tile_ln')
        y += hgt
        k += 1
    # side wall pieces: anchor charts (US) / class notices and a window with curtains (KR)
    for i, x in enumerate((22, 62, 402, 442)):
        piece = M.anchor_chart((i * 2 + (1 if kr else 0)) % 5)
        img.alpha_composite(up(piece, 2).crop((0, 8, 32, 56)), (x - 8, 50))
    if kr:
        bx, by, bw, bh = 128, 44, 224, 62
        rect(img, bx - 3, by - 3, bw + 6, bh + 6, 'metal')
        rect(img, bx - 1, by - 1, bw + 2, bh + 2, 'metal_dk')
        rect(img, bx, by, bw, bh, 'board')
        rect(img, bx + bw // 2, by, 1, bh, 'board_dk')             # the two sliding panels
        rect(img, bx, by + bh, bw, 3, 'metal')                     # chalk tray
        rect(img, W // 2 - 20, 24, 40, 16, 'ink')                   # TV above the board
        rect(img, W // 2 - 18, 26, 36, 12, 'screen')
        rect(img, bx, 28, 14, 10, 'chalk'); rect(img, bx + 4, 31, 6, 4, 'red'); rect(img, bx + 5, 34, 4, 2, 'blue')  # flag
        rect(img, bx + bw - 34, 28, 34, 10, 'wood'); rect(img, bx + bw - 32, 30, 30, 6, 'cream')               # class motto
        fg, fg2, acc = 'chalk', 'chalk_gy', 'yellow'
    else:
        bx, by, bw, bh = 132, 38, 196, 66
        rect(img, bx - 3, by - 3, bw + 6, bh + 6, 'metal_dk')
        rect(img, bx - 1, by - 1, bw + 2, bh + 2, 'metal')
        rect(img, bx, by, bw, bh, 'whiteboard')
        rect(img, bx, by + bh + 1, bw, 2, 'metal')
        rect(img, 336, 44, 40, 26, 'ink'); rect(img, 338, 46, 36, 22, 'screen')          # flat panel
        rect(img, 340, 48, 20, 3, 'teal'); rect(img, 340, 54, 28, 2, 'slate')
        fg, fg2, acc = 'ink', 'slate', 'blue'
    return img, (bx, by, bw, bh), (fg, fg2, acc)


def board_work(img, box, ink, sid):
    """The lesson on the board: language-neutral (numbers and drawings), readable."""
    bx, by, bw, bh = box
    fg, fg2, acc = ink
    cx = bx + bw // 2

    def t(s, x, y, size=16, key=None):
        im = pixel_text(s, size, key or fg)
        img.alpha_composite(im, (int(x - im.width // 2), int(y)))
        return im

    def bar(x, y, w, parts, shade):
        rect(img, x, y, w, 10, fg)
        rect(img, x + 1, y + 1, w - 2, 8, 'whiteboard' if fg == 'ink' else 'board')
        for i in range(parts):
            if i < shade:
                rect(img, x + 1 + i * (w - 2) // parts, y + 1, (w - 2) // parts, 8, acc)
            rect(img, x + i * w // parts, y, 1, 10, fg)

    def circle(x, y, r, slices, shade):
        for a10 in range(0, 3600, 6):
            a = math.radians(a10 / 10.0)
            B.put(img, int(round(x + r * math.cos(a))), int(round(y + r * math.sin(a))), fg)
        for s in range(slices):
            a = math.radians(360.0 * s / slices - 90)
            for rr in range(r):
                B.put(img, int(round(x + rr * math.cos(a))), int(round(y + rr * math.sin(a))), fg)
        for s in range(shade):
            a = math.radians(360.0 * (s + 0.5) / slices - 90)
            B.put(img, int(x + r * 0.55 * math.cos(a)), int(y + r * 0.55 * math.sin(a)), acc)
            B.put(img, int(x + r * 0.55 * math.cos(a)) + 1, int(y + r * 0.55 * math.sin(a)), acc)

    if sid == 'lecture_fractions':
        t('1/2 = 2/4', cx, by + 8, 20)
        bar(bx + 30, by + 40, 64, 2, 1); bar(bx + bw - 94, by + 40, 64, 4, 2)
    elif sid == 'independent_fractions':
        t('1/3 + 1/3 = ?', cx, by + 8, 18)
        for i in range(3):
            rect(img, bx + 24, by + 38 + i * 10, bw - 48, 1, fg2)
            t('%d.' % (i + 1), bx + 18, by + 32 + i * 10, 12, fg2)
    elif sid == 'discussion_fractions':
        t('1/8  ?  1/4', cx, by + 6, 18)
        circle(bx + 60, by + 50, 17, 8, 1); circle(bx + bw - 60, by + 50, 17, 4, 1)
    elif sid == 'reading_main_idea':
        rect(img, bx + 30, by + 22, 16, 10, 'yellow'); rect(img, bx + 34, by + 22, 3, 10, fg); rect(img, bx + 40, by + 22, 3, 10, fg)
        rect(img, bx + 32, by + 16, 8, 6, fg2); rect(img, bx + 42, by + 16, 8, 6, fg2)              # a honeybee
        t('?', bx + 38, by + 40, 18, acc)
        for i in range(5):
            rect(img, bx + 70, by + 14 + i * 10, bw - 100 - (i % 2) * 30, 1, fg2)
    elif sid == 'culturally_responsive_intro':
        circle(bx + 56, by + 38, 24, 8, 3)
        t('1/8', bx + 56, by + 6, 12, fg2)
        t('3/8 ?', bx + bw - 64, by + 24, 20)
    elif sid == 'custom_comparing_decimals':
        t('0.25  ?  0.5', cx, by + 8, 20)
        for i, lab in enumerate(['0.', '1', '2', '5']):
            rect(img, bx + 40 + i * 30, by + 42, 28, 18, fg)
            rect(img, bx + 41 + i * 30, by + 43, 26, 16, 'whiteboard' if fg == 'ink' else 'board')
            t(lab, bx + 54 + i * 30, by + 45, 12)
    elif sid == 'group_work_fractions':
        for i, n in enumerate((1, 2, 3, 4, 6)):
            bar(bx + 20, by + 8 + i * 12, bw - 40, n, n // 2 if n > 1 else 1)
    elif sid == 'science_force_motion':
        for i in range(70):                                   # ramp
            rect(img, bx + 24 + i, by + 60 - i * 40 // 70, 1, 1 + i * 40 // 70, fg2)
        rect(img, bx + 70, by + 22, 12, 8, acc); rect(img, bx + 71, by + 30, 3, 3, fg); rect(img, bx + 78, by + 30, 3, 3, fg)
        t('1 kg  vs  5 kg', bx + bw - 64, by + 14, 14)
        t('?', bx + bw - 64, by + 36, 22, acc)
    elif sid == 'gym_capstone':
        t('2/3 ?', cx, by + 10, 20)
        t('11:00', bx + bw - 30, by + bh - 18, 12, fg2)
    else:
        t('?', cx, by + 18, 24)


# --------------------------------------------------------------------- seating in front view

def seats(arr):
    """(x, y_top, scale) for each seat seen from the front, back row first (drawn first)."""
    # back row x3 / front row x4; the middle stays clear under the board so it reads
    if arr.startswith('ushape'):
        return [(176, 94, 2), (272, 94, 2), (88, 86, 3), (344, 86, 3), (8, 112, 4), (408, 112, 4), (224, 94, 2), (96, 128, 4), (320, 128, 4)]
    if arr.startswith('clusters'):
        return [(40, 86, 3), (100, 86, 3), (332, 86, 3), (392, 86, 3), (16, 114, 4), (92, 114, 4), (324, 114, 4), (400, 114, 4)]
    return [(20, 86, 3), (100, 86, 3), (332, 86, 3), (412, 86, 3), (208, 112, 4), (40, 116, 4), (376, 116, 4), (160, 86, 3)]


def draw_student(img, pid, frame, x, y, k, look, darken=0.0):
    s = up(sprite(pid, frame), k)
    d = up(Image.open(os.path.join(ROOT, 'assets', 'v2', 'room_%s' % ('kr' if look == 'kr' else 'us'), 'desk.png')).convert('RGBA'), k)
    if darken:
        s, d = dim(s.copy(), darken), dim(d.copy(), darken)
    img.alpha_composite(s, (x, y))
    img.alpha_composite(d, (x - k, y + 15 * k))


def ring(img, cx, cy, r, frac=0.7):
    for a10 in range(0, 3600, 8):
        a = math.radians(a10 / 10.0 - 90)
        for rr in (r, r + 1, r + 2):
            B.put(img, int(round(cx + rr * math.cos(a))), int(round(cy + rr * math.sin(a))), 'focus' if a10 < 3600 * frac else 'slate')


MOOD_FRAME = {'excited': 4, 'proud': 4, 'withdrawn': 5, 'shy': 5, 'anxious': 5, 'confused': 2,
              'thinking': 3, 'frustrated': 5, 'neutral': 0, 'engaged': 1, 'curious': 3}


def class_layer(look, cfg, focus=(), frames=None, darken_others=0.0, skip=(), empty=False, focus_frac=0.7):
    """The seated class in its arrangement (a small class takes the big front seats first).
    focus ids are drawn bright and ringed; empty draws the desks only (before the bell)."""
    img = new()
    roster = [r['id'] for r in cfg.get('roster', [])]
    spots = seats(str(cfg.get('arrangement', 'rows')))
    order = sorted(range(len(spots)), key=lambda i: (-spots[i][2], spots[i][1]))[:len(roster)]
    taken = sorted(((spots[si], roster[n]) for n, si in enumerate(order)), key=lambda t: (t[0][2], t[0][1]))
    placed = {}
    desk_png = os.path.join(ROOT, 'assets', 'v2', 'room_%s' % ('kr' if look == 'kr' else 'us'), 'desk.png')
    for n, ((x, y, k), pid) in enumerate(taken):
        if empty:
            img.alpha_composite(up(Image.open(desk_png).convert('RGBA'), k), (x - k, y + 15 * k))
            continue
        if pid in skip:
            continue
        fr = (frames or {}).get(pid, (n * 3) % 2)      # calm / breathing, varied
        draw_student(img, pid, fr, x, y, k, look, 0.0 if pid in focus else darken_others)
        placed[pid] = (x, y, k)
    for pid in focus:
        if pid in placed:
            x, y, k = placed[pid]
            ring(img, x + 8 * k, y + 6 * k, 9 * k, focus_frac)
    return img


def foreground_bust(img, port, right=True, k=3, desk_look=None):
    """A speaker large in the foreground. Adults' busts run off the bottom; a student's
    floats, so they sit behind a big desk front (their own desk, close to camera)."""
    b = up(port, k)
    x = W - b.width - 10 if right else 6
    y = H - b.height - (34 if desk_look else 14)
    img.alpha_composite(b, (x, y))
    if desk_look:
        d = up(Image.open(os.path.join(ROOT, 'assets', 'v2', 'room_%s' % desk_look, 'desk.png')).convert('RGBA'), 9)
        img.alpha_composite(d, (x + b.width // 2 - d.width // 2, y + 150))
    return x, y


# --------------------------------------------------------------------- shots

def mentioned(text):
    return re.findall(r'\{([a-z0-9_]+)\}', text or '')


# Per-beat direction: what just happened and where the eye goes. side = which side the
# speaker stands (alternates so consecutive lines are different pictures); class = the
# room's state; focus = students the beat is about (ringed); teacher = you, walking the room.
HEADS_DOWN, AWAY, HANDS, EYES = 'heads_down', 'away', 'hands', 'eyes'
DIRECTION = {
    'lecture_fractions': {0: {'empty': True}, 2: {'side': 'right'}, 3: {'side': 'left', 'class': AWAY},
                          4: {'side': 'right', 'class': HANDS}, 5: {'class': EYES}},
    'independent_fractions': {0: {'class': HEADS_DOWN}, 1: {'class': HEADS_DOWN}, 2: {'side': 'right'},
                              3: {'side': 'left', 'class': HEADS_DOWN, 'teacher': True}},
    'discussion_fractions': {2: {'side': 'right'}, 3: {'side': 'left', 'focus': ['sam_withdrawn'], 'frac': 0.3},
                             4: {'class': EYES}},
    'reading_main_idea': {2: {'side': 'right'}, 3: {'side': 'left', 'class': HANDS}},
    'culturally_responsive_intro': {0: {'empty': True}, 2: {'side': 'left'}, 4: {'side': 'right', 'focus': ['diego_ell']}},
    'custom_comparing_decimals': {2: {'side': 'left', 'focus': ['noah_g5_fractions']}, 3: {'side': 'right', 'class': HANDS}},
    'group_work_fractions': {1: {'side': 'right'}, 3: {'side': 'left'}, 4: {'side': 'right', 'teacher': True}},
    'science_force_motion': {1: {'side': 'left'}, 3: {'side': 'right'}},
    'gym_capstone': {0: {'adult': ('reyes', 'neutral'), 'side': 'left'}, 1: {'side': 'right'},
                     3: {'class': 'chaos'}, 4: {'side': 'left'},
                     5: {'side': 'right', 'focus': ['noah_g5_fractions'], 'frames': {'noah_g5_fractions': 4}}},
}
NAMED_FRAME = {'riley_avoidant': 5, 'sam_withdrawn': 5, 'talia_dominator': 4, 'marcus_volatile': 3}


def class_frames(cfg, state):
    ids = [r['id'] for r in cfg.get('roster', [])]
    if state == HEADS_DOWN:
        return {p: 5 for p in ids}
    if state == AWAY:                    # half the room is gone
        return {p: (5, 2, 0, 3)[i % 4] for i, p in enumerate(ids)}
    if state == HANDS:
        return {p: (4 if i % 2 == 0 else 1) for i, p in enumerate(ids)}
    if state == EYES:
        return {p: 0 for p in ids}
    if state == 'chaos':
        return {'marcus_volatile': 5, 'noah_g5_fractions': 4, 'priya_quiet': 5, 'deshawn_offtask': 2}
    return {}


def teacher_walking(img):
    t = up(B.teacher_frame(B.T_BACK, 0), 4)           # you, from behind, walking the room
    img.alpha_composite(t, (W // 2 - 90, H - t.height - 40))


def frame_for(sid, cfg, beat, look, idx, kind_override=None):
    img, box, ink = room(look)
    board_work(img, box, ink, sid)
    beat = beat or {}
    who = beat.get('speaker', 'narrator')
    mood = beat.get('mood', 'neutral')
    d = DIRECTION.get(sid, {}).get(int(idx), {}) if str(idx).isdigit() else {}
    ids = [r['id'] for r in cfg.get('roster', [])]
    names = [n for n in mentioned(beat.get('text', '')) if n in ids] + [n for n in d.get('focus', []) if n in ids]
    kind = kind_override or ('wide' if who == 'narrator' else 'you' if who == 'you' else
                             'adult' if who in ('vee', 'hollis', 'reyes') else 'student')
    if d.get('adult'):
        kind = 'adult'
        who, mood = d['adult']
    text = beat.get('text', '').lower()
    state = d.get('class') or (HEADS_DOWN if ('worksheet' in text or 'practice day' in text) else
                               'chaos' if 'projector dies' in text else None)
    frames = class_frames(cfg, state)
    frames.update(d.get('frames', {}))
    for pid in names:                                 # a named student shows what the line says
        frames.setdefault(pid, NAMED_FRAME.get(pid, 0))
    if 'projector dies' in text:
        rect(img, 338, 46, 36, 22, 'ink')
    frac = d.get('frac', 0.7)
    right = d.get('side', 'right') != 'left'
    if kind == 'wide':
        img.alpha_composite(class_layer(look, cfg, focus=names, frames=frames, darken_others=0.4 if names else 0.0,
                                        empty=d.get('empty', False), focus_frac=frac))
        if d.get('teacher'):
            teacher_walking(img)
    elif kind == 'you':
        # over your shoulder: you, from behind and large in the foreground, the class
        # looking back at you (eyes front)
        img.alpha_composite(class_layer(look, cfg, focus=names, frames=frames or {p: 0 for p in ids},
                                        darken_others=0.35 if names else 0.0))
        t = up(B.teacher_frame(B.T_BACK, 1), 6)
        img.alpha_composite(t, (24, H - t.height + 26))
    elif kind == 'adult':
        pid = {'vee': 'coach_vee', 'hollis': 'mr_hollis', 'reyes': 'principal_reyes'}[who]
        img.alpha_composite(class_layer(look, cfg, focus=names, frames=frames, focus_frac=frac,
                                        darken_others=0.45 if names else 0.2))
        if d.get('teacher'):
            teacher_walking(img)
        port = portrait(pid, mood)
        if port is not None:
            foreground_bust(img, port, right=right)
    else:   # a student speaks: large at their desk in front, the class behind
        img.alpha_composite(class_layer(look, cfg, frames=frames, darken_others=0.5, skip=(who,)))
        port = portrait(who, mood)
        if port is not None:
            bxp, byp = foreground_bust(img, port, right=right, desk_look='kr' if look == 'kr' else 'us')
            ring(img, bxp + 96, byp + 84, 70, 0.55)
    return img.convert('RGB')


def main():
    chapters = json.load(open(os.path.join(ROOT, 'data', 'narrative', 'chapters.json'), encoding='utf8'))['chapters']
    sheets = {'us': [], 'kr': []}
    n = 0
    for sid, ch in chapters.items():
        cfg = json.load(open(os.path.join(ROOT, 'data', 'scenarios', '%s.json' % sid), encoding='utf8'))
        d = os.path.join(OUT, sid)
        os.makedirs(d, exist_ok=True)
        for look in ('us', 'kr'):
            suf = '_kr' if look == 'kr' else ''
            shots = [('title', None, 'wide')] + [(str(i), b, None) for i, b in enumerate(ch.get('intro', []))] \
                + [('outro', {'speaker': 'vee', 'mood': 'warm', 'text': ''}, 'adult')]
            for name, beat, kind in shots:
                im = frame_for(sid, cfg, beat, look, name, kind)
                im.save(os.path.join(d, name + suf + '.png'))
                sheets[look].append((sid + '/' + name, im))
                n += 1
    print('wrote %d frames to %s' % (n, OUT))
    for look, items in sheets.items():
        cols = 6
        rows = (len(items) + cols - 1) // cols
        sh = Image.new('RGB', (cols * 244, rows * 140), (20, 20, 24))
        for i, (_, im) in enumerate(items):
            sh.paste(im.resize((240, 135), Image.NEAREST), ((i % cols) * 244, (i // cols) * 140))
        out = os.path.join(ROOT, 'docs', 'qa', 'open-items', 'cinematic_frames_%s.png' % look)
        sh.save(out)
        print(out)


if __name__ == '__main__':
    main()
