#!/bin/bash
# Copy the doll runtime and both baked sets into the game (godot-spike): addons/trilobit_doll, gfx/dolls (64 px, the
# creation screen) and gfx/dolls32 (32 px, the world view).  Run after a bake; the game's own tests then check them.
set -e
cd "$(dirname "$0")/.."
GAME=${GAME:-../godot-spike}
mkdir -p "$GAME/addons/trilobit_doll"
cp addons/trilobit_doll/*.gd addons/trilobit_doll/*.gdshader "$GAME/addons/trilobit_doll/"
for set in dolls dolls32; do
  [ -f $set/dolls.json ] || { echo "no $set: bake it first"; exit 1; }
  rm -f "$GAME/gfx/$set"/doll_*.png "$GAME/gfx/$set"/doll_*.png.import "$GAME/gfx/$set/dolls.json"
  mkdir -p "$GAME/gfx/$set"
  cp $set/dolls.json $set/doll_*.png "$GAME/gfx/$set/"     # the game imports them with its own .import files
done
echo "synced the runtime, dolls and dolls32 into $GAME"
