#!/bin/bash
# Every check on a baked set: Python QA, Godot data and runtime tests, pixel fidelity (needs xvfb).  Run after bake.py.
# GODOT defaults to `godot` on PATH; ITEMS to the game's item list.
cd "$(dirname "$0")"
GODOT=${GODOT:-godot}
ITEMS=${ITEMS:-../godot-spike/data/items.json}
rc=0
$GODOT --headless --path . --import >/dev/null 2>&1
for lod in 64 32; do
  set=dolls; [ $lod = 32 ] && set=dolls32
  [ -f $set/dolls.json ] || { echo "no $set: skipped"; continue; }
  echo "== $set (LOD $lod)"
  python3 tools/dollgen/qa.py $set tests/qa_report_$lod.json || rc=1
  out=$(timeout 600 $GODOT --headless --path . -s tests/run_tests.gd -- res://$set 2>&1)
  echo "$out" | grep -E "PASS|FAIL|DOLLS|repairs|SCRIPT ERROR"
  echo "$out" | grep -qE "^DOLLS ([0-9]+)/\1$" || rc=1
  python3 tools/dollgen/expect.py "$ITEMS" tests/expected_$lod $lod >/dev/null || rc=1
  out=$(timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --path . --rendering-driver opengl3 -s tests/render_check.gd -- res://$set res://tests/expected_$lod 2>&1)
  echo "$out" | grep -E "PASS|FAIL|RENDER|SCRIPT ERROR"
  echo "$out" | grep -qE "^RENDER ([0-9]+)/\1$" || rc=1
done
exit $rc
