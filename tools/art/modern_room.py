"""Modern classroom art (US default + Korean variant), built on build_art helpers.

Grounded in current classroom references (see docs/ui-design-plan.md section 5.1):
US: light vinyl composition tile with a carpet-tile area, whiteboard + interactive flat
panel, word wall and anchor charts, windows with blinds, bulletin boards, storage bins,
maple-top desks with separate plastic chairs, teacher desk with a laptop.
Korea: pale wood-look laminate, sliding green board with a TV, flag and class motto above,
rear lockers, cleaning-tool corner, curtains, individual desks with bag hooks.
All original art in the locked palette.
"""
from build_art import (new, put, rect, stamp, outline, pad, upscale, hashf, save, P)


# ---------------------------------------------------------------- shared modern bits

def wall_face():
    t = new(16, 32)
    rect(t, 0, 0, 16, 32, 'wall_mod')
    rect(t, 0, 0, 16, 2, 'ceiling')
    rect(t, 0, 2, 16, 1, 'tile')
    rect(t, 0, 28, 16, 3, 'metal_dk')      # vinyl cove base
    rect(t, 0, 31, 16, 1, 'ink')
    return t


def cap_base():
    t = new(16, 16)
    rect(t, 0, 0, 16, 16, 'tile_ln')
    rect(t, 1, 1, 14, 14, 'wall_mod')
    rect(t, 1, 13, 14, 2, 'tile')
    return t


# ---------------------------------------------------------------- floors

