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
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SSRG = ROOT / "assets/ssrg/imported"
OUT = ROOT / "assets/synk_mode"

CREAM = np.array([255, 241, 220]) / 255
CORAL = np.array([255, 107, 61]) / 255
AMBER = np.array([255, 195, 107]) / 255
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


# Where a note sits in its sprite, as fractions of the sprite, matched to the SSRG note
# sprites (their outline spans x 2..207, y 10..108 of 212 x 116), so notes meet the lane
# rings and the judgment line exactly as the SSRG notes do.
PUCK_TOP = .435    # centre of the top face, from the sprite's top
PUCK_SIDE = .14    # thickness of the side below the face


def downsample(rgb, a, w, h):
    img = Image.fromarray(np.clip(np.dstack([rgb * a[..., None], a]) * 255 + .5, 0, 255).astype(np.uint8), "RGBA")
    small = np.asarray(img.resize((w, h), Image.LANCZOS)).astype(float) / 255
    sa = small[..., 3]
    return small[..., :3] / np.maximum(sa, 1e-6)[..., None], sa


# --- Notes from the supplied artwork (assets/synk_mode/source) -------------------------
# ring.png: the gold ring note. flick.png: the ring with three rising chevrons.
# trail.png: the hold beam. They are fitted to the game's note logic here: the sprite
# sizes and outlines of the SSRG notes they replace, the six-frame beat pulse, the
# six-frame rising flick, and a cross-section for the hold trail.
SOURCE = OUT / "source"


def outline(img):
    """Bounding box (x0, y0, x1, y1) of the solid part of an RGBA image."""
    alpha = np.asarray(img)[..., 3]
    ys, xs = np.where(alpha > 127)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def place(img, src_box, dst_box, size, shift=(0, 0)):
    """`img` scaled so that `src_box` lands on `dst_box`, on a transparent canvas."""
    sx = (dst_box[2] - dst_box[0]) / (src_box[2] - src_box[0])
    sy = (dst_box[3] - dst_box[1]) / (src_box[3] - src_box[1])
    scaled = img.convert("RGBa").resize((max(1, round(img.width * sx)), max(1, round(img.height * sy))), Image.LANCZOS).convert("RGBA")
    ox = round(dst_box[0] - src_box[0] * sx + shift[0]); oy = round(dst_box[1] - src_box[1] * sy + shift[1])
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    # Crop what falls outside the canvas, then lay it down.
    left, top = max(0, -ox), max(0, -oy)
    right, bottom = min(scaled.width, size[0] - ox), min(scaled.height, size[1] - oy)
    if right > left and bottom > top:
        canvas.alpha_composite(scaled.crop((left, top, right, bottom)), (ox + left, oy + top))
    return canvas


def pulse(img, heat):
    """The beat pulse: a soft bloom behind the note and a brighter face, by `heat` (0..1)."""
    arr = np.asarray(img).astype(float) / 255
    bloom = np.asarray(img.filter(ImageFilter.GaussianBlur(max(2, img.width / 45)))).astype(float) / 255
    rgb, a = over(bloom[..., :3], bloom[..., 3] * heat * .85, arr[..., :3], arr[..., 3])
    rgb = rgb + (1 - rgb) * (.28 * heat)
    return rgb, a


# One colour per note type, by turning the gold art's hue (gold sits at hue 0.11): the
# shapes, shading and white highlights stay exactly as supplied.
HUE_TAP = 0.0       # gold, as supplied
HUE_HOLD = 0.42     # cyan: holds, slides, their end caps and beams
HUE_FLICK = -0.17   # hot pink


def recolour(rgb, turn, richer=1.0):
    """Turn the hue of an RGB array (0..1) by `turn` of a full circle."""
    if turn == 0.0: return rgb
    mx = rgb.max(-1); mn = rgb.min(-1); span = mx - mn
    safe = np.maximum(span, 1e-6)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.where(mx == r, ((g - b) / safe) % 6, np.where(mx == g, (b - r) / safe + 2, (r - g) / safe + 4)) / 6
    sat = np.clip(np.where(mx > 0, span / np.maximum(mx, 1e-6), 0) * richer, 0, 1)
    hue = (hue + turn) % 1.0
    k = (np.stack([5, 3, 1], -1) + hue[..., None] * 6) % 6
    return mx[..., None] * (1 - sat[..., None] * np.clip(np.minimum(k, 4 - k), 0, 1))


