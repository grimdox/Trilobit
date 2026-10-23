#!/bin/bash
# Copy the baked district tilesets into the game: sets/<theme> -> godot-spike/gfx/tiles_<theme>.  Run after a bake.
set -e
cd "$(dirname "$0")/.."
GAME=${GAME:-../godot-spike}
for d in sets/*/; do
  th=$(basename "$d")
  [ -f "$d/tile_config.json" ] || continue
  mkdir -p "$GAME/gfx/tiles_$th"
  cp "$d/tile_config.json" "$d/sheet_tiles.png" "$GAME/gfx/tiles_$th/"
done
echo "synced $(ls -d sets/*/ | wc -l) tilesets into $GAME/gfx"
