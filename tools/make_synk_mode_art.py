"""Draw the SYNK mode artwork: notes, lane rings, rails and judgment bar.

SYNK mode is a skin of the SSRG stage, so every image keeps the size and layout
of the SSRG sprite it replaces (and the rail and judgment bar keep their exact
silhouettes); only the look is new. The palette follows the SYNK logo: warm
coral and amber on near-black, with cream highlights.

    python tools/make_synk_mode_art.py
"""
import time
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
    # Another program (antivirus, a sync tool) can briefly lock a file it has just seen
    # change; try again a few times before giving up.
    for attempt in range(8):
        try:
            img.save(path); return
        except OSError:
            if attempt == 7: raise
            time.sleep(.4)


# Puck geometry as fractions of its sprite, matched to the SSRG note sprites it replaces
# (their outline spans x 2..207, y 10..108 of 212 x 116), so notes meet the lane rings and
# the judgment line exactly as the SSRG notes do.
PUCK_RX = .47      # half-width of the face
PUCK_TOP = .435    # centre of the top face, from the sprite's top
PUCK_RY = .34      # half-height of the face
PUCK_SIDE = .14    # thickness of the side below the face


def puck(w, h, color, heat):
    """A glass puck seen from the player's angle: top face, a coloured side, a halo,
    a cream rim, a white-hot core and a small four-point sparkle (the SYNK mark)."""
    W, H = w * SS, h * SS
    y, x = np.mgrid[0:H, 0:W].astype(float) / SS
    cx, rx = w / 2, w * PUCK_RX
    top_cy, ry = h * PUCK_TOP, h * PUCK_RY
    side = h * PUCK_SIDE  # thickness of the side below the top face
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
    # The original flick's disc is 623 px wide, with its outline centred at y=558.5.
    w = round(623 / (2 * PUCK_RX)); h = round(w * 116 / 212)
    top_cy = (PUCK_TOP + PUCK_SIDE / 2) * h
    for i in range(6):
        k = i / 5
        rgb = np.zeros((size, size, 3)); a = np.zeros((size, size))
        prgb, pa = downsample(*puck(w, h, FLICK, HEAT[min(i, 2)]), w, h)
        x0, y0 = round(size / 2 - w / 2), round(558.5 - top_cy)
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


def hit():
    """SYNK mode's hit flash: 11 frames on black for additive blending, the same 310 x 186
    sprite and 33 fps rhythm as SSRG's Effect_A (bloom to a white-hot peak by the third
    frame, then a spreading ring and drifting shards). Its own character: the bloom is
    SYNK's four-point sparkle, a cross of light over a flattened shock ring, and the
    shards are small sparkles. The game recolours it per note from its brightness."""
    w, h, ss = 310, 186, 2
    Y, X = np.mgrid[0:h * ss, 0:w * ss].astype(float) / ss
    cx, cy, half, squash = 155.0, 92.0, 150.0, .6
    dx, dy = X - cx, Y - cy
    r = np.hypot(dx, dy / squash) / half          # 0 at the centre, 1 at the sprite's edge
    rng = np.random.default_rng(7)
    shards = [(rng.uniform(0, 2 * np.pi), rng.uniform(.45, 1.15), rng.uniform(4.5, 9.5), rng.uniform(0, .5)) for _ in range(18)]
    for i in range(11):
        t = i / 10
        peak = np.exp(-((t - .24) / .24) ** 2)     # the bloom: strongest at frame 3
        fade = (1 - t) ** 1.1
        light = np.zeros_like(r)
        # White-hot core, flattened like the floor it sits on.
        core_r = .16 + .40 * peak
        light += np.exp(-(r / core_r) ** 2) * max(1.9 * peak, 1.15 * (1 - t) ** 1.3)
        light += np.exp(-r / (.2 + .35 * peak)) * (.7 * peak + .25 * fade)
        # A glowing disc of light on the floor, spreading with the ring and lasting like SSRG's.
        disc_r = .34 + .5 * (1 - (1 - t) ** 2)
        light += smooth(disc_r, disc_r * .55, r) * (.7 * peak + .45 * (1 - t) ** 1.2)
        # Shock ring spreading out, and a fainter one following it.
        ring_r = .14 + .8 * (1 - (1 - t) ** 2.2)
        light += np.exp(-((r - ring_r) / (.02 + .06 * (1 - t))) ** 2) * fade * 1.15
        if t > .1:
            light += np.exp(-((r - ring_r * .62) / .03) ** 2) * (1 - t) ** 1.4 * .7
        # The four-point sparkle: a long horizontal flare and a shorter rising one.
        light += np.exp(-(dy / (1.6 + 3.2 * peak)) ** 2) * np.exp(-np.abs(dx) / (30 + 115 * peak)) * peak * 1.25
        light += np.exp(-(dx / (1.6 + 2.6 * peak)) ** 2) * np.exp(-np.abs(dy) / (10 + 62 * peak)) * peak * 1.0
        # Sparkle shards thrown outward, drifting up a little as they fade.
        for angle, speed, size, lift in shards:
            d = (.1 + speed * (1 - (1 - t) ** 1.8)) * half * .92
            sx = cx + np.cos(angle) * d
            sy = cy + np.sin(angle) * d * squash - lift * d * .3
            scale = size * (1 - .55 * t) * (.6 + .6 * peak)
            ax, ay = np.abs(X - sx) / scale, np.abs(Y - sy) / scale
            star = np.clip(1 - (np.sqrt(ax / 2.2) + np.sqrt(ay / 2.2)), 0, 1)
            light += (star ** 1.3 * 2.0 + np.exp(-(ax ** 2 + ay ** 2) * 2) * 1.0) * (1 - t) ** .8 * min(1.0, t * 12)
        # Keep everything inside the sprite.
        light *= smooth(1.0, .9, r) * smooth(0, 8, np.minimum(Y, h - Y))
        light = np.clip(light, 0, 2)
        base = np.clip(light, 0, 1)
        rgb = CORAL * base[..., None] + (WHITE - CORAL) * np.clip(light - .55, 0, 1)[..., None]
        img = Image.fromarray(np.clip(rgb * 255 + .5, 0, 255).astype(np.uint8), "RGB").resize((w, h), Image.LANCZOS).convert("RGBA")
        for attempt in range(8):
            try:
                img.save(OUT / f"hit_{i + 1:02d}.png"); break
            except OSError:
                if attempt == 7: raise
                time.sleep(.4)


