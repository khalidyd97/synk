"""'Lens' note set: chrome bezel + glowing glass dome, lit with real normals.
Frame 1 = beat flash, 2..5 decay, 6 = resting state."""
import sys, os
import numpy as np
from PIL import Image, ImageFilter

SS = 4
W, H = 212, 116
PULSE = [1.0, 0.72, 0.48, 0.30, 0.15, 0.05]

THEMES = {
    "tap": dict(core=(1.00, 0.80, 0.92), mid=(1.00, 0.22, 0.58), edge=(0.62, 0.02, 0.48),
                glass=(0.20, 0.00, 0.14), chrome=(1.00, 0.62, 0.84), glow=(1.00, 0.25, 0.62)),
    "hold": dict(core=(0.85, 1.00, 0.95), mid=(0.10, 0.85, 0.75), edge=(0.00, 0.40, 0.55),
                 glass=(0.00, 0.10, 0.12), chrome=(0.60, 1.00, 0.92), glow=(0.15, 1.00, 0.80)),
}

ELEV = np.deg2rad(25.0)
V = np.array([0.0, np.cos(ELEV), np.sin(ELEV)])          # surface -> camera (+v is toward viewer)
L = np.array([-0.45, -0.35, 0.82]); L /= np.linalg.norm(L)  # key light from upper-left
Hh = (V + L); Hh /= np.linalg.norm(Hh)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def dot3(n, a):
    return n[0] * a[0] + n[1] * a[1] + n[2] * a[2]


def env(n, tint):
    """Studio environment for chrome: bright softbox above, dark band, warm floor bounce."""
    rx, ry, rz = [2 * dot3(n, V) * n[i] - V[i] for i in range(3)]
    sky = smooth(0.25, 0.85, rz)
    band = np.exp(-((rz - 0.05) ** 2) / 0.01)
    side = smooth(0.3, 0.9, -rx) * 0.35
    val = 0.18 + 0.95 * sky + 0.25 * side - 0.12 * band
    return np.clip(val, 0, 1.4)[..., None] * np.array(tint)


