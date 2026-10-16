"""Builds every app icon from assets/icon_source/icon_mark.png.

The source is the 1080 px mark (black "mu", blue and pink dots on white).
Its edges are cleaned up (upsample, blur, re-threshold) and each colour is
re-drawn flat, then written as:
  assets/icon/icon.png         legacy launcher icon (white square)
  assets/icon/foreground.png   adaptive icon foreground (transparent)
  assets/icon/monochrome.png   Android 13+ themed icon (alpha only)
  store/play_store_icon_512.png
  android/.../drawable-*/ic_stat_muslic.png  white notification glyph

Run: python3 ci/make_icon.py
"""
import numpy as np
from PIL import Image, ImageFilter

SRC = "assets/icon_source/icon_mark.png"
BLUE = (0, 148, 255)
PINK = (255, 0, 246)
UP = 4


def clean(mask):
    """Smooth jagged edges of a 0..1 mask, return it at UP x resolution."""
    m = Image.fromarray((mask * 255).astype(np.uint8))
    m = m.resize((m.width * UP, m.height * UP), Image.LANCZOS)
    m = m.filter(ImageFilter.GaussianBlur(UP * 1.6))
    a = np.asarray(m).astype(np.float32) / 255
    # Re-sharpen around the 50% edge: about 2 source px of soft edge.
    a = np.clip((a - 0.5) * 3.0 + 0.5, 0, 1)
    return a


src = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float32)
r, g, b = src[..., 0], src[..., 1], src[..., 2]
sat = src.max(axis=2) - src.min(axis=2)
lum = (r + g + b) / 3
black = np.clip((200 - lum) / 150, 0, 1) * (sat < 90)
blue = ((sat > 90) & (b > r)).astype(np.float32)
pink = ((sat > 90) & (r > b - 30) & (r > 150)).astype(np.float32)

layers = [(clean(black), (0, 0, 0)), (clean(blue), BLUE), (clean(pink), PINK)]
H, W = layers[0][0].shape


def render(bg):
    """RGBA at UP x size; bg None = transparent."""
    rgb = np.zeros((H, W, 3), np.float32)
    alpha = np.zeros((H, W), np.float32)
    if bg is not None:
        rgb[:] = bg
        alpha[:] = 1
    for a, col in layers:
        rgb = rgb * (1 - a[..., None]) + np.array(col, np.float32) * a[..., None]
        alpha = alpha + a * (1 - alpha)
    if bg is None:
        # Un-premultiply for transparent output.
        safe = np.maximum(alpha, 1e-4)[..., None]
        prem = np.zeros_like(rgb)
        for a, col in layers:
            prem = prem * (1 - a[..., None]) + np.array(col, np.float32) * a[..., None]
        rgb = prem / safe
    out = np.dstack([np.clip(rgb, 0, 255), alpha * 255]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


full = render((255, 255, 255)).convert("RGB")
full.resize((1024, 1024), Image.LANCZOS).save("assets/icon/icon.png")
full.resize((512, 512), Image.LANCZOS).save("store/play_store_icon_512.png")

# Adaptive: the visible part of the 108 dp canvas is the middle 72 dp, so
# the whole source square is fitted into that middle two thirds.
fg = render(None)
inner = round(1024 * 72 / 108)
canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
canvas.paste(fg.resize((inner, inner), Image.LANCZOS),
             ((1024 - inner) // 2, (1024 - inner) // 2))
canvas.save("assets/icon/foreground.png")

alpha_all = np.zeros((H, W), np.float32)
for a, _ in layers:
    alpha_all = alpha_all + a * (1 - alpha_all)


def glyph(size, fill):
    """Mark as a single colour on transparent, fitted in a size x size box."""
    ys, xs = np.where(alpha_all > 0.02)
    a = alpha_all[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = a.shape
    s = fill * size / max(h, w)
    img = Image.fromarray((a * 255).astype(np.uint8)).resize(
        (max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    white = Image.new("RGBA", img.size, (255, 255, 255, 255))
    out.paste(white, ((size - img.width) // 2, (size - img.height) // 2), img)
    return out


mono = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
m = glyph(inner, 578 / 1080)  # same size as the mark in the colour icon
mono.paste(m, ((1024 - inner) // 2, (1024 - inner) // 2), m)
mono.save("assets/icon/monochrome.png")

for name, px in [("mdpi", 24), ("hdpi", 36), ("xhdpi", 48), ("xxhdpi", 72),
                 ("xxxhdpi", 96)]:
    glyph(px, 0.92).save(
        f"android/app/src/main/res/drawable-{name}/ic_stat_muslic.png")
print("icons written")
