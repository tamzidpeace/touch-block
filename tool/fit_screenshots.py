"""Reframe screenshots/*.jpg to Play's 1080x1920 store requirement.

The source captures are 504x1024 (ratio 2.03), just past Play's 2:1 maximum
long:short ratio. Rather than crop content, this widens the canvas with a
blurred cover-fit bleed of the image's own edges, then upscales the result.
No source pixels are discarded.
"""
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "screenshots"
OUT = ROOT / "store" / "screenshots"
TARGET_W, TARGET_H = 1080, 1920
TARGET_RATIO = TARGET_H / TARGET_W  # 1.778


def reframe(path: Path) -> None:
    original = Image.open(path).convert("RGB")
    w, h = original.size

    # Width needed at the source's height to hit the target ratio exactly.
    new_w = round(h / TARGET_RATIO)

    # Blurred cover-fit backdrop: scale the source to fill new_w x h, crop
    # the overflow off the top/bottom, then blur so it reads as an ambient
    # bleed rather than a duplicated image.
    scale = new_w / w
    bg = original.resize((new_w, round(h * scale)), Image.LANCZOS)
    top = (bg.height - h) // 2
    bg = bg.crop((0, top, new_w, top + h))
    bg = bg.filter(ImageFilter.GaussianBlur(radius=40))

    canvas = bg.copy()
    offset_x = (new_w - w) // 2
    canvas.paste(original, (offset_x, 0))

    final = canvas.resize((TARGET_W, TARGET_H), Image.LANCZOS)

    target = OUT / path.name
    final.save(target, quality=92)
    print(f"{path.name}: {w}x{h} -> {final.size[0]}x{final.size[1]}  wrote {target.relative_to(ROOT)}")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for src in sorted(SRC.glob("*.jpg")):
        reframe(src)
