#!/bin/bash
# Run every spike test headless.  Needs Godot 4.3 on the PATH as `godot`.  Exit code is non-zero if any test fails or does not finish.
cd "$(dirname "$0")"
python3 tools/export_items.py
python3 tools/content/gen_paperdoll.py data/items.json gfx/paperdoll
python3 tools/content/gen_figures.py data/items.json gfx/figure
rc=0
python3 tools/content/check_figures.py data/items.json || { echo "  >> figures FAILED"; rc=1; }
for t in pockets world scale levels game vertical guns stealth zmove melee npcfall things menus vehicles island combat facing trains needs skills citylayout bigcity remake timeui marks ap ranged npcparts creation missions power lots batch2 cars dolls; do
  out=$(timeout -s KILL 280 godot --headless --path . -s tests/run_$t.gd 2>&1)
  echo "$out" | grep -E "FAIL|SCRIPT ERROR|^[A-Z]+ [0-9]+/[0-9]+|^\s+\("
  line=$(echo "$out" | grep -E "^[A-Z]+ [0-9]+/[0-9]+" | tail -1)
  p=$(echo "$line" | sed -E 's/^[A-Z]+ ([0-9]+)\/([0-9]+).*/\1/'); n=$(echo "$line" | sed -E 's/^[A-Z]+ ([0-9]+)\/([0-9]+).*/\2/')
  if [ -z "$line" ] || [ "$p" != "$n" ]; then echo "  >> $t FAILED"; rc=1; fi
done
exit $rc
