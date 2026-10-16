#!/bin/bash
# Run every spike test headless.  Needs Godot 4.3 on the PATH as `godot`.  Exit code is non-zero if any test fails or does not finish.
cd "$(dirname "$0")"
python3 tools/export_items.py
rc=0
for t in pockets world scale levels game vertical guns stealth zmove melee npcfall things menus vehicles island combat facing; do
  out=$(timeout -s KILL 280 godot --headless --path . -s tests/run_$t.gd 2>&1)
  echo "$out" | grep -E "FAIL|SCRIPT ERROR|^[A-Z]+ [0-9]+/[0-9]+|^\s+\("
  line=$(echo "$out" | grep -E "^[A-Z]+ [0-9]+/[0-9]+" | tail -1)
  p=$(echo "$line" | sed -E 's/^[A-Z]+ ([0-9]+)\/([0-9]+).*/\1/'); n=$(echo "$line" | sed -E 's/^[A-Z]+ ([0-9]+)\/([0-9]+).*/\2/')
  if [ -z "$line" ] || [ "$p" != "$n" ]; then echo "  >> $t FAILED"; rc=1; fi
done
exit $rc
