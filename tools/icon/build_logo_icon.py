"""Build launcher vector assets from the supplied SYNK logo's exact S path."""
from pathlib import Path
import xml.etree.ElementTree as ET
ET.register_namespace("", "http://www.w3.org/2000/svg")

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/brand"
source = ET.parse(OUT / "logo_static_source.svg")
ns = {"s": "http://www.w3.org/2000/svg"}
mark = source.find(".//s:g[@id='synk-full-stat-path-S']/s:path", ns).get("d")
gradients = "".join(ET.tostring(e, encoding="unicode") for e in source.findall(".//s:linearGradient", ns))

def svg(content, definitions=""):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512"><defs>{definitions}</defs>{content}</svg>'

background = '''<defs><radialGradient id="back" cx="25%" cy="15%" r="110%"><stop stop-color="#19365e"/><stop offset=".5" stop-color="#10102b"/><stop offset="1" stop-color="#310c3c"/></radialGradient></defs>
<rect width="512" height="512" fill="url(#back)"/>
<path d="M 0 92 L 92 0 M 420 512 L 512 420" stroke="#7a28ff" stroke-width="20" opacity=".18"/>
<path d="M 0 82 L 82 0" stroke="#00f2fe" stroke-width="4" opacity=".5"/>
<path d="M 430 512 L 512 430" stroke="#ff00a0" stroke-width="4" opacity=".5"/>'''

def symbol(scale):
    return f'''<g transform="translate(256 256) scale({scale}) skewX(-11) translate(-125 -147.5)">
<path d="{mark}" fill="none" stroke="url(#synk-full-stat-neonBorder)" stroke-width="22" opacity=".08"/>
<path d="{mark}" fill="none" stroke="url(#synk-full-stat-neonBorder)" stroke-width="13" opacity=".18"/>
<path d="{mark}" transform="translate(-5 6)" fill="none" stroke="url(#synk-full-stat-offsetGrad)" stroke-width="3"/>
<path d="{mark}" fill="url(#synk-full-stat-bodyFill)" stroke="url(#synk-full-stat-neonBorder)" stroke-width="6" stroke-linejoin="round"/>
<path d="M 103 73 L 207 73 M 61 219 L 179 219" fill="none" stroke="#e8fbff" stroke-width="2" opacity=".8"/>
<path d="M 108 116 L 196 116" stroke="#00f2fe" stroke-width="2" stroke-dasharray="14 6" opacity=".6"/>
</g>'''

(OUT / "icon_launcher.svg").write_text(svg(background + symbol(1.65), gradients), encoding="utf-8")
(OUT / "icon_adaptive_foreground.svg").write_text(svg(symbol(.99), gradients), encoding="utf-8")
(OUT / "icon_adaptive_background.svg").write_text(svg(background), encoding="utf-8")
(OUT / "icon_adaptive_monochrome.svg").write_text(svg(f'<g transform="translate(256 256) scale(.99) skewX(-11) translate(-125 -147.5)"><path d="{mark}" fill="white"/></g>'), encoding="utf-8")
print("Created launcher vectors from the supplied SYNK S mark.")
