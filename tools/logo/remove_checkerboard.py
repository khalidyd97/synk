"""Turns a logo exported with a baked-in "transparency" checkerboard into a real transparent PNG.

The checkerboard is regular (light and dark grey squares), so the exact background behind every
pixel can be rebuilt. Each pixel is then un-blended from that background ("colour to alpha"):
alpha is how far the pixel is from the background, and the colour is what remains once the
background's share is removed. Glows and sparks stay soft and translucent instead of being cut out.

Usage (from the repository root):
  python tools/logo/remove_checkerboard.py <input.jpg|png> assets/brand/synk_logo.png
"""
import math
import sys

import numpy as np
from PIL import Image, ImageFilter

LIGHT, DARK = 90.0, 31.0
SUPERSAMPLE = 4


def measure_grid(gray):
    """Square size and offsets, from the light/dark transitions along the top row and left column."""
    row = gray[min(40, gray.shape[0] - 1)]
    col = gray[:, min(40, gray.shape[1] - 1)]
    threshold = (LIGHT + DARK) / 2
    xs = [x for x in range(1, len(row)) if (row[x - 1] > threshold) != (row[x] > threshold)]
    ys = [y for y in range(1, len(col)) if (col[y - 1] > threshold) != (col[y] > threshold)]
    size = (xs[-1] - xs[0]) / (len(xs) - 1)
    first_light = row[0] > threshold
    return size, xs[0] % size, ys[0] % size, first_light


def background(shape, size, offset_x, offset_y, first_light):
    """The checkerboard rendered at higher resolution and softened like the JPEG it came from."""
    h, w = shape
    big = Image.new("L", (w * SUPERSAMPLE, h * SUPERSAMPLE))
    yy, xx = np.mgrid[0:h * SUPERSAMPLE, 0:w * SUPERSAMPLE] / SUPERSAMPLE
    cells = np.floor((xx - offset_x) / size) + np.floor((yy - offset_y) / size)
    # The sampled pixel (0, 40) is light or dark; every cell with its parity matches it.
    reference = (math.floor((0 - offset_x) / size) + math.floor((40 - offset_y) / size)) % 2
    light = (cells % 2 == reference) if first_light else (cells % 2 != reference)
    big = Image.fromarray(np.where(light, LIGHT, DARK).astype(np.uint8))
    small = big.resize((w, h), Image.BOX).filter(ImageFilter.GaussianBlur(.6))
    return np.asarray(small, dtype=np.float32)


def edge_band(shape, size, offset_x, offset_y, width=2.0):
    """Pixels within `width` of a square's edge, where the JPEG blends the two shades."""
    h, w = shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32) + .5
    dx = np.abs(((xx - offset_x) / size + .5) % 1 - .5) * size
    dy = np.abs(((yy - offset_y) / size + .5) % 1 - .5) * size
    return (dx < width) | (dy < width)


def color_to_alpha(rgb, b, chroma):
    above = np.clip((rgb - b) / (255.0 - b), 0, 1)
    below = np.clip((b - rgb) / np.maximum(b, 1), 0, 1)
    # Grey darkening (the artwork's soft drop shadow over the squares) is dropped: it only shows
    # up as faint squares, and the logo always sits on dark backgrounds anyway.
    below = below * np.clip((chroma - 20) / 30, 0, 1)[..., None]
    return np.max(np.maximum(above, below), axis=2)


def unblend(rgb, back, band):
    gray = rgb.mean(axis=2)
    # Along square edges the background can be any grey between the two shades; take the one
    # closest to the pixel so the seams between squares disappear.
    edge_back = np.clip(gray, DARK, LIGHT)
    b = np.where(band, edge_back, back)[..., None]
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    alpha = color_to_alpha(rgb, b, chroma)
    # The checkerboard is pure grey and the logo is saturated neon: colourfulness says how opaque
    # a pixel is, which keeps the solid letter glass fully opaque over both shades.
    alpha = np.maximum(alpha, np.clip((chroma - 14) / 80, 0, 1))
    # JPEG noise leaves a faint haze over the empty background; fade it out.
    alpha = alpha * np.clip((alpha - .06) / .1, 0, 1)
    safe = np.maximum(alpha, 1e-4)[..., None]
    color = np.clip((rgb - (1 - alpha[..., None]) * b) / safe, 0, 255)
    return np.dstack([color, alpha * 255]).astype(np.uint8)


def main(source, target):
    image = Image.open(source).convert("RGB")
    rgb = np.asarray(image, dtype=np.float32)
    gray = rgb.mean(axis=2)
    size, offset_x, offset_y, first_light = measure_grid(gray)
    back = background(gray.shape, size, offset_x, offset_y, first_light)
    result = Image.fromarray(unblend(rgb, back, edge_band(gray.shape, size, offset_x, offset_y)), "RGBA")
    bbox = result.getchannel("A").point(lambda v: 255 if v > 10 else 0).getbbox()
    pad = 24
    bbox = (max(0, bbox[0] - pad), max(0, bbox[1] - pad), min(result.width, bbox[2] + pad), min(result.height, bbox[3] + pad))
    result = result.crop(bbox)
    result.save(target)
    print(f"grid {size:.2f}px, offset ({offset_x:.1f}, {offset_y:.1f}); wrote {target} {result.size}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
