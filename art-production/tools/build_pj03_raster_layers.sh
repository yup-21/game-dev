#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
p=art-production/candidates/scenes/pingjiang_riverside_market
out="$p/layers-v02"
# Model source and normalized clean plate are preserved alongside these layers.
magick "$p/environment_pingjiang_riverside_market_master_v01.webp" -crop 4800x580+0+0 +repage -background none -gravity north -extent 4800x1000 -quality 94 "$out/background.webp"
magick "$out/clean_plate.webp" -crop 4800x420+0+580 +repage -background none -gravity south -extent 4800x1000 -quality 94 "$out/ground.webp"
magick "$out/source_foreground.png" -crop 2172x155+0+440 +repage -resize 4800x320! -background none -gravity south -extent 4800x1000 -quality 94 "$out/foreground.webp"
magick "$out/background.webp" "$out/ground.webp" -compose over -composite "$out/foreground.webp" -compose over -composite -quality 94 "$out/composite.webp"
# Explicit import is separate: review layers before replacing Resource-bound copies.
