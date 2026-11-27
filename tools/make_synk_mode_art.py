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


# One shade of the supplied gold per note type (gold sits at hue 0.11): a small turn of
# the hue, with the colour made richer or paler and brighter. The shapes, shading and
# white highlights stay exactly as supplied.
#               hue turn, richer, brighter
SHADE_TAP = (0.0, 1.0, 1.0)       # gold, as supplied
SHADE_HOLD = (-0.05, 1.5, 1.0)    # copper: holds and slides
SHADE_TRAIL = (-0.045, 1.08, 1.0) # their beams: a little lighter and more orange, to stand off the road
SHADE_FLICK = (0.01, .5, 1.3)     # champagne: pale, bright gold
COPPER = np.array([255, 122, 46]) / 255   # the glow of a hold's end cap and bend diamonds


def recolour(rgb, turn, richer=1.0, brighter=1.0):
    """Turn the hue of an RGB array (0..1) by `turn` of a full circle, and scale its
    saturation and brightness."""
    if turn == 0.0 and richer == 1.0 and brighter == 1.0: return rgb
    mx = rgb.max(-1); mn = rgb.min(-1); span = mx - mn
    safe = np.maximum(span, 1e-6)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.where(mx == r, ((g - b) / safe) % 6, np.where(mx == g, (b - r) / safe + 2, (r - g) / safe + 4)) / 6
    sat = np.clip(np.where(mx > 0, span / np.maximum(mx, 1e-6), 0) * richer, 0, 1)
    hue = (hue + turn) % 1.0
    k = (np.stack([5, 3, 1], -1) + hue[..., None] * 6) % 6
    return np.clip(mx * brighter, 0, 1)[..., None] * (1 - sat[..., None] * np.clip(np.minimum(k, 4 - k), 0, 1))


def notes():
    ring = Image.open(SOURCE / "ring.png").convert("RGBA")
    box = outline(ring)
    for prefix, size, dst, shade in [("tap", (212, 116), (2, 10, 208, 109), SHADE_TAP), ("hold", (212, 116), (2, 10, 208, 109), SHADE_HOLD)]:
        fitted = place(ring, box, dst, size)
        for i, heat in enumerate(HEAT, start=1):
            rgb, a = pulse(fitted, heat)
            save(recolour(rgb, *shade), a, OUT / f"{prefix}{i}.png")


