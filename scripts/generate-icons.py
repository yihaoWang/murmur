#!/usr/bin/env python3
"""Generate Murmur app icons inspired by the reference design.

Version 1 (App Icon): Dark rounded-rect background, head silhouette speaking with sound waves + cursor
Version 2 (Menu Bar): Simple monochrome sound-wave icon as template image
"""

from PIL import Image, ImageDraw, ImageFont
import math, os

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(PROJECT, "Murmur", "Assets.xcassets", "AppIcon.appiconset")
RESOURCES_DIR = os.path.join(PROJECT, "Murmur", "Resources")

# ── Version 1: App Icon ──────────────────────────────────────────────

def draw_app_icon(size=1024):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = size  # shorthand

    # Background: dark rounded rect (macOS style)
    bg_color = (30, 32, 44)
    corner = int(s * 0.22)
    d.rounded_rectangle([0, 0, s - 1, s - 1], radius=corner, fill=bg_color)

    # Head silhouette (circle head + trapezoid body)
    head_color = (200, 208, 220)
    cx, cy = int(s * 0.38), int(s * 0.36)
    head_r = int(s * 0.09)
    d.ellipse([cx - head_r, cy - head_r, cx + head_r, cy + head_r], fill=head_color)

    # Neck + shoulders (rounded body shape)
    body_top = cy + head_r - int(s * 0.02)
    body_bottom = int(s * 0.72)
    body_left = int(s * 0.18)
    body_right = int(s * 0.58)
    body_corner = int(s * 0.08)
    d.rounded_rectangle(
        [body_left, body_top, body_right, body_bottom],
        radius=body_corner, fill=head_color
    )

    # Mouth area - small arc to suggest speaking
    mouth_cx = cx + int(s * 0.07)
    mouth_cy = cy + int(s * 0.04)
    mouth_r = int(s * 0.025)
    d.ellipse(
        [mouth_cx - mouth_r, mouth_cy - mouth_r, mouth_cx + mouth_r, mouth_cy + mouth_r],
        fill=bg_color
    )

    # Sound waves (3 arcs radiating from mouth area)
    wave_cx = cx + int(s * 0.12)
    wave_cy = cy + int(s * 0.02)
    wave_colors = [
        (100, 140, 200, 255),
        (120, 160, 220, 220),
        (140, 180, 240, 180),
    ]
    for i, color in enumerate(wave_colors):
        r = int(s * (0.08 + i * 0.06))
        lw = max(int(s * 0.018), 2)
        # Draw arc segment (~60 degrees)
        bbox = [wave_cx - r, wave_cy - r, wave_cx + r, wave_cy + r]
        d.arc(bbox, start=-40, end=40, fill=color, width=lw)

    # Cursor arrow (small, bottom-right of waves)
    cursor_x = int(s * 0.62)
    cursor_y = int(s * 0.50)
    cs = int(s * 0.08)
    arrow = [
        (cursor_x, cursor_y),
        (cursor_x, cursor_y + cs),
        (cursor_x + int(cs * 0.35), cursor_y + int(cs * 0.75)),
        (cursor_x + int(cs * 0.55), cursor_y + int(cs * 1.05)),
        (cursor_x + int(cs * 0.72), cursor_y + int(cs * 0.88)),
        (cursor_x + int(cs * 0.50), cursor_y + int(cs * 0.60)),
        (cursor_x + int(cs * 0.78), cursor_y + int(cs * 0.38)),
        (cursor_x, cursor_y),
    ]
    d.polygon(arrow, fill=(200, 208, 220))

    # Subtle text "Murmur" at bottom
    text_y = int(s * 0.80)
    font_size = int(s * 0.07)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/SFCompact.ttf", font_size)
    except (OSError, IOError):
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
        except (OSError, IOError):
            font = ImageFont.load_default()

    text_color = (160, 170, 190)
    bbox = d.textbbox((0, 0), "Murmur", font=font)
    tw = bbox[2] - bbox[0]
    d.text((int((s - tw) / 2), text_y), "Murmur", fill=text_color, font=font)

    return img


# ── Version 2: Menu Bar Icon (template) ─────────────────────────────

def draw_menubar_icon(size=32):
    """Simple sound wave icon - monochrome for macOS template rendering."""
    # Menu bar template images: use black on transparent, macOS will handle light/dark
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = size
    cx = int(s * 0.35)
    cy = int(s * 0.5)

    # Simple mic/head dot
    dot_r = max(int(s * 0.10), 2)
    d.ellipse([cx - dot_r, cy - dot_r - int(s*0.08), cx + dot_r, cy + dot_r - int(s*0.08)], fill=(0, 0, 0, 255))

    # Small body
    body_w = int(s * 0.18)
    body_h = int(s * 0.20)
    body_top = cy + int(s * 0.02)
    d.rounded_rectangle(
        [cx - body_w, body_top, cx + body_w, body_top + body_h],
        radius=max(int(s * 0.06), 1), fill=(0, 0, 0, 255)
    )

    # Sound waves
    wave_cx = cx + int(s * 0.12)
    wave_cy = cy - int(s * 0.04)
    for i in range(3):
        r = int(s * (0.12 + i * 0.10))
        lw = max(int(s * 0.06), 1)
        bbox = [wave_cx - r, wave_cy - r, wave_cx + r, wave_cy + r]
        d.arc(bbox, start=-35, end=35, fill=(0, 0, 0, 255), width=lw)

    return img


# ── Generate all sizes ───────────────────────────────────────────────

def main():
    os.makedirs(ASSETS_DIR, exist_ok=True)
    os.makedirs(RESOURCES_DIR, exist_ok=True)

    # Version 1: App icon at all required sizes
    icon = draw_app_icon(1024)
    for sz in [1024, 512, 256, 128, 64, 32, 16]:
        resized = icon.resize((sz, sz), Image.LANCZOS)
        path = os.path.join(ASSETS_DIR, f"AppIcon_{sz}.png")
        resized.save(path)
        print(f"  wrote {path}")

    # Also save 1024 as Resources/AppIcon.png (used by setupApp)
    icon.save(os.path.join(RESOURCES_DIR, "AppIcon.png"))
    print(f"  wrote Resources/AppIcon.png")

    # Version 2: Menu bar icon (template images)
    for sz, suffix in [(18, ""), (36, "@2x")]:
        mb = draw_menubar_icon(sz)
        path = os.path.join(RESOURCES_DIR, f"MenuBarIcon{suffix}.png")
        mb.save(path)
        print(f"  wrote {path}")

    print("\nDone! Menu bar icons are template images (black on transparent).")
    print("Set isTemplate=true in code for macOS to auto-adapt to light/dark mode.")


if __name__ == "__main__":
    main()
