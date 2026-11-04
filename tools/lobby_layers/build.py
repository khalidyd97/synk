"""Cut the lobby art into depth layers and render the generated stage sprites.

Run from the project root: python tools/lobby_layers/build.py
Outputs go to assets/lobby/layers/. Re-running is deterministic (fixed seeds).
"""
from pathlib import Path
import math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = Path(__file__).resolve().parents[2]
UI = ROOT / 'assets/lobby/ui'
OUT = ROOT / 'assets/lobby/layers'


def rgba(a):
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGBA')


def feathered(size, draw_fn, blur):
    m = Image.new('L', size, 0)
    draw_fn(ImageDraw.Draw(m))
    return m.filter(ImageFilter.GaussianBlur(blur)) if blur else m


def with_alpha(img, mask):
    out = img.convert('RGBA')
    out.putalpha(ImageChops.multiply(out.getchannel('A'), mask))
    return out


# --- Stage: one photo split into depth planes ---------------------------------
def stage():
    src = Image.open(UI / 'concert_stage_clean.png').convert('RGB')
    w, h = src.size
    # Back wall: the revealed edges behind moving planes are softened like depth of field.
    soft = src.filter(ImageFilter.GaussianBlur(14))
    prop_mask = feathered((w, h), lambda d: (
        d.rounded_rectangle((-40, int(h*.38), int(w*.29), int(h*.73)), 60, fill=255),
        d.rounded_rectangle((int(w*.80), int(h*.40), w+40, int(h*.73)), 60, fill=255)), 26)
    floor_mask = feathered((w, h), lambda d: d.rectangle((-40, int(h*.70), w+40, h+40), fill=255), 22)
    back = Image.composite(soft, src, ImageChops.lighter(prop_mask, floor_mask).point(lambda v: int(v*.85)))
    back.save(OUT / 'stage_back.png')
    with_alpha(src, prop_mask).save(OUT / 'stage_props.png')
    with_alpha(src, floor_mask).save(OUT / 'stage_floor.png')


# --- Generated light sprites ---------------------------------------------------
def beam():
    w, h = 256, 1024
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    t = y / h
    half = 6 + t * (w * .5 - 6)
    edge = np.clip(1 - np.abs(x - w/2) / half, 0, 1) ** 1.6
    rng = np.random.default_rng(7)
    streaks = np.interp(x[0], np.linspace(0, w, 40), rng.uniform(.65, 1, 40))[None, :]
    fade = (1 - t) ** 1.25 * np.clip(t * 18, 0, 1)
    a = edge * fade * streaks * 255
    img = np.dstack([np.full_like(a, 255), np.full_like(a, 214), np.full_like(a, 160), a])
    rgba(img).filter(ImageFilter.GaussianBlur(3)).save(OUT / 'beam.png')


def radial(name, size, power, core=0.0):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    r = np.hypot(x - size/2, y - size/2) / (size/2)
    a = np.clip(1 - r, 0, 1) ** power
    if core: a = np.maximum(a, np.clip(1 - r / core, 0, 1) ** .6)
    rgba(np.dstack([np.full_like(a, 255)] * 3 + [a * 255])).save(OUT / name)


def streak():
    w, h = 512, 48
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    a = np.clip(1 - np.abs(x - w/2) / (w/2), 0, 1) ** 2.2 * np.exp(-((y - h/2) / (h*.12)) ** 2)
    rgba(np.dstack([np.full_like(a, 255)] * 3 + [a * 255])).save(OUT / 'flare_streak.png')


def bokeh():
    s = 128
    y, x = np.mgrid[0:s, 0:s].astype(np.float32)
    r = np.hypot(x - s/2, y - s/2) / (s/2 - 4)
    disc = np.clip((1 - r) * 10, 0, 1)
    rim = np.exp(-((r - .9) / .08) ** 2) * .5
    a = np.clip(disc * .55 + rim, 0, 1)
    rgba(np.dstack([np.full_like(a, 255)] * 3 + [a * 255])).filter(ImageFilter.GaussianBlur(1.5)).save(OUT / 'bokeh.png')


