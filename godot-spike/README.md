# Trilobit Godot spike

A time-boxed test of whether Godot 4 can carry Trilobit instead of CDDA.  Three pass/fail tests, run headless with `./run_all.sh`
(Godot 4.3, GDScript only, no C++).  Plan, results and what the spike does not prove are in the Project doc "Trilobit Godot Spike Plan".

| Test | Files |
|---|---|
| 1. NPC scale with level of detail | `src/flowfield.gd`, `src/npc_sim.gd`, `tests/test_scale.gd` |
| 2. Pocket inventory | `src/item.gd`, `src/item_db.gd`, `tests/test_pockets.gd`, `tools/export_items.py` |
| 3. Anchored overworld and a city | `src/worldgen.gd`, `src/citygen.gd`, `data/anchors.json`, `tests/test_world.gd` |

## Keys added in round three
`<` / PgUp go up, `>` / PgDn go down (stairs, elevators, ladders; an elevator rides three floors), `t` talk, `p` pay 100 on the debt (Shift+P 1000).  Walk into a locked door to pick it; step onto a carriage while the train doors are open to board.
## Movement and stealth
`c` crouch, `z` crawl, Shift+direction run, `q` then a direction jump.  People look in a cone and hear your steps by stance; strike unaware people from behind for a quiet kill; use crates, dumpsters, planters and railings as cover.

## Levels, implants and melee
`<` `>` stairs and elevators (or, with jump jets, fly up and down); `e` gets into gyros (flying) and mechs; `q` + direction jumps, off an edge you fall; `w` + direction strikes at reach; `\\` swaps weapon.  Ripperdocs sell leg actuators and jump jets.  25 Japanese and Russian melee weapons in three grades.

## Guns
`f` fire at the target (Shift+F at anyone), Tab cycle targets, `a` aim (stacks to 3 turns), `r` reload or clear a jam, `v` fire mode, `x` next ammunition kind, `m` gunsmith (fit scopes, suppressors, magazines, grips, stocks, barrels).
Tests: `./run_all.sh` (pockets, world, scale, levels, game, vertical, guns, stealth, zmove, melee).  Screenshots: `xvfb-run -a godot --path . --rendering-driver opengl3 -s tests/shot3.gd`.
