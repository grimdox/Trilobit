#!/bin/bash
# Bake every district tileset, check it (QA T1-T7), prove the bake is deterministic, and write the review sheets.
# Usage: bash run_all.sh [SHEETS_DIR]   (sheets default to ./review)
set -e
cd "$(dirname "$0")"
python3 tools/tilegen/bake.py sets
python3 tools/tilegen/qa.py sets ../godot-spike/gfx/Trilobit64/tile_config.json
tmp=$(mktemp -d)
python3 tools/tilegen/bake.py "$tmp" --no-cache >/dev/null
for th in sets/*/; do
  t=$(basename "$th")
  cmp -s "$th/sheet_tiles.png" "$tmp/$t/sheet_tiles.png" && cmp -s "$th/tile_config.json" "$tmp/$t/tile_config.json" \
    || { echo "  FAIL $t: a cached bake differs from a fresh one"; exit 1; }
done
rm -rf "$tmp"
echo "  PASS cached and fresh bakes are byte-identical"
python3 tools/tilegen/sheets.py sets "${1:-review}"
