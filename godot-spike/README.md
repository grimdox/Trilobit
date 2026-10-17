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

## Round six
- Fixed a crash when stepping onto the railway in any zone without a subway (`transit.car_cell` took a modulo by an empty ring).
- Exe icon (the splash-screen car, `trilobit-tools/gen_icon.py`) and version info are stamped by `tools/set_exe_icon.py`; `tools/build_windows.sh` exports, stamps and zips.
- Loading screen shows とりろびつ (bundled kana subset of Noto Sans CJK JP, OFL); the title tag line is gone; menus take mouse hover, click, right-click back and wheel.
- Everyone has an on-screen facing arrow (people, animals, you); the drawn vision-cone tint is removed.  The player sees a 180 degree half circle (`vision_arc()`; implants may add degrees with an `arc` field); `;` + direction turns without a step.  NPCs still look back at you all round (`fov.around`).
- Windows SmartScreen only goes away with a trusted code-signing certificate; see README-FIRST.txt in the zip for the workaround.

## City layout, districts and the harbor
- The city's blocks are merged into bigger buildings: mega-towers fill 2-3 blocks each way (4-9 blocks) in the centre, the ring around them has buildings 1-2 blocks wide (1-4 blocks), and houses/venues sit in the outer suburbs.  Mega-towers are always among the tallest.
- Wealth districts (`CityGen.wealth`, lower / middle / upper): bare concrete and dingy tint, plain, or marble and bright tint; venue tier, residents' cash and clothes follow the district.  The HUD shows the district name.
- The harbor: north end = unaffiliated criminals (faction GANG) around derelict warehouses, centre = the working port (quay road with AI trucks, six animated gantry cranes, container yard, dock workers in hard hats), south end = Bratva around the dormitories.
- `trilobit-tools/gen_tiles64.py` draws the whole 64x64 tileset (terrain, furniture, harbor props, items, animals, top-down paper dolls); `tools/build_windows.sh` runs it.

## Rail line, side panel, hunger and thirst
- One rail line, three trains in a repeating loop (`transit.gd`).  Tracks are two tiles wide and the line is two-track (four rows apart); a train is four tiles wide (wall/door lane, two floor lanes you can stand and walk in, wall/door lane) and each carriage is six tiles long, four carriages to a train; the two middle tiles of each side wall are the doors, which open at stops.  The route: the four city stations (level -1, 30-tile platforms on both sides of the train), a twin-track tunnel west to a portal, the island railway through the pass, the Harbor Terminal (platform on the port siding), buffers, and back on the return track.  Trains are stateless (a tabulated timetable indexed by a clock that travels with the player), so every zone game draws just its part of the line; riders carry across the zone border.  Step onto a carriage while its doors are open to board, onto a platform to leave.
- The right-hand side panel (`view.gd _draw_hud`) shows place/time/yen, an empty NAV IMPLANT bay (the minimap is a purchasable upgrade, not built yet), an anatomical figure tinted per limb, limb meters with armour, health/armour/stamina, food and water meters, status effects, speed, heat, carry weight and the gun.
- F11 or Alt+Enter toggles exclusive fullscreen (covers the Windows taskbar); remembered in settings.  `--fullscreen` starts that way.
- Hunger and thirst are placeholders: 24 hours (1440 turns) without food makes you Hungry, 4 hours without a drink makes you Thirsty; each is -20% walking speed (stacking to 64%).  Eating or drinking resets the matching clock (`Game.last_ate`, `last_drank`).

## Attributes and skills
- Five attributes (Strength, Perception, Agility, Cognition, Endurance), all 10 at the start.  Every two points over 10 add 1 to each skill the attribute governs.  Sixteen skills in four groups (Combat: Unarmed, Melee, Ranged, Dodge, Grit; Hacking: Networking, Analysis, Implementation; Labour: Manual, Engineering, Artisan, Research; Social: Streetwise, Etiquette, Deception, Negotiation), all 0 at the start, each raised by its own XP (`skill_up`: risky tasks teach, easy ones do not; base level capped at 20).  The number shown and used is the effective level (`Game.lvl(id)`) = base + attribute bonus.
- `src/skills.gd` holds the tables (names, governing attributes, descriptions, disciplines, whether the skill is live yet) and the shared formulas.  Disciplines unlock at an effective level: Parry 3, Riposte 6 (Melee), Iron Fist 5, Pressure Points 8 (Unarmed), Steady Aim 5, Marksman 8 (Ranged).
- In play today: Unarmed/Melee (hit chance +3% a level, damage +1 per 2 levels, strike speed), Ranged (+2% a level, aim speed), Dodge (+2% a level against blows; bullets only from level 7), Grit (-1 damage per 4 levels, critical hits 6% falling to 1%), Engineering (lock picking, fewer gun jams), Manual (heavy shoving), Streetwise/Etiquette/Negotiation (shop prices, fixer pay), Deception (pickpocketing), Research (extra rumours).  Hacking skills and Artisan wait for the nanohack and crafting systems (the screen says so).
- NPCs have the same five attributes and sixteen skills, derived from faction and person index (`SK.npc_attrs`, `SK.npc_base`; nothing stored, same on every replay of a seed).  They drive NPC dodge, bullet dodge, shooting and melee accuracy and Grit.
- **F7** (or Pause > Attributes & Skills) opens the screen: attributes in one box along the top, the selected line's description, governing attributes and disciplines beside it, four skill boxes below with the effective level and an XP bar.  Arrows, numpad or the mouse choose a line.
- Critical hits are new (decided by the defender's Grit, rolled by hashing the seed and turn so they never disturb the random stream); `Game.crits = false` switches them off for tests.
- Saves keep `attrs`, `skills` and `xp`; old saves load with the known skills kept and the rest at defaults.  Tests: `tests/test_skills.gd` (62 checks).  Screenshot: `tests/shot19.gd`.
