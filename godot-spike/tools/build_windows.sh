#!/bin/bash
# Export the Windows build, stamp the icon and version info into it (no Wine needed) and zip it with a short readme.
# usage: tools/build_windows.sh [version, default 0.19.0.0]
set -e
cd "$(dirname "$0")/.."
VER=${1:-0.19.0.0}
python3 tools/export_items.py
python3 ../trilobit-tools/gen_paperdoll.py data/items.json gfx/paperdoll
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --export-release "Windows Desktop" build/Trilobit.exe 2>&1 | grep -E "ERROR|error" || true
python3 tools/set_exe_icon.py build/Trilobit.exe gfx/icon.ico "Trilobit" "Trilobit" "$VER" "Trilobit"
cat > build/README-FIRST.txt <<'T'
TRILOBIT - how to run

1. Unzip, then double-click Trilobit.exe.
2. If Windows shows "Windows protected your PC": click "More info", then "Run anyway".
   (The build is not code-signed yet, so Windows does not know the publisher.  It is only that warning.)
   To avoid it: right-click the downloaded .zip, choose Properties, tick "Unblock", OK, and only then unzip.
T
rm -f build/Trilobit-windows.zip
(cd build && zip -q Trilobit-windows.zip Trilobit.exe README-FIRST.txt)
ls -la build/Trilobit-windows.zip
