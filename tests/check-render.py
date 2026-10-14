#!/usr/bin/env python3
"""Detect empty/flat frames and large brightness dips in verify.qml captures."""
from pathlib import Path
import sys
from PIL import Image, ImageStat

files = sorted(Path(sys.argv[1]).glob('*.png'))
assert files, 'No rendered captures'
means = []
for path in files:
    image = Image.open(path).convert('L')
    stats = ImageStat.Stat(image)
    assert stats.stddev[0] > 5, f'Blank or flat frame: {path}'
    means.append(stats.mean[0])
assert max(means) - min(means) < 4, f'Brightness dip: {min(means):.2f}–{max(means):.2f}'
print(f'{len(files)} captures; no blank frames; brightness {min(means):.2f}–{max(means):.2f}')
