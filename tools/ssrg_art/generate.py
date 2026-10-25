# Generates SYNK's own SSRG-style artwork into assets/ssrg/ (original drawings; nothing is
# copied from any other game). Same file names, sizes and frame layout the SSRG code expects.
#   python tools/ssrg_art/generate.py
import math, random, os
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "ssrg")
FONT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "fonts", "FiraSans-Bold.ttf")
SS = 4  # supersampling

def blank(w, h): return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
def down(im, w, h): return im.resize((w, h), Image.LANCZOS)

def ellipse_layer(size, box, fill, blur=0):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse(box, fill=fill)
    return layer.filter(ImageFilter.GaussianBlur(blur)) if blur else layer

def puck(w, h, rim, deep):
    """A glossy disc seen at an angle: coloured rim with depth, pearl ring, bright white core."""
    im = blank(w, h); W, H = im.size
    cx, cy = W / 2, H * .46
    rx, ry = W * .47, H * .40
    thick = H * .10
    # soft shadow and side wall (thickness below the face)
    im.alpha_composite(ellipse_layer(im.size, (cx - rx, cy - ry + thick * 1.4, cx + rx, cy + ry + thick * 1.4), (0, 0, 0, 90), 6 * SS))
    for i in range(int(thick), 0, -1):
        t = i / thick
        c = tuple(int(deep[k] * (0.55 + .45 * (1 - t))) for k in range(3))
        im.alpha_composite(ellipse_layer(im.size, (cx - rx, cy - ry + i, cx + rx, cy + ry + i), c + (255,)))
    # rim face with a vertical gradient (light top, saturated bottom)
    face = Image.new("RGBA", im.size, (0, 0, 0, 0)); fd = ImageDraw.Draw(face)
    for y in range(int(cy - ry), int(cy + ry) + 1):
        t = (y - (cy - ry)) / (2 * ry)
        c = tuple(int(255 * (1 - t) * .35 + rim[k] * (.65 + .35 * t)) for k in range(3))
        fd.line([(0, y), (W, y)], fill=c + (255,))
    mask = ellipse_layer(im.size, (cx - rx, cy - ry, cx + rx, cy + ry), (255, 255, 255, 255)).split()[3]
    im.paste(face, (0, 0), mask)
    # pearl ring, inner dark groove, glowing core
    ImageDraw.Draw(im).ellipse((cx - rx * .80, cy - ry * .78, cx + rx * .80, cy + ry * .74), outline=(255, 255, 255, 235), width=int(3.2 * SS))
    im.alpha_composite(ellipse_layer(im.size, (cx - rx * .70, cy - ry * .66, cx + rx * .70, cy + ry * .62), tuple(int(v * .55) for v in deep) + (255,)))
    im.alpha_composite(ellipse_layer(im.size, (cx - rx * .62, cy - ry * .58, cx + rx * .62, cy + ry * .50), (255, 255, 255, 255), 2 * SS))
    im.alpha_composite(ellipse_layer(im.size, (cx - rx * .70, cy - ry * .66, cx + rx * .70, cy + ry * .62), (255, 255, 255, 120), 5 * SS))
    # specular highlight on the top-left of the rim and a thin bright outline
    spec = ellipse_layer(im.size, (cx - rx * .85, cy - ry * .95, cx + rx * .05, cy - ry * .62), (255, 255, 255, 150), 3 * SS)
    spec.putalpha(ImageChops.multiply(spec.split()[3], mask))   # keep the shine on the face
    im.alpha_composite(spec)
    ImageDraw.Draw(im).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), outline=(255, 255, 255, 200), width=int(1.6 * SS))
    return down(im, w, h)

def judgment(w, h):
    """Dark glass band across the judgement line with a bright silver top edge."""
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    inset = int(h * .55)
    for y in range(h):
        t = y / (h - 1)
        a = int(170 + 60 * t)
        c = (int(28 + 40 * (1 - t)), int(28 + 40 * (1 - t)), int(40 + 46 * (1 - t)), a)
        x0 = inset * (1 - t); d.line([(x0, y), (w - x0, y)], fill=c)
    for i in range(6):
        d.line([(inset - i * .4, i), (w - inset + i * .4, i)], fill=(255, 255, 255, 230 - i * 35))
    d.line([(0, h - 2), (w, h - 2)], fill=(255, 255, 255, 90))
    return im

def rail(w, h):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    for y in range(h):
        t = abs(y - (h - 1) / 2) / ((h - 1) / 2)
        v = int(255 * (1 - t) ** 1.6); d.line([(0, y), (w, y)], fill=(255, 255, 255, v))
    fade = Image.linear_gradient("L").rotate(90, expand=True).resize((w, h))   # bright near, fading far
    r, g, b, a = im.split(); im.putalpha(ImageChops.multiply(a, fade))
    return im

def perfect(w, h):
    im = blank(w, h); W, H = im.size
    font = ImageFont.truetype(FONT, int(H * .9))
    text = "PERFECT"
    box = ImageDraw.Draw(im).textbbox((0, 0), text, font=font)
    tw, th = box[2] - box[0], box[3] - box[1]
    pos = ((W - tw) / 2 - box[0], (H - th) / 2 - box[1])
    mask = Image.new("L", im.size, 0); ImageDraw.Draw(mask).text(pos, text, font=font, fill=255)
    chrome = Image.new("RGBA", im.size); cd = ImageDraw.Draw(chrome)
    for y in range(H):
        t = y / H
        v = 255 if t < .45 else int(150 + 105 * (t - .45) / .55)
        v = int(v * (0.86 if .46 < t < .55 else 1.0))
        cd.line([(0, y), (W, y)], fill=(v, v, min(255, v + 12), 255))
    outline = mask.filter(ImageFilter.MaxFilter(int(5 * SS) | 1))
    im.paste((40, 44, 70, 255), (0, 0), outline)
    im.paste(chrome, (0, 0), mask)
    return down(im, w, h)

