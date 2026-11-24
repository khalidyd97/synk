"""Draw the SYNK mode artwork: notes, lane rings, rails and judgment bar.

SYNK mode is a skin of the SSRG stage, so every image keeps the size and layout
of the SSRG sprite it replaces (and the rail and judgment bar keep their exact
silhouettes); only the look is new. The palette follows the SYNK logo: warm
coral and amber on near-black, with cream highlights.

    python tools/make_synk_mode_art.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SSRG = ROOT / "assets/ssrg/imported"
OUT = ROOT / "assets/synk_mode"

CREAM = np.array([255, 241, 220]) / 255
CORAL = np.array([255, 107, 61]) / 255
AMBER = np.array([255, 195, 107]) / 255
FLICK = np.array([255, 45, 122]) / 255
WHITE = np.ones(3)
SS = 4  # supersampling for smooth edges

# Beat pulse heat for the six frames (frame 1 is the hottest, as in the SSRG frames).
HEAT = [1.0, .85, .68, .5, .36, .3]


def smooth(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)


def over(dst_rgb, dst_a, rgb, a):
    """Composite (rgb, a) over (dst_rgb, dst_a), straight alpha."""
    out_a = a + dst_a * (1 - a)
    out_rgb = (rgb * a[..., None] + dst_rgb * dst_a[..., None] * (1 - a[..., None])) / np.maximum(out_a, 1e-6)[..., None]
    return out_rgb, out_a


def save(rgb, a, path, size=None):
    img = Image.fromarray(np.clip(np.dstack([rgb, a]) * 255 + .5, 0, 255).astype(np.uint8), "RGBA")
    if size: img = img.resize(size, Image.LANCZOS)
    img.save(path)


def puck(w, h, color, heat):
    """A glass puck seen from the player's angle: top face, a coloured side, a halo,
    a cream rim, a white-hot core and a small four-point sparkle (the SYNK mark)."""
    W, H = w * SS, h * SS
    y, x = np.mgrid[0:H, 0:W].astype(float) / SS
    cx, rx = w / 2, w * .44
    top_cy, ry = h * .43, h * .32
    side = h * .1  # thickness of the side below the top face
    r_top = np.sqrt(((x - cx) / rx) ** 2 + ((y - top_cy) / ry) ** 2)
    r_low = np.sqrt(((x - cx) / rx) ** 2 + ((y - top_cy - side) / ry) ** 2)
    rgb = np.zeros((H, W, 3)); a = np.zeros((H, W))

    # Halo around the whole puck, brighter on the beat.
    r_out = np.minimum(r_top, r_low)
    halo = np.exp(-np.maximum(r_out - 1, 0) * 7) * (r_out > .95) * (.35 + .45 * heat)
    rgb, a = over(rgb, a, np.broadcast_to(color, rgb.shape), halo)

    # Side: the puck's coloured edge, darker, with a cream lip along its bottom.
    side_mask = smooth(1.02, .98, r_low) * (y > top_cy)
    side_col = color * .55
    lip = np.exp(-((r_low - .97) / .025) ** 2) * (y > top_cy + ry * .3)
    side_rgb = side_col + (CREAM - side_col) * (lip * .7)[..., None]
    rgb, a = over(rgb, a, side_rgb, side_mask)

    # Top face.
    face = smooth(1.0, .97, r_top)
    shade = np.clip(.75 + .35 * (top_cy - y) / ry, .5, 1.1)  # lit from above
    body = np.clip(color * shade[..., None], 0, 1)
    core_t = smooth(.5, .1, r_top) * (.35 + .6 * heat)
    body = body + (WHITE - body) * core_t[..., None]
    rim = np.exp(-((r_top - .93) / .035) ** 2)
    ring = np.exp(-((r_top - .52) / .025) ** 2) * .8
    body = body + (CREAM - body) * np.clip(rim + ring, 0, 1)[..., None]
    # A soft diagonal sheen across the upper left of the face.
    sheen = np.exp(-(((x - cx) * .45 + (y - top_cy) * 1.6 + ry * .35) / (ry * .28)) ** 2) * smooth(.9, .3, r_top) * .35
    body = body + (WHITE - body) * sheen[..., None]
    rgb, a = over(rgb, a, body, face)

    # The SYNK sparkle: a four-point star in the middle of the face.
    dx, dy = np.abs(x - cx) / (rx * .3), np.abs(y - top_cy) / (ry * .5)
    star = np.clip(1.15 * (1 - (np.sqrt(dx) + np.sqrt(dy))), 0, 1) ** .8 * (.75 + .25 * heat)
    rgb, a = over(rgb, a, np.broadcast_to(WHITE, rgb.shape), star * face)
    return rgb, a


def downsample(rgb, a, w, h):
    img = Image.fromarray(np.clip(np.dstack([rgb * a[..., None], a]) * 255 + .5, 0, 255).astype(np.uint8), "RGBA")
    small = np.asarray(img.resize((w, h), Image.LANCZOS)).astype(float) / 255
    sa = small[..., 3]
    return small[..., :3] / np.maximum(sa, 1e-6)[..., None], sa


def notes():
    for prefix, color, (w, h) in [("tap", CORAL, (212, 116)), ("hold", AMBER, (212, 116)), ("tail", AMBER, (132, 72))]:
        for i, heat in enumerate(HEAT, start=1):
            rgb, a = downsample(*puck(w, h, color, heat), w, h)
            save(rgb, a, OUT / f"{prefix}{i}.png")


def seg_dist(x, y, a, b):
    """Distance from each pixel to the segment a-b."""
    ax, ay = a; bx, by = b
    vx, vy = bx - ax, by - ay
    t = np.clip(((x - ax) * vx + (y - ay) * vy) / (vx * vx + vy * vy), 0, 1)
    return np.hypot(x - ax - t * vx, y - ay - t * vy)


def chevron(x, y, cx, cy, half, drop, width):
    """Distance field of an up-pointing chevron (^) with its tip at (cx, cy)."""
    tip = (cx, cy)
    return np.minimum(seg_dist(x, y, (cx - half, cy + drop), tip), seg_dist(x, y, tip, (cx + half, cy + drop))) - width / 2


def flick():
    """The SYNK flick: a hot-pink puck in the tap/hold style, and a cream double chevron
    in a pink glow that rises over six frames (the game loops them up and down). Same
    768 px frame as the original flick art: the disc is 636 px wide, centred at y=553."""
    size, ss = 768, 2
    disc_w = 636
    w = round(disc_w / .88); h = round(w * 116 / 212)
    top_cy = .43 * h
    for i in range(6):
        k = i / 5
        rgb = np.zeros((size, size, 3)); a = np.zeros((size, size))
        prgb, pa = downsample(*puck(w, h, FLICK, HEAT[min(i, 2)]), w, h)
        x0, y0 = round(size / 2 - w / 2), round(553 - top_cy)
        y1 = min(size, y0 + h)
        crop = y1 - y0
        sub_rgb = rgb[y0:y1, x0:x0 + w]; sub_a = a[y0:y1, x0:x0 + w]
        sub_rgb, sub_a = over(sub_rgb, sub_a, prgb[:crop], pa[:crop])
        rgb[y0:y1, x0:x0 + w] = sub_rgb; a[y0:y1, x0:x0 + w] = sub_a

        # Chevrons, supersampled: the main one rises from the puck's face to well above
        # it; a fainter one trails below it, so the arrow reads as moving up.
        Y, X = np.mgrid[0:size * ss, 0:size * ss].astype(float) / ss
        crgb = np.zeros((size * ss, size * ss, 3)); ca = np.zeros((size * ss, size * ss))
        tip = 430 - 250 * k
        for offset, strength, scale in [(95, .45, .8), (0, 1.0, 1.0)]:
            d = chevron(X, Y, size / 2, tip + offset, 150 * scale, 105 * scale, 34 * scale)
            glow = np.exp(-np.maximum(d, 0) / 26) * .85 * strength
            crgb, ca = over(crgb, ca, np.broadcast_to(FLICK, crgb.shape), glow)
            core = smooth(1.5, -1.5, d) * strength
            body = CREAM + (WHITE - CREAM) * smooth(0, -10, d)[..., None]
            crgb, ca = over(crgb, ca, body, core)
        # A few speed streaks under the chevron.
        for dx, length in [(-70, 90), (0, 130), (70, 90)]:
            sx = size / 2 + dx; sy = tip + 120
            streak = np.exp(-((X - sx) / 4) ** 2) * smooth(sy + length, sy, Y) * (Y > sy) * .5
            crgb, ca = over(crgb, ca, np.broadcast_to(CREAM, crgb.shape), streak)
        crgb, ca = downsample(crgb, ca, size, size)
        rgb, a = over(rgb, a, crgb, ca)
        save(rgb, a, OUT / f"flick{i + 1}.png")


def pause():
    """Pause button: a dark glass tile with one corner cut on the slant, a coral-to-amber
    rim with a soft glow, and two cream bars. Same 80x85 footprint as the SSRG icon (x2)."""
    w, h = 160, 170
    W, H = w * SS, h * SS
    y, x = np.mgrid[0:H, 0:W].astype(float) / SS
    pad, cut, rad = 18, 30, 16
    # Signed distance to a rounded rectangle whose top-right corner is cut off.
    cx, cy = w / 2, h / 2
    hx, hy = w / 2 - pad - rad, h / 2 - pad - rad
    qx, qy = np.abs(x - cx) - hx, np.abs(y - cy) - hy
    box = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - rad
    corner = ((x - (w - pad)) - (y - pad) + cut) / np.sqrt(2)  # > 0 beyond the cut
    d = np.maximum(box, corner)
    rgb = np.zeros((H, W, 3)); a = np.zeros((H, W))
    rim_col = CORAL + (AMBER - CORAL) * smooth(0, w, x + (h - y))[..., None] * .9
    rgb, a = over(rgb, a, rim_col, np.exp(-np.maximum(d, 0) / 7) * .55)
    fill = np.array([.07, .05, .09]) + np.array([.08, .04, .06]) * smooth(h, 0, y)[..., None]
    rgb, a = over(rgb, a, fill, smooth(0.8, -0.8, d) * .92)
    rgb, a = over(rgb, a, rim_col, np.exp(-(d / 2.2) ** 2))
    for bx in (cx - 17, cx + 17):
        bar = np.hypot(np.maximum(np.abs(x - bx) - 4, 0), np.maximum(np.abs(y - cy) - 26, 0)) - 4
        rgb, a = over(rgb, a, np.broadcast_to(CORAL, rgb.shape), np.exp(-np.maximum(bar, 0) / 6) * .45)
        rgb, a = over(rgb, a, np.broadcast_to(CREAM, rgb.shape), smooth(0.8, -0.8, bar))
    save(*downsample(rgb, a, w, h), OUT / "pause.png")


def guide():
    """Lane ring: a cream ellipse with a faint coral glow, the shape of the puck's face."""
    w, h = 212, 116
    W, H = w * SS, h * SS
    y, x = np.mgrid[0:H, 0:W].astype(float) / SS
    r = np.sqrt(((x - w / 2) / (w * .44)) ** 2 + ((y - h * .43) / (h * .32)) ** 2)
    rgb = np.zeros((H, W, 3)); a = np.zeros((H, W))
    rgb, a = over(rgb, a, np.broadcast_to(CORAL, rgb.shape), np.exp(-((r - .95) / .12) ** 2) * .45)
    rgb, a = over(rgb, a, np.broadcast_to(CREAM, rgb.shape), np.exp(-((r - .95) / .025) ** 2))
    rgb, a = over(rgb, a, np.broadcast_to(CREAM, rgb.shape), np.exp(-((r - .55) / .02) ** 2) * .45)
    save(*downsample(rgb, a, w, h), OUT / "guide.png")


