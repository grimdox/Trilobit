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
# the game loads its sheets as imported textures: re-import so a sheet that grew is not read through a stale import
# (a stale import cuts off the sprites past its old size).  Needs godot on PATH; the editor does the same on opening.
if command -v godot >/dev/null; then
  (cd "$GAME" && godot --headless --import >/dev/null 2>&1) && echo "re-imported the game's resources"
else
  echo "godot is not on PATH: open the project in the editor (or run godot --headless --import) before playing"
fi