# How far above the ring's top edge (source px) the flick's chevron stack starts to thin out.
FLICK_FADE = 150


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
    # Keep the art above the ring's top edge. Below the lowest chevron the glassy column
    # thins out gradually and is gone before the ring, so the stack dissolves into the
    # ring's glow instead of stopping on a hard shelf.
    rows = np.arange(art.height)[:, None]
    chevrons[..., 3] = a_flick[..., 3] * smooth(ring_box[1] - 4, ring_box[1] - FLICK_FADE, rows) ** 1.5
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
        save(recolour(rgb, *SHADE_FLICK), a, OUT / f"flick{i + 1}.png")


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
    save(np.repeat(recolour(rgb, *SHADE_TRAIL), 4, axis=0), np.repeat(alpha, 4, axis=0), OUT / "trail_profile.png")


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
    """SYNK mode's hit, in the spirit of SSRG's Effect_A: a flat pool of light that swells to
    a white-hot bloom on the third frame, crossed by a lens streak, then sinks back to
    a glint and leaves a few sparks drifting. Same 310 x 186 sprite, eleven frames, 33 fps.
    What makes it SYNK's own: where SSRG swirls discs of light, this opens a six-rayed star
    lying on the road and throws kite-shaped sparks upward, with no ring at all. Drawn on black for additive blending; the game recolours it per note."""
    w, h, ss = 310, 186, 2
    Y, X = np.mgrid[0:h * ss, 0:w * ss].astype(float) / ss
    cx, cy, half, squash = 155.0, 92.0, 150.0, .52
    dx, dy = X - cx, Y - cy
    r = np.hypot(dx, dy / squash) / half                 # 0 at the centre, 1 at the sprite's side edge
    theta = np.arctan2(dy / squash, dx)
    rng = np.random.default_rng(23)
    # How wide and how bright the pool is on each frame: small, swelling, peak on the third, sinking.
    SIZE = [.20, .40, .74, .64, .52, .47, .44, .41, .30, .19, .12]
    HEAT = [.75, 1.1, 1.6, 1.35, 1.1, .88, .66, .46, .36, .18, .07]
    # Sparks: direction, speed, size, spin, lift, and whether it is a kite or a mote.
    sparks = [(rng.uniform(0, 2 * np.pi), rng.uniform(.45, 1.15), rng.uniform(3.0, 6.5), rng.uniform(-4, 4), rng.uniform(.2, 1.0), rng.random() < .55) for _ in range(16)]
    for i in range(11):
        t = i / 10
        size, heat = SIZE[i], HEAT[i]
        ease = 1 - (1 - t) ** 2.2
        fade = (1 - t) ** 1.2
        light = np.zeros_like(r)
        # The pool: a soft flat bloom with a wide faint skirt.
        light += np.exp(-(r / (size * .66)) ** 2) * heat * .42
        light += np.exp(-r / (size * .7)) * heat * .22
        # A soft glassy fill, so the whole pool glows as SSRG's does. No ring: it fades out evenly.
        light += np.exp(-(r / (size * .60)) ** 2) * heat * .30
        # Its white-hot heart.
        light += np.exp(-(r / (size * .30)) ** 2) * heat * .75
        # The star: six soft rays lying on the road, turning slowly, longest at the peak.
        turn = .35 + 1.1 * t
        rays = np.cos(3 * (theta + turn)) ** 2
        fine = np.cos(6 * (theta - turn * .6) + 1.0) ** 2
        light += rays ** 7 * np.exp(-r / (size * .5)) * heat * .38 * smooth(.02, .12, r)
        light += fine ** 14 * np.exp(-r / (size * .34)) * heat * .18 * smooth(.02, .10, r)
        # The lens streak across the road, widest at the peak: a short, fine accent that stays
        # inside the pool rather than a line running out past it.
        light += np.exp(-(dy / (.9 + .8 * heat)) ** 2) * np.exp(-np.abs(dx) / (half * size * .55)) * heat * .30
        # Near the end the heart shrinks to a four-point glint.
        if t >= .7:
            glint = np.exp(-np.abs(dx) / 16) * np.exp(-(dy / 1.3) ** 2) + np.exp(-np.abs(dy) / 9) * np.exp(-(dx / 1.3) ** 2)
            light += glint * (1 - t) ** .8 * 1.3
        # Sparks: kites and motes thrown out and upward, tumbling, outliving the bloom.
        for angle, speed, sz, spin, lift, kite_shape in sparks:
            d = (.10 + speed * .78 * ease) * half * .8
            sx = cx + np.cos(angle) * d
            sy = cy + np.sin(angle) * d * squash - lift * ease * 50
            alive = min(1.0, t * 8) * (1 - t) ** .6
            if kite_shape:
                rot = angle + spin * t
                lx = (X - sx) * np.cos(rot) + (Y - sy) * np.sin(rot)
                ly = -(X - sx) * np.sin(rot) + (Y - sy) * np.cos(rot)
                scale = sz * (1 - .45 * t)
                kite = 1 - (np.abs(lx) / (scale * np.where(lx > 0, 1.7, .7)) + np.abs(ly) / (scale * .45))
                light += np.clip(kite * 3, 0, 1) * alive * 1.2
                light += np.exp(-np.hypot(X - sx, Y - sy) / (scale * 1.1)) * alive * .30
            else:
                light += np.exp(-(np.hypot(X - sx, Y - sy) / (sz * .38)) ** 2) * alive * 1.3
                light += np.exp(-np.hypot(X - sx, Y - sy) / (sz * .9)) * alive * .25
        # Fade to nothing well before the sprite's edges, so its rectangle never shows.
        light *= smooth(1.0, .5, np.maximum(np.abs(dx) / (w * .5), np.abs(dy) / (h * .5)))
        # A soft shoulder instead of a hard clip: only the very heart reaches full brightness,
        # so the game's recolouring gives a glow that melts outward rather than a white blob.
        base = 1 - np.exp(-np.clip(light, 0, 4) * .9)
        rgb = CORAL * base[..., None] + (WHITE - CORAL) * np.clip((base - .72) / .28, 0, 1)[..., None] * base[..., None]
        img = Image.fromarray(np.clip(rgb * 255 + .5, 0, 255).astype(np.uint8), "RGB").resize((w, h), Image.LANCZOS).convert("RGBA")
        for attempt in range(8):
            try:
                img.save(OUT / f"hit_{i + 1:02d}.png"); break
            except OSError:
                if attempt == 7: raise
                time.sleep(.4)


