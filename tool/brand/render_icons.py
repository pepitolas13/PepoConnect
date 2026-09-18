"""Renders the PepoConnect icons from the same geometry as assets/brand/pepoconnect.svg.

Pillow only (no cairosvg / resvg). Everything is drawn at 4x and downsampled.

    python tool/brand/render_icons.py

Outputs:
  assets/icon/*.png, favicon.ico          sources for flutter_launcher_icons, tray, Linux
  windows/runner/resources/app_icon.ico   Windows app icon (title bar, taskbar, exe, launcher)
  android/app/src/main/res/drawable-*/ic_stat_pepoconnect.png
                                          Android status-bar icon (notifications, foreground
                                          service): white glyph on transparent, 24 dp
"""
from __future__ import annotations

import io
import os
import struct
import sys

from PIL import Image, ImageChops, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "icon")
WINDOWS_ICO = os.path.join(ROOT, "windows", "runner", "resources", "app_icon.ico")
ANDROID_RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

# Sizes Windows asks for: 16/20/24 (title bar, tray at 100-150 %), 32/40/48 (taskbar,
# Alt-Tab), 64/96/128 (Explorer views), 256 (jumbo). Everything below PNG_FROM is stored
# as an uncompressed 32-bit DIB, which is what LoadIcon/LoadImage and every shell
# component understand; only the 256 px image is PNG-compressed, as Windows expects.
WINDOWS_ICO_SIZES = [16, 20, 24, 32, 40, 48, 64, 96, 128, 256]
TRAY_ICO_SIZES = [16, 20, 24, 32, 40, 48, 64, 256]
PNG_FROM = 256

# Android status-bar icon: 24 dp at every density.
ANDROID_STATUS_ICON = "ic_stat_pepoconnect.png"
ANDROID_DENSITIES = {"mdpi": 24, "hdpi": 36, "xhdpi": 48, "xxhdpi": 72, "xxxhdpi": 96}
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


def dib_entry(frame: Image.Image) -> bytes:
    """32-bit BGRA DIB (BITMAPINFOHEADER, XOR bitmap, 1-bit AND mask) for an ICO entry."""
    w, h = frame.size
    header = struct.pack("<IiiHHIIiiII", 40, w, h * 2, 1, 32, 0, 0, 0, 0, 0, 0)
    px = frame.load()
    xor = bytearray(w * h * 4)
    and_row = ((w + 31) // 32) * 4
    and_mask = bytearray(and_row * h)
    i = 0
    for y in range(h - 1, -1, -1):  # DIBs are stored bottom-up
        row = (h - 1 - y) * and_row
        for x in range(w):
            r, g, b, a = px[x, y]
            xor[i : i + 4] = (b, g, r, a)
            i += 4
            if a == 0:  # AND bit set = transparent (for renderers that ignore alpha)
                and_mask[row + (x >> 3)] |= 0x80 >> (x & 7)
    return header + bytes(xor) + bytes(and_mask)


def encode_ico(source: Image.Image, sizes: list[int], png_from: int = PNG_FROM) -> bytes:
    """ICO container: DIB entries below `png_from`, PNG entries from there on."""
    entries: list[tuple[int, bytes]] = []
    for size in sizes:
        frame = source.resize((size, size), Image.LANCZOS).convert("RGBA")
        if size >= png_from:
            buf = io.BytesIO()
            frame.save(buf, format="PNG")
            data = buf.getvalue()
        else:
            data = dib_entry(frame)
        entries.append((size, data))
    directory = bytearray(struct.pack("<HHH", 0, 1, len(entries)))
    offset = 6 + 16 * len(entries)
    body = bytearray()
    for size, data in entries:
        directory += struct.pack(
            "<BBBBHHII", size % 256, size % 256, 0, 0, 1, 32, len(data), offset + len(body)
        )
        body += data
    return bytes(directory + body)


def report(path: str, detail: str) -> None:
    print(f"  {os.path.relpath(path, ROOT)}  {detail}")


def save(img: Image.Image, name: str) -> None:
    path = os.path.join(OUT, name)
    img.save(path)
    report(path, f"{img.size[0]}x{img.size[1]}")


def save_ico(source: Image.Image, path: str, sizes: list[int]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(encode_ico(source, sizes))
    report(path, "ico " + "/".join(str(s) for s in sizes))


def save_android_status_icons() -> None:
    for density, px in ANDROID_DENSITIES.items():
        folder = os.path.join(ANDROID_RES, f"drawable-{density}")
        os.makedirs(folder, exist_ok=True)
        path = os.path.join(folder, ANDROID_STATUS_ICON)
        img = render_tray(px, WHITE)
        img.save(path)
        report(path, f"{px}x{px}")


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
    # Windows: the tray icon (tray_manager loads it from the assets) and the app icon
    # compiled into pepoconnect.exe and stamped on the launcher.
    save_ico(icon, os.path.join(OUT, "favicon.ico"), TRAY_ICO_SIZES)
    save_ico(icon, WINDOWS_ICO, WINDOWS_ICO_SIZES)
    # Android: status-bar icon (Android only uses its alpha channel).
    save_android_status_icons()
    return 0


if __name__ == "__main__":
    sys.exit(main())