def notes():
    ring = Image.open(SOURCE / "ring.png").convert("RGBA")
    box = outline(ring)
    for prefix, size, dst, turn in [("tap", (212, 116), (2, 10, 208, 109), HUE_TAP), ("hold", (212, 116), (2, 10, 208, 109), HUE_HOLD), ("tail", (132, 72), (3, 3, 130, 65), HUE_HOLD)]:
        fitted = place(ring, box, dst, size)
        for i, heat in enumerate(HEAT, start=1):
            rgb, a = pulse(fitted, heat)
            save(recolour(rgb, turn), a, OUT / f"{prefix}{i}.png")


def flick():
    """Six flick frames in the original flick's 768 px layout (disc 623 px wide, outline
    centred at y=558.5): the ring, with the supplied chevrons rising out of it frame by
    frame (the game loops the frames up and down)."""
    size = (768, 768)
    ring = Image.open(SOURCE / "ring.png").convert("RGBA")
    art = Image.open(SOURCE / "flick.png").convert("RGBA")
    ring_box = outline(ring)
    disc = (71, 409, 695, 709)
    base = place(ring, ring_box, disc, size)
    # The chevrons are what the flick art has beyond the plain ring.
    a_flick = np.asarray(art).astype(float) / 255
    chevrons = a_flick.copy()
    # Keep the art above the ring's top edge and fade it out just inside the ring, so the
    # chevrons seem to rise out of it without doubling the ring's own rim.
    rows = np.arange(art.height)[:, None]
    chevrons[..., 3] = a_flick[..., 3] * smooth(ring_box[1] + 34, ring_box[1] - 6, rows)
    chevron_img = Image.fromarray(np.clip(chevrons * 255 + .5, 0, 255).astype(np.uint8), "RGBA")
    # Same width scale as the ring; a little less tall so the stack fits the frame.
    sx = (disc[2] - disc[0]) / (ring_box[2] - ring_box[0])
    ring_cx = (ring_box[0] + ring_box[2]) / 2; ring_cy = (ring_box[1] + ring_box[3]) / 2
    src = (0, 0, art.width, art.height)
    w, h = art.width * sx, art.height * 1.2
    for i in range(6):
        k = i / 5
        ox = 383 - ring_cx * sx; oy = 558.5 - ring_cy * 1.2 + (34 - 84 * k)
        rising = place(chevron_img, src, (ox, oy, ox + w, oy + h), size)
        frame = base.copy(); frame.alpha_composite(rising)
        rgb, a = pulse(frame, HEAT[min(i, 2)] * .6)
        save(recolour(rgb, HUE_FLICK, 1.1), a, OUT / f"flick{i + 1}.png")


