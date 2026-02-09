#!/usr/bin/env python3
"""Generate the DMG background image for VibePad.

Produces dmg-resources/background@2x.png (1320x800 — Retina for a 660x400 window).

Design matches the VibePad website dark theme:
- Background: #0f1117
- Blue radial glow behind the app icon (left side)
- "VibePad" title in Inter ExtraBold (800) with left-to-right blue gradient
- Whimsical curved arrow between icon positions (supersampled for smooth edges)
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

# --- Constants (all in @2x pixels) ---
WIDTH, HEIGHT = 1320, 800
BG_COLOR = (15, 17, 23)  # #0f1117

# Icon positions (@2x)
ICON_LEFT_X = 360
ICON_RIGHT_X = 960
ICON_Y = 440

# Glow: centered on the left icon position
GLOW_CENTER = (ICON_LEFT_X, ICON_Y)
GLOW_RX, GLOW_RY = 400, 400
GLOW_COLOR = (105, 166, 247)  # #69A6F7
GLOW_ALPHA = 0.40

# Title gradient endpoints (left-to-right, matching website)
GRADIENT_LEFT = (105, 166, 247)   # #69A6F7 — blue
GRADIENT_RIGHT = (202, 237, 248)  # #CAEDF8 — light cyan

# Font
TITLE_SIZE = 72  # @2x

# Arrow supersample factor (draw at Nx, then downscale for smooth edges)
ARROW_SS = 4


def find_inter_font() -> str:
    """Find the Inter font on the system."""
    candidates = [
        Path.home() / "Library/Fonts/Inter.ttf",
        Path("/Library/Fonts/Inter.ttf"),
        Path("/System/Library/Fonts/Inter.ttf"),
        Path.home() / "Library/Fonts/Inter-Bold.ttf",
        Path("/Library/Fonts/Inter-Bold.ttf"),
    ]
    for p in candidates:
        if p.exists():
            return str(p)
    return None


def draw_radial_glow(img: Image.Image, center, rx, ry, color, alpha) -> None:
    """Draw a soft radial glow onto the image (composited)."""
    glow = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    pixels = glow.load()

    cx, cy = center
    for y in range(max(0, cy - ry), min(HEIGHT, cy + ry)):
        for x in range(max(0, cx - rx), min(WIDTH, cx + rx)):
            dx = (x - cx) / rx
            dy = (y - cy) / ry
            dist = math.sqrt(dx * dx + dy * dy)
            if dist < 1.0:
                intensity = (1.0 - dist) ** 2.0
                a = int(255 * alpha * intensity)
                pixels[x, y] = (*color, a)

    img.paste(Image.alpha_composite(img.convert("RGBA"), glow).convert("RGB"))


def draw_gradient_text(img: Image.Image, text: str, font: ImageFont.FreeTypeFont,
                       center_x: int, y: int) -> None:
    """Draw text with a horizontal (left-to-right) gradient fill."""
    dummy = Image.new("L", (WIDTH, HEIGHT), 0)
    dummy_draw = ImageDraw.Draw(dummy)
    bbox = dummy_draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]

    mask = Image.new("L", (tw, th), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.text((-bbox[0], -bbox[1]), text, fill=255, font=font)

    # Horizontal gradient (left-to-right)
    gradient = Image.new("RGB", (tw, th))
    gpx = gradient.load()
    for gx in range(tw):
        t = gx / max(tw - 1, 1)
        r = int(GRADIENT_LEFT[0] + t * (GRADIENT_RIGHT[0] - GRADIENT_LEFT[0]))
        g = int(GRADIENT_LEFT[1] + t * (GRADIENT_RIGHT[1] - GRADIENT_LEFT[1]))
        b = int(GRADIENT_LEFT[2] + t * (GRADIENT_RIGHT[2] - GRADIENT_LEFT[2]))
        for gy in range(th):
            gpx[gx, gy] = (r, g, b)

    x = center_x - tw // 2
    img.paste(gradient, (x, y), mask)


def bezier_point(t, p0, p1, p2, p3):
    """Evaluate cubic bezier at parameter t."""
    u = 1 - t
    return (
        u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0],
        u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1],
    )


def draw_curved_arrow(img: Image.Image) -> None:
    """Draw a whimsical curved arrow between the two icon positions.

    Renders at ARROW_SS× resolution then downscales with LANCZOS for
    perfectly smooth, anti-aliased edges.
    """
    ss = ARROW_SS
    sw, sh = WIDTH * ss, HEIGHT * ss
    overlay = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    # Scale icon positions
    lx, rx, iy = ICON_LEFT_X * ss, ICON_RIGHT_X * ss, ICON_Y * ss

    # Start/end — between the icon zones
    x0 = lx + 140 * ss
    x3 = rx - 140 * ss
    y_base = iy

    # Bezier control points — arc upward
    p0 = (x0, y_base + 10 * ss)
    p1 = (x0 + 120 * ss, y_base - 160 * ss)
    p2 = (x3 - 120 * ss, y_base - 160 * ss)
    p3 = (x3, y_base + 10 * ss)

    # Sample curve densely
    num_segments = 300
    points = []
    for i in range(num_segments + 1):
        t = i / num_segments
        points.append(bezier_point(t, p0, p1, p2, p3))

    # Draw solid thick curve
    arrow_color = (105, 166, 247, 210)
    stroke_w = 6 * ss
    for i in range(len(points) - 1):
        x1, y1 = int(points[i][0]), int(points[i][1])
        x2, y2 = int(points[i + 1][0]), int(points[i + 1][1])
        draw.line([(x1, y1), (x2, y2)], fill=arrow_color, width=stroke_w)

    # Round line cap at start
    cap_r = stroke_w // 2
    sx, sy = int(points[0][0]), int(points[0][1])
    draw.ellipse([sx - cap_r, sy - cap_r, sx + cap_r, sy + cap_r], fill=arrow_color)

    # Arrowhead — chevron (two lines) following the curve tangent
    t_end = 0.96
    near_end = bezier_point(t_end, p0, p1, p2, p3)
    end = bezier_point(1.0, p0, p1, p2, p3)
    dx = end[0] - near_end[0]
    dy = end[1] - near_end[1]
    length = math.sqrt(dx * dx + dy * dy)
    if length > 0:
        dx, dy = dx / length, dy / length

    # Perpendicular
    px, py = -dy, dx
    head_len = 36 * ss
    head_spread = 18 * ss
    tip_x, tip_y = int(end[0]), int(end[1])
    wing1 = (int(tip_x - head_len * dx + head_spread * px),
             int(tip_y - head_len * dy + head_spread * py))
    wing2 = (int(tip_x - head_len * dx - head_spread * px),
             int(tip_y - head_len * dy - head_spread * py))

    draw.line([(tip_x, tip_y), wing1], fill=arrow_color, width=stroke_w)
    draw.line([(tip_x, tip_y), wing2], fill=arrow_color, width=stroke_w)
    # Round cap at tip
    draw.ellipse([tip_x - cap_r, tip_y - cap_r, tip_x + cap_r, tip_y + cap_r], fill=arrow_color)

    # Downscale with LANCZOS for smooth anti-aliased edges
    overlay = overlay.resize((WIDTH, HEIGHT), Image.LANCZOS)

    # Composite
    base = img.convert("RGBA")
    result = Image.alpha_composite(base, overlay)
    img.paste(result.convert("RGB"))


def main():
    project_root = Path(__file__).resolve().parent.parent
    out_dir = project_root / "dmg-resources"
    out_dir.mkdir(exist_ok=True)
    out_path = out_dir / "background@2x.png"

    # Create base image
    img = Image.new("RGB", (WIDTH, HEIGHT), BG_COLOR)

    # Draw glow behind left icon (app icon position)
    print("Drawing icon glow...")
    draw_radial_glow(img, GLOW_CENTER, GLOW_RX, GLOW_RY, GLOW_COLOR, GLOW_ALPHA)

    # Draw title text
    font_path = find_inter_font()
    if font_path:
        print(f"Using font: {font_path}")
        font = ImageFont.truetype(font_path, TITLE_SIZE)
        # Set to ExtraBold (800) to match website design
        try:
            font.set_variation_by_axes([800, 0])  # wght=800, slnt=0
        except Exception:
            pass
    else:
        print("Inter font not found, using default")
        font = ImageFont.load_default()

    print("Drawing title text...")
    draw_gradient_text(img, "VibePad", font, WIDTH // 2, 80)

    # Draw whimsical curved arrow
    print("Drawing curved arrow...")
    draw_curved_arrow(img)

    # Save
    img.save(str(out_path), "PNG")
    print(f"Saved: {out_path}")
    print(f"Size: {WIDTH}x{HEIGHT} (@2x for {WIDTH // 2}x{HEIGHT // 2} window)")


if __name__ == "__main__":
    main()
