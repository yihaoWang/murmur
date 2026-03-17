#!/usr/bin/env python3
"""Generate menu bar template icon matching typeness style - slim person + sound waves."""

from PIL import Image, ImageDraw
import os, math

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESOURCES = os.path.join(PROJECT, "Murmur", "Resources")


def draw_menubar(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = size

    # Slim head (small circle)
    cx = int(s * 0.30)
    head_cy = int(s * 0.28)
    head_r = max(int(s * 0.10), 2)
    d.ellipse([cx - head_r, head_cy - head_r, cx + head_r, head_cy + head_r],
              fill=(0, 0, 0, 255))

    # Slim neck
    neck_w = max(int(s * 0.05), 1)
    neck_top = head_cy + head_r - 1
    neck_bot = int(s * 0.46)
    d.rectangle([cx - neck_w, neck_top, cx + neck_w, neck_bot], fill=(0, 0, 0, 255))

    # Slim shoulders (thin trapezoid)
    shoulder_top = neck_bot - 1
    shoulder_bot = int(s * 0.72)
    shoulder_w_top = int(s * 0.10)
    shoulder_w_bot = int(s * 0.26)
    # Draw as polygon for slimmer look
    d.polygon([
        (cx - shoulder_w_top, shoulder_top),
        (cx + shoulder_w_top, shoulder_top),
        (cx + shoulder_w_bot, shoulder_bot),
        (cx - shoulder_w_bot, shoulder_bot),
    ], fill=(0, 0, 0, 255))

    # Round bottom of shoulders
    r = max(int(s * 0.04), 1)
    d.ellipse([cx - shoulder_w_bot - r//2, shoulder_bot - r,
               cx - shoulder_w_bot + r + r//2, shoulder_bot + r], fill=(0, 0, 0, 255))
    d.ellipse([cx + shoulder_w_bot - r - r//2, shoulder_bot - r,
               cx + shoulder_w_bot + r//2, shoulder_bot + r], fill=(0, 0, 0, 255))

    # Sound waves (3 arcs from mouth area)
    wave_cx = cx + int(s * 0.14)
    wave_cy = int(s * 0.38)
    for i in range(3):
        r = int(s * (0.12 + i * 0.10))
        lw = max(int(s * 0.055), 1)
        bbox = [wave_cx - r, wave_cy - r, wave_cx + r, wave_cy + r]
        d.arc(bbox, start=-38, end=38, fill=(0, 0, 0, 255), width=lw)

    return img


def main():
    os.makedirs(RESOURCES, exist_ok=True)
    for sz, suffix in [(18, ""), (36, "@2x")]:
        icon = draw_menubar(sz)
        path = os.path.join(RESOURCES, f"MenuBarIcon{suffix}.png")
        icon.save(path)
        print(f"  wrote {path}")
    print("Done!")


if __name__ == "__main__":
    main()
