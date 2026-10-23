#!/bin/bash
# After adding or changing tiles: bake (only what changed is drawn again), check, and copy the sets into the game.
set -e
cd "$(dirname "$0")"
t0=$(date +%s)
python3 tools/tilegen/bake.py sets
python3 tools/tilegen/qa.py sets ../godot-spike/gfx/Trilobit64/tile_config.json
[ -n "$NO_SYNC" ] || bash tools/sync_to_game.sh
echo "update done in $(( $(date +%s) - t0 ))s"
