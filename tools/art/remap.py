"""Remap the existing painted portraits onto the v2 palette and texel grid.

    python tools/art/remap.py [size]      # default size 64 texels (shown at 2 px/texel = 128 px)

Each 128 px source portrait loses its painted background, is downsampled to `size`
texels (the world's 2 px texel grid), and gets its own small palette pulled toward the
core palette so its hues sit with the world art. No dithering. Output: assets/v2/portraits/<same name>.png.
The originals in assets/portraits stay untouched (owner decision: remap, no new art).
"""
import glob
import os
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from palette import PALETTE, SHADE  # noqa: E402
from PIL import ImageFilter  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SRC = os.path.join(ROOT, 'assets', 'portraits')
OUT = os.path.join(ROOT, 'assets', 'v2', 'portraits')

# Portrait backgrounds become the chalkboard green; skin, hair and clothes keep their own
# ramps. Colours that would only appear as UI state are excluded so faces never use them.
EXCLUDE = {'ok', 'early', 'notyet', 'neutral', 'focus', 'warn'}
KEYS = [k for k in PALETTE if k not in EXCLUDE]


def ramp_colours():
    """Core palette plus the midpoint of every shade pair (skin, hair, cloth ramps), so
    faces get softer steps while every colour still derives from the palette."""
    cols = [PALETTE[k][:3] for k in KEYS]
    for a, b in SHADE.items():
        if a in EXCLUDE or b in EXCLUDE or a not in PALETTE or b not in PALETTE:
            continue
        ca, cb = PALETTE[a], PALETTE[b]
        mid = tuple((ca[i] + cb[i]) // 2 for i in range(3))
        if mid not in cols:
            cols.append(mid)
    return cols[:256]


def palette_image():
    pal = []
    for c in ramp_colours():
        pal.extend(c)
    n = len(pal) // 3
    pal.extend(pal[:3] * (256 - n))
    img = Image.new('P', (1, 1))
    img.putpalette(pal)
    return img


def clear_background(img, step_tol=34):
    """Flood-fill from the four corners, following the painted blue gradient: a pixel joins
    the background only if it is blue-dominant and close to the neighbour it was reached
    from, so clothes that touch the frame edge (even purple ones) are kept."""
    w, h = img.size
    px = img.load()
    seen = set()
    stack = [((0, 0), None), ((w - 1, 0), None), ((0, h - 1), None), ((w - 1, h - 1), None)]
    while stack:
        (x, y), prev = stack.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        c = px[x, y]
        bluish = c[2] > c[0] + 10 and c[2] >= c[1] - 4
        # near the bottom edge clothes meet the frame: follow the gradient much more strictly
        tol = step_tol if y < h * 0.62 else 10
        close = prev is None or sum(abs(c[i] - prev[i]) for i in range(3)) < tol
        if c[3] == 0 or (bluish and close):
            seen.add((x, y))
            px[x, y] = (0, 0, 0, 0)
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                stack.append(((x + d[0], y + d[1]), c[:3]))
    return img


def nearest_core(c):
    best = None
    for k in KEYS:
        q = PALETTE[k]
        d = (c[0] - q[0]) ** 2 + (c[1] - q[1]) ** 2 + (c[2] - q[2]) ** 2
        if best is None or d < best[0]:
            best = (d, q)
    return best[1]


def remap(path, size, _pal=None, colours=28, pull=0.35):
    """Gentle remap: per-portrait palette of `colours`, each colour pulled `pull` of the way
    toward its nearest core palette colour (so hues harmonise with the world), no dither."""
    src = clear_background(Image.open(path).convert('RGBA'))
    small = src.resize((size, size), Image.LANCZOS)
    alpha = small.getchannel('A')
    q = small.convert('RGB').quantize(colors=colours, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = q.getpalette()[:colours * 3]
    out = []
    for i in range(0, len(pal), 3):
        c = pal[i:i + 3]
        n = nearest_core(c)
        out.extend(int(round(c[j] + (n[j] - c[j]) * pull)) for j in range(3))
    q.putpalette(out + [0] * (768 - len(out)))
    rgba = q.convert('RGBA')
    rgba.putalpha(alpha.point(lambda a: 255 if a >= 128 else 0))
    return rgba


def main():
    size = int(sys.argv[1]) if len(sys.argv) > 1 else 64
    pal = palette_image()
    os.makedirs(OUT, exist_ok=True)
    n = 0
    for path in sorted(glob.glob(os.path.join(SRC, '*.png'))):
        name = os.path.basename(path)
        if name.endswith('_large.png'):
            continue
        remap(path, size, pal).save(os.path.join(OUT, name))
        n += 1
    print('remapped %d portraits to %d texels into %s' % (n, size, OUT))


if __name__ == '__main__':
    main()
