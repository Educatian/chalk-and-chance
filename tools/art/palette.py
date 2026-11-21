"""Chalk & Chance locked palette: 35 core colours + 8 portrait + 15 modern-room materials (docs/ui-design-plan.md section 3.3).

Every generated asset must use only these colours (plus transparency); build_art.py
fails the build if a pixel falls outside the palette.
"""

def hx(s):
    s = s.lstrip('#')
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)

PALETTE = {
    'ink': hx('#14131c'),
    'board_dk': hx('#1c2a26'), 'board': hx('#2b3f37'), 'board_lt': hx('#3e5a4c'),
    'chalk': hx('#f2eedd'), 'chalk_gy': hx('#b9b7a8'),
    'paper': hx('#f6ecd2'), 'paper_sh': hx('#e2d1aa'), 'paper_ln': hx('#c2a878'),
    'wood_dk': hx('#5a3a26'), 'wood': hx('#8a5a36'), 'wood_lt': hx('#b57c48'),
    'floor': hx('#c99a62'), 'floor_lt': hx('#ddb27a'),
    'wall': hx('#e9dcc0'), 'wall_sh': hx('#c9b892'),
    'skin1': hx('#f3c9a5'), 'skin2': hx('#d9a07a'), 'skin3': hx('#a96f4b'), 'skin4': hx('#6e4632'),
    'hair_dk': hx('#2a1d18'), 'hair_br': hx('#6b4128'), 'hair_gd': hx('#c98f3c'),
    'blue': hx('#3c6fb4'), 'red': hx('#c2453c'), 'green': hx('#3f8a54'),
    'yellow': hx('#e0a93a'), 'purple': hx('#7a4fa0'), 'slate': hx('#4a5a72'),
    'ok': hx('#5fbf6a'), 'early': hx('#6fa8e8'), 'notyet': hx('#ec8a6e'), 'neutral': hx('#9aa0aa'),
    'focus': hx('#ffd34e'), 'warn': hx('#e4573d'),
    # portrait extension: extra skin depth, pinks, teal, navy, hair highlight, warm cream
    'skin_mid': hx('#bf8560'), 'skin_dk2': hx('#4e3024'), 'pink': hx('#d46a9a'), 'pink_dk': hx('#9c4470'),
    'teal': hx('#3f8f96'), 'navy': hx('#24304f'), 'hair_hl': hx('#8f5a35'), 'cream': hx('#fbe0c4'),
    # modern classroom materials: painted walls, vinyl tile, laminate, aluminium, screens
    'wall_mod': hx('#f4f1ea'), 'ceiling': hx('#d9dde2'), 'tile_lt': hx('#eeece6'), 'tile': hx('#dcd8d0'),
    'tile_ln': hx('#c3beb4'), 'metal': hx('#aab0b8'), 'metal_dk': hx('#6f7781'), 'screen': hx('#1f2b3b'),
    'whiteboard': hx('#fbfbf7'), 'maple_lt': hx('#efd9b0'), 'maple': hx('#e2c48f'), 'maple_sh': hx('#c7a46c'),
    'teal_lt': hx('#5fb1b6'), 'cork': hx('#c79a6a'), 'locker': hx('#8fa6bd'),
}

assert len(PALETTE) <= 60, len(PALETTE)   # 35 core + 8 portrait + 15 modern-room materials

# Shade ramps: base colour -> darker neighbour inside the palette (for automatic shading).
SHADE = {
    'skin1': 'skin2', 'skin2': 'skin3', 'skin3': 'skin4', 'skin4': 'hair_dk',
    'hair_gd': 'hair_br', 'hair_br': 'hair_dk', 'hair_dk': 'ink',
    'blue': 'slate', 'red': 'wood_dk', 'green': 'board_lt', 'yellow': 'wood_lt',
    'purple': 'slate', 'slate': 'ink', 'chalk': 'chalk_gy', 'chalk_gy': 'neutral',
    'notyet': 'red', 'early': 'blue', 'ok': 'green', 'paper': 'paper_sh', 'wall': 'wall_sh',
    'wood_lt': 'wood', 'wood': 'wood_dk', 'wood_dk': 'ink', 'floor_lt': 'floor', 'floor': 'wood_lt',
    'neutral': 'slate', 'board_lt': 'board', 'board': 'board_dk', 'focus': 'yellow',
}