def guide():
    """Lane ring: a cream ellipse with a faint coral glow, the shape of the puck's face."""
    w, h = 212, 116
    W, H = w * SS, h * SS
    y, x = np.mgrid[0:H, 0:W].astype(float) / SS
    # Where a note's base lands: the SSRG guide ring spans x 7..202, y 25..108.
    r = np.sqrt(((x - w / 2) / (w * .485)) ** 2 + ((y - h * (PUCK_TOP + PUCK_SIDE)) / (h * .375)) ** 2)
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


# The design guide's amber: a white-hot edge core in an amber glow.
GLOW_AMBER = np.array([1.0, .55, .18])
CORE_WARM = np.array([1.0, .86, .62])


def rail():
    """Left rail sprite, after the design guide's layers, on the SSRG rail's silhouette.
    Edge core: a slim tapered streak, white-hot in the middle with amber edges.
    Outer glow: soft amber light spilling off both sides of it.
    The road keeps its black pixels (the stage shader draws them as floor)."""
    src, bright, pl, pr = rail_edges()
    H, W = src.shape[:2]
    road_a = np.where(bright, 0.0, src[..., 3])        # the road's own coverage
    y, x = np.mgrid[0:H, 0:W].astype(float)
    L = pl[0] * y + pl[1]; R = pr[0] * y + pr[1]
    width = np.maximum(R - L, 1)
    t = (x - L) / width                                 # 0 at the outer edge, 1 at the road edge
    off = (t - .5) * width                              # pixels from the rail's centre line
    far = smooth(0, 110, y)                             # the rail thins and fades into the distance
    core = np.exp(-(off / (width * .13 + .6)) ** 2)     # white-hot middle
    body = np.exp(-(off / (width * .30 + 1.0)) ** 2)    # amber streak around it
    glow = np.exp(-np.abs(off) / (width * .55 + 10)) * .5   # outer glow, both sides
    light = np.clip(body + glow, 0, 1) * far
    col = GLOW_AMBER + (CORE_WARM - GLOW_AMBER) * np.clip(body * 1.2, 0, 1)[..., None]
    col = col + (WHITE - col) * np.clip(core * 1.1, 0, 1)[..., None]
    # Light over the black road (or over nothing, outside it).
    rgb = np.zeros((H, W, 3)); a = road_a.copy()
    rgb, a = over(rgb, a, col, light)
    save(rgb, a, OUT / "rail.png")


# The base bar: dark glass, lighter at its top, under a bright hairline.
BAR_HI = np.array([.26, .26, .30])
BAR_LO = np.array([.05, .05, .07])
BAR_LINE = np.array([.92, .93, 1.0])


def judgment():
    """Judgment bar, the design guide's base bar: dark glass that is lighter toward its
    top, under a thin bright line along the top edge, trimmed at each rail's road-side edge
    so it never runs over the rails.

    Stage geometry (SSRG canvas units, from ssrg_stage.gd): the bar is a 1156 x 130 plane
    centred at x=-5, z=16; the left rail sprite is 720 x 578 centred at x=-360, z=-203,
    so its pixel (px, py) is world x = px - 720, z = py - 492; the right rail mirrors it."""
    src = np.asarray(Image.open(SSRG / "judgment_Main_black_BG3.png").convert("RGBA")).astype(float) / 255
    H, W = src.shape[:2]
    y, x = np.mgrid[0:H, 0:W].astype(float)
    v = (y + .5) / H
    # Keep the source bar's soft top and bottom, but take its ends from the rails.
    vertical = src[:, W // 2, 3][:, None] * np.ones((1, W))
    _, _, pl, pr = rail_edges()
    z = -49.0 + v * 130.0
    # The bar runs up to the rail's bright core, which sits mid-way across the rail band.
    outer_x = pl[0] * (z + 492.0) + pl[1]; road_x = pr[0] * (z + 492.0) + pr[1]
    inner = 720.0 - (outer_x + (road_x - outer_x) * .66)
    world_x = -5.0 - 578.0 + (x + .5) / W * 1156.0
    ends = smooth(0.0, 3.0, inner - np.abs(world_x))
    mask = vertical * ends

    rgb = BAR_HI + (BAR_LO - BAR_HI) * smooth(0, .8, v)[..., None]
    alpha = .78 - .2 * smooth(.3, 1, v)
    # The hairline along the top edge, with a soft bloom under it.
    line = np.exp(-((v - .06) / .022) ** 2)
    bloom = np.exp(-np.maximum(v - .06, 0) / .12) * (v > .06) * .35
    rgb = rgb + (BAR_LINE - rgb) * np.clip(line + bloom, 0, 1)[..., None]
    alpha = np.clip(alpha + line * .4, 0, 1)
    # The source bar fades in over its first rows; keep the line crisp there.
    vertical = np.maximum(vertical, line * (v > .03))
    mask = vertical * ends
    save(rgb, alpha * mask, OUT / "judgment.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    notes(); flick(); guide(); rail(); judgment(); pause(); hit()
    print("SYNK mode art written to", OUT)