def rail_edges():
    """Straight-line fits of the SSRG left rail's outer and road-side edges, in rail
    sprite pixels: x = slope * y + offset (y runs from the far end, 0, to the near end)."""
    src = np.asarray(Image.open(SSRG / "rail_original.png").convert("RGBA")).astype(float) / 255
    bright = (src[..., :3].max(2) > .16) & (src[..., 3] > .04)
    ys = np.arange(src.shape[0])
    left = np.full(len(ys), np.nan); right = np.full(len(ys), np.nan)
    for yy in ys:
        xs = np.where(bright[yy])[0]
        if len(xs) > 3: left[yy], right[yy] = xs.min(), xs.max()
    ok = ~np.isnan(left)
    return src, bright, np.polyfit(ys[ok], left[ok], 1), np.polyfit(ys[ok], right[ok], 1)


def rail():
    """Left rail sprite with the SSRG rail's exact silhouette. The road keeps its black
    pixels (the stage shader draws them as floor); the rail band becomes a coral glow
    edge, a bright cream core and an amber inner edge, with a coral haze outside."""
    src, bright, pl, pr = rail_edges()
    H, W = src.shape[:2]
    rgb = src[..., :3].copy(); a = src[..., 3].copy()
    y, x = np.mgrid[0:H, 0:W].astype(float)
    L = pl[0] * y + pl[1]; R = pr[0] * y + pr[1]
    t = (x - L) / np.maximum(R - L, 1)  # 0 at the outer edge, 1 at the road edge
    band = bright | ((t >= 0) & (t <= 1) & (a > .04))
    col = np.where((t < .3)[..., None], CORAL + (CREAM - CORAL) * smooth(.05, .3, t)[..., None],
                   CREAM + (AMBER - CREAM) * smooth(.45, .95, t)[..., None])
    core = np.exp(-((t - .4) / .1) ** 2)
    col = col + (WHITE - col) * (core * .6)[..., None]
    # Fade the rail out toward the far end like the source does.
    far = smooth(0, 90, y)
    rgb = np.where(band[..., None], col, rgb)
    a = np.where(band, np.maximum(a, .95) * far, a)
    # A soft coral haze outside the rail, off the road.
    outside = np.clip(-t, 0, None) * (R - L)
    haze = np.exp(-outside / 14) * (t < 0) * .55 * far
    rgb, a = over(rgb, a * (~(t < 0)), np.broadcast_to(CORAL, rgb.shape), haze)
    save(rgb, a, OUT / "rail.png")


