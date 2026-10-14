#!/usr/bin/env python3
"""Rebuild static fallbacks and the gallery. Development only: Python + Pillow + Node."""
import base64
import io
import json
from pathlib import Path
import subprocess

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'AsciiWallpaper/assets'
CATALOG = json.loads((ROOT / 'AsciiWallpaper/scenes/catalog.json').read_text())


def render(packet, cell=10):
    grid = Image.open(io.BytesIO(base64.b64decode(packet['grid'].split(',')[1])))
    atlas = Image.open(ASSETS / 'glyphs.png')
    masks = [atlas.crop((i * 48, 0, (i + 1) * 48, 48)).getchannel('A').resize(
        (cell, cell), Image.Resampling.LANCZOS) for i in range(4)]
    image = Image.new('RGB', (packet['cols'] * cell, packet['rows'] * cell), packet['ground'])
    tiles = {}
    for y in range(packet['rows']):
        for x in range(packet['cols']):
            glyph, color, _, _ = grid.getpixel((x, y))
            if not glyph:
                continue
            key = glyph, color
            if key not in tiles:
                tile = Image.new('RGB', (cell, cell), packet['ground'])
                tile.paste(Image.new('RGB', (cell, cell), packet['colors'][color]), mask=masks[glyph])
                tiles[key] = tile
            image.paste(tiles[key], (x * cell, y * cell))
    return image


def main():
    (ASSETS / 'stills').mkdir(exist_ok=True)
    (ROOT / 'docs').mkdir(exist_ok=True)
    width, height, label, gap = 600, 300, 36, 20
    gallery = Image.new('RGB', (3 * width + 4 * gap, 5 * (height + label) + 6 * gap), '#1e1e2e')
    draw = ImageDraw.Draw(gallery)
    try:
        font = ImageFont.truetype('DejaVuSansMono.ttf', 18)
    except OSError:
        font = ImageFont.load_default(size=18)
    for i, entry in enumerate(CATALOG):
        packet = json.loads(subprocess.check_output(['node', str(ROOT / 'scripts/export-frame.mjs'), entry['slug']], text=True))
        image = render(packet)
        image.save(ASSETS / 'stills' / (entry['slug'] + '.png'), optimize=True)
        x, y = gap + (i % 3) * (width + gap), gap + (i // 3) * (height + label + gap)
        gallery.paste(image.resize((width, height), Image.Resampling.LANCZOS), (x, y))
        draw.text((x, y + height + 8), entry['name'], fill='#cdd6f4', font=font)
        print(entry['slug'])
    gallery.save(ROOT / 'docs/scenes.png', optimize=True)


if __name__ == '__main__':
    main()
