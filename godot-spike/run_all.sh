#!/bin/bash
# Run the three spike tests headless.  Needs Godot 4.3 on the PATH as `godot`.  Exit code is non-zero if any test fails.
cd "$(dirname "$0")"
python3 tools/export_items.py
rc=0
for t in pockets world scale game; do
  timeout 280 godot --headless --path . -s tests/run_$t.gd 2>&1 | grep -v "^$\|Godot Engine" || rc=1
done
exit $rc
