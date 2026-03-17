#!/usr/bin/env python3
"""Extract typeness app icon silhouette as menu bar template icon - no corners, bigger."""

from PIL import Image
import os, subprocess, tempfile, shutil

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESOURCES = os.path.join(PROJECT, "Murmur", "Resources")
SOURCE = os.path.expanduser("~/project/typeness/icon.icns")


def main():
    os.makedirs(RESOURCES, exist_ok=True)

    iconset = tempfile.mkdtemp(suffix=".iconset")
    subprocess.run(["iconutil", "-c", "iconset", SOURCE, "-o", iconset], check=True)

    src = Image.open(os.path.join(iconset, "icon_256x256.png")).convert("RGBA")

    # Crop more aggressively to remove rounded corners and zoom in on content
    w, h = src.size
    pad = int(w * 0.22)  # tighter crop = bigger silhouette
    cropped = src.crop((pad, pad, w - pad, h - pad))

    for sz, suffix in [(18, ""), (36, "@2x")]:
        resized = cropped.resize((sz, sz), Image.LANCZOS)

        out = Image.new("RGBA", (sz, sz), (0, 0, 0, 0))
        pixels = resized.load()
        out_pixels = out.load()

        for y in range(sz):
            for x in range(sz):
                r, g, b, a = pixels[x, y]
                lum = 0.299 * r + 0.587 * g + 0.114 * b
                if lum > 140:
                    alpha = min(255, int((lum - 140) / (255 - 140) * 255))
                    out_pixels[x, y] = (0, 0, 0, alpha)

        path = os.path.join(RESOURCES, f"MenuBarIcon{suffix}.png")
        out.save(path)
        print(f"  wrote {path}")

    shutil.rmtree(iconset)
    print("Done!")


if __name__ == "__main__":
    main()
