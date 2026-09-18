"""Renders the PepoConnect icons from the same geometry as assets/brand/pepoconnect.svg.

Pillow only (no cairosvg / resvg). Everything is drawn at 4x and downsampled.

    python tool/brand/render_icons.py
"""
from __future__ import annotations

import os
import sys

from PIL import Image, ImageChops, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "icon")
SS = 4  # supersampling factor
DESIGN = 512.0

GRADIENT_START = (0x0A, 0x3D, 0x8F)
GRADIENT_END = (0x12, 0xB6, 0xD9)
SUN = (0xFF, 0xC8, 0x57)
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)

# Design-space geometry (512 grid), identical to the SVG.
BACK = (112.0, 128.0, 220.0, 176.0)  # x, y, w, h
FRONT = (196.0, 200.0, 220.0, 176.0)
FRAME_RADIUS = 30.0
STROKE = 28.0
ERASE_STROKE = 40.0
CROSSING = (296.0, 178.0, 58.0, 58.0)
CHECK = [(150.0, 165.0), (166.0, 181.0), (194.0, 151.0)]
CHECK_STROKE = 14.0
MOUNTAIN = [(224.0, 346.0), (286.0, 262.0), (322.0, 300.0), (352.0, 272.0), (388.0, 346.0)]
MOUNTAIN_STROKE = 8.0
SUN_CENTER = (372.0, 244.0)
SUN_RADIUS = 16.0
GLYPH_BOUNDS = (98.0, 114.0, 430.0, 390.0)  # l, t, r, b (strokes included)

# Simplified 24-grid mark for the tray (same as pepoconnect-mono.svg).
MONO_BACK = (2.5, 4.5, 11.0, 9.0)
MONO_FRONT = (10.5, 10.5, 11.0, 9.0)
MONO_RADIUS = 2.0
MONO_STROKE = 2.0
MONO_ERASE = 3.6
MONO_CROSSING = (11.5, 8.5, 4.5, 4.5)


def diagonal_gradient(size: int) -> Image.Image:
    """Top-left GRADIENT_START -> bottom-right GRADIENT_END."""
    n = 256
    px = bytearray(n * n)
    for y in range(n):
        row = y * n
        for x in range(n):
            px[row + x] = int(round(255 * (x + y) / (2 * (n - 1))))
    mask = Image.frombytes("L", (n, n), bytes(px)).resize((size, size), Image.BILINEAR)
    start = Image.new("RGBA", (size, size), GRADIENT_START + (255,))
    end = Image.new("RGBA", (size, size), GRADIENT_END + (255,))
    return Image.composite(end, start, mask)


class Space:
    """Maps design coordinates to supersampled pixels."""

    def __init__(self, canvas: int, scale: float, ox: float, oy: float):
        self.canvas = canvas
        self.s = scale
        self.ox = ox
        self.oy = oy

    def p(self, x: float, y: float) -> tuple[float, float]:
        return (self.ox + x * self.s, self.oy + y * self.s)

    def box(self, rect: tuple[float, float, float, float], inflate: float = 0.0):
        x, y, w, h = rect
        x0, y0 = self.p(x - inflate, y - inflate)
        x1, y1 = self.p(x + w + inflate, y + h + inflate)
        return [x0, y0, x1, y1]

    def ring(self, mask: Image.Image, rect, radius: float, stroke: float, value: int = 255) -> None:
        """Stroke of `stroke` centred on the rounded rect outline."""
        d = ImageDraw.Draw(mask)
        half = stroke / 2
        d.rounded_rectangle(
            self.box(rect, inflate=half),
            radius=(radius + half) * self.s,
            outline=value,
            width=max(1, int(round(stroke * self.s))),
        )


def frames_mask(sp: Space, back, front, radius, stroke, erase_stroke, crossing) -> Image.Image:
    """Two linked frames: the front passes over the back except at the
    upper-right crossing, where a gap is cut around the back stroke."""
    size = sp.canvas
    back_m = Image.new("L", (size, size), 0)
    sp.ring(back_m, back, radius, stroke)
    front_m = Image.new("L", (size, size), 0)
    sp.ring(front_m, front, radius, stroke)
    frames = ImageChops.lighter(back_m, front_m)

    clip = Image.new("L", (size, size), 0)
    ImageDraw.Draw(clip).rectangle(sp.box(crossing), fill=255)
    erase = Image.new("L", (size, size), 0)
    sp.ring(erase, back, radius, erase_stroke)
    erase = ImageChops.multiply(erase, clip)
    back_in_clip = ImageChops.multiply(back_m, clip)

    glyph = ImageChops.subtract(frames, erase)
    return ImageChops.lighter(glyph, back_in_clip)


