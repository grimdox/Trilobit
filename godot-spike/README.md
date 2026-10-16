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
`<` `>` stairs and elevators (or, with jump jets, fly up and down); `e` gets into gyros (flying) and mechs; `q` + direction jumps, off an edge you fall; `w` + direction strikes at reach; `\\` swaps weapon; `o` + direction shoves people, crates, tables, chairs and animals (or just walk into a crate to push it).  Ripperdocs sell leg actuators and jump jets.  25 Japanese and Russian melee weapons in three grades.

## Guns
`f` fire at the target (Shift+F at anyone), Tab cycle targets, `a` aim (stacks to 3 turns), `r` reload or clear a jam, `v` fire mode, `x` next ammunition kind, `F4` gunsmith (fit scopes, suppressors, magazines, grips, stocks, barrels).

## Round five: the island, scale, menus, combat
- **World**: `src/island.gd` generates a 2304x1408 island from a seed (west harbor, one mountain range with a thin winding pass carrying a 12-wide highway and a 4-wide railway, the city, a small town, plains and fields, a sheer east cliff, rocky north and south shores).  It is a 5x3 grid of 512x512 zones that overlap; `src/world.gd` keeps one zone Game live and swaps zones at the border, carrying the player and any vehicle.  `M` opens the island map with a you-are-here marker.
- **Vehicles** (`src/vehicles.gd`): cars 4x6 (2x2 cabin, engine bay, trunk), trucks, helicopters, planes, mechs; engines swap (`Shift+E` / `F6`), parts take damage; NPCs drive.  Roads are 12 wide (two lanes of six), rail corridors 4 wide.
- **Menus**: title, options (rebind keys, sound), Esc pause with save slots, load, implants body map (`F3`).
- **Combat**: per-limb health (`src/body.gd`; head/chest at 0 is death, other limbs go offline), flat-deduction armor on worn items and implants that wears out, ranged accuracy from sights/scope/brain and eye implants, aim speed, cover, bullet dodge only from grade 3+ implants, melee accuracy/attack speed/dodge, parry and riposte hooks (`melee_arts`).  HP, armor and a body diagram are drawn top right.
Tests: `./run_all.sh` (pockets, world, scale, levels, game, vertical, guns, stealth, zmove, melee, npcfall, things, menus, vehicles, island, combat).  Screenshots: `xvfb-run -a godot --path . --rendering-driver opengl3 -s tests/shot3.gd`.
