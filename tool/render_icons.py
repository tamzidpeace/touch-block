"""Rasterize assets/icon/icon.svg into the 1024x1024 masters.

The SVG is the single source of truth for the launcher icon. Re-run this
after editing it, then re-run `dart run flutter_launcher_icons`.
"""
import re
from pathlib import Path

import cairosvg

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "icon" / "icon.svg"
OUT = ROOT / "assets" / "icon"
SIZE = 1024

svg = SRC.read_text()


def render(name: str, markup: str) -> None:
    target = OUT / name
    cairosvg.svg2png(
        bytestring=markup.encode(),
        write_to=str(target),
        output_width=SIZE,
        output_height=SIZE,
    )
    print(f"wrote {target.relative_to(ROOT)}")


def drop(markup: str, element_id: str) -> str:
    """Remove a top-level element by id.

    Handles the two shapes present in icon.svg separately. A single combined
    pattern would be wrong: the glyph group contains self-closing <path/>
    children, so a non-greedy match ending in `/>` would stop at the first
    child and leave the rest of the group orphaned.
    """
    group = rf'<g id="{element_id}".*?</g>'
    if re.search(group, markup, flags=re.DOTALL):
        return re.sub(group, "", markup, flags=re.DOTALL)
    return re.sub(rf'<rect id="{element_id}"[^>]*/>', "", markup)


# Full-bleed master: used for the legacy square launcher icon and the
# Play Console 512x512 hi-res icon.
render("icon.png", svg)

# Adaptive background: the gradient field with no glyph.
render("icon_background.png", drop(svg, "glyph"))

# Adaptive foreground: glyph only, on transparent, at full canvas size.
#
# Deliberately NOT inset here. flutter_launcher_icons wraps this drawable in
# an <inset android:inset="16%"/> in mipmap-anydpi-v26/ic_launcher.xml, which
# is what keeps the artwork inside the adaptive-icon safe zone. Insetting in
# this script as well would compound the two and shrink the glyph to roughly
# 38% of the icon.
#
# This also doubles as the Android 13+ themed (monochrome) layer — the system
# tints that layer itself, so a white-on-transparent glyph is already the
# correct input and a separate file would be byte-identical.
render("icon_foreground.png", drop(svg, "bg"))