def hit_sheet(w, h, color, star):
    """11 frames (4x3 grid, last cell empty): a flash that blooms, an expanding ring, sparks."""
    fw, fh = w // 4, h // 3
    sheet = Image.new("RGB", (w, h), (0, 0, 0))
    rnd = random.Random(7 if star else 3)
    sparks = [(rnd.uniform(0, math.tau), rnd.uniform(.4, 1.0), rnd.uniform(1.2, 3.0)) for _ in range(26)]
    for f in range(11):
        t = f / 10.0
        im = Image.new("RGB", (fw * 2, fh * 2), (0, 0, 0)); W, H = im.size; cx, cy = W / 2, H * .5
        layer = Image.new("RGB", im.size, (0, 0, 0)); d = ImageDraw.Draw(layer)
        grow = 1 - (1 - min(1, t * 2.4)) ** 3
        fade = (1 - t) ** 1.4
        rx, ry = W * (.07 + .15 * grow), H * (.05 + .12 * grow)   # stays inside its frame
        glow = tuple(int(c * fade) for c in color)
        d.ellipse((cx - rx * 1.5, cy - ry * 1.5, cx + rx * 1.5, cy + ry * 1.5), fill=glow)
        layer = layer.filter(ImageFilter.GaussianBlur(W * .05))
        core = Image.new("RGB", im.size, (0, 0, 0)); cd = ImageDraw.Draw(core)
        cw = min(1.0, 1.6 * max(0.0, 1 - t * 1.5))   # white-hot first frames
        cd.ellipse((cx - rx * .7, cy - ry * .7, cx + rx * .7, cy + ry * .7), fill=(int(255 * cw),) * 3)
        core = core.filter(ImageFilter.GaussianBlur(W * .025))
        ring = Image.new("RGB", im.size, (0, 0, 0)); rd = ImageDraw.Draw(ring)
        rr = 1 + t * .8
        rd.ellipse((cx - rx * rr, cy - ry * rr, cx + rx * rr, cy + ry * rr), outline=tuple(int(min(255, c * 1.2) * fade) for c in color), width=max(2, int(W * .012 * (1 - t) + 2)))
        ring = ring.filter(ImageFilter.GaussianBlur(1.5))
        im = ImageChops.add(ImageChops.add(layer, core), ring)
        if star and t > .2:
            st = Image.new("RGB", im.size, (0, 0, 0)); sd = ImageDraw.Draw(st)
            s = W * .11 * (1 + t * .4); a = min(1, (t - .2) * 4) * (1 - t)
            pts = [(cx + math.cos(-math.pi / 2 + i * math.pi / 5) * (s if i % 2 == 0 else s * .45), cy + math.sin(-math.pi / 2 + i * math.pi / 5) * (s if i % 2 == 0 else s * .45) * .62) for i in range(10)]
            sd.polygon(pts, fill=(int(255 * a),) * 3)
            im = ImageChops.add(im, st.filter(ImageFilter.GaussianBlur(2)))
        sp = Image.new("RGB", im.size, (0, 0, 0)); spd = ImageDraw.Draw(sp)
        for ang, spd_v, size in sparks:
            dist = (.12 + spd_v * t) * W * .32
            x = cx + math.cos(ang) * dist; y = cy + math.sin(ang) * dist * .55 - t * H * .1
            a = max(0.0, 1 - t * 1.1)
            c = tuple(int(min(255, v * 1.3) * a) for v in color)
            r = size * (1 - t * .5)
            spd.ellipse((x - r, y - r, x + r, y + r), fill=c)
        im = ImageChops.add(im, sp)
        sheet.paste(im.resize((fw, fh), Image.LANCZOS), ((f % 4) * fw, (f // 4) * fh))
    return sheet

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    puck(212, 116, (40, 150, 255), (10, 70, 190)).save(os.path.join(OUT, "tap.png"))
    puck(212, 116, (255, 190, 30), (190, 110, 10)).save(os.path.join(OUT, "hold.png"))
    puck(212, 116, (255, 80, 170), (170, 20, 110)).save(os.path.join(OUT, "flick.png"))
    puck(212, 116, (40, 215, 120), (10, 130, 70)).save(os.path.join(OUT, "slide.png"))
    puck(132, 72, (255, 190, 30), (190, 110, 10)).save(os.path.join(OUT, "end.png"))
    judgment(1024, 128).save(os.path.join(OUT, "judgment.png"))
    rail(1024, 16).save(os.path.join(OUT, "rail.png"))
    perfect(272, 54).save(os.path.join(OUT, "perfect.png"))
    hit_sheet(1240, 558, (60, 210, 255), False).save(os.path.join(OUT, "hit_a.png"))
    hit_sheet(1240, 558, (230, 220, 60), True).save(os.path.join(OUT, "hit_b.png"))
    print("written to", os.path.abspath(OUT))
