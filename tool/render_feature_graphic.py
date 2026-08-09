"""Build the 1024x500 Play Console feature graphic.

Reuses the same SVG source and gradient palette as the app icon
(assets/icon/icon.svg) so the store listing reads as one identity rather
than a separate asset. The gradient field is rasterized with cairosvg; the
wordmark is composited with PIL/Arial afterward because cairosvg's text
rendering depends on Pango being installed, which is not guaranteed here.
"""
import re
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ICON_SVG = ROOT / "assets" / "icon" / "icon.svg"
OUT = ROOT / "store" / "feature-graphic.png"
W, H = 1024, 500

ARIAL_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
ARIAL = "/System/Library/Fonts/Supplemental/Arial.ttf"

svg = ICON_SVG.read_text()


def drop(markup: str, element_id: str) -> str:
    group = rf'<g id="{element_id}".*?</g>'
    if re.search(group, markup, flags=re.DOTALL):
        return re.sub(group, "", markup, flags=re.DOTALL)
    return re.sub(rf'<rect id="{element_id}"[^>]*/>', "", markup)


# --- Background: the same gradient field, stretched to fill 1024x500 ---
# icon.svg's gradient runs bottom-left -> top-right over a square; reusing
# its stop colors directly (rather than re-rasterizing the square icon and
# stretching it, which would distort the padlock glyph) keeps the mark crisp.
bg_svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
  <defs>
    <linearGradient id="field" x1="0" y1="{H}" x2="{W}" y2="0" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#28216F"/>
      <stop offset="0.5" stop-color="#5C427C"/>
      <stop offset="1" stop-color="#956E95"/>
    </linearGradient>
  </defs>
  <rect width="{W}" height="{H}" fill="url(#field)"/>
</svg>"""

bg_path = ROOT / "store" / "_bg_tmp.png"
cairosvg.svg2png(bytestring=bg_svg.encode(), write_to=str(bg_path), output_width=W, output_height=H)
canvas = Image.open(bg_path).convert("RGBA")
bg_path.unlink()

# --- Icon mark: rasterize the glyph-only layer, place on the left ---
glyph_svg = drop(svg, "bg")
mark_size = 320
mark_path = ROOT / "store" / "_mark_tmp.png"
cairosvg.svg2png(
    bytestring=glyph_svg.encode(),
    write_to=str(mark_path),
    output_width=mark_size,
    output_height=mark_size,
)
mark = Image.open(mark_path).convert("RGBA")
mark_path.unlink()

mark_x = 50
mark_y = (H - mark_size) // 2
canvas.alpha_composite(mark, (mark_x, mark_y))

# --- Wordmark: composited with PIL for reliable text rendering ---
draw = ImageDraw.Draw(canvas)
right_margin = 50
text_x = mark_x + mark_size + 40
available_w = W - right_margin - text_x

title = "Touch Block"
subtitle = "Prevent accidental touches during video calls"


def fit_font(path: str, text: str, start_size: int, max_w: int) -> ImageFont.FreeTypeFont:
    """Shrink font size until the rendered text fits max_w."""
    size = start_size
    while size > 10:
        font = ImageFont.truetype(path, size)
        bbox = draw.textbbox((0, 0), text, font=font)
        if bbox[2] - bbox[0] <= max_w:
            return font
        size -= 2
    return ImageFont.truetype(path, 10)


title_font = fit_font(ARIAL_BOLD, title, 92, available_w)
subtitle_font = fit_font(ARIAL, subtitle, 34, available_w)

title_bbox = draw.textbbox((0, 0), title, font=title_font)
subtitle_bbox = draw.textbbox((0, 0), subtitle, font=subtitle_font)
title_h = title_bbox[3] - title_bbox[1]
subtitle_h = subtitle_bbox[3] - subtitle_bbox[1]
gap = 22
block_h = title_h + gap + subtitle_h
start_y = (H - block_h) // 2

draw.text((text_x, start_y - title_bbox[1]), title, font=title_font, fill="#FFFFFF")
draw.text(
    (text_x, start_y + title_h + gap - subtitle_bbox[1]),
    subtitle,
    font=subtitle_font,
    fill="#E8E0F0",
)

# Feature graphics must not carry an alpha channel.
canvas.convert("RGB").save(OUT, "PNG")
print(f"wrote {OUT.relative_to(ROOT)} ({canvas.size[0]}x{canvas.size[1]})")
