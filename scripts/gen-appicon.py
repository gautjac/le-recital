#!/usr/bin/env python3
"""Render Le Récital's app icon — a fine little chapbook: a warm cream page with
a deep madder ribbon-bookmark, an antique-gilt edge, and a serif drop-cap "R" —
as a COMPLETE opaque iPhone/iPad icon set.

Single-size icons can render blank on physical devices, and iOS app icons must be
OPAQUE (no alpha). We draw at high resolution with PIL and downsample.

Run:  python3 scripts/gen-appicon.py
"""
import os
import json
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SET = os.path.join(HERE, "..", "Resources", "Assets.xcassets", "AppIcon.appiconset")
os.makedirs(SET, exist_ok=True)

# Chapbook palette (matches Theme.jour).
BG      = (39, 31, 26)       # warm dark leather binding (full-bleed, opaque)
PAGE    = (245, 237, 222)    # warm cream paper
PAGE_HI = (252, 247, 236)    # page highlight
EDGE    = (224, 211, 184)    # deckled edge tint
GILT    = (179, 138, 51)     # antique gilt edge
INK     = (43, 33, 26)       # serif ink
RIBBON  = (158, 41, 41)      # deep madder red ribbon
RIBBON_D = (122, 28, 28)     # ribbon shadow fold
RULE    = (199, 181, 151)


def _font(paths, size):
    for p in paths:
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            continue
    return None


def render(px):
    S = 1024
    img = Image.new("RGB", (S, S), BG)
    d = ImageDraw.Draw(img)

    # Subtle vertical warm gradient on the binding background.
    for y in range(S):
        t = y / S
        r = int(39 + (28 - 39) * t)
        g = int(31 + (22 - 31) * t)
        b = int(26 + (18 - 26) * t)
        d.line([(0, y), (S, y)], fill=(r, g, b))

    # The page: a tall cream rectangle, slightly inset, with a gilt right edge.
    px0, py0, px1, py1 = 168, 132, 856, 892
    # Gilt page-edge stack (right + bottom) for a "closed book" thickness.
    for i in range(26):
        d.rectangle([px0 + i + 4, py0 + i + 4, px1 + i + 4, py1 + i + 4],
                    fill=GILT if i % 2 == 0 else EDGE)

    # The face page.
    d.rectangle([px0, py0, px1, py1], fill=PAGE)
    # Soft top-left highlight.
    d.polygon([(px0, py0), (px1, py0), (px0, py1)], fill=PAGE_HI)
    d.rectangle([px0, py0, px1, py1], outline=RULE, width=3)

    # Twin justification rules framing the drop-cap, chapbook style.
    d.line([px0 + 70, py0 + 120, px1 - 70, py0 + 120], fill=RULE, width=5)
    d.line([px0 + 70, py1 - 120, px1 - 70, py1 - 120], fill=RULE, width=5)

    # Serif drop-cap "R".
    rf = _font([
        "/System/Library/Fonts/Supplemental/Georgia.ttf",
        "/System/Library/Fonts/NewYork.ttf",
        "/Library/Fonts/Georgia.ttf",
        "/System/Library/Fonts/Times.ttc",
    ], 460)
    cx, cy = (px0 + px1) // 2 - 6, (py0 + py1) // 2 + 18
    if rf:
        d.text((cx, cy), "R", fill=INK, anchor="mm", font=rf)
    else:
        d.text((cx, cy), "R", fill=INK, anchor="mm")

    # A few faint "verse" rules below, suggesting lines of a poem.
    vy = py1 - 250
    for k in range(3):
        w = (px1 - px0) - 220 - k * 60
        d.line([px0 + 90, vy + k * 46, px0 + 90 + w, vy + k * 46], fill=EDGE, width=8)

    # The ribbon bookmark — drapes from the top, past the page bottom, with a
    # notched tail. Drawn last so it sits on top of the page.
    rx = px0 + 250
    rw = 92
    d.rectangle([rx, py0 - 24, rx + rw, py1 + 150], fill=RIBBON)
    # Fold shadow down the left of the ribbon.
    d.rectangle([rx, py0 - 24, rx + 22, py1 + 150], fill=RIBBON_D)
    # Notched (swallow-tail) tail.
    tail_y = py1 + 150
    d.polygon([(rx, tail_y), (rx + rw // 2, tail_y - 64), (rx + rw, tail_y),
               (rx + rw, tail_y + 6), (rx, tail_y + 6)], fill=BG)

    if px != S:
        img = img.resize((px, px), Image.LANCZOS)
    return img.convert("RGB")  # ensure opaque, no alpha


sizes = [40, 58, 60, 80, 87, 120, 167, 152, 76, 180, 1024]
for s in sizes:
    render(s).save(os.path.join(SET, f"icon-{s}.png"))

contents = {
    "images": [
        {"idiom": "iphone", "scale": "2x", "size": "20x20", "filename": "icon-40.png"},
        {"idiom": "iphone", "scale": "3x", "size": "20x20", "filename": "icon-60.png"},
        {"idiom": "iphone", "scale": "2x", "size": "29x29", "filename": "icon-58.png"},
        {"idiom": "iphone", "scale": "3x", "size": "29x29", "filename": "icon-87.png"},
        {"idiom": "iphone", "scale": "2x", "size": "40x40", "filename": "icon-80.png"},
        {"idiom": "iphone", "scale": "3x", "size": "40x40", "filename": "icon-120.png"},
        {"idiom": "iphone", "scale": "2x", "size": "60x60", "filename": "icon-120.png"},
        {"idiom": "iphone", "scale": "3x", "size": "60x60", "filename": "icon-180.png"},
        {"idiom": "ipad", "scale": "1x", "size": "20x20", "filename": "icon-40.png"},
        {"idiom": "ipad", "scale": "2x", "size": "20x20", "filename": "icon-40.png"},
        {"idiom": "ipad", "scale": "1x", "size": "29x29", "filename": "icon-58.png"},
        {"idiom": "ipad", "scale": "2x", "size": "29x29", "filename": "icon-58.png"},
        {"idiom": "ipad", "scale": "1x", "size": "40x40", "filename": "icon-40.png"},
        {"idiom": "ipad", "scale": "2x", "size": "40x40", "filename": "icon-80.png"},
        {"idiom": "ipad", "scale": "1x", "size": "76x76", "filename": "icon-76.png"},
        {"idiom": "ipad", "scale": "2x", "size": "76x76", "filename": "icon-152.png"},
        {"idiom": "ipad", "scale": "2x", "size": "83.5x83.5", "filename": "icon-167.png"},
        {"idiom": "ios-marketing", "scale": "1x", "size": "1024x1024", "filename": "icon-1024.png"},
    ],
    "info": {"author": "xcode", "version": 1},
}

with open(os.path.join(SET, "Contents.json"), "w") as f:
    f.write(json.dumps(contents, indent=2) + "\n")

print(f"OK — {len(sizes)} opaque icon PNGs written to {SET}")
