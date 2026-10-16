"""Generates the result-screen rank letters (S, A, B, C, D) in the style of the combo digits.

The combo digits (assets/hud/Combo_Digits_1_to_9.png) are wide geometric neon glass glyphs:
a magenta-to-blue-to-cyan body, a bright white rim, a thin inner outline, a soft outer glow and
small sparkles. Each letter here is drawn on the same 447x391 cell with the same proportions,
so it can sit next to the digits and share the in-game gradient material.

Run from the project root:  python tools/rank_letters/generate.py
Writes assets/hud/Rank_<letter>.png
"""
import math
import os
from PIL import Image, ImageChops, ImageDraw, ImageFilter

CELL = (447, 391)
SCALE = 2  # drawn at 2x, then downsampled for smooth edges
STROKE = 56
LEFT, RIGHT, TOP, BOTTOM = 78, 362, 78, 332
MIDDLE = 205
RADIUS = 52

MAGENTA = (240, 30, 230)
BLUE = (40, 30, 235)
CYAN = (20, 200, 255)

# Each glyph is a list of centerline paths: (points, closed, corner radii per point).
GLYPHS = {
    "S": [([(RIGHT, TOP), (LEFT, TOP), (LEFT, MIDDLE), (RIGHT, MIDDLE), (RIGHT, BOTTOM), (LEFT, BOTTOM)], False, RADIUS)],
    "C": [([(RIGHT, TOP), (LEFT, TOP), (LEFT, BOTTOM), (RIGHT, BOTTOM)], False, RADIUS)],
    "D": [([(LEFT, TOP), (RIGHT, TOP), (RIGHT, BOTTOM), (LEFT, BOTTOM)], True, [0, RADIUS * 1.6, RADIUS * 1.6, 0])],
    "A": [([(LEFT, BOTTOM), (LEFT, TOP), (RIGHT, TOP), (RIGHT, BOTTOM)], False, RADIUS),
          ([(LEFT, 215), (RIGHT, 215)], False, 0)],
    "B": [([(LEFT, MIDDLE), (335, MIDDLE), (335, TOP), (LEFT, TOP), (LEFT, BOTTOM), (RIGHT, BOTTOM), (RIGHT, MIDDLE), (335, MIDDLE)],
           False, [0, RADIUS * .7, RADIUS, 0, 0, RADIUS, RADIUS * .7, 0])],
}


def rounded_polyline(points, closed, radii):
    """Samples a polyline whose corners are rounded with quadratic curves."""
    if not isinstance(radii, list):
        radii = [radii] * len(points)
    count = len(points)
    result = []
    for i in range(count):
        point = points[i]
        has_prev = closed or i > 0
        has_next = closed or i < count - 1
        radius = radii[i]
        if not (has_prev and has_next) or radius <= 0:
            result.append(point)
            continue
        prev_point = points[i - 1]
        next_point = points[(i + 1) % count]

        def toward(a, b, distance):
            length = math.dist(a, b)
            t = min(distance, length / 2) / max(length, 1e-6)
            return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)

        start = toward(point, prev_point, radius)
        end = toward(point, next_point, radius)
        for step in range(13):
            t = step / 12
            x = (1 - t) ** 2 * start[0] + 2 * (1 - t) * t * point[0] + t * t * end[0]
            y = (1 - t) ** 2 * start[1] + 2 * (1 - t) * t * point[1] + t * t * end[1]
            result.append((x, y))
    if closed:
        result.append(result[0])
    return result


def stroke_mask(letter):
    size = (CELL[0] * SCALE, CELL[1] * SCALE)
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    half = STROKE * SCALE / 2
    for points, closed, radii in GLYPHS[letter]:
        line = rounded_polyline(points, closed, radii)
        for a, b in zip(line, line[1:]):
            length = math.dist(a, b)
            steps = max(1, int(length * SCALE / 2))
            for s in range(steps + 1):
                t = s / steps
                x = (a[0] + (b[0] - a[0]) * t) * SCALE
                y = (a[1] + (b[1] - a[1]) * t) * SCALE
                draw.ellipse((x - half, y - half, x + half, y + half), fill=255)
    return mask