def tail():
    """The end of a hold or slide: not a small ring like the notes but a thin flat bar lying
    across the trail, white-hot along its middle with a copper glow, tapering to a point at
    each side. Six frames on the notes' beat pulse, in the 132 x 72 tail sprite."""
    w, h, ss = 132, 72, 4
    Y, X = np.mgrid[0:h * ss, 0:w * ss].astype(float) / ss
    dx, dy = np.abs(X - 66.0), np.abs(Y - 36.0)
    half = 56.0                                              # half the bar's length
    along = smooth(half, half - 16, dx)                      # tapers to a point at each side
    core = np.exp(-(dy / (1.5 * along + .2)) ** 2) * (dx < half)
    body = np.exp(-(dy / (3.2 * along + .3)) ** 2) * along
    for i, heat in enumerate(HEAT, start=1):
        glow = np.exp(-dy / (5.0 + 3.0 * heat)) * smooth(half + 6, half - 22, dx) * (.30 + .30 * heat)
        white = np.clip(core * (.85 + .15 * heat), 0, 1)
        a = np.clip(body + glow, 0, 1) * smooth(0, 5, np.minimum(36.0 - dy, 66.0 - dx))
        rgb = COPPER + (WHITE - COPPER) * white[..., None]
        save(rgb, a, OUT / f"tail{i}.png", (w, h))


def connector():
    """The marker at each bend of a slide, in the tail cap's 132 x 72 sprite. Not a small
    ring like the notes: a white-hot diamond lying on the road with a bright rim, a copper
    glow and a short tick to either side, so a bend reads at a glance against the beam."""
    w, h, ss = 132, 72, 4
    Y, X = np.mgrid[0:h * ss, 0:w * ss].astype(float) / ss
    dx, dy = np.abs(X - 66.0), np.abs(Y - 36.0)
    d = dx / 40.0 + dy / 21.0                               # 1 on the diamond's edge
    inside = smooth(1.0, .93, d)
    rim = np.exp(-((d - 1.0) / .075) ** 2)
    inner = np.exp(-((d - .62) / .04) ** 2) * .55            # a fine second facet line
    glow = np.exp(-np.clip(d - 1.0, 0, None) / .32) * (d > .95) * .8
    tick = np.exp(-(dy / 1.5) ** 2) * smooth(63, 54, dx) * smooth(40, 44, dx)
    core = np.clip(1 - d, 0, 1) ** .7
    white = np.clip(inside * (.72 + .28 * core) + rim + inner + tick, 0, 1)
    a = np.clip(inside + rim + glow + tick, 0, 1)
    rgb = COPPER + (WHITE - COPPER) * white[..., None]
    save(rgb, a, OUT / "connector.png", (w, h))


