# Trilobit Godot spike

A time-boxed test of whether Godot 4 can carry Trilobit instead of CDDA.  Three pass/fail tests, run headless with `./run_all.sh`
(Godot 4.3, GDScript only, no C++).  Plan, results and what the spike does not prove are in the Project doc "Trilobit Godot Spike Plan".

| Test | Files |
|---|---|
| 1. NPC scale with level of detail | `src/flowfield.gd`, `src/npc_sim.gd`, `tests/test_scale.gd` |
| 2. Pocket inventory | `src/item.gd`, `src/item_db.gd`, `tests/test_pockets.gd`, `tools/export_items.py` |
| 3. Anchored overworld and a city | `src/worldgen.gd`, `src/citygen.gd`, `data/anchors.json`, `tests/test_world.gd` |