def full_glyph_mask(sp: Space) -> Image.Image:
    """Frames + check + mountain (white parts). The sun is a separate layer."""
    size = sp.canvas
    mask = frames_mask(sp, BACK, FRONT, FRAME_RADIUS, STROKE, ERASE_STROKE, CROSSING)
    d = ImageDraw.Draw(mask)
    # Check with round caps and joins.
    pts = [sp.p(*pt) for pt in CHECK]
    w = int(round(CHECK_STROKE * sp.s))
    d.line(pts, fill=255, width=w, joint="curve")
    r = CHECK_STROKE / 2 * sp.s
    for x, y in (pts[0], pts[-1]):
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    # Mountain, filled, with rounded peaks.
    mpts = [sp.p(*pt) for pt in MOUNTAIN]
    d.polygon(mpts, fill=255)
    d.line(mpts + [mpts[0]], fill=255, width=int(round(MOUNTAIN_STROKE * sp.s)), joint="curve")
    return mask


def sun_layer(sp: Space, color) -> Image.Image:
    size = sp.canvas
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cx, cy = sp.p(*SUN_CENTER)
    r = SUN_RADIUS * sp.s
    ImageDraw.Draw(layer).ellipse([cx - r, cy - r, cx + r, cy + r], fill=color + (255,))
    return layer


def render_full_icon(px: int) -> Image.Image:
    size = px * SS
    sp = Space(size, size / DESIGN, 0.0, 0.0)
    bg = diagonal_gradient(size)
    rounded = Image.new("L", (size, size), 0)
    ImageDraw.Draw(rounded).rounded_rectangle([0, 0, size - 1, size - 1], radius=112 * sp.s, fill=255)
    bg.putalpha(rounded)
    white = Image.new("RGBA", (size, size), WHITE + (255,))
    icon = Image.composite(white, bg, full_glyph_mask(sp))
    icon = Image.alpha_composite(icon, sun_layer(sp, SUN))
    return icon.resize((px, px), Image.LANCZOS)


def render_glyph_only(px: int, fraction: float, color, sun=None) -> Image.Image:
    """Glyph centred on a transparent canvas, longest side = fraction * px."""
    size = px * SS
    l, t, r, b = GLYPH_BOUNDS
    gw, gh = r - l, b - t
    scale = size * fraction / max(gw, gh)
    ox = (size - gw * scale) / 2 - l * scale
    oy = (size - gh * scale) / 2 - t * scale
    sp = Space(size, scale, ox, oy)
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    fill = Image.new("RGBA", (size, size), color + (255,))
    layer = Image.composite(fill, layer, full_glyph_mask(sp))
    layer = Image.alpha_composite(layer, sun_layer(sp, sun or color))
    return layer.resize((px, px), Image.LANCZOS)


def render_tray(px: int, color) -> Image.Image:
    size = px * SS
    sp = Space(size, size / 24.0, 0.0, 0.0)
    mask = frames_mask(sp, MONO_BACK, MONO_FRONT, MONO_RADIUS, MONO_STROKE, MONO_ERASE, MONO_CROSSING)
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    fill = Image.new("RGBA", (size, size), color + (255,))
    layer = Image.composite(fill, layer, mask)
    return layer.resize((px, px), Image.LANCZOS)


def save(img: Image.Image, name: str, **kwargs) -> None:
    path = os.path.join(OUT, name)
    img.save(path, **kwargs)
    print(f"  {os.path.relpath(path, ROOT)}  {img.size[0]}x{img.size[1]}")


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    print("Rendering PepoConnect icons")
    icon = render_full_icon(1024)
    save(icon, "icon-1024.png")
    save(icon.resize((512, 512), Image.LANCZOS), "pepoconnect-512.png")
    save(icon.resize((256, 256), Image.LANCZOS), "pepoconnect-256.png")
    save(render_glyph_only(1024, 0.72, WHITE, SUN), "icon-foreground.png")
    save(render_glyph_only(1024, 0.80, WHITE), "icon-mono.png")
    save(render_tray(16, WHITE), "tray-16.png")
    save(render_tray(32, WHITE), "tray-32.png")
    save(render_tray(16, BLACK), "tray-16-dark.png")
    save(render_tray(32, BLACK), "tray-32-dark.png")
    favicon = icon.resize((256, 256), Image.LANCZOS)
    save(favicon, "favicon.ico", sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (256, 256)])
    return 0


if __name__ == "__main__":
    sys.exit(main())
