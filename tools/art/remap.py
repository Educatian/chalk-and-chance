"""Remap the existing painted portraits onto the v2 palette and texel grid.

    python tools/art/remap.py [size]      # default size 64 texels (shown at 2 px/texel = 128 px)

Each 128 px source portrait is box-downsampled to `size` texels, mapped to the nearest
palette colour (no dithering, so flat pixel-art regions), and given the 1-texel ink
outline rule against its background. Output: assets/v2/portraits/<same name>.png.
The originals in assets/portraits stay untouched (owner decision: remap, no new art).
"""
import glob
import os
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from palette import PALETTE  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SRC = os.path.join(ROOT, 'assets', 'portraits')
OUT = os.path.join(ROOT, 'assets', 'v2', 'portraits')

# Portrait backgrounds become the chalkboard green; skin, hair and clothes keep their own
# ramps. Colours that would only appear as UI state are excluded so faces never use them.
EXCLUDE = {'ok', 'early', 'notyet', 'neutral', 'focus', 'warn'}
KEYS = [k for k in PALETTE if k not in EXCLUDE]


def palette_image():
    pal = []
    for k in KEYS:
        pal.extend(PALETTE[k][:3])
    pal.extend(pal[:3] * (256 - len(KEYS)))
    img = Image.new('P', (1, 1))
    img.putpalette(pal)
    return img


def clear_background(img, tol=150):
    """Flood-fill from the four corners over pixels close to the corner colour -> transparent."""
    w, h = img.size
    px = img.load()
    seen = set()
    stack = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    refs = [px[x, y][:3] for x, y in stack]
    def near(c):
        # the painted backgrounds are a blue gradient; hair and skin are never blue-dominant
        bluish = c[2] > c[0] + 12 and c[2] >= c[1]
        return bluish and any(abs(c[0] - r[0]) + abs(c[1] - r[1]) + abs(c[2] - r[2]) < tol for r in refs)
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        seen.add((x, y))
        c = px[x, y]
        if c[3] == 0 or near(c[:3]):
            px[x, y] = (0, 0, 0, 0)
            stack.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return img


def remap(path, size, pal):
    src = clear_background(Image.open(path).convert('RGBA'))
    small = src.resize((size, size), Image.BOX)
    alpha = small.getchannel('A')
    q = small.convert('RGB').quantize(palette=pal, dither=Image.Dither.NONE).convert('RGBA')
    q.putalpha(alpha.point(lambda a: 255 if a >= 128 else 0))
    return q


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