# Warm graphite greys for the judgment bar, between the near-black road and the cream lines.
GRAPHITE_HI = np.array([.44, .42, .46])
GRAPHITE_LO = np.array([.19, .18, .21])
GRAPHITE_EDGE = np.array([.66, .64, .67])


def judgment():
    """Judgment bar: a warm graphite glass band with a bright cream hit line, trimmed at
    each rail's road-side edge so it never runs over the rails.

    Stage geometry (SSRG canvas units, from ssrg_stage.gd): the bar is a 1156 x 130 plane
    centred at x=-5, z=16; the left rail sprite is 720 x 578 centred at x=-360, z=-203,
    so its pixel (px, py) is world x = px - 720, z = py - 492; the right rail mirrors it."""
    src = np.asarray(Image.open(SSRG / "judgment_Main_black_BG3.png").convert("RGBA")).astype(float) / 255
    H, W = src.shape[:2]
    y, x = np.mgrid[0:H, 0:W].astype(float)
    v = (y + .5) / H
    # Keep the source bar's soft top and bottom, but take its ends from the rails.
    vertical = src[:, W // 2, 3][:, None] * np.ones((1, W))
    _, _, _, pr = rail_edges()
    z = -49.0 + v * 130.0
    inner = 720.0 - (pr[0] * (z + 492.0) + pr[1]) - 2.0  # road half-width, 2 units inside the rail
    world_x = -5.0 - 578.0 + (x + .5) / W * 1156.0
    ends = smooth(0.0, 3.0, inner - np.abs(world_x))
    mask = vertical * ends

    hit = 49.0 / 130.0  # the hit plane, 49 of the band's 130 units down
    base = GRAPHITE_HI + (GRAPHITE_LO - GRAPHITE_HI) * smooth(0, 1, v)[..., None]
    fill_a = .5 + .2 * smooth(1, hit, v)
    line = np.exp(-((v - hit) / .03) ** 2)
    glow = np.exp(-((v - hit) / .14) ** 2) * .5
    rgb = base + (CREAM - base) * np.clip(line + glow * .45, 0, 1)[..., None]
    alpha = np.clip(fill_a + line * .5 + glow * .25, 0, 1)
    # A fine light-grey edge along the top and bottom.
    edge = np.exp(-(v / .04) ** 2) + np.exp(-((1 - v) / .04) ** 2)
    rgb = rgb + (GRAPHITE_EDGE - rgb) * np.clip(edge * .8, 0, 1)[..., None]
    save(rgb, alpha * mask, OUT / "judgment.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    notes(); flick(); guide(); rail(); judgment(); pause()
    print("SYNK mode art written to", OUT)
