#!/bin/bash
# The whole update after adding or changing parts: bake both sets (only parts whose inputs changed are rendered; the
# rest come from .cache/), check them, and copy them into the game.  A colour preset alone: pass --palette-only.
#   bash update.sh                 # bake changed parts, check, sync to the game
#   bash update.sh --palette-only  # colours only: seconds
#   NO_SYNC=1 bash update.sh       # leave the game alone
# GODOT: the Godot 4.5 binary for the checks (default `godot` on PATH); ITEMS: the game's item list.
set -e
cd "$(dirname "$0")"
ITEMS=${ITEMS:-../godot-spike/data/items.json}
t0=$(date +%s)
python3 tools/dollgen/bake.py "$ITEMS" dolls "$@"
python3 tools/dollgen/bake.py "$ITEMS" dolls32 --lod 32 "$@"
t1=$(date +%s)
bash run_all.sh
t2=$(date +%s)
[ -n "$NO_SYNC" ] || bash tools/sync_to_game.sh
echo "update done: bake $((t1 - t0))s, checks $((t2 - t1))s"
