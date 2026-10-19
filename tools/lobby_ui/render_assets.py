"""Renders the home-screen (mode lobby) SVG elements to PNGs the game can use.

The SVGs in tools/lobby_ui/svg/ use blur and drop-shadow filters that Godot's SVG importer
does not support, so they are rendered with headless Chrome instead, at 2x their design size,
with transparent backgrounds. The full-screen mockup also provides the background: everything
after its stage gradient, light beams and floor arcs is stripped before rendering.

Run from the repository root (needs Google Chrome):
  python tools/lobby_ui/render_assets.py
Writes assets/lobby/ui/*.png
"""
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SVG = Path(__file__).resolve().parent / "svg"
OUT = ROOT / "assets" / "lobby" / "ui"
CHROME = r"C:/Program Files/Google/Chrome/Application/chrome.exe"
SCALE = 2

# output name -> source file
ELEMENTS = {
    "logo.png": "01_synk_logo.svg",
    "play_button.png": "02_button_play_complete.svg",
    "create_button.png": "03_button_create_charts_complete.svg",
    "settings_button.png": "06_button_settings.svg",
    "header.png": "07_header_choose_your_rhythm.svg",
}


def view_box(svg_text):
    numbers = re.search(r'viewBox="\s*([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)"', svg_text)
    return float(numbers.group(3)), float(numbers.group(4))


def render(svg_path, out_path, scale=SCALE, opaque=False):
    width, height = view_box(svg_path.read_text(encoding="utf-8"))
    width, height = int(width * scale), int(height * scale)
    with tempfile.TemporaryDirectory() as temp:
        page = Path(temp) / "page.html"
        page.write_text(f'<html><body style="margin:0;background:transparent"><img src="{svg_path.as_uri()}" '
                        f'style="width:{width}px;height:{height}px;display:block"></body></html>', encoding="utf-8")
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                        "--no-first-run", "--no-default-browser-check", f"--user-data-dir={Path(temp) / 'profile'}",
                        "--default-background-color=" + ("000000ff" if opaque else "00000000"),
                        f"--window-size={width},{height}", f"--screenshot={out_path}", page.as_uri()],
                       check=True, capture_output=True, timeout=120)
    print(f"wrote {out_path.relative_to(ROOT)} ({width}x{height})")


def background_svg(temp_dir):
    """The full screen with only its backdrop: stage gradient, light beams and floor arcs."""
    text = (SVG / "00_full_menu_screen.svg").read_text(encoding="utf-8")
    cut = text.index('<g transform="translate(560, 20)">')
    path = Path(temp_dir) / "background.svg"
    path.write_text(text[:cut] + "</svg>\n", encoding="utf-8")
    return path


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, source in ELEMENTS.items():
        render(SVG / source, OUT / name)
    with tempfile.TemporaryDirectory() as temp:
        render(background_svg(temp), OUT / "background.png", scale=1, opaque=True)


if __name__ == "__main__":
    main()
