"""Draw the SYNK app icon in the SYNK mode look.

A black field, the highway's two amber rails running to a vanishing point, the base bar's
bright line across them, and the gold chevron note (assets/synk_mode/source/flick.png)
glowing on the road between them.

    python tools/make_app_icon.py

Writes, in assets/brand/new_icon/:
    icon_1024.png          full-bleed square (what iOS and the stores take)
    icon_rounded_1024.png  the same with rounded corners, like the current icon.png
    icon_foreground_432.png / icon_background_432.png / icon_monochrome_432.png
                           Android adaptive layers
    icon_android_192.png   Android legacy launcher icon
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/brand/new_icon"
NOTE = ROOT / "assets/synk_mode/source/flick.png"
SIZE = 1024

AMBER = np.array([1.0, .55, .18])
EMBER = np.array([.80, .30, .08])
WARM = np.array([1.0, .86, .62])
WHITE = np.ones(3)


def segment_distance(x, y, a, b):
    ax, ay = a; bx, by = b
    vx, vy = bx - ax, by - ay
    t = np.clip(((x - ax) * vx + (y - ay) * vy) / (vx * vx + vy * vy), 0, 1)
    return np.hypot(x - ax - t * vx, y - ay - t * vy), t


def smooth(e0, e1, v):
    t = np.clip((v - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def scene(size=SIZE, with_note=True, with_background=True):
    """The icon as float RGB (additive light on black) plus the note layer."""
    y, x = np.mgrid[0:size, 0:size].astype(float)
    u, v = x / size, y / size
    light = np.zeros((size, size, 3))
    if with_background:
        # Amber rising from the bottom corners, and a faint glow where the rails meet.
        for cx in (0.0, 1.0):
            light += EMBER * (np.exp(-np.hypot((u - cx) * .9, v - 1.0) * 3.4) * .30)[..., None]
        light += EMBER * (np.exp(-np.hypot(u - .5, (v - .16) * 1.4) * 5.0) * .35)[..., None]
        # Two silk ribbons behind the rails.
        for base, sway, wave, phase, reach in [(.40, .07, 5.5, .4, .22), (.56, .05, 4.2, 2.1, .80)]:
            path = base + sway * np.sin(u * wave + phase)
            d = v - path
            stretch = np.exp(-((u - reach) / .26) ** 2)
            light += AMBER * (np.exp(-(d / .0035) ** 2) * stretch * .55)[..., None]
            light += EMBER * (np.exp(-np.maximum(d, 0) / .05) * (d > 0) * stretch * .16)[..., None]
    # The rails: a white-hot core in an amber body and a wide soft glow, thinning with distance.
    top_y = .17 * size
    for side in (-1, 1):
        a = (size * (.5 + side * .045), top_y)
        b = (size * (.5 + side * .56), size * 1.04)
        d, t = segment_distance(x, y, a, b)
        width = size * (.004 + .020 * t)
        fade = smooth(0, .12, t)
        core = np.exp(-(d / (width * .45)) ** 2)
        body = np.exp(-(d / width) ** 2)
        glow = np.exp(-d / (width * 3.2 + size * .012)) * .45
        colour = AMBER + (WARM - AMBER) * np.clip(body, 0, 1)[..., None]
        colour = colour + (WHITE - colour) * np.clip(core, 0, 1)[..., None]
        light += colour * (np.clip(body + glow, 0, 1) * fade)[..., None]
    # The base bar: dark glass under a bright hairline, between the rails.
    bar_top, bar_bottom = .80, .93
    half = (.045 + (.56 - .045) * ((v * size - top_y) / (size * 1.04 - top_y))) - .012
    inside = smooth(0, .01, half - np.abs(u - .5))
    glass = smooth(bar_top, bar_top + .004, v) * smooth(bar_bottom + .02, bar_bottom - .03, v) * inside
    light += np.array([.20, .20, .24]) * (glass * (1 - smooth(bar_top, bar_bottom, v) * .8))[..., None]
    light += np.array([.92, .93, 1.0]) * (np.exp(-((v - bar_top) / .0035) ** 2) * inside)[..., None]
    rgb = np.clip(light, 0, 1)
    if not with_note: return rgb
    # The gold chevron note, standing on the bar, with a bloom behind it.
    note = Image.open(NOTE).convert("RGBA")
    scale = size * .60 / note.width
    note = note.convert("RGBa").resize((round(note.width * scale), round(note.height * scale)), Image.LANCZOS).convert("RGBA")
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    layer.alpha_composite(note, (round(size / 2 - note.width / 2), round(size * .915 - note.height)))
    bloom = np.asarray(layer.filter(ImageFilter.GaussianBlur(size * .03))).astype(float) / 255
    rgb = np.clip(rgb + bloom[..., :3] * bloom[..., 3:] * .9, 0, 1)
    arr = np.asarray(layer).astype(float) / 255
    alpha = arr[..., 3:]
    return rgb * (1 - alpha) + arr[..., :3] * alpha


def to_image(rgb, alpha=None):
    data = np.clip(rgb * 255 + .5, 0, 255).astype(np.uint8)
    if alpha is None: return Image.fromarray(data, "RGB")
    return Image.fromarray(np.dstack([data, np.clip(alpha * 255 + .5, 0, 255).astype(np.uint8)]), "RGBA")


def rounded_mask(size, radius):
    y, x = np.mgrid[0:size, 0:size].astype(float) + .5
    qx = np.abs(x - size / 2) - (size / 2 - radius); qy = np.abs(y - size / 2) - (size / 2 - radius)
    d = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - radius
    return np.clip(.5 - d, 0, 1)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / ".gdignore").write_text("")
    full = scene()
    to_image(full).save(OUT / "icon_1024.png")
    to_image(full, rounded_mask(SIZE, SIZE * .225)).save(OUT / "icon_rounded_1024.png")
    to_image(full, rounded_mask(SIZE, SIZE * .225)).resize((192, 192), Image.LANCZOS).save(OUT / "icon_android_192.png")
    # Android adaptive layers: the launcher crops to the middle two thirds, so the art is
    # drawn smaller on the foreground and the background carries the stage alone.
    background = scene(with_note=False)
    to_image(background).resize((432, 432), Image.LANCZOS).save(OUT / "icon_background_432.png")
    note = Image.open(NOTE).convert("RGBA")
    scale = 432 * .42 / note.width
    note = note.convert("RGBa").resize((round(note.width * scale), round(note.height * scale)), Image.LANCZOS).convert("RGBA")
    foreground = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    foreground.alpha_composite(note, (round(216 - note.width / 2), round(432 * .70 - note.height)))
    foreground.save(OUT / "icon_foreground_432.png")
    mono = np.asarray(foreground).astype(float) / 255
    to_image(np.ones((432, 432, 3)), mono[..., 3]).save(OUT / "icon_monochrome_432.png")
    print("icon written to", OUT)


if __name__ == "__main__":
    main()