def haze():
    # Tileable fBm built from wrapped low-res noise, so it can scroll forever.
    # Tileable by construction: 1/f noise shaped in the frequency domain wraps at both edges.
    rng = np.random.default_rng(11)
    w, h = 1024, 512
    fy = np.fft.fftfreq(h)[:, None] * h / 2; fx = np.fft.fftfreq(w)[None, :] * w / 4
    f = np.hypot(fx, fy); f[0, 0] = 1
    spectrum = np.fft.fft2(rng.standard_normal((h, w))) / f ** 2.1 * np.exp(-f / 40)
    acc = np.real(np.fft.ifft2(spectrum))
    acc = np.clip((acc - acc.min()) / (acc.max() - acc.min()), 0, 1) ** 2.2
    rgba(np.dstack([np.full_like(acc, 255)] * 3 + [acc * 255])).save(OUT / 'haze.png')


def crowd():
    # Backlit audience: soft dark heads and shoulders, a few raised hands and phones.
    w, h = 3600, 420
    rng = random.Random(23)
    body = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(body)
    phones = []
    x = -40
    while x < w + 40:
        s = rng.uniform(.8, 1.25)
        top = h - rng.uniform(190, 250) * s
        hx = x + rng.uniform(-8, 8)
        d.ellipse((hx - 34*s, top, hx + 34*s, top + 84*s), fill=255)
        d.rounded_rectangle((hx - 92*s, top + 70*s, hx + 92*s, h + 60), int(70*s), fill=255)
        if rng.random() < .11:
            # Raised arm: shoulder -> elbow -> hand, tapered, with a fist or open hand.
            side = rng.choice((-1, 1))
            sx, sy = hx + side * 66*s, top + 104*s
            ex, ey = sx + side * rng.uniform(30, 50)*s, sy - rng.uniform(52, 70)*s
            tx, ty = ex + side * rng.uniform(-10, 14)*s, ey - rng.uniform(50, 66)*s
            for (ax, ay, bx, by, wa, wb) in ((sx, sy, ex, ey, 34, 26), (ex, ey, tx, ty, 26, 20)):
                nx, ny = -(by - ay), bx - ax
                n = max(math.hypot(nx, ny), 1); nx, ny = nx / n, ny / n
                d.polygon([(ax + nx*wa*s/2, ay + ny*wa*s/2), (bx + nx*wb*s/2, by + ny*wb*s/2),
                           (bx - nx*wb*s/2, by - ny*wb*s/2), (ax - nx*wa*s/2, ay - ny*wa*s/2)], fill=255)
                d.ellipse((bx - wb*s/2, by - wb*s/2, bx + wb*s/2, by + wb*s/2), fill=255)
            d.ellipse((tx - 19*s, ty - 26*s, tx + 19*s, ty + 12*s), fill=255)
            if rng.random() < .55: phones.append((tx, ty - 34*s, s))
        x += rng.uniform(70, 120)
    body = body.filter(ImageFilter.GaussianBlur(3))
    # Warm rim light from the stage catches the top edges.
    rim = ImageChops.subtract(body, body.transform(body.size, Image.AFFINE, (1, 0, 0, 0, 1, 7)).filter(ImageFilter.GaussianBlur(4)))
    a = np.asarray(body, np.float32)
    r = np.asarray(rim, np.float32) / 255
    r[-12:] = 0
    rgb = np.stack([8 + r * 200, 7 + r * 118, 9 + r * 52], -1)
    rgba(np.dstack([rgb, a])).save(OUT / 'crowd.png')
    (OUT / 'crowd_phones.txt').write_text('\n'.join(f'{px/w:.4f},{py/h:.4f},{ps:.3f}' for px, py, ps in phones) + '\n')


# --- Cards: split into plate, moving art and knobs ----------------------------
def fill_from_strip(img, mask, strip_x0, strip_x1):
    """Repaint masked pixels with a mirrored tiling of a clean vertical plate strip."""
    a = np.asarray(img).copy()
    strip = a[:, strip_x0:strip_x1]
    tile = np.concatenate([strip, strip[:, ::-1]], 1)
    reps = math.ceil(a.shape[1] / tile.shape[1]) + 1
    wide = np.concatenate([tile] * reps, 1)[:, :a.shape[1]]
    m = np.asarray(mask, np.float32)[..., None] / 255
    a[..., :3] = a[..., :3] * (1 - m) + wide[..., :3] * m
    return Image.fromarray(a.astype(np.uint8), 'RGBA')


