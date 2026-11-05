"""'Halo' SSRG note set: a glowing neon tube ring over frosted glass.
Frame 1 = beat flash, 2..5 decay, 6 = resting state (held most of the beat).
Usage: python tools/gen_halo_notes.py assets/ssrg/halo_ui"""
import sys, os
import numpy as np
from PIL import Image, ImageFilter

SS = 4
W, H = 212, 116
PULSE = [1.0, 0.70, 0.46, 0.28, 0.13, 0.04]
ELEV = np.deg2rad(25.0)

THEMES = {
    "tap": dict(tube=(1.00, 0.55, 0.12), hot=(1.00, 0.93, 0.70), deep=(0.75, 0.16, 0.04),
                glass=(0.05, 0.05, 0.11), glow=(1.00, 0.45, 0.10)),
    "hold": dict(tube=(0.62, 0.36, 1.00), hot=(0.93, 0.86, 1.00), deep=(0.28, 0.08, 0.70),
                 glass=(0.04, 0.03, 0.12), glow=(0.55, 0.30, 1.00)),
}


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def render(theme, p):
    T = {k: np.array(v) for k, v in THEMES[theme].items()}
    w, h = W * SS, H * SS
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32) + 0.5
    xs /= SS; ys /= SS
    cx, cy, R, K = W / 2, 50.0, 88.0, np.sin(ELEV)
    px = 1.0 / R
    rc, hw = 0.86, 0.12          # tube centre radius and half width (plate units)
    TUBE_DROP = 6.0              # screen px between top and underside of the tube

    def coords(yy):
        u = (xs - cx) / R
        v = (yy - cy) / (R * K)
        return u, v, np.sqrt(u * u + v * v)

    rgb = np.zeros((h, w, 3)); a = np.zeros((h, w))

    def over(col, al):
        nonlocal rgb, a
        al = np.clip(al, 0, 1)
        rgb = col * al[..., None] + rgb * (1 - al[..., None])
        a = al + a * (1 - al)

    # ---- frosted glass disc (sits a little lower than the ring) ----
    u, v, r = coords(ys - 3.0)
    disc_r = rc - hw * 0.4
    disc_m = smooth(disc_r + px, disc_r - px, r)
    q = np.clip(r / disc_r, 0, 1)
    glass = T["glass"] * (0.9 + 0.6 * (1 - q))[..., None]
    fill = np.exp(-(q ** 2) / (0.10 + 0.5 * p)) * (0.18 + 1.5 * p)
    glass = glass + T["tube"] * fill[..., None] * 0.8 + T["hot"] * (fill ** 2)[..., None] * 0.5
    # fine concentric grooves etched in the glass
    grooves = (0.5 + 0.5 * np.cos(q * np.pi * 14)) * smooth(0.2, 0.5, q) * smooth(0.98, 0.8, q)
    glass = glass + T["tube"] * grooves[..., None] * 0.07
    # small inner ring and centre jewel
    inner = np.exp(-(((q - 0.42) * disc_r * R) ** 2) / 0.9)
    glass = glass + T["hot"] * inner[..., None] * (0.35 + 0.5 * p)
    jewel = np.exp(-(q ** 2) / 0.006) * (0.8 + 0.4 * p)
    glass = glass + T["hot"] * jewel[..., None]
    glass = 1 - np.exp(-glass * 1.2)
    # frosted sheen on the far half
    sheen = smooth(0.1, -0.7, v) * smooth(1.0, 0.6, q) * 0.10
    glass = glass + sheen[..., None]
    over(glass, disc_m * (0.78 + 0.2 * p))

    # ---- neon tube: underside first (gives the ring thickness) ----
    def tube(yy, bright):
        u, v, r = coords(yy)
        t = (r - rc) / hw
        m = smooth(1.0 + px / hw, 1.0 - px / hw, np.abs(t))
        core = np.exp(-(t ** 2) / (0.10 + 0.12 * p))
        col = T["deep"] * (1 - np.abs(t) ** 2)[..., None] * 0.9 + T["tube"] * (1 - np.abs(t))[..., None]
        col = col + T["hot"] * core[..., None] * (0.55 + 0.6 * p)
        # lit from upper-left: brighter on the far-left arc
        ang = np.arctan2(v, u)
        key = 0.75 + 0.35 * np.cos(ang + 2.3)
        col = col * key[..., None] * bright
        # glassy specular stripe on the tube's upper edge
        spec = np.exp(-((t + 0.45) ** 2) / 0.02) * smooth(0.3, -0.6, v) * 0.6
        col = col + spec[..., None]
        return np.clip(col, 0, 1), m

    col, m = tube(ys - TUBE_DROP, 0.45)
    over(col, m)
    col, m = tube(ys, 1.0)
    over(col, m)

    # ---- glint: four-point star on the upper-left of the ring ----
    gx, gy = cx - R * rc * 0.62, cy - R * K * rc * 0.78
    du, dv = (xs - gx), (ys - gy)
    size = 14 + 14 * p
    star = np.exp(-(np.abs(du) / size) ** 0.9 * 6 - (dv / 1.1) ** 2) + np.exp(-(np.abs(dv) / (size * 0.7)) ** 0.9 * 6 - (du / 1.1) ** 2)
    star += np.exp(-(du ** 2 + dv ** 2) / 6.0) * 1.2
    star *= (0.7 + 0.3 * p)
    rgb = rgb + (T["hot"] * 0.3 + 0.7) * star[..., None] * 1.0
    a = np.clip(a + star * (1 - a), 0, 1)
    rgb = np.clip(rgb, 0, 1)

    # ---- downsample ----
    pm = np.concatenate([rgb * a[..., None], a[..., None]], -1)
    pm = pm.reshape(H, SS, W, SS, 4).mean(axis=(1, 3))

    # ---- bloom from the tube, behind the art ----
    lum = pm[..., :3].max(-1)
    src = Image.fromarray((np.clip(lum, 0, 1) * 255).astype(np.uint8))
    blur = np.asarray(src.filter(ImageFilter.GaussianBlur(4 + 2.5 * p)), np.float32) / 255
    yy, xx = np.mgrid[0:H, 0:W]
    win = smooth(0, 6, yy) * smooth(H, H - 6, yy) * smooth(0, 6, xx) * smooth(W, W - 6, xx)
    ga = np.clip(blur * (0.75 + 0.8 * p) * win, 0, 1)
    fa = pm[..., 3]
    out_rgb = pm[..., :3] + T["glow"] * ga[..., None] * (1 - fa[..., None])
    out_a = fa + ga * (1 - fa)
    out_rgb = np.where(out_a[..., None] > 1e-5, out_rgb / np.maximum(out_a[..., None], 1e-5), 0)
    out = np.concatenate([np.clip(out_rgb, 0, 1), out_a[..., None]], -1)
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(os.path.join(out, "normal"), exist_ok=True)
    os.makedirs(os.path.join(out, "long"), exist_ok=True)
    for i, p in enumerate(PULSE, 1):
        render("tap", p).save(os.path.join(out, "normal", f"na{i}.png"))
        hold = render("hold", p)
        hold.save(os.path.join(out, "normal", f"nb{i}.png"))
        hold.resize((132, 72), Image.LANCZOS).save(os.path.join(out, "long", f"nc{i}.png"))
    print("ok")

