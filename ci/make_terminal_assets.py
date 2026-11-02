"""Builds the Terminal theme's images from the Figma exports.

Inputs: assets/ui_source/term_*.png (fetched from Figma, see
assets/figma-assets.txt). Outputs: assets/ui/term_*.png.

Figma draws the player bar, its buttons and the TV through a "Dither"
effect (ordered Bayer 16x16, 3 levels per channel; the TV uses 2 px
blocks and 4 levels). Those images never change, so the dither is baked in
here once instead of running a shader on the phone. Images are sized to
their Figma frame size, which is 1:1 with the pixels of a 1080 px wide
screen; the app draws them without smoothing so the dots stay crisp.

Run: python3 ci/make_terminal_assets.py
"""
import numpy as np
from PIL import Image, ImageDraw

SRC = "assets/ui_source/"
OUT = "assets/ui/"


def bayer(n):
    if n == 1:
        return np.zeros((1, 1))
    s = bayer(n // 2)
    return np.block([[4 * s, 4 * s + 2], [4 * s + 3, 4 * s + 1]])


B16 = (bayer(16) + 0.5) / 256.0


def dither(im, levels=3, block=1):
    a = np.asarray(im.convert("RGBA")).astype(np.float32) / 255.0
    h, w = a.shape[:2]
    rgb, alpha = a[..., :3], a[..., 3:]
    # Work in blocks of block x block pixels (Figma "Size").
    bh, bw = (h + block - 1) // block, (w + block - 1) // block
    small = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).resize(
        (bw, bh), Image.BOX)).astype(np.float32) / 255.0
    s_rgb = small[..., :3]
    ty = np.arange(bh)[:, None] % 16
    tx = np.arange(bw)[None, :] % 16
    th = B16[ty, tx][..., None]
    L = levels - 1
    q = np.clip(np.round((s_rgb + (th - 0.5) / L) * L) / L, 0, 1)
    big = np.repeat(np.repeat(q, block, 0), block, 1)[:h, :w]
    out = np.concatenate([big, alpha], axis=2)
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


def fit(name, size, resample=Image.LANCZOS):
    return Image.open(SRC + name).convert("RGBA").resize(size, resample)


def pause_variant(play):
    """The play button with its triangle replaced by two bars."""
    im = play.copy()
    d = ImageDraw.Draw(im)
    face = im.getpixel((20, 29))
    stroke = (178, 181, 186, 255)
    d.rectangle((68, 8, 118, 50), fill=face)
    for x in (84, 98):
        d.rounded_rectangle((x, 16, x + 7, 42), radius=2, fill=stroke)
    return im


# name, Figma size, dither (levels, block) or None, resample
JOBS = [
    ("term_bar.png", (1006, 176), (3, 1)),
    ("term_play.png", (180, 58), (3, 1)),
    ("term_prev.png", (81, 47), (3, 1)),
    ("term_next.png", (81, 47), (3, 1)),
    ("term_loop.png", (61, 61), (3, 1)),
    ("term_shuffle.png", (61, 61), (3, 1)),
    ("term_eq.png", (75, 43), (3, 1)),
    ("term_ambient.png", (75, 43), (3, 1)),
    ("term_tv.png", (1026, 786), (4, 2)),
    ("term_playhead.png", (61, 61), None),
]

for name, size, d in JOBS:
    im = fit(name, size)
    if name == "term_play.png":
        pause = pause_variant(im)
        (dither(pause, *d) if d else pause).save(OUT + "term_pause.png")
    (dither(im, *d) if d else im).save(OUT + name)

# Pixel-art icons: keep hard edges. Shown at 72 Figma px; stored at 3x.
for name in ("term_settings.png", "term_search.png"):
    fit(name, (216, 216), Image.NEAREST).save(OUT + name)

# Logo: 285 x 119 in Figma, cropped like object-fit: cover; stored at 3x.
logo = Image.open(SRC + "term_logo.png").convert("RGBA")
tw, th = 285 * 3, 119 * 3
s = max(tw / logo.width, th / logo.height)
logo = logo.resize((round(logo.width * s), round(logo.height * s)), Image.LANCZOS)
l, t = (logo.width - tw) // 2, (logo.height - th) // 2
logo.crop((l, t, l + tw, t + th)).save(OUT + "term_logo.png")
print("terminal assets written")