def trail():
    """The hold trail's cross-section, from the supplied beam: its colours and opacity
    from edge to edge (bright rims, darker glassy middle, faint inner streaks), averaged
    along its length. solid_trail.gdshader stretches it along every hold and slide."""
    beam = np.asarray(Image.open(SOURCE / "trail.png").convert("RGBA")).astype(float) / 255
    rows = []
    for y in range(int(beam.shape[0] * .45), int(beam.shape[0] * .9), 6):
        xs = np.where(beam[y, :, 3] > .05)[0]
        if len(xs) < 50: continue
        strip = beam[y:y + 1, xs.min():xs.max() + 1]
        strip = np.concatenate([strip[..., :3] * strip[..., 3:], strip[..., 3:]], axis=2)   # premultiplied
        img = Image.fromarray(np.clip(strip * 255 + .5, 0, 255).astype(np.uint8), "RGBA").resize((256, 1), Image.LANCZOS)
        rows.append(np.asarray(img).astype(float) / 255)
    mean = np.mean(rows, axis=0)
    mean = (mean + mean[:, ::-1]) / 2                       # even on both sides
    alpha = mean[..., 3]
    rgb = mean[..., :3] / np.maximum(alpha, 1e-6)[..., None]
    alpha = alpha * smooth(0, 6, np.minimum(np.arange(256), 255 - np.arange(256)))[None, :]   # soft outer edge
    save(np.repeat(recolour(rgb, HUE_HOLD), 4, axis=0), np.repeat(alpha, 4, axis=0), OUT / "trail_profile.png")


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
    """SYNK mode's hit: the note's ring releasing. Eleven frames on black for additive
    blending, the same 310 x 186 sprite and 33 fps timing as SSRG's Effect_A.
    The ring snaps outward along the road as a crisp double rim; the glass inside it
    flashes once; a narrow pillar of light shoots up from the centre and thins away; and
    shards of glass scatter and tumble upward. There is no large bloom, so the road stays
    readable. The game recolours it per note from its brightness."""
    w, h, ss = 310, 186, 2
    Y, X = np.mgrid[0:h * ss, 0:w * ss].astype(float) / ss
    cx, cy, half, squash = 155.0, 96.0, 150.0, .52       # the ring lies flat on the road, centred on the hit
    dx, dy = X - cx, Y - cy
    r = np.hypot(dx, dy / squash) / half                 # 0 at the centre, 1 at the sprite's side edge
    rng = np.random.default_rng(11)
    # Shards: direction, speed, size, spin, rise.
    shards = [(rng.uniform(0, 2 * np.pi), rng.uniform(.5, 1.05), rng.uniform(12, 22), rng.uniform(-3, 3), rng.uniform(.3, 1.0)) for _ in range(11)]
    for i in range(11):
        t = i / 10
        ease = 1 - (1 - t) ** 2.4                        # fast out, slowing
        fade = (1 - t) ** 1.3
        snap = np.exp(-(t / .16) ** 2)                   # the first instant
        light = np.zeros_like(r)
        # The ring: a bold outer rim and a fine inner one, like the note, thinning as it runs.
        ring_r = .28 + .27 * ease                        # ends a little over 1.5x the note's width
        width = .030 * (1 - .65 * t) + .006
        light += np.exp(-((r - ring_r) / width) ** 2) * (.55 + .75 * fade) * min(1.0, 1.5 - t)
        light += np.exp(-((r - ring_r * .86) / (width * .45)) ** 2) * fade * .7
        light += np.exp(-np.abs(r - ring_r) / .05) * fade * .22          # a soft glow hugging the rim
        # A second, fainter ring leaves a beat later.
        if t > .2:
            late = (t - .2) / .8
            light += np.exp(-((r - (.20 + .24 * (1 - (1 - late) ** 2))) / .012) ** 2) * (1 - late) ** 1.5 * .45
        # The glass inside the ring flashes once and clears.
        light += smooth(ring_r, ring_r * .5, r) * snap * .5
        # A small hot core, only at the first instant.
        light += np.exp(-(r / .11) ** 2) * snap * 1.6
        # The pillar: a narrow column rising from the centre, thinning and fading.
        rise = np.clip((cy - Y) / (cy - 4), 0, 1)        # 0 at the ring's centre, 1 at the sprite's top
        pillar_w = 2.0 + 9.0 * (1 - t) ** 2
        reach = min(1.0, .35 + 2.6 * t)                  # how high it has shot
        column = np.exp(-(dx / pillar_w) ** 2) * (Y <= cy + 2) * smooth(reach, reach * .55, rise) * (1 - t) ** 1.6
        light += column * 1.25
        light += np.exp(-np.abs(dx) / (pillar_w * 3.5)) * (Y <= cy + 2) * smooth(reach, reach * .4, rise) * (1 - t) ** 2 * .22
        # A fine streak along the road through the centre.
        light += np.exp(-(dy / (1.2 + 2.0 * snap)) ** 2) * np.exp(-np.abs(dx) / (30 + 45 * ease)) * (1 - t) ** 2.2 * .9
        # Shards of glass: kites lit along one edge, flying out, rising and tumbling.
        for angle, speed, size, spin, lift in shards:
            d = (.20 + speed * .55 * ease) * half * .8
            sx = cx + np.cos(angle) * d
            sy = cy + np.sin(angle) * d * squash - lift * ease * 46
            turn = angle + spin * t
            lx = (X - sx) * np.cos(turn) + (Y - sy) * np.sin(turn)
            ly = -(X - sx) * np.sin(turn) + (Y - sy) * np.cos(turn)
            scale = size * (1 - .5 * t)
            kite = 1 - (np.abs(lx) / (scale * np.where(lx > 0, 1.5, .7)) + np.abs(ly) / (scale * .42))
            inside = kite > 0
            facet = np.clip(.18 + .5 * (ly / (scale * .42) + 1) / 2, 0, 1)
            rim = smooth(.16, 0, kite) * (ly > 0)
            light += inside * (facet * .95 + rim * 1.5) * (1 - t) ** .9 * min(1.0, t * 10)
        # Keep everything inside the sprite.
        light *= smooth(0, 6, np.minimum(np.minimum(X, w - X), np.minimum(Y, h - Y)))
        light = np.clip(light, 0, 2)
        base = np.clip(light, 0, 1)
        rgb = CORAL * base[..., None] + (WHITE - CORAL) * np.clip(light - .6, 0, 1)[..., None]
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


