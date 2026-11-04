#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
p=art-production/candidates/scenes/pingjiang_riverside_market
out="$p/layers-v02"
# Rebuild only damaged WebP derivatives. The already-reviewed alpha ground and
# foreground are canonical; their original clean-plate/foreground model outputs
# cannot be recovered from a truncated WebP upload.
magick "$p/environment_pingjiang_riverside_market_master_v01.webp" \
  -crop 4800x580+0+0 +repage -background none -gravity north \
  -extent 4800x1000 -define webp:method=6 -quality 85 "$out/background.webp"
magick "$out/background.webp" "$out/ground.webp" -compose over -composite \
  -define webp:method=6 -quality 76 "$out/clean_plate.webp"
magick "$out/clean_plate.webp" "$out/foreground.webp" -compose over -composite \
  -define webp:method=6 -quality 76 "$out/composite.webp"
# Keep the dedicated QA Resource's in-use mirror in sync with its candidate.
cp "$out/background.webp" demos/changfeng-battle/assets/imported/scenes/pingjiang_riverside_market/background_v02.webp
# Source ground/foreground and their in-use mirrors are intentionally untouched.
