"""Renders the SYNK app icon in the game's neon style.

A slanted neon "S" (same stroke shape and cyan-violet-magenta gradient as the SYNK wordmark)
floats over the gameplay highway: a perspective track with a cyan left rail, a magenta right
rail, a glowing hit bar and a note landing on it, all on a deep violet starfield.

Run from the repository root:  python tools/icon/generate_icon.py
Writes into assets/brand/:
  icon.png                    1024 x 1024 full icon (rounded corners), used by the project
  icon_android_192.png        192 x 192 legacy launcher icon
  icon_background_432.png     adaptive icon background layer (highway + sky)
  icon_foreground_432.png     adaptive icon foreground layer (the S), inside the safe zone
  icon_monochrome_432.png     adaptive icon monochrome layer (themed icons)
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SIZE = 1024
SS = 2                       # supersampling
W = SIZE * SS
OUT = Path(__file__).resolve().parents[2] / "assets" / "brand"
GRADIENT = [(0.0, (56, 186, 255)), (0.5, (163, 106, 255)), (1.0, (255, 79, 216))]
CYAN = (56, 186, 255)
VIOLET = (163, 106, 255)
MAGENTA = (255, 79, 216)

# The wordmark's S, in its 100 x 120 box (y grows downward).
S_LINE = [(90, 12), (30, 12), (11, 31), (11, 42), (29, 60), (71, 60), (89, 78), (89, 89), (70, 108), (10, 108)]
SLANT = 0.22


def gradient_color(t):
    t = min(1.0, max(0.0, t))
    for (t0, c0), (t1, c1) in zip(GRADIENT, GRADIENT[1:]):
        if t <= t1:
            f = (t - t0) / (t1 - t0)
            return tuple(round(a + (b - a) * f) for a, b in zip(c0, c1))
    return GRADIENT[-1][1]


def gradient_layer(mask, angle_mix=0.35, alpha_scale=1.0, box=None):
    """Colours a mask with the diagonal cyan-violet-magenta gradient, spread across box."""
    size = mask.size
    box = box or (0, 0, size[0], size[1])
    small = Image.new("RGB", (64, 64))
    for y in range(64):
        for x in range(64):
            small.putpixel((x, y), gradient_color((x / 63) * (1 - angle_mix) + (1 - y / 63) * angle_mix))
    stretched = small.resize((max(1, box[2] - box[0]), max(1, box[3] - box[1])), Image.BILINEAR)
    full = Image.new("RGB", size, GRADIENT[0][1])
    full.paste(GRADIENT[-1][1], (box[2], 0, size[0], size[1]))
    full.paste(stretched, (box[0], box[1]))
    layer = full.convert("RGBA")
    layer.putalpha(mask.point(lambda v: int(v * alpha_scale)))
    return layer


def solid(color, mask, alpha_scale=1.0):
    layer = Image.new("RGBA", mask.size, color + (0,))
    layer.putalpha(mask.point(lambda v: int(v * alpha_scale)))
    return layer


def s_mask(center, height, width_px):
    mask = Image.new("L", (W, W), 0)
    draw = ImageDraw.Draw(mask)
    k = height / 120.0
    pts = []
    for x, y in S_LINE:
        x += (120 - y) * SLANT
        pts.append(((center[0] + (x - 61) * k) * SS, (center[1] + (y - 60) * k) * SS))
    draw.line(pts, fill=255, width=round(width_px * SS), joint="curve")
    r = width_px * SS / 2
    for x, y in (pts[0], pts[-1]):
        draw.ellipse((x - r, y - r, x + r, y + r), fill=255)
    return mask


def neon(mask, core_width_mask, glow=(70, 22)):
    """Wide haze, tight bloom, gradient tube and a white-hot core."""
    box = mask.getbbox()
    layer = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    layer.alpha_composite(gradient_layer(mask.filter(ImageFilter.GaussianBlur(glow[0] * SS)), alpha_scale=.6, box=box))
    layer.alpha_composite(gradient_layer(mask.filter(ImageFilter.GaussianBlur(glow[1] * SS)), alpha_scale=.9, box=box))
    layer.alpha_composite(gradient_layer(mask, box=box))
    layer.alpha_composite(solid((255, 255, 255), core_width_mask.filter(ImageFilter.GaussianBlur(3 * SS)), .9))
    return layer


def background(bar_y=835):
    canvas = Image.new("RGBA", (W, W), (0, 0, 0, 255))
    # Deep violet sky, brightest just above the vanishing point.
    sky = Image.new("RGB", (128, 128))
    for y in range(128):
        for x in range(128):
            d = math.hypot((x - 64) / 64, (y - 46) / 64)
            t = max(0.0, 1 - d / 1.25)
            base = (8, 7, 26)
            glow = (54, 18, 112)
            sky.putpixel((x, y), tuple(int(base[c] + (glow[c] - base[c]) * t ** 1.6) for c in range(3)))
    canvas.alpha_composite(sky.resize((W, W), Image.BICUBIC).convert("RGBA"))
    # Stars.
    rng = random.Random(7)
    stars = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    draw = ImageDraw.Draw(stars)
    for _ in range(90):
        x, y = rng.uniform(0, W), rng.uniform(0, W * .55)
        r = rng.uniform(1.0, 2.6) * SS
        a = rng.randint(60, 200)
        draw.ellipse((x - r, y - r, x + r, y + r), fill=(220, 210, 255, a))
    canvas.alpha_composite(stars.filter(ImageFilter.GaussianBlur(.6 * SS)))

    # Highway in perspective.
    horizon_y, bottom_y = 330, 1090
    top_half, bottom_half = 70, 560
    cx = 512

    def edge(y, side):
        f = (y - horizon_y) / (bottom_y - horizon_y)
        return (cx + side * (top_half + (bottom_half - top_half) * f)) * SS

    track = Image.new("L", (W, W), 0)
    ImageDraw.Draw(track).polygon([(edge(horizon_y, -1), horizon_y * SS), (edge(horizon_y, 1), horizon_y * SS),
                                   (edge(bottom_y, 1), bottom_y * SS), (edge(bottom_y, -1), bottom_y * SS)], fill=255)
    fade = Image.linear_gradient("L").resize((W, W))  # 0 at top, 255 at bottom
    track_alpha = ImageChops.multiply(track, fade.point(lambda v: int(min(255, 60 + v * .8))))
    canvas.alpha_composite(solid((34, 16, 78), track_alpha, .95))
    # Faint lane guides.
    lanes = Image.new("L", (W, W), 0)
    ld = ImageDraw.Draw(lanes)
    for i in (1, 2, 3):
        f = i / 4
        top = edge(horizon_y, -1) + (edge(horizon_y, 1) - edge(horizon_y, -1)) * f
        bottom = edge(bottom_y, -1) + (edge(bottom_y, 1) - edge(bottom_y, -1)) * f
        ld.line((top, horizon_y * SS, bottom, bottom_y * SS), fill=255, width=2 * SS)
    canvas.alpha_composite(solid((150, 120, 255), ImageChops.multiply(lanes, fade), .35))
    # Rails: cyan on the left, magenta on the right.
    for side, color in ((-1, CYAN), (1, MAGENTA)):
        rail = Image.new("L", (W, W), 0)
        ImageDraw.Draw(rail).line((edge(horizon_y, side), horizon_y * SS, edge(bottom_y, side), bottom_y * SS), fill=255, width=12 * SS)
        rail = ImageChops.multiply(rail, fade.point(lambda v: int(min(255, 40 + v))))
        canvas.alpha_composite(solid(color, rail.filter(ImageFilter.GaussianBlur(22 * SS)), 1.0))
        canvas.alpha_composite(solid(color, rail))
        canvas.alpha_composite(solid((255, 255, 255), rail.filter(ImageFilter.MinFilter(5)), .7))

    # Hit bar across the track, and a note landing on it with a burst.
    bar = Image.new("L", (W, W), 0)
    ImageDraw.Draw(bar).rounded_rectangle((edge(bar_y, -1) + 10 * SS, (bar_y - 20) * SS, edge(bar_y, 1) - 10 * SS, (bar_y + 20) * SS), radius=10 * SS, fill=255)
    canvas.alpha_composite(gradient_layer(bar.filter(ImageFilter.GaussianBlur(26 * SS)), angle_mix=0, alpha_scale=.8))
    canvas.alpha_composite(gradient_layer(bar, angle_mix=0, alpha_scale=.85))
    core = Image.new("L", (W, W), 0)
    ImageDraw.Draw(core).line((edge(bar_y, -1) + 30 * SS, bar_y * SS, edge(bar_y, 1) - 30 * SS, bar_y * SS), fill=255, width=4 * SS)
    canvas.alpha_composite(solid((255, 255, 255), core.filter(ImageFilter.GaussianBlur(1.5 * SS)), .8))
    return canvas


def note_and_burst(cy=835):
    layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    cx = 512
    burst = Image.new("L", (W, W), 0)
    ImageDraw.Draw(burst).ellipse(((cx - 150) * SS, (cy - 60) * SS, (cx + 150) * SS, (cy + 60) * SS), fill=255)
    layer.alpha_composite(solid((255, 255, 255), burst.filter(ImageFilter.GaussianBlur(40 * SS)), .55))
    puck = Image.new("L", (W, W), 0)
    ImageDraw.Draw(puck).ellipse(((cx - 92) * SS, (cy - 34) * SS, (cx + 92) * SS, (cy + 34) * SS), fill=255)
    layer.alpha_composite(solid(CYAN, puck.filter(ImageFilter.GaussianBlur(10 * SS)), .9))
    layer.alpha_composite(solid(CYAN, puck))
    inner = Image.new("L", (W, W), 0)
    ImageDraw.Draw(inner).ellipse(((cx - 60) * SS, (cy - 21) * SS, (cx + 60) * SS, (cy + 21) * SS), fill=255)
    layer.alpha_composite(solid((200, 240, 255), inner.filter(ImageFilter.GaussianBlur(4 * SS)), .9))
    rim = Image.new("L", (W, W), 0)
    ImageDraw.Draw(rim).ellipse(((cx - 92) * SS, (cy - 34) * SS, (cx + 92) * SS, (cy + 34) * SS), outline=255, width=5 * SS)
    layer.alpha_composite(solid((255, 255, 255), rim, .9))
    # Light streak shooting up from the hit.
    streak = Image.new("L", (W, W), 0)
    ImageDraw.Draw(streak).polygon([((cx - 30) * SS, cy * SS), ((cx + 30) * SS, cy * SS), (cx * SS, (cy - 330) * SS)], fill=255)
    layer.alpha_composite(solid((255, 255, 255), streak.filter(ImageFilter.GaussianBlur(14 * SS)), .35))
    return layer


def foreground(center=(512, 470), height=470, stroke=78):
    mask = s_mask(center, height, stroke)
    core = s_mask(center, height, stroke * .3)
    return neon(mask, core), mask


def rounded(image, radius_fraction=.22):
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, image.width - 1, image.height - 1), radius=int(image.width * radius_fraction), fill=255)
    result = image.copy()
    result.putalpha(ImageChops.multiply(image.getchannel("A"), mask))
    return result


def downsample(image, size):
    return image.resize((size, size), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    back = background()
    back.alpha_composite(note_and_burst())
    s_layer, s_shape = foreground()

    full = back.copy()
    full.alpha_composite(s_layer)
    icon = rounded(downsample(full, SIZE))
    icon.save(OUT / "icon.png")
    downsample(icon, 192).save(OUT / "icon_android_192.png")

    # Adaptive layers: launchers crop to the middle ~66%, so the S is drawn smaller for the foreground.
    # Round and squircle masks hide the bottom corners, so the hit bar sits higher here.
    adaptive_back = background(bar_y=700)
    adaptive_back.alpha_composite(note_and_burst(cy=700))
    downsample(adaptive_back, 432).save(OUT / "icon_background_432.png")
    adaptive_s, adaptive_shape = foreground(center=(512, 450), height=360, stroke=64)
    downsample(adaptive_s, 432).save(OUT / "icon_foreground_432.png")
    mono = Image.new("RGBA", (W, W), (255, 255, 255, 0))
    mono.putalpha(adaptive_shape)
    downsample(mono, 432).save(OUT / "icon_monochrome_432.png")
    for name in ("icon.png", "icon_android_192.png", "icon_background_432.png", "icon_foreground_432.png", "icon_monochrome_432.png"):
        print("wrote", OUT / name)


if __name__ == "__main__":
    main()