def erode(mask, pixels):
    return mask.filter(ImageFilter.MinFilter(pixels * 2 + 1)) if pixels > 0 else mask


def gradient(size):
    """Magenta on the left through blue to cyan on the right, tilted slightly."""
    width, height = size
    image = Image.new("RGB", size)
    pixels = image.load()
    for y in range(height):
        for x in range(width):
            t = min(1.0, max(0.0, (x / width) * .85 + (1 - y / height) * .15))
            if t < .5:
                k = t / .5
                color = tuple(int(MAGENTA[c] + (BLUE[c] - MAGENTA[c]) * k) for c in range(3))
            else:
                k = (t - .5) / .5
                color = tuple(int(BLUE[c] + (CYAN[c] - BLUE[c]) * k) for c in range(3))
            pixels[x, y] = color
    return image


def layer(color_image, alpha):
    result = color_image.convert("RGBA")
    result.putalpha(alpha)
    return result


def sparkle(draw, center, size, alpha):
    x, y = center
    for length, width in ((size, 2 * SCALE), (size * .45, 1 * SCALE)):
        draw.line((x - length, y, x + length, y), fill=(255, 255, 255, alpha), width=int(width))
        draw.line((x, y - length, x, y + length), fill=(255, 255, 255, alpha), width=int(width))
    draw.ellipse((x - 4 * SCALE, y - 4 * SCALE, x + 4 * SCALE, y + 4 * SCALE), fill=(255, 255, 255, alpha))


def render(letter, colors):
    mask = stroke_mask(letter)
    size = mask.size
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    # Soft outer glow in the gradient colours.
    glow_alpha = mask.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(16 * SCALE)).point(lambda v: int(v * .7))
    canvas.alpha_composite(layer(colors, glow_alpha))
    # Solid glass body in the full gradient, a little lighter down the middle of the stroke.
    inner = erode(mask, 12 * SCALE).filter(ImageFilter.GaussianBlur(8 * SCALE))
    white = Image.new("RGB", size, (255, 255, 255))
    body = Image.composite(Image.blend(colors, white, .1), colors, inner.point(lambda v: int(v * .8)))
    canvas.alpha_composite(layer(body, mask))
    # Glossy streak across the upper part of each stroke.
    gloss = ImageChops.subtract(mask, ImageChops.offset(mask, 0, 9 * SCALE)).filter(ImageFilter.GaussianBlur(3 * SCALE)).point(lambda v: int(v * .3))
    canvas.alpha_composite(layer(white, gloss))
    # Bright rim along the outside edge, lightly tinted.
    rim = ImageChops.subtract(mask, erode(mask, 3 * SCALE)).filter(ImageFilter.GaussianBlur(1 * SCALE))
    rim_color = Image.blend(colors, Image.new("RGB", size, (255, 255, 255)), .55)
    canvas.alpha_composite(layer(rim_color, rim))
    # Thin inner outline that gives the digits their double-line glass look.
    outline = ImageChops.subtract(erode(mask, 14 * SCALE), erode(mask, 15 * SCALE)).point(lambda v: int(v * .3))
    canvas.alpha_composite(layer(Image.new("RGB", size, (235, 245, 255)), outline))
    # Sparkles on two corners, like the light glints on the digits.
    shine = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(shine)
    sparkle(draw, ((RIGHT + 6) * SCALE, (TOP - 8) * SCALE), 24 * SCALE, 235)
    sparkle(draw, ((LEFT - 4) * SCALE, (BOTTOM + 6) * SCALE), 16 * SCALE, 200)
    canvas.alpha_composite(shine.filter(ImageFilter.GaussianBlur(1)))
    return canvas.resize(CELL, Image.LANCZOS)


def main():
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    out_dir = os.path.join(root, "assets", "hud")
    colors = gradient((CELL[0] * SCALE, CELL[1] * SCALE))
    for letter in GLYPHS:
        path = os.path.join(out_dir, f"Rank_{letter}.png")
        render(letter, colors).save(path)
        print("wrote", path)


if __name__ == "__main__":
    main()
