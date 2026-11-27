"""Three app icon concepts for SYNK, drawn as light on black.

    python tools/make_app_icon_concepts.py

Writes full-bleed 1024 px squares to assets/brand/new_icon/concepts/:
    1_s_strokes.png   an S in two strokes of light, gold above and pink below,
                      meeting in a white spark
    2_sync_rings.png  two rings, gold and cyan, overlapping like an eclipse
    3_highway_s.png   the highway bent into an S, seen from above (the chosen icon)

    python tools/make_app_icon_concepts.py --apply

also writes the chosen icon over the app's icon files in assets/brand.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/brand/new_icon/concepts"
RING = ROOT / "assets/synk_mode/source/ring.png"
SIZE = 1024

GOLD = np.array([1.0, .66, .18])
AMBER = np.array([1.0, .50, .14])
PINK = np.array([1.0, .22, .52])
CYAN = np.array([.22, .82, 1.0])
WARM = np.array([1.0, .90, .72])
WHITE = np.ones(3)

Y, X = np.mgrid[0:SIZE, 0:SIZE].astype(float) + .5


def smooth(e0, e1, v):
    t = np.clip((v - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def arc_distance(centre, radius, start, end):
    """Distance to an arc of a circle, whether each pixel lies beside the arc (rather than
    past an end), and the distance to its far end. Angles in degrees, measured clockwise on
    screen from the +x axis; the arc runs clockwise from start to end."""
    dx, dy = X - centre[0], Y - centre[1]
    angle = (np.degrees(np.arctan2(dy, dx)) - start) % 360
    span = (end - start) % 360 or 360
    on_arc = angle <= span
    d_ring = np.abs(np.hypot(dx, dy) - radius)
    ends = []
    for a in (start, end):
        ex = centre[0] + radius * np.cos(np.radians(a)); ey = centre[1] + radius * np.sin(np.radians(a))
        ends.append(np.hypot(X - ex, Y - ey))
    d = np.where(on_arc, d_ring, np.minimum(ends[0], ends[1]))
    # ends[1] is the distance to the arc's far (free) end; the last value is how many
    # degrees of arc remain before that end (0 past it).
    return d, on_arc, ends[1], np.where(on_arc, span - angle, 0.0)


def neon(light, d, colour, width, strength=1.0):
    """Add a stroke of light: white-hot core, coloured body, wide soft glow."""
    core = np.exp(-(d / (width * .38)) ** 2)
    body = np.exp(-(d / width) ** 2)
    glow = np.exp(-d / (width * 2.6)) * .30 + np.exp(-d / (width * 7.0)) * .09
    if np.ndim(colour) == 1: colour = np.broadcast_to(colour, light.shape)
    tone = colour + (WARM - colour) * np.clip(body * .9, 0, 1)[..., None]
    tone = tone + (WHITE - tone) * np.clip(core, 0, 1)[..., None]
    light += tone * (np.clip(body + glow, 0, 1.2) * strength)[..., None]


def sparkle(light, at, size, strength=1.0):
    """SYNK's four-point sparkle."""
    dx, dy = np.abs(X - at[0]) / size, np.abs(Y - at[1]) / size
    star = np.clip(1 - (np.sqrt(dx) + np.sqrt(dy)), 0, 1) ** 1.3
    flare = np.exp(-(dy * 9) ** 2) * np.exp(-dx * 1.6) + np.exp(-(dx * 9) ** 2) * np.exp(-dy * 2.2)
    light += WHITE * ((star * 1.6 + flare * .55 + np.exp(-(dx * dx + dy * dy) * 5) * .9) * strength)[..., None]


def backdrop(tint, centre=(.5, .5), strength=.16):
    r = np.hypot(X / SIZE - centre[0], Y / SIZE - centre[1])
    light = np.zeros((SIZE, SIZE, 3)) + np.array([.012, .009, .016])
    light += tint * (np.exp(-r * 3.2) * strength)[..., None]
    return light


