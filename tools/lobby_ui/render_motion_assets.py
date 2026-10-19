"""Split supplied SVG artwork into small moving parts without changing the originals.

Run after render_assets.py. The same Chrome renderer preserves SVG filters/glows.
"""
from copy import deepcopy
import json
import tempfile
from pathlib import Path
from xml.etree import ElementTree as ET
from render_assets import SVG, OUT, ROOT, render

ET.register_namespace("", "http://www.w3.org/2000/svg")


def export(root, nodes, name, bounds=(0, 0, 700, 380)):
    doc = ET.Element(root.tag, dict(root.attrib))
    doc.set("viewBox", " ".join(map(str, bounds)))
    doc.append(deepcopy(root[0]))
    for node in nodes:
        doc.append(deepcopy(node))
    # Rebase a cropped viewBox: render_assets expects dimensions as viewBox width/height.
    with tempfile.TemporaryDirectory() as temp:
        path = Path(temp) / "layer.svg"
        ET.ElementTree(doc).write(path, encoding="utf-8", xml_declaration=True)
        render(path, OUT / name)


def main():
    metadata = {}
    for kind, source in [("play", "02_button_play_complete.svg"), ("create", "03_button_create_charts_complete.svg")]:
        root = ET.parse(SVG / source).getroot()
        bars = [dict(node.attrib) for node in root[1]]
        frame = [deepcopy(node) for i, node in enumerate(root) if i not in [0, 1, 15] and (kind != "play" or i not in [8, 9])]
        if kind == "create":
            icon = next(node for node in frame if node.get("transform") == "translate(110, 108)")
            for knob in list(icon)[-3:]:
                icon.remove(knob)
            for i, knob in enumerate(list(root[8])[-3:]):
                group = ET.Element(root[8].tag, dict(root[8].attrib))
                group.append(deepcopy(knob))
                x = 110 + float(knob.get("x")) - 16
                y = 108 + float(knob.get("y")) - 16
                export(root, [group], f"create_knob_{i}.png", (x, y, 56, 42))
        else:
            export(root, [root[8], root[9]], "play_icon_motion.png", (85, 85, 170, 180))
        export(root, frame, f"{kind}_motion_base.png")
        export(root, [root[15]], f"{kind}_chevrons.png", (480, 210, 145, 95))
        arrow_parts = list(root[15])[:2] + list(root[15][-1])
        for i, arrow in enumerate(arrow_parts):
            outer = ET.Element(root[15].tag, dict(root[15].attrib))
            if i >= 2:
                glow = ET.SubElement(outer, root[15][-1].tag, dict(root[15][-1].attrib))
                glow.append(deepcopy(arrow))
            else:
                outer.append(deepcopy(arrow))
            export(root, [outer], f"{kind}_chevron_{i}.png", (480, 210, 145, 95))
        metadata[kind] = {"bars": bars, "rim": root[5].get("points")}
    root = ET.parse(SVG / "06_button_settings.svg").getroot()
    export(root, [root[1], root[2]], "settings_orb.png", (0, 0, 120, 120))
    export(root, [root[3]], "settings_gear.png", (0, 0, 120, 120))
    (OUT / "motion_geometry.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    (ROOT / "scripts" / "lobby_art_geometry.gd").write_text(
        '# Generated from supplied SVG geometry by render_motion_assets.py.\nextends RefCounted\nconst DATA = '
        + json.dumps(metadata, indent=4) + '\n', encoding="utf-8")


if __name__ == "__main__":
    main()
