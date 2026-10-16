"""Renders the SYNK neon wordmark to assets/brand/synk_logo.png (transparent background).

Run from the repository root:  python tools/logo/generate_logo.py
Requires Pillow. Letters are drawn as rounded strokes, slanted, filled with the game's
cyan-violet-magenta gradient, given a white-hot tube core and a layered glow, then
underlined with a "hit bar" streak like the gameplay judgment line.
"""
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SCALE = 4                      # supersampling factor for smooth edges
LETTER_W, LETTER_H, GAP = 100, 120, 26
STROKE = 21
SLANT = 0.22                   # italic shear: x shifts right as y rises
MARGIN_X, MARGIN_TOP, MARGIN_BOTTOM = 70, 46, 86
GRADIENT = [(0.0, (56, 186, 255)), (0.5, (163, 106, 255)), (1.0, (255, 79, 216))]
OUT = Path(__file__).resolve().parents[2] / "assets" / "brand" / "synk_logo.png"

# Each letter is a list of polylines in a 100 x 120 box (y grows downward).
LETTERS = {
    "S": [[(90, 12), (30, 12), (11, 31), (11, 42), (29, 60), (71, 60), (89, 78), (89, 89), (70, 108), (10, 108)]],
    "Y": [[(10, 12), (50, 58)], [(90, 12), (50, 58), (50, 108)]],
    "N": [[(12, 108), (12, 12), (88, 108), (88, 12)]],
    "K": [[(12, 12), (12, 108)], [(88, 12), (24, 62)], [(42, 49), (90, 108)]],
}


def gradient_color(t):
    for (t0, c0), (t1, c1) in zip(GRADIENT, GRADIENT[1:]):
        if t <= t1:
            f = (t - t0) / (t1 - t0)
            return tuple(round(a + (b - a) * f) for a, b in zip(c0, c1))
    return GRADIENT[-1][1]


def to_canvas(point, letter_index):
    x, y = point
    x += (LETTER_H - y) * SLANT
    x += MARGIN_X + letter_index * (LETTER_W + GAP)
    return ((x) * SCALE, (y + MARGIN_TOP) * SCALE)


def stroke_mask(size, width):
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    radius = width * SCALE / 2
    for index, letter in enumerate("SYNK"):
        for line in LETTERS[letter]:
            points = [to_canvas(p, index) for p in line]
            draw.line(points, fill=255, width=round(width * SCALE), joint="curve")
            for x, y in (points[0], points[-1]):
                draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=255)
    return mask


def hit_bar_mask(size, text_left, text_right):
    # A slanted streak under the letters, thickest in the middle and tapering to points.
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    y = (MARGIN_TOP + LETTER_H + 30) * SCALE
    left, right = text_left - 30 * SCALE, text_right + 10 * SCALE
    steps = 120
    top, bottom = [], []
    for i in range(steps + 1):
        f = i / steps
        x = left + (right - left) * f
        half = (0.6 + 3.4 * (1 - abs(f - 0.5) * 2) ** 1.6) * SCALE
        top.append((x, y - half))
        bottom.append((x, y + half))
    draw.polygon(top + bottom[::-1], fill=255)
    return mask

def colorize(mask, alpha_scale=1.0):
    width, height = mask.size
    gradient = Image.new("RGB", (width, 1))
    for x in range(width):
        gradient.putpixel((x, 0), gradient_color(x / (width - 1)))
    gradient = gradient.resize((width, height))
    layer = gradient.convert("RGBA")
    layer.putalpha(mask.point(lambda v: int(v * alpha_scale)))
    return layer


def main():
    width = MARGIN_X * 2 + 4 * LETTER_W + 3 * GAP + int(LETTER_H * SLANT)
    height = MARGIN_TOP + LETTER_H + MARGIN_BOTTOM
    size = (width * SCALE, height * SCALE)

    letters = stroke_mask(size, STROKE)
    core = stroke_mask(size, STROKE * 0.32).filter(ImageFilter.GaussianBlur(1.5 * SCALE))
    bbox = letters.getbbox()
    bar = hit_bar_mask(size, bbox[0], bbox[2])
    shape = ImageChops.lighter(letters, bar)

    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    # Layered glow: wide soft haze, then a tighter bloom.
    canvas.alpha_composite(colorize(shape.filter(ImageFilter.GaussianBlur(26 * SCALE)), 0.55))
    canvas.alpha_composite(colorize(shape.filter(ImageFilter.GaussianBlur(9 * SCALE)), 0.85))
    canvas.alpha_composite(colorize(shape))
    white_core = Image.new("RGBA", size, (255, 255, 255, 0))
    white_core.putalpha(ImageChops.lighter(core, bar.filter(ImageFilter.GaussianBlur(1 * SCALE)).point(lambda v: v // 2)).point(lambda v: int(v * 0.85)))
    canvas.alpha_composite(white_core)

    # Trim to the visible glow so the logo can be placed by its real bounds.
    canvas = canvas.crop(canvas.getchannel("A").point(lambda v: 255 if v > 6 else 0).getbbox())
    final = canvas.resize((canvas.width // 2, canvas.height // 2), Image.LANCZOS)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    final.save(OUT)
    print(f"wrote {OUT} ({final.width}x{final.height})")


if __name__ == "__main__":
    main()
