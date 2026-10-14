#!/usr/bin/env sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
qsb=${QSB:-qsb}
"$qsb" --qsbversion 65 --glsl '100 es,120,150' --hlsl 50 --msl 12 \
    -o "$root/AsciiWallpaper/assets/scene.frag.qsb" "$root/AsciiWallpaper/assets/scene.frag"
