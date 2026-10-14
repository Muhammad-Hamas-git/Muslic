"""Builds assets/ui/ambient.png and ambient_on.png from the Figma equalizer
button: paints out the bars, then draws three waves in the same style."""
import sys, math
from PIL import Image, ImageFilter, ImageDraw
import numpy as np
from scipy.ndimage import gaussian_filter
root = sys.argv[1]
src = Image.open(f'{root}/ui_source/equalizer.png').convert('RGB')
a = np.asarray(src).astype(np.float64); H, W, _ = a.shape
mi = Image.new('L', (W, H), 0)
ImageDraw.Draw(mi).rounded_rectangle((405, 205, 860, 665), radius=90, fill=255)
m = np.asarray(mi).astype(np.float64) / 255; valid = 1 - m
filled = a.copy()
for i, s in enumerate([90, 35, 15, 6]):   # coarse fills all, finer refine edges
    num = np.stack([gaussian_filter(a[..., c] * valid, s) for c in range(3)], -1)
    den = gaussian_filter(valid, s)
    est = num / np.maximum(den[..., None], 1e-12)
    ok = (m > 0) if i == 0 else ((m > 0) & (den > 0.15))
    filled = np.where(ok[..., None], est, filled)
fm = gaussian_filter(m, 22)[..., None]
base = Image.fromarray((filled * fm + a * (1 - fm)).clip(0, 255).astype(np.uint8))

S = 4; cx, cy = 630, 425; width = 400; gap = 105; stroke = 46; amp = 26
glyph = Image.new('L', (W * S, H * S), 0); d = ImageDraw.Draw(glyph)
r = stroke * S / 2
for k, dy in enumerate([-gap, 0, gap]):
    x0 = cx - width / 2; n = 160
    for i in range(n + 1):   # round brush along the curve: smooth, no joints
        x = (x0 + width * i / n) * S
        y = (cy + dy + amp * math.sin(i / n * 2 * math.pi * 1.5 + k * 0.6)) * S
        d.ellipse((x - r, y - r, x + r, y + r), fill=255)
glyph = glyph.resize((W, H), Image.LANCZOS)
shadow = glyph.filter(ImageFilter.GaussianBlur(10)).transform((W, H), Image.AFFINE, (1, 0, 0, 0, 1, -8))

# Inside of the glass circle, for the "lit" on-state.
disc = Image.new('L', (W, H), 0)
ImageDraw.Draw(disc).ellipse((300, 90, 975, 772), fill=255)
disc = disc.filter(ImageFilter.GaussianBlur(60))

def compose(glow, alpha):
    out = Image.composite(Image.new('RGB', (W, H), (8, 8, 8)), base, shadow.point(lambda v: int(v * 0.5)))
    if glow:
        # The whole circle lights up softly, plus a bright halo on the waves.
        out = Image.composite(Image.new('RGB', (W, H), (150, 150, 155)), out, disc.point(lambda v: int(v * 0.55)))
        g = glyph.filter(ImageFilter.GaussianBlur(45))
        out = Image.composite(Image.new('RGB', (W, H), (255, 255, 255)), out, g.point(lambda v: min(255, int(v * 1.1))))
    return Image.composite(Image.new('RGB', (W, H), (255, 255, 255) if glow else (232, 234, 236)), out, glyph.point(lambda v: int(v * alpha)))

for name, img in [('ambient', compose(False, 0.92)), ('ambient_on', compose(True, 1.0))]:
    img.save(f'{root}/ui_source/{name}.png')
    img.resize((243, 160), Image.LANCZOS).save(f'{root}/ui/{name}.png', optimize=True)
prev = Image.new('RGB', (1230, 420), 'black')
for i, n in enumerate(['equalizer', 'ambient', 'ambient_on']):
    prev.paste(Image.open(f'{root}/ui_source/{n}.png').convert('RGB').crop((240, 30, 1035, 830)).resize((400, 402)), (i * 410, 0))
prev.save(sys.argv[2])
