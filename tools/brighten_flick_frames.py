"""Make the flick chevron in the six animation frames more vibrant.

Reads the original artwork from assets/neon/flick/source/ and writes the game
frames to assets/neon/flick/. The puck is left untouched; only the chevron
(and its small spark lines) gets a solid white core and a hot-pink neon glow.

    python tools/brighten_flick_frames.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/neon/flick/source"
OUT = ROOT / "assets/neon/flick"

# Rows above this hold only chevron/sparks in every frame; below it is the puck.
PUCK_TOP = 380
# Over the puck the chevron (frames 1-3) stays inside this box; the puck's inner
# rings shift slightly between frames, so nothing outside it is treated as chevron.
CHEVRON_BOX = (220, 380, 550, 525)  # x0, y0, x1, y1
GLOW = np.array([255, 46, 150], dtype=float)  # hot pink neon
CORE_BOOST = 1.6   # how much the chevron core's opacity is lifted
GLOW_NEAR = 2.4   # tight glow strength
GLOW_FAR = 1.5    # wide glow strength


def blur(mask: np.ndarray, radius: float) -> np.ndarray:
    img = Image.fromarray(np.clip(mask * 255, 0, 255).astype(np.uint8))
    return np.asarray(img.filter(ImageFilter.GaussianBlur(radius))).astype(float) / 255


def dilate(mask: np.ndarray, size: int) -> np.ndarray:
    img = Image.fromarray(np.clip(mask * 255, 0, 255).astype(np.uint8))
    return np.asarray(img.filter(ImageFilter.MaxFilter(size))).astype(float) / 255


def main() -> None:
    frames = [np.asarray(Image.open(SRC / f"flick_{i}.png").convert("RGBA")).astype(float) / 255 for i in range(1, 7)]
    # The last frame's chevron is far above the puck: with its top rows cleared it is
    # a clean puck to compare every frame against.
    clean_disc = frames[-1].copy()
    clean_disc[:PUCK_TOP] = 0
    inside = clean_disc[..., 3] > 0.02
    box = np.zeros(inside.shape, bool)
    x0, y0, x1, y1 = CHEVRON_BOX
    box[y0:y1, x0:x1] = True
    for i, f in enumerate(frames, start=1):
        rgb, a = f[..., :3], f[..., 3]
        # Over the puck, the chevron is whatever is whiter than the clean disc.
        lift = np.clip((rgb.mean(axis=2) * a - clean_disc[..., :3].mean(axis=2) * clean_disc[..., 3]) * 4.0, 0, 1)
        mask = np.where(inside, np.where(box, lift, 0.0), a)
        mask = np.where(mask > 0.08, mask, 0.0)
        core = np.clip(dilate(mask, 3) * CORE_BOOST, 0, 1)
        glow = np.clip(blur(mask, 5) * GLOW_NEAR + blur(mask, 14) * GLOW_FAR, 0, 1)
        glow = np.where(inside, glow * 0.6, glow)  # keep the puck's own colour readable

        # Glow over the original (premultiplied "over").
        out_a = glow + a * (1 - glow)
        out_rgb = (GLOW * glow[..., None] / 255 + rgb * a[..., None] * (1 - glow[..., None])) / np.maximum(out_a, 1e-6)[..., None]
        # Solid white core on top.
        out_rgb = out_rgb * (1 - core[..., None]) + core[..., None]
        out_a = core + out_a * (1 - core)

        out = np.dstack([out_rgb, out_a])
        Image.fromarray(np.clip(out * 255 + 0.5, 0, 255).astype(np.uint8), "RGBA").save(OUT / f"flick_{i}.png")
        print(f"flick_{i}.png")


if __name__ == "__main__":
    main()