def guide():
    """Lane marker on the judgment bar: a glass pad the shape of the puck's face. One fine
    cream rim with a faint amber fill, both brighter along the edge nearest the player, so
    it reads as a lit lip rather than a target of rings."""
    w, h = 212, 116
    W, H = w * SS, h * SS
    y, x = np.mgrid[0:H, 0:W].astype(float) / SS
    # Where a note's base lands: the SSRG guide ring spans x 7..202, y 25..108.
    v = (y - h * (PUCK_TOP + PUCK_SIDE)) / (h * .375)
    r = np.sqrt(((x - w / 2) / (w * .485)) ** 2 + v ** 2)
    near = smooth(-.2, 1.0, v)                               # 0 at the far edge, 1 at the near lip
    rgb = np.zeros((H, W, 3)); a = np.zeros((H, W))
    rgb, a = over(rgb, a, np.broadcast_to(AMBER, rgb.shape), smooth(1.0, .9, r) * (.07 + .13 * near * r))
    rgb, a = over(rgb, a, np.broadcast_to(CORAL, rgb.shape), np.exp(-((r - .95) / .11) ** 2) * (.18 + .4 * near))
    rgb, a = over(rgb, a, np.broadcast_to(CREAM, rgb.shape), np.exp(-((r - .95) / .022) ** 2) * (.45 + .55 * near))
    # Fade to nothing before the sprite's edges, so its rectangle never shows on the bar.
    a = a * smooth(0, 7, np.minimum(np.minimum(x, w - x), np.minimum(y, h - y)))
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


def rail_beam():
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
    return rgb, a


# --- Rail designs (Settings > Visual effects > Highway > Rail design) -------------------
# Every design is drawn on the SSRG rail's silhouette, so the road, the notes and the
# judgment bar meet it in the same place. "beam" above is the first SYNK rail.
KERB_GLASS = np.array([.20, .09, .05])   # the kerb's glass, between its lit steps


class RailSpace:
    """The left rail sprite's coordinates: `t` across the rail (0 outer edge, 1 road edge),
    `px` pixels per unit of t, and steps along it that are evenly spaced on the road, so
    they bunch up toward the far end."""
    def __init__(self, steps):
        self.src, bright, pl, pr = rail_edges()
        H, W = self.src.shape[:2]
        self.road_a = np.where(bright, 0.0, self.src[..., 3])
        y, x = np.mgrid[0:H, 0:W].astype(float)
        L = pl[0] * y + pl[1]; R = pr[0] * y + pr[1]
        self.px = np.maximum(R - L, 1)
        self.slant = (pl[0] + pr[0]) * .5
        self.t = (x - L) / self.px
        self.far = smooth(0, 150, y)
        along = steps * (y / H) ** .55
        self.step = np.floor(along); self.within = along - self.step     # 0 far edge of a step, 1 near edge
        self.span = 1 / np.maximum(np.gradient(along, axis=0), 1e-6)     # a step's length here, in pixels
        # Pixels across the rail from its middle, measured at the near edge of this pixel's
        # step, so a shape drawn inside a step is not sheared by the rail's slant.
        self.across = (self.t - .5) * self.px - self.slant * (1 - self.within) * self.span
        self.rgb = np.zeros((H, W, 3)); self.a = self.road_a.copy()

    def band(self, lo, hi, soft=1.2):
        return smooth(0, soft, (self.t - lo) * self.px) * smooth(0, soft, (hi - self.t) * self.px)

    def line(self, at, sigma):
        return np.exp(-(((self.t - at) * self.px) / sigma) ** 2)

    def halo(self, at, reach):
        return np.exp(-np.abs(self.t - at) * self.px / reach)

    def every(self, n):
        return (np.mod(self.step, n) == n - 1).astype(float)

    def paint(self, colour, amount):
        self.rgb, self.a = over(self.rgb, self.a, np.broadcast_to(colour, self.rgb.shape), np.clip(amount, 0, 1) * self.far)

    def done(self):
        return self.rgb, self.a


def rail_kerb():
    """A strip of dark amber glass cut into steps like the frames of a film strip, each lit
    along its near edge (every fourth brightly), beside a cream hairline on the road's edge."""
    r = RailSpace(26); bar = r.every(4)
    gap = smooth(0, 1.5, r.within * r.span - 1.0) * smooth(0, 1.5, (1 - r.within) * r.span - 1.0)
    lip = np.exp(-(((1 - r.within) * r.span - 2.5) / 2.2) ** 2)
    strip = r.band(.10, .66) * gap
    r.paint(KERB_GLASS, strip * (.50 + .28 * bar))
    r.paint(GLOW_AMBER, strip * r.within ** 2 * (.16 + .30 * bar))
    r.paint(CORE_WARM, strip * lip * (.55 + .45 * bar))
    r.paint(GLOW_AMBER, r.line(.035, 1.3) * .55 + r.halo(.90, 7.0) * .30)
    r.paint(CREAM, r.line(.90, 1.7))
    return r.done()