# The judgment bar: a strip of nearly clear glass lit from its top line.
BAR_GLASS = np.array([.05, .06, .09])
BAR_LINE = np.array([.86, .91, 1.0])
BAR_LINE_WARM = np.array([1.0, .74, .40])


def judgment():
    """Judgment bar: a crisp bright line along the top, warming to amber at the rails,
    with its light spilling down into nearly clear glass that fades away, and a faint second
    line at the bottom. It runs on under the rails, which are drawn over it.

    Stage geometry (SSRG canvas units, from ssrg_stage.gd): the bar is a 1156 x 130 plane
    centred at x=-5, z=16; the left rail sprite is 720 x 578 centred at x=-360, z=-203,
    so its pixel (px, py) is world x = px - 720, z = py - 492; the right rail mirrors it."""
    src = np.asarray(Image.open(SSRG / "judgment_Main_black_BG3.png").convert("RGBA")).astype(float) / 255
    H, W = src.shape[:2]
    y, x = np.mgrid[0:H, 0:W].astype(float)
    v = (y + .5) / H
    _, _, pl, pr = rail_edges()
    z = -49.0 + v * 130.0
    # The bar runs on under the rails, which are drawn over it, and stops at their outer edge.
    outer_x = pl[0] * (z + 492.0) + pl[1]; road_x = pr[0] * (z + 492.0) + pr[1]
    inner = 720.0 - (outer_x + (road_x - outer_x) * .3)
    world_x = -5.0 - 578.0 + (x + .5) / W * 1156.0
    ends = smooth(0.0, 3.0, inner - np.abs(world_x))

    # How close each pixel is to a rail: 0 across the middle of the bar, 1 at its ends.
    to_rail = smooth(190.0, 0.0, inner - np.abs(world_x))[..., None]
    top = .07                                   # where the top line sits
    below = np.maximum(v - top, 0)
    # Glass: nearly clear, with a cool dark tint that thins out toward the bottom, so the
    # bar reads as a strip of light on the road rather than a grey block.
    rgb = np.broadcast_to(BAR_GLASS, (H, W, 3)).copy()
    alpha = (.46 * np.exp(-below / .5) + .05) * (v > top - .012)
    # Light spilling down from the top line into the glass: cool in the middle of the bar,
    # warming to amber where it meets the rails.
    line_colour = BAR_LINE + (BAR_LINE_WARM - BAR_LINE) * to_rail
    spill = np.exp(-below / .15) * (v >= top)
    rgb = rgb + (line_colour - rgb) * (spill * .5)[..., None]
    alpha = alpha + spill * .2
    # The top line: crisp and bright.
    line = np.exp(-((v - top) / .017) ** 2)
    rgb = rgb + (line_colour - rgb) * np.clip(line * 1.2, 0, 1)[..., None]
    rgb = rgb + (1 - rgb) * (np.exp(-((v - top) / .007) ** 2) * .8)[..., None]
    alpha = np.maximum(alpha, line)
    # A faint second line closes the strip at the bottom.
    low = np.exp(-((v - .925) / .011) ** 2)
    rgb = rgb + (line_colour * .9 - rgb) * (low * .8)[..., None]
    alpha = np.maximum(alpha, low * .38)
    alpha = np.clip(alpha, 0, 1) * smooth(1.0, .96, v)
    mask = ends
    save(rgb, alpha * mask, OUT / "judgment.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    notes(); flick(); trail(); guide(); rail(); judgment(); pause(); hit()
    print("SYNK mode art written to", OUT)