def render(theme, p):
    T = {k: np.array(v) for k, v in THEMES[theme].items()}
    w, h = W * SS, H * SS
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32) + 0.5
    xs /= SS; ys /= SS
    cx, cy, R, K, THICK = W / 2, 46.0, 90.0, np.sin(ELEV), 11.0
    px = 1.0 / R

    def radius(yy):
        return np.sqrt(((xs - cx) / R) ** 2 + ((yy - cy) / (R * K)) ** 2)

    r = radius(ys)
    u = (xs - cx) / R
    v = (ys - cy) / (R * K)
    ru, rv = u / np.maximum(r, 1e-4), v / np.maximum(r, 1e-4)

    rgb = np.zeros((h, w, 3)); a = np.zeros((h, w))

    def over(col, al):
        nonlocal rgb, a
        rgb = col * al[..., None] + rgb * (1 - al[..., None])
        a = al + a * (1 - al)

    # ---- side wall (sweep of rim downward) ----
    r_side = np.min(np.stack([radius(ys - t) for t in np.linspace(0, THICK, 22)]), axis=0)
    side_m = smooth(1 + px, 1 - px, r_side)
    depth = np.clip((ys - cy) / (R * K + THICK), 0, 1)
    nside = (ru, rv, np.zeros_like(r))
    side_col = env((ru * 0.9, rv * 0.9, np.full_like(r, 0.44)), T["chrome"]) * (0.55 - 0.35 * depth[..., None])
    over(np.clip(side_col * 0.55 + T["edge"] * (0.75 - 0.45 * depth[..., None]), 0, 1), side_m)
    # emissive lip at the bottom of the wall
    lip = np.exp(-(((radius(ys - THICK * 0.55) - 1.0) * R) ** 2) / 1.4) * side_m * (r > 1)
    over(np.clip(T["glow"] * (0.8 + 0.6 * p) + 0.25 * p, 0, 1), np.clip(lip * (0.55 + 0.4 * p), 0, 1))

    # ---- top: bezel torus 0.80..1.0 ----
    top_m = smooth(1 + px, 1 - px, r)
    rin, rout = 0.80, 1.0
    rc, hw = (rin + rout) / 2, (rout - rin) / 2
    t = np.clip((r - rc) / hw, -1, 1)
    nz = np.sqrt(1 - t * t * 0.92)
    nb = (ru * t, rv * t, nz)
    nlen = np.sqrt(nb[0] ** 2 + nb[1] ** 2 + nb[2] ** 2); nb = tuple(c_ / nlen for c_ in nb)
    bez = env(nb, T["chrome"]) * 0.75 + T["edge"] * 0.25
    bez += (np.clip(dot3(nb, Hh), 0, 1) ** 60 * 1.3)[..., None]
    # thin coloured groove between bezel and glass
    groove = np.exp(-(((r - rin) * R) ** 2) / 1.0)

    # ---- glass dome r < rin ----
    q = np.clip(r / rin, 0, 1)
    dh = 0.55
    hz = np.sqrt(np.maximum(1 - q * q, 0))
    slope = q / np.maximum(hz, 0.08) * dh
    nd = (ru * slope, rv * slope, np.ones_like(r))
    nlen = np.sqrt(nd[0] ** 2 + nd[1] ** 2 + 1); nd = tuple(c_ / nlen for c_ in nd)
    fres = (1 - np.clip(dot3(nd, V), 0, 1)) ** 3

    # emissive light inside the glass: radial gradient core -> mid -> edge
    sig = 0.18 + 0.32 * p
    core_w = np.exp(-(q ** 2) / sig)[..., None]
    mid_w = np.exp(-((q - 0.55) ** 2) / 0.12)[..., None]
    inten = 0.45 + 1.3 * p
    core_col = T["mid"] * (1 - p) + T["core"] * p
    emis = (core_col * core_w * (0.9 + 0.6 * p) + T["mid"] * mid_w * 0.9 + T["edge"] * q[..., None] ** 2 * 1.2) * inten
    # floating inner ring of light (gives depth, like a lens element)
    ring = np.exp(-((q - 0.62) ** 2) / 0.0018)
    emis += T["core"] * ring[..., None] * (0.35 + 0.5 * p)
    # beat flash wash
    emis += (p ** 2 * 1.4) * np.exp(-(q ** 2) / 0.5)[..., None]
    glass = T["glass"] + emis
    glass = 1 - np.exp(-glass * 1.15)  # soft tone map: hot areas saturate to white
    glass += fres[..., None] * T["mid"] * 0.6
    # specular: sharp key highlight + soft broad sheen + bottom caustic
    glass += (np.clip(dot3(nd, Hh), 0, 1) ** 140 * 1.6)[..., None]
    glass += (np.clip(dot3(nd, Hh), 0, 1) ** 12 * 0.12)[..., None]
    gloss = smooth(0.75, 0.55, np.sqrt(((u + 0.12) / 0.62) ** 2 + ((v + 0.30) / 0.38) ** 2)) * smooth(0.0, -0.35, v)
    glass += gloss[..., None] * 0.28
    caus = np.exp(-(((u) / 0.35) ** 2 + ((v - 0.55) / 0.12) ** 2)) * 0.35
    glass += caus[..., None] * T["core"]

    in_glass = smooth(rin + px * 0.7, rin - px * 0.7, r)
    top = bez * (1 - in_glass[..., None]) + glass * in_glass[..., None]
    top += groove[..., None] * T["glow"] * (0.6 + 0.6 * p)
    # crisp outer edge highlight
    top += (np.exp(-(((r - 1.0) * R) ** 2) / 0.5) * 0.35)[..., None]
    over(np.clip(top, 0, 1), top_m)

    # ---- downsample ----
    pm = np.concatenate([rgb * a[..., None], a[..., None]], -1)
    pm = pm.reshape(H, SS, W, SS, 4).mean(axis=(1, 3))

    # ---- bloom from glass emission, placed behind ----
    lum = (pm[..., :3].mean(-1) * (r.reshape(H, SS, W, SS).mean(axis=(1, 3)) < 1.02))
    glow_src = Image.fromarray((np.clip(lum, 0, 1) * 255).astype(np.uint8))
    blur = np.asarray(glow_src.filter(ImageFilter.GaussianBlur(4 + 2 * p)), np.float32) / 255
    yy, xx = np.mgrid[0:H, 0:W]
    win = smooth(0, 6, yy) * smooth(H, H - 6, yy) * smooth(0, 6, xx) * smooth(W, W - 6, xx)
    ga = np.clip(blur * (0.5 + 0.7 * p) * win, 0, 1)
    gcol = np.clip(T["glow"] * (1 - 0.3 * p) + 0.3 * p, 0, 1)
    fa = pm[..., 3]
    out_rgb = pm[..., :3] + gcol * ga[..., None] * (1 - fa[..., None])
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