def rail_hairline():
    """Three fine lines and nothing else: cream on the road's edge, amber beside it, and a
    faint one further out. No glow."""
    r = RailSpace(1)
    r.paint(GLOW_AMBER, r.line(.06, 1.1) * .40)
    r.paint(GLOW_AMBER, r.line(.50, 1.3) * .80)
    r.paint(CREAM, r.line(.90, 1.6))
    return r.done()


def rail_dashes():
    """A road marking: one line of long cream dashes with a little warmth around them."""
    r = RailSpace(20)
    dash = smooth(0, 1.5, r.within * r.span - 0.5) * smooth(0, 1.5, (.62 - r.within) * r.span)
    strip = r.band(.58, .94, 1.5) * dash
    r.paint(GLOW_AMBER, r.halo(.76, 9.0) * dash * .38)
    r.paint(CREAM, strip)
    return r.done()


def rail_beads():
    """A string of lights, like the lamps along a runway; every fourth one is larger."""
    r = RailSpace(34); big = r.every(4)
    radius = r.px * (.16 + .05 * big) + 1.0
    d = np.hypot((r.across + r.slant * .5 * r.span - .22 * r.px) / radius, (r.within - .5) * r.span / (radius * .55))
    r.paint(GLOW_AMBER, np.exp(-d ** 2 / 2.2) * (.42 + .2 * big))
    r.paint(CORE_WARM, np.exp(-d ** 2 / .9))
    r.paint(WHITE, np.exp(-d ** 2 / .22))
    return r.done()


def rail_chevrons():
    """Arrowheads running down the rail toward the player; every fourth one is brighter."""
    r = RailSpace(24); bar = r.every(4)
    reach = r.within * r.span + np.abs(r.across) * .55      # equal along a V whose point is nearest the player
    start = r.span * .70; thick = 1.6 + r.span * .13
    stroke = smooth(0, 1.4, reach - start) * smooth(0, 1.4, start + thick - reach) * smooth(0, 1.5, r.px * .44 - np.abs(r.across))
    soft = np.exp(-np.abs(reach - start - thick * .5) / (thick * 1.6)) * smooth(0, 4.0, r.px * .5 - np.abs(r.across))
    r.paint(GLOW_AMBER, soft * (.10 + .12 * bar))
    r.paint(GLOW_AMBER, stroke * (.85 - .0 * bar))
    r.paint(CREAM, stroke * (.25 + .75 * bar))
    return r.done()


def rail_glass():
    """A wall of light with no hard beam: brightest against the road and fading outward,
    coral at its foot and amber beyond, closed by a fine cream line on the road's edge."""
    r = RailSpace(1)
    out = np.clip(.93 - r.t, 0, None) * r.px                       # pixels outward from the road's edge
    wall = np.exp(-out / (r.px * .75 + 8)) * smooth(0, 2.0, (.95 - r.t) * r.px)
    r.paint(GLOW_AMBER, wall * .34)
    r.paint(CORAL, np.exp(-out / (r.px * .22 + 3)) * smooth(0, 2.0, (.95 - r.t) * r.px) * .55)
    r.paint(CREAM, r.line(.93, 1.4) * .95)
    return r.done()


RAIL_DESIGNS = {"beam": rail_beam, "kerb": rail_kerb, "hairline": rail_hairline, "dashes": rail_dashes,
                "beads": rail_beads, "chevrons": rail_chevrons, "glass": rail_glass}


def rail():
    """One left rail sprite per design: rail.png is the beam, rail_<design>.png the others."""
    for name, draw in RAIL_DESIGNS.items():
        rgb, a = draw()
        save(rgb, a, OUT / ("rail.png" if name == "beam" else "rail_%s.png" % name))