def develop(light):
    """Light to a finished picture (0..1): a touch of bloom, then a soft roll-off so the
    brightest light keeps its colour."""
    img = Image.fromarray(np.clip(light * 255, 0, 255).astype(np.uint8), "RGB")
    bloom = np.asarray(img.filter(ImageFilter.GaussianBlur(SIZE * .014))).astype(float) / 255
    out = 1 - np.exp(-(light + bloom * .22) * 1.05)
    return np.clip(out / (1 - np.exp(-1.25)), 0, 1)


def finish(light, name):
    Image.fromarray(np.clip(develop(light) * 255 + .5, 0, 255).astype(np.uint8), "RGB").save(OUT / name)


# The S both letter concepts share: an upper bowl open to the lower right and a lower bowl
# open to the upper left, meeting with one tangent at the icon's centre.
S_RADIUS = 158.0
S_TOP = (512.0, 512.0 - S_RADIUS)
S_BOTTOM = (512.0, 512.0 + S_RADIUS)


def s_strokes():
    light = backdrop(AMBER * .6 + PINK * .4, strength=.10)
    # Upper stroke, gold: from the centre, round the left and over the top, to the upper right.
    d, _, _, _ = arc_distance(S_TOP, S_RADIUS, 90, 322)
    neon(light, d, GOLD, 24.0)
    # A fine inner line, like the note ring's second rim.
    d_in, _, _, _ = arc_distance(S_TOP, S_RADIUS - 46, 104, 300)
    neon(light, d_in, GOLD, 4.0, .5)
    # Lower stroke, pink: from the centre, round the right and bottom, to the lower left.
    d, _, _, _ = arc_distance(S_BOTTOM, S_RADIUS, 270, 142)
    neon(light, d, PINK, 24.0)
    d_in, _, _, _ = arc_distance(S_BOTTOM, S_RADIUS - 46, 284, 120)
    neon(light, d_in, PINK, 4.0, .5)
    # Where the two meet, they sync: a white spark.
    sparkle(light, (512, 512), 120.0, .75)
    finish(light, "1_s_strokes.png")


def sync_rings():
    light = backdrop(GOLD * .5 + CYAN * .5, strength=.07)
    radius, offset = 232.0, 112.0
    left = (512 - offset, 512.0); right = (512 + offset, 512.0)
    d_left = np.hypot(X - left[0], Y - left[1]); d_right = np.hypot(X - right[0], Y - right[1])
    # Each ring is a note: a bold rim and a fine inner one, with dark glass inside.
    for d, colour in [(d_left, GOLD), (d_right, CYAN)]:
        light += colour * (smooth(radius, radius - 70, d) * .035)[..., None]
        neon(light, np.abs(d - radius), colour, 13.0)
        neon(light, np.abs(d - (radius - 38)), colour, 3.2, .5)
    # The overlap is where they are in sync: it glows, brightest down its middle.
    lens = smooth(radius - 14, radius - 44, d_left) * smooth(radius - 14, radius - 44, d_right)
    core = np.exp(-(np.hypot(X - 512, (Y - 512) / 2.4) / 70) ** 2)
    light += WARM * (lens * (.10 + .55 * core))[..., None]
    # The two crossing points flare.
    reach = np.sqrt(radius ** 2 - offset ** 2)
    for cy in (512 - reach, 512 + reach):
        sparkle(light, (512, cy), 80.0, .7)
    finish(light, "2_sync_rings.png")


