#!/bin/bash
# usage: tests/runt.sh <name> [timeout_s] [max_lines]   parse-checks tests/test_<name>.gd, then runs tests/run_<name>.gd with a hard timeout
cd "$(dirname "$0")/.."
out=/tmp/claude-0/t_$1.txt
timeout -s KILL 40 godot --headless --path . --check-only -s tests/test_$1.gd > $out.chk 2>&1
if grep -q "Parse Error\|Compile Error" $out.chk; then grep -A1 "Error" $out.chk | head -20; echo "PARSE FAILED"; exit 1; fi
timeout -s KILL ${2:-100} godot --headless --path . -s tests/run_$1.gd > $out 2>&1
grep -E "FAIL|SCRIPT ERROR|Parse Error|^[A-Z]+ [0-9]+/[0-9]+|^\s+\(" $out | head -${3:-30}