def play_card():
    card = Image.open(UI / 'play_card_sprite.png').convert('RGBA')
    size = card.size
    cx, cy, r = 665, 428, 213
    # The front sleeve's right edge leans from (710,193) to (747,655); the record peeks out past it.
    outline = [(190, 150), (768, 150), (768, 238), (714, 238), (747, 655), (747, 705), (190, 705)]
    sleeves = feathered(size, lambda d: d.polygon(outline, fill=255), .8)
    # Plate without the visible vinyl or its drop shadow, so a separate record can spin and slide out.
    disc = feathered(size, lambda d: d.ellipse((cx - r - 26, cy - r - 26, cx + r + 30, cy + r + 30), fill=255), 6)
    plate = fill_from_strip(card, ImageChops.multiply(disc, ImageChops.invert(sleeves)), 890, 970)
    plate.save(OUT / 'play_plate.png')
    with_alpha(card, sleeves).crop((180, 140, 780, 715)).save(OUT / 'play_sleeves.png')
    # Record: grooves, sheen bands and a label that matches the card's teal.
    s = 2 * r + 8
    y, x = np.mgrid[0:s, 0:s].astype(np.float32)
    rr = np.hypot(x - s/2, y - s/2) / r
    ang = np.arctan2(y - s/2, x - s/2)
    grooves = .5 + .5 * np.sin(rr * 260)
    base = 10 + grooves * 7 * (rr > .36)
    sheen = (np.cos(2 * ang) ** 8) * 38 * (rr > .36) * (rr < .98)
    lum = base + sheen
    rgb = np.stack([lum, lum, lum * 1.04], -1)
    label = rr < .33
    rgb[label] = [70, 128, 150]
    ring = (rr > .30) & (rr < .33)
    rgb[ring] = [40, 76, 92]
    rgb[rr < .035] = [6, 6, 8]
    a = np.clip((1 - rr) * r, 0, 1) * 255
    rgba(np.dstack([rgb, a])).save(OUT / 'play_vinyl.png')


def create_card():
    card = Image.open(UI / 'create_card_sprite.png').convert('RGBA')
    a = np.asarray(card).copy()
    knobs = [(335, 397, 37), (433, 472, 35), (528, 430, 35)]
    for i, (kx, ky, kr) in enumerate(knobs):
        pad = kr + 6
        crop = card.crop((kx - pad, ky - pad, kx + pad, ky + pad))
        m = feathered(crop.size, lambda d: d.ellipse((6, 6, 2 * pad - 6, 2 * pad - 6), fill=255), 1.2)
        with_alpha(crop, m).save(OUT / f'create_knob_{i}.png')
        # Rebuild the slot under the knob (and its shadow) by blending the clean rows above and below,
        # which also carries the slot's colour gradient across the gap.
        y0, y1 = ky - kr - 12, ky + kr + 18
        x0, x1 = kx - kr - 16, kx + kr + 20
        top = a[y0 - 1, x0:x1].astype(np.float32); bottom = a[y1, x0:x1].astype(np.float32)
        t = np.linspace(0, 1, y1 - y0)[:, None, None]
        patch = top[None] * (1 - t) + bottom[None] * t
        # Matching grain hides the streaks a pure blend leaves on the textured panel.
        patch[..., :3] += np.random.default_rng(i).normal(0, 4, patch.shape[:2])[..., None]
        edge = np.minimum(np.arange(x1 - x0), np.arange(x1 - x0)[::-1]).astype(np.float32)
        m = np.clip(edge / 8, 0, 1)[None, :, None]
        a[y0:y1, x0:x1] = np.clip(a[y0:y1, x0:x1] * (1 - m) + patch * m, 0, 255).astype(np.uint8)
    Image.fromarray(a, 'RGBA').save(OUT / 'create_plate.png')
    (OUT / 'create_knobs.txt').write_text('\n'.join(f'{kx},{ky},{kr}' for kx, ky, kr in knobs) + '\n')


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    stage(); beam(); haze(); bokeh(); streak(); crowd()
    radial('glow.png', 256, 2.4, core=.12)
    radial('mote.png', 64, 1.8)
    play_card(); create_card()
    print('lobby layers written to', OUT)