def floor_us(v):
    """Vinyl composition tile: one 16-texel square per cell, very low contrast so the
    room reads clean; faint grout lines and a little speckle."""
    t = new(16, 16)
    rect(t, 0, 0, 16, 16, 'tile_lt' if v % 2 == 0 else 'wall_mod')
    for k in range(4):
        hh = hashf(v, k)
        put(t, 1 + hh % 13, 1 + (hh // 13) % 13, 'tile')
    rect(t, 0, 15, 16, 1, 'tile')
    rect(t, 15, 0, 1, 16, 'tile')
    return t


def floor_kr(v):
    """Pale wood-look laminate: wide, low-contrast boards."""
    t = new(16, 16)
    rect(t, 0, 0, 16, 16, 'maple')
    for row in range(2):
        y0 = row * 8
        if (row + v) % 2:
            rect(t, 0, y0, 16, 7, 'maple')
        else:
            rect(t, 0, y0, 16, 7, 'maple_lt')
        rect(t, 0, y0 + 7, 16, 1, 'maple_sh')
        jx = [11, 4, 13, 7][(v + row) % 4]
        rect(t, jx, y0, 1, 7, 'maple_sh')
        h = hashf(v, row)
        rect(t, 2 + h % 8, y0 + 3, 3, 1, 'maple_sh')    # faint grain
    return t


def carpet(edge, style):
    """Low-pile carpet: one calm colour with a faint weave, a slim border. Low contrast on
    purpose, so students and state markers stay the strongest things on screen."""
    l, r, tp, b = edge
    t = new(16, 16)
    base, weave, border = {
        'us': ('teal_lt', 'teal', 'teal'),
        'us_area': ('ceiling', 'tile', 'metal'),
        'kr': ('tile_lt', 'tile', 'tile_ln'),
        'kr_area': ('tile_lt', 'tile', 'tile_ln'),
    }[style]
    rect(t, 0, 0, 16, 16, base)
    for y in range(1, 16, 4):
        for x in range((y // 4) % 2 * 2, 16, 4):
            put(t, x, y, weave)
    if tp:
        rect(t, 0, 0, 16, 1, border)
    if b:
        rect(t, 0, 15, 16, 1, border)
    if l:
        rect(t, 0, 0, 1, 16, border)
    if r:
        rect(t, 15, 0, 1, 16, border)
    return t


# ---------------------------------------------------------------- front wall

def us_board(idx):
    """Whiteboard across six tiles; the middle two carry the interactive flat panel."""
    t = wall_face()
    x0 = 1 if idx == 0 else 0
    x1 = 15 if idx == 5 else 16
    rect(t, x0, 7, x1 - x0, 18, 'metal')               # frame
    rect(t, x0 + (1 if idx == 0 else 0), 8, (x1 - x0) - (1 if idx in (0, 5) else 0), 16, 'whiteboard')
    rect(t, x0, 24, x1 - x0, 1, 'metal_dk')           # marker tray
    if idx in (2, 3):                                  # flat panel (two tiles wide)
        px0 = 2 if idx == 2 else 0
        px1 = 16 if idx == 2 else 14
        rect(t, px0, 5, px1 - px0, 18, 'ink')
        rect(t, px0 + (1 if idx == 2 else 0), 6, (px1 - px0) - 1, 16, 'screen')
        if idx == 2:                                   # slide: a fraction bar model
            rect(t, 4, 9, 11, 1, 'chalk')
            rect(t, 4, 12, 11, 4, 'early')
            rect(t, 4, 12, 6, 4, 'yellow')
            for x in (6, 8, 10, 12):
                rect(t, x, 12, 1, 4, 'screen')
        else:
            rect(t, 1, 9, 8, 1, 'chalk')
            rect(t, 1, 12, 10, 1, 'chalk_gy')
            rect(t, 1, 14, 7, 1, 'chalk_gy')
    elif idx == 1:                                     # marker work: pie in red and blue
        for (x, y) in [(6, 11), (7, 11), (8, 11), (5, 12), (9, 12), (5, 13), (9, 13), (5, 14), (9, 14),
                       (6, 15), (7, 15), (8, 15), (7, 12), (7, 13), (7, 14)]:
            put(t, x, y, 'blue')
        rect(t, 5, 18, 6, 1, 'red')
    elif idx == 4:
        rect(t, 2, 11, 10, 1, 'green')
        rect(t, 2, 14, 7, 1, 'blue')
        rect(t, 2, 17, 9, 1, 'blue')
    if idx in (0, 5):
        for y in (12, 15, 18):
            rect(t, 3 if idx == 0 else 4, y, 8, 1, 'chalk_gy')
    # word wall strip above the board
    cols = ['yellow', 'ok', 'early', 'pink', 'notyet']
    for i in range(3):
        c = cols[hashf(idx, i) % len(cols)]
        rect(t, 1 + i * 5, 3, 4, 3, c)
        put(t, 2 + i * 5, 4, 'ink')
    return t


def kr_board(idx):
    """Sliding green board (two sliding panels framed in aluminium), TV above the middle,
    flag and class-motto frame above the sides."""
    t = wall_face()
    x0 = 1 if idx == 0 else 0
    x1 = 15 if idx == 5 else 16
    rect(t, x0, 11, x1 - x0, 15, 'metal')
    rect(t, x0 + (1 if idx == 0 else 0), 12, (x1 - x0) - (1 if idx in (0, 5) else 0), 12, 'board')
    rect(t, x0, 12, x1 - x0, 1, 'board_lt')
    rect(t, x0, 24, x1 - x0, 1, 'metal_dk')
    if idx == 3:
        rect(t, 0, 12, 1, 12, 'metal')                  # sliding panel seam
    if idx in (2, 3):                                    # TV above the board
        px0 = 3 if idx == 2 else 0
        px1 = 16 if idx == 2 else 13
        rect(t, px0, 2, px1 - px0, 8, 'ink')
        rect(t, px0 + (1 if idx == 2 else 0), 3, (px1 - px0) - 1, 6, 'screen')
        rect(t, (6 if idx == 2 else 0), 4, 5, 1, 'chalk_gy')
    if idx == 1:                                         # national flag (simplified, small)
        rect(t, 4, 3, 9, 6, 'chalk')
        rect(t, 7, 5, 3, 1, 'red')
        rect(t, 7, 6, 3, 1, 'blue')
        for (x, y) in [(5, 4), (11, 4), (5, 7), (11, 7)]:
            put(t, x, y, 'ink')
    if idx == 4:                                         # class motto frame
        rect(t, 1, 3, 13, 6, 'wood')
        rect(t, 2, 4, 11, 4, 'paper')
        rect(t, 3, 5, 9, 1, 'ink')
        rect(t, 4, 7, 7, 1, 'paper_ln')
    if idx in (1, 4, 0, 5):
        for y in (15, 18, 21):
            rect(t, 3, y, 6 + hashf(idx, y) % 5, 1, 'chalk_gy')
    return t


def anchor_chart(v):
    t = wall_face()
    col = ['early', 'ok', 'notyet', 'yellow', 'pink'][v % 5]
    rect(t, 2, 6, 12, 18, 'paper')
    rect(t, 2, 6, 12, 3, col)
    for i, y in enumerate((11, 14, 17, 20)):
        rect(t, 4, y, 4 + hashf(v, i) % 7, 1, 'tile_ln')
        put(t, 3, y, col)
    put(t, 3, 6, 'red'); put(t, 12, 6, 'red')
    return t


def us_door():
    t = wall_face()
    rect(t, 2, 5, 12, 26, 'metal_dk')
    rect(t, 3, 6, 10, 25, 'maple')
    rect(t, 9, 8, 3, 9, 'early')                         # narrow vision glass
    rect(t, 4, 17, 2, 1, 'metal')                        # lever
    return t


def kr_door():
    """Corridor-side sliding door with a window."""
    t = wall_face()
    rect(t, 1, 4, 14, 27, 'metal')
    rect(t, 2, 5, 12, 26, 'maple_sh')
    rect(t, 3, 7, 10, 8, 'early')
    rect(t, 3, 7, 10, 1, 'chalk')
    rect(t, 11, 18, 1, 4, 'metal_dk')
    return t


def clock_speaker():
    t = wall_face()
    for (x, y) in [(6, 6), (7, 6), (8, 6), (9, 6), (5, 7), (10, 7), (4, 8), (11, 8), (4, 9), (11, 9),
                   (4, 10), (11, 10), (4, 11), (11, 11), (5, 12), (10, 12), (6, 13), (7, 13), (8, 13), (9, 13)]:
        put(t, x, y, 'ink')
    rect(t, 5, 8, 6, 4, 'chalk')
    rect(t, 6, 7, 4, 1, 'chalk'); rect(t, 6, 12, 4, 1, 'chalk')
    put(t, 7, 8, 'ink'); put(t, 7, 9, 'ink'); put(t, 8, 10, 'ink'); put(t, 9, 10, 'ink')
    rect(t, 5, 18, 6, 5, 'metal')                        # PA speaker
    for y in (19, 21):
        rect(t, 6, y, 4, 1, 'metal_dk')
    return t


def plain_modern():
    return wall_face()


# ---------------------------------------------------------------- side / back walls

def window_blinds():
    t = cap_base()
    rect(t, 2, 1, 12, 14, 'metal')
    rect(t, 3, 2, 10, 12, 'early')
    for y in range(3, 14, 2):
        rect(t, 3, y, 10, 1, 'chalk')                    # blinds slats
    return t


def window_wall(kind):
    """Continuous window wall seen from above: glass with blinds, a sill on the room side,
    a mullion only at the top/bottom end pieces so a run of tiles reads as one window."""
    t = cap_base()
    rect(t, 1, 0, 12, 16, 'early')
    for y in range(1, 16, 2):
        rect(t, 1, y, 12, 1, 'chalk')                   # blind slats
    rect(t, 13, 0, 2, 16, 'chalk')                       # sill (room side)
    rect(t, 15, 0, 1, 16, 'tile_ln')
    if kind == 'top':
        rect(t, 1, 0, 12, 2, 'metal')
    if kind == 'bottom':
        rect(t, 1, 14, 12, 2, 'metal')
    if kind == 'mid':
        rect(t, 1, 15, 12, 1, 'metal')                  # pane joint
    return t


def window_wall_kr(kind):
    t = window_wall(kind)
    rect(t, 1, 0, 3, 16, 'notyet')                       # curtain gathered at one end of each pane
    for y in range(0, 16, 3):
        put(t, 2, y, 'red')
    return t


def window_curtain():
    t = window_blinds()
    rect(t, 3, 2, 3, 12, 'notyet')                       # curtains drawn to the sides
    rect(t, 10, 2, 3, 12, 'notyet')
    for y in range(2, 14, 3):
        put(t, 4, y, 'red'); put(t, 11, y, 'red')
    return t


def ac_unit():
    t = cap_base()
    rect(t, 2, 4, 12, 9, 'chalk')
    rect(t, 2, 4, 12, 1, 'tile')
    for y in (8, 10):
        rect(t, 3, y, 10, 1, 'tile_ln')
    put(t, 12, 6, 'ok')
    return t


def bulletin(v):
    t = cap_base()
    border = ['red', 'blue', 'ok', 'yellow'][v % 4]
    rect(t, 1, 2, 14, 12, border)
    rect(t, 2, 3, 12, 10, 'cork')
    for i, (x, y) in enumerate([(3, 4), (8, 4), (4, 8), (9, 8)]):
        c = ['paper', 'early', 'paper', 'pink'][hashf(v, i) % 4]
        rect(t, x, y, 4, 3, c)
        put(t, x + 1, y, 'red')
    return t


def storage_bins(v):
    t = cap_base()
    rect(t, 1, 3, 14, 11, 'maple')
    rect(t, 1, 3, 14, 1, 'maple_lt')
    cols = ['blue', 'yellow', 'ok', 'red', 'purple', 'teal']
    for i, bx in enumerate((2, 6, 10)):
        c = cols[hashf(v, i) % len(cols)]
        rect(t, bx, 6, 4, 6, c)
        rect(t, bx, 6, 4, 1, 'chalk')
    return t


def low_bookshelf(v):
    t = cap_base()
    rect(t, 1, 3, 14, 11, 'maple')
    cols = ['red', 'blue', 'yellow', 'green', 'purple', 'teal', 'pink']
    for i in range(2):
        y = 5 + i * 4
        for x in range(2, 14):
            c = cols[hashf(v, i, x // 2) % len(cols)]
            put(t, x, y, c); put(t, x, y + 1, c); put(t, x, y + 2, 'maple_sh')
    return t


def lockers(v):
    """Korean rear-wall lockers: small doors with name tags."""
    t = cap_base()
    rect(t, 1, 2, 14, 12, 'metal')
    for i, x in enumerate((2, 6, 10)):
        rect(t, x, 3, 4, 10, 'locker')
        rect(t, x, 3, 4, 1, 'chalk_gy')
        rect(t, x + 1, 5, 2, 1, 'paper')                 # name tag
        put(t, x + 3, 8, 'metal_dk')                     # handle
    return t


def cleaning_corner():
    t = cap_base()
    rect(t, 3, 2, 1, 11, 'wood')                         # broom handle
    rect(t, 2, 12, 3, 2, 'yellow')
    rect(t, 7, 2, 1, 10, 'metal')                        # mop
    rect(t, 6, 11, 3, 3, 'chalk_gy')
    rect(t, 10, 8, 4, 6, 'blue')                         # bucket
    rect(t, 10, 8, 4, 1, 'early')
    return t


def coat_hooks(v):
    t = cap_base()
    rect(t, 1, 2, 14, 1, 'metal')
    cols = ['red', 'blue', 'yellow', 'purple', 'green', 'teal']
    for i, x in enumerate((3, 9)):
        c = cols[hashf(v, i) % len(cols)]
        rect(t, x, 4, 4, 7, c)
        rect(t, x, 4, 4, 1, 'ink')
    return t


def sink_modern():
    t = cap_base()
    rect(t, 2, 3, 12, 10, 'chalk')
    rect(t, 4, 5, 8, 6, 'tile')
    rect(t, 7, 2, 2, 3, 'metal')
    return t


def plant_modern():
    t = cap_base()
    rect(t, 5, 9, 6, 5, 'chalk')
    rect(t, 5, 9, 6, 1, 'tile')
    for (x, y) in [(7, 2), (8, 2), (6, 3), (9, 3), (5, 4), (8, 4), (10, 4), (6, 5), (7, 5), (9, 5), (4, 6), (7, 6),
                   (8, 6), (11, 6), (5, 7), (6, 7), (9, 7), (10, 7), (7, 8), (8, 8)]:
        put(t, x, y, 'green')
    for (x, y) in [(7, 3), (8, 5), (6, 6), (10, 6), (8, 7)]:
        put(t, x, y, 'ok')
    return t


def purifier():
    t = cap_base()
    rect(t, 3, 2, 10, 11, 'chalk')
    rect(t, 3, 2, 10, 1, 'tile')
    for y in range(4, 11, 2):
        rect(t, 4, y, 8, 1, 'tile_ln')
    put(t, 11, 3, 'ok')
    return t


# ---------------------------------------------------------------- furniture

def desk_modern(style):
    d = new(16, 10)
    top, top_sh = ('maple_lt', 'maple') if style == 'us' else ('maple', 'maple_sh')
    rect(d, 1, 0, 14, 3, top)
    rect(d, 1, 0, 14, 1, 'chalk' if style == 'us' else 'maple_lt')
    rect(d, 1, 3, 14, 1, top_sh)
    rect(d, 2, 4, 12, 3, 'metal' if style == 'us' else 'maple_sh')   # book box / apron
    rect(d, 2, 6, 12, 1, 'metal_dk')
    rect(d, 2, 7, 1, 3, 'metal_dk')                     # thin metal legs
    rect(d, 13, 7, 1, 3, 'metal_dk')
    rect(d, 9, 1, 4, 2, 'paper')
    put(d, 10, 1, 'paper_ln')
    put(d, 4, 1, 'yellow'); put(d, 5, 1, 'yellow'); put(d, 6, 1, 'pink')
    if style == 'kr':
        rect(d, 14, 4, 1, 2, 'metal')                    # bag hook
        rect(d, 13, 6, 3, 3, 'notyet')                   # bag on the hook
    return outline(pad(d, 1))


def chair_modern(style):
    c = new(12, 9)
    shell = 'blue' if style == 'us' else 'maple'
    rect(c, 1, 0, 10, 4, shell)
    rect(c, 1, 0, 10, 1, 'early' if style == 'us' else 'maple_lt')
    rect(c, 2, 4, 8, 2, shell)
    rect(c, 2, 6, 1, 3, 'metal_dk')
    rect(c, 9, 6, 1, 3, 'metal_dk')
    return outline(pad(c, 1))


def teacher_desk_modern(style):
    d = new(32, 14)
    rect(d, 0, 0, 32, 4, 'maple_lt' if style == 'us' else 'maple')
    rect(d, 0, 0, 32, 1, 'chalk')
    rect(d, 0, 4, 32, 1, 'maple_sh')
    rect(d, 1, 5, 30, 7, 'metal')
    rect(d, 3, 6, 9, 5, 'tile')
    put(d, 7, 8, 'metal_dk')
    rect(d, 1, 12, 2, 2, 'metal_dk')
    rect(d, 29, 12, 2, 2, 'metal_dk')
    rect(d, 13, 0, 9, 4, 'metal_dk')                     # laptop
    rect(d, 14, 0, 7, 3, 'screen')
    rect(d, 15, 1, 4, 1, 'early')
    rect(d, 4, 1, 6, 2, 'paper')
    rect(d, 25, 1, 3, 2, 'red' if style == 'us' else 'chalk')   # mug
    return outline(pad(d, 1))


def build_modern():
    for style, floor_fn in (('us', floor_us), ('kr', floor_kr)):
        for v in range(4):
            save(floor_fn(v), 'room_%s/floor_%d.png' % (style, v))
        for name, edge in {
            'tl': (1, 0, 1, 0), 't': (0, 0, 1, 0), 'tr': (0, 1, 1, 0), 'l': (1, 0, 0, 0), 'm': (0, 0, 0, 0),
            'r': (0, 1, 0, 0), 'bl': (1, 0, 0, 1), 'b': (0, 0, 0, 1), 'br': (0, 1, 0, 1),
        }.items():
            save(carpet(edge, style), 'room_%s/rug_%s.png' % (style, name))
            save(carpet(edge, style + '_area'), 'room_%s/area_%s.png' % (style, name))
        board = us_board if style == 'us' else kr_board
        for i in range(6):
            save(board(i), 'room_%s/board_%d.png' % (style, i))
        save(us_door() if style == 'us' else kr_door(), 'room_%s/front_door.png' % style)
        save(desk_modern(style), 'room_%s/desk.png' % style)
        save(chair_modern(style), 'room_%s/chair.png' % style)
        save(teacher_desk_modern(style), 'room_%s/teacher_desk.png' % style)
    for v in range(5):
        save(anchor_chart(v), 'room_common/anchor_%d.png' % v)
    save(clock_speaker(), 'room_common/front_clock.png')
    save(plain_modern(), 'room_common/front_plain.png')
    save(window_blinds(), 'room_common/window_blinds.png')
    for kind in ('top', 'mid', 'bottom'):
        save(window_wall(kind), 'room_common/windowwall_%s.png' % kind)
        save(window_wall_kr(kind), 'room_common/windowwall_kr_%s.png' % kind)
    save(window_curtain(), 'room_common/window_curtain.png')
    save(ac_unit(), 'room_common/ac_unit.png')
    for v in range(4):
        save(bulletin(v), 'room_common/bulletin_%d.png' % v)
    for v in range(3):
        save(storage_bins(v), 'room_common/bins_%d.png' % v)
        save(low_bookshelf(v), 'room_common/bookshelf_%d.png' % v)
        save(lockers(v), 'room_common/lockers_%d.png' % v)
        save(coat_hooks(v), 'room_common/hooks_%d.png' % v)
    save(cleaning_corner(), 'room_common/cleaning.png')
    save(sink_modern(), 'room_common/sink.png')
    save(plant_modern(), 'room_common/plant.png')
    save(purifier(), 'room_common/purifier.png')
    save(cap_base(), 'room_common/wall_cap.png')
    modern_backdrop()


def modern_backdrop(style='us'):
    """Encounter backdrop: the modern room's front wall and floor, softened. Exempt from the
    palette check on purpose: it is blurred, then shown dimmed behind the panels."""
    from PIL import ImageFilter
    import os
    import build_art as B
    bd = new(480, 270)
    x = 0
    seq = ['plain', 'anchor_0', 'plain', 'board0', 'board1', 'board2', 'board3', 'board4', 'board5', 'plain',
           'anchor_2', 'plain', 'clock', 'plain', 'door']
    i = 0
    while x < 480:
        k = seq[i % len(seq)]
        if k == 'plain':
            piece = plain_modern()
        elif k.startswith('anchor'):
            piece = anchor_chart(int(k[-1]))
        elif k == 'clock':
            piece = clock_speaker()
        elif k == 'door':
            piece = us_door()
        else:
            piece = us_board(int(k[-1]))
        bd.alpha_composite(upscale(piece, 2), (x, 0))
        x += 32
        i += 1
    for ty in range(64, 270, 32):
        for tx in range(0, 480, 32):
            bd.alpha_composite(upscale(floor_us(hashf(tx, ty) % 4), 2), (tx, ty))
    soft = bd.filter(ImageFilter.GaussianBlur(2.2))
    path = os.path.join(B.OUT, 'ui', 'encounter_backdrop_modern.png')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    soft.save(path)