# The judgment bar: a strip of nearly clear glass lit from its top line.
BAR_GLASS = np.array([.05, .06, .09])
BAR_LINE = np.array([.86, .91, 1.0])
BAR_LINE_WARM = np.array([1.0, .74, .40])


# SYNK mode's bar plane runs this deep (SSRG canvas units; SSRG's own is 130), so its
# gradient carries on past the bottom of the screen. Matches SYNK_BAR_DEPTH in ssrg_stage.gd.
JUDGMENT_DEPTH = 260.0
# Ember bar colours, toned down from the rails' amber.
EMBER_EDGE = np.array([.86, .40, .26])
EMBER_MIDDLE = np.array([.88, .66, .34])


def judgment():
    """Judgment bar, "Ember": a quiet band of light that burns coral at the rails and gold
    in the middle, brightest along its top edge and cooling to nothing below, under a slim
    warm-white line. Kept low so notes and hits stay the brightest things on the road.
    It runs on under the rails, which are drawn over it.

    Stage geometry (SSRG canvas units, from ssrg_stage.gd): the bar is a 1156 x 130 plane
    centred at x=-5, z=16 (SYNK mode's is JUDGMENT_DEPTH deep from the same top edge); the left rail sprite is 720 x 578 centred at x=-360, z=-203,
    so its pixel (px, py) is world x = px - 720, z = py - 492; the right rail mirrors it."""
    src = np.asarray(Image.open(SSRG / "judgment_Main_black_BG3.png").convert("RGBA")).astype(float) / 255
    H, W = src.shape[:2]
    H = int(H * JUDGMENT_DEPTH / 130.0)
    y, x = np.mgrid[0:H, 0:W].astype(float)
    # v counts in bar heights: 0 at the top of SSRG's 130-unit bar, 1 at its bottom (about
    # the bottom of the screen), and on past it to the end of SYNK mode's deeper plane.
    v = (y + .5) / H * JUDGMENT_DEPTH / 130.0
    _, _, pl, pr = rail_edges()
    z = -49.0 + v * 130.0
    # The bar runs on under the rails, which are drawn over it, and stops at their outer edge.
    outer_x = pl[0] * (z + 492.0) + pl[1]; road_x = pr[0] * (z + 492.0) + pr[1]
    inner = 720.0 - (outer_x + (road_x - outer_x) * .3)
    world_x = -5.0 - 578.0 + (x + .5) / W * 1156.0
    ends = smooth(0.0, 3.0, inner - np.abs(world_x))
    top = .07                                   # where the top line sits
    below = np.maximum(v - top, 0)
    # The band's colour: muted coral beside the rails, muted gold across the middle.
    middle = np.exp(-(world_x / 360.0) ** 2)[..., None]
    band = EMBER_EDGE + (EMBER_MIDDLE - EMBER_EDGE) * middle
    # A long fall-off that is still alight where it leaves the bottom of the screen, so
    # the gradient never ends in view.
    heat = np.exp(-below / .80) * (v >= top - .01)
    rgb = band * (.4 + .6 * heat[..., None])
    alpha = heat * .44
    # The top line: slim, warm white, a little softer than the rails.
    line = np.exp(-((v - top) / .014) ** 2)
    rgb = rgb + (CORE_WARM - rgb) * np.clip(line, 0, 1)[..., None]
    rgb = rgb + (1 - rgb) * (np.exp(-((v - top) / .006) ** 2) * .6)[..., None]
    alpha = np.maximum(alpha, line * .85)
    alpha = np.maximum(alpha, np.exp(-np.maximum(top - v, 0) / .03) * (v < top) * .3)
    # The plane ends well below the screen; fade there only so its edge is never hard.
    alpha = np.clip(alpha, 0, 1) * smooth(JUDGMENT_DEPTH / 130.0, JUDGMENT_DEPTH / 130.0 - .4, v)
    save(rgb, alpha * ends, OUT / "judgment.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    notes(); flick(); trail(); tail(); connector(); guide(); rail(); judgment(); pause(); hit()
    print("SYNK mode art written to", OUT)
