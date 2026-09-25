#!/usr/bin/env python3
"""Generate the placeholder launcher-icon sources for Jangla.

Draws a simple "J" mark and writes three 1024x1024 PNGs into assets/icon/:

  app_icon.png             full icon (gradient background, no alpha, square)
  app_icon_foreground.png  transparent mark for Android adaptive icons
  app_icon_monochrome.png  transparent white mark for Android themed icons

Then wire them into every platform with:

  dart run flutter_launcher_icons

Requires Pillow:  python3 -m pip install pillow
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw

SIZE = 1024

# Matches colorSchemeSeed in lib/main.dart and adaptive_icon_background below.
BG_TOP = "#00796B"
BG_BOTTOM = "#004D40"
MARK_COLOR = "#FFFFFF"

# Fraction of the canvas the mark occupies. The adaptive value compensates for
# the 16% inset flutter_launcher_icons applies, while still landing inside
# Android's 108dp safe zone (66/108 ~= 0.61) so masks never clip it.
FULL_MARK_FRACTION = 0.54
ADAPTIVE_MARK_FRACTION = 0.70

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "icon")


def _hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def draw_mark(canvas: int = 1600) -> Image.Image:
    """Draws the mark on a transparent canvas and crops it to its bounds."""
    img = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    s = canvas
    stroke = 0.16 * s
    half = stroke / 2

    stem_x = 0.62 * s
    stem_top = 0.20 * s
    bend_y = 0.62 * s
    radius = 0.16 * s
    centre_x = stem_x - radius

    # Hook: a half ring built as an explicit polygon. Pillow's thick arc and
    # joint="curve" both leave spikes on a shape this thick.
    steps = 64
    outer = [
        (
            centre_x + (radius + half) * math.cos(math.pi * i / steps),
            bend_y + (radius + half) * math.sin(math.pi * i / steps),
        )
        for i in range(steps + 1)
    ]
    inner = [
        (
            centre_x + (radius - half) * math.cos(math.pi * i / steps),
            bend_y + (radius - half) * math.sin(math.pi * i / steps),
        )
        for i in range(steps, -1, -1)
    ]
    draw.polygon(outer + inner, fill=MARK_COLOR)

    # Stem, flush with the flat cut at the hook's right end.
    draw.rectangle([stem_x - half, stem_top, stem_x + half, bend_y], fill=MARK_COLOR)

    # Round caps on the two free ends.
    for px, py in ((stem_x, stem_top), (centre_x - radius, bend_y)):
        draw.ellipse([px - half, py - half, px + half, py + half], fill=MARK_COLOR)

    return img.crop(img.getbbox())


def scaled_mark(frac: float, canvas: int = SIZE) -> Image.Image:
    mark = draw_mark()
    w, h = mark.size
    scale = (frac * canvas) / max(w, h)
    size = (max(1, round(w * scale)), max(1, round(h * scale)))
    return mark.resize(size, Image.LANCZOS)


def gradient(canvas: int = SIZE) -> Image.Image:
    top = _hex_to_rgb(BG_TOP)
    bottom = _hex_to_rgb(BG_BOTTOM)
    strip = Image.new("RGB", (1, canvas))
    for y in range(canvas):
        t = y / max(1, canvas - 1)
        strip.putpixel(
            (0, y),
            tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)),
        )
    return strip.resize((canvas, canvas))


def paste_centred(bg: Image.Image, mark: Image.Image) -> Image.Image:
    x = (bg.width - mark.width) // 2
    y = (bg.height - mark.height) // 2
    bg.paste(mark, (x, y), mark)
    return bg


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)

    full = paste_centred(gradient(), scaled_mark(FULL_MARK_FRACTION))
    full.convert("RGB").save(os.path.join(OUT_DIR, "app_icon.png"))

    transparent = (0, 0, 0, 0)
    foreground = paste_centred(
        Image.new("RGBA", (SIZE, SIZE), transparent),
        scaled_mark(ADAPTIVE_MARK_FRACTION),
    )
    foreground.save(os.path.join(OUT_DIR, "app_icon_foreground.png"))

    monochrome = paste_centred(
        Image.new("RGBA", (SIZE, SIZE), transparent),
        scaled_mark(ADAPTIVE_MARK_FRACTION),
    )
    monochrome.save(os.path.join(OUT_DIR, "app_icon_monochrome.png"))

    print(f"Wrote app_icon.png, app_icon_foreground.png, app_icon_monochrome.png to {OUT_DIR}")


if __name__ == "__main__":
    main()