def highway_s_light(with_backdrop=True):
    """The chosen icon: the highway bent into an S, seen from above. Dark glass road with
    two lane lines, between two amber rails that fade out at the S's free ends."""
    light = backdrop(AMBER, strength=.10) if with_backdrop else np.zeros((SIZE, SIZE, 3))
    half = 62.0                                                # half the road's width
    for centre, start, stop in [(S_TOP, 90, 322), (S_BOTTOM, 270, 142)]:
        _, on_arc, to_end, remaining = arc_distance(centre, S_RADIUS, start, stop)
        across = np.hypot(X - centre[0], Y - centre[1]) - S_RADIUS   # distance across the road
        # The road thins out over its last stretch, by angle, so its glow leaves no edge.
        fade = smooth(0, 34, remaining) * smooth(half * .4, half * 2.4, to_end) * on_arc
        road = smooth(half, half - 5, np.abs(across)) * fade
        light += np.array([.085, .085, .11]) * road[..., None]
        for lane in (-half / 3, half / 3):
            light += np.array([.5, .5, .56]) * (np.exp(-((across - lane) / 1.5) ** 2) * road * .28)[..., None]
        neon(light, np.abs(np.abs(across) - half), AMBER, 8.0, fade)
    return light


def highway_s():
    finish(highway_s_light(), "3_highway_s.png")


def rounded_mask(size, radius):
    y, x = np.mgrid[0:size, 0:size].astype(float) + .5
    qx = np.abs(x - size / 2) - (size / 2 - radius); qy = np.abs(y - size / 2) - (size / 2 - radius)
    d = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - radius
    return np.clip(.5 - d, 0, 1)


def rgba(rgb, alpha):
    return Image.fromarray(np.dstack([np.clip(rgb * 255 + .5, 0, 255), np.clip(alpha * 255 + .5, 0, 255)]).astype(np.uint8), "RGBA")


def apply_highway_s():
    """Write the chosen icon over the app's icon files in assets/brand."""
    brand = ROOT / "assets/brand"
    full = develop(highway_s_light())
    Image.fromarray(np.clip(full * 255 + .5, 0, 255).astype(np.uint8), "RGB").save(ROOT / "assets/brand/new_icon/icon_1024.png")
    # icon.png: the project's icon, with rounded corners like the one it replaces.
    rounded = rgba(full, rounded_mask(SIZE, SIZE * .225))
    rounded.save(brand / "icon.png")
    rounded.resize((192, 192), Image.LANCZOS).save(brand / "icon_android_192.png")
    # Android adaptive icon: the launcher shows only the middle two thirds of each layer.
    plain = develop(backdrop(AMBER, strength=.10))
    Image.fromarray(np.clip(plain * 255 + .5, 0, 255).astype(np.uint8), "RGB").resize((432, 432), Image.LANCZOS).save(brand / "icon_background_432.png")
    mark = develop(highway_s_light(with_backdrop=False))
    alpha = np.clip(mark.max(axis=2) * 1.25, 0, 1)
    letter = rgba(mark / np.maximum(alpha, 1e-6)[..., None], alpha)
    inner = round(432 * .74)
    small = letter.convert("RGBa").resize((inner, inner), Image.LANCZOS).convert("RGBA")
    layer = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    layer.alpha_composite(small, ((432 - inner) // 2, (432 - inner) // 2))
    layer.save(brand / "icon_foreground_432.png")
    mono_alpha = np.asarray(layer).astype(float)[..., 3] / 255
    rgba(np.ones((432, 432, 3)), mono_alpha).save(brand / "icon_monochrome_432.png")
    # Start-up splash (project.godot boot_splash/image; iOS shows it on the launch screen):
    # the letter alone on the splash's black, with room around it.
    inner = round(SIZE * .5)
    splash = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255))
    splash.alpha_composite(letter.convert("RGBa").resize((inner, inner), Image.LANCZOS).convert("RGBA"), ((SIZE - inner) // 2, (SIZE - inner) // 2))
    splash.save(brand / "synk_logo.png")
    print("highway S icon applied to", brand)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    import sys
    s_strokes(); sync_rings(); highway_s()
    print("concepts written to", OUT)
    # `--apply` makes the highway S (the chosen concept) the app's icon.
    if "--apply" in sys.argv: apply_highway_s()
