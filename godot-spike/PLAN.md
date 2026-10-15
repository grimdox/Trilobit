# Trilobit Godot Spike Plan

**Question:** can Godot 4 carry Trilobit better than a CDDA fork?  **Budget:** two weeks of work, three pass/fail tests, then a decision.  Built 2026-10-14; the first round of tests runs headless in GDScript only (no C++), so a pass is a conservative result.

## What the spike must show
| # | Test | Pass mark | Why it matters |
|---|---|---|---|
| 1 | NPC scale with level of detail | 2,000 NPCs: average tick under 4 ms, p95 under 8 ms, worst under 50 ms; 5,000 NPCs average under 8 ms; LOD at least 2x cheaper than all-agents | CDDA's crowd cost is the main reason to leave |
| 2 | Pocket inventory | Nested pockets with volume, weight, tag, watertight and length rules, best-fit insert, stacking, save and load | You like CDDA's storage and want to keep it |
| 3 | Anchored overworld and a city | Anchors (coast, mountains, big city, harbor, airport, industrial belt) exist in all of 100 seeds, relations hold (harbor on the sea), same seed gives the same world, different seeds differ; a 256x256 city with every home, work and shop reachable on foot | Your fixed-places-with-varying-detail world |

## Results (first round, 2026-10-14)
All three pass: **pockets 19 of 19, world 12 of 12, scale 6 of 6.**  Run `godot-spike/run_all.sh`.
- **Scale:** 2,000 NPCs with constant re-targeting: average 0.30 ms per tick, p95 0.41 ms, worst 3.6 ms, about 80 full agents near the player.  5,000 NPCs: average 0.74 ms.  The same 2,000 with no LOD: 3.06 ms, so LOD is about 10x cheaper.  Numbers come from a shared sandbox CPU; treat them as relative.
- **Pockets:** rigid and flexible pockets, tag restrictions (holster takes only pistols), watertight liquids, length limits, cycle protection, deep best-fit insert, stacking, JSON round trip.  All 50 new Trilobit guns load from the CDDA-side tables through `tools/export_items.py`, which shows the content transfers.
- **World:** the harbor always sits on the sea, the airport outside the city, the coast appears on different sides, the city moves; 100 seeds give 100 different worlds; the generator takes about 15 ms for the overworld and 35 ms for a city.  Preview images: city and overworld PNGs are written to the temp folder by the tests.

## What the spike does not prove yet
- Real NPC decisions (combat, theft, dialogue, faction logic).  The sim measures movement, a line-of-sight check and bookkeeping only.  Expect real AI to take much more of the budget; the margin is about 10x at 2,000 NPCs.
- Rendering, field of view and lighting, multiple floors, items on tiles, saving the whole world.
- Vehicles (ground, air, mecha) and NPC driving.
- Last-mile movement: agents snap to their exact destination within 14 tiles; a small A* window replaces that.
- The sandbox clock is not your machine.

## Round two (the rest of the two weeks)
1. Draw it: a tile renderer using the Bouma tilesets, FOV and lighting, so we can see and walk the generated city.
2. Real agents: awareness meter, alarms and morale ported from `trl_aware.cpp`, one weapon, and theft.
3. One floor above and below, doors, and items on tiles with pockets on the player.
4. One vehicle you can drive, and one NPC driving a route.
5. Save and load the whole state.

**Decision gate:** after round two, if a 60-minute playable slice holds a steady frame rate with a few hundred full agents, we plan the move.  If scale fails, we try Rust with Bevy.  CDDA remains the content lab until then.

## Risks
GDScript speed for real AI (mitigation: hot loops in C# or GDExtension), art pipeline mapping (the generators are engine-independent), and the sheer volume of UI to rebuild.

## Round two status (vertical slice)
Playable slice in `src/game.gd`, `view.gd`, `main.gd`: city, FOV, Bouma/Mokuhanga tilesets (F2), pockets inventory, awareness-driven Bratva/NAP/Nasim hostiles, theft, shooting, heat, 30 cars (12 AI-driven), save/load (F5/F9). Tests: pockets 19/19, world 12/12, scale 6/6, game 20/20; full turn ~2.5 ms at 2,000 people.
Known gaps: no floors/stairs, 1x1 vehicles, no overworld travel, no dialogue, no Windows export workflow. Crowding on promotion is density, not a bug: default population lowered to 1,200.

## Round three: the vertical world (towers to 30 floors, underground) and the next five systems
Why: the city was flat.  Verticality is also the cheapest big win for the NPC simulation: it multiplies places to live and work without more map area.

**How levels work.**  All levels sit in ONE array, ground first, so every ground cell index is unchanged: level n occupies cells n*256*256 ..; then floors 1..30, then -1 and -2.  A cell index says which level it is on.  Row distance between levels is >= 256, so level of detail is free: only people on the player's own level are ever "near" and fully simulated; the rest are abstract agents whose commute is the flow-field distance (through stairs and elevators).  Stairs, elevators, ladders and manholes are `links` (cell -> cells) that BFS flow fields, the near-agent step, and the player treat as one more step.  FOV runs per level; air cells draw the ground below, dimmed.  2.16 M cells, 33 levels: build 40 ms, setup 0.55 s, a full turn 1.2 ms with 1,500 people.
- Above ground: the core buildings become towers (heights from distance to centre, the tallest always 30): glass-and-wall shell, BSP floors alternating two plans, a stair and an elevator shaft on every floor, retail on floors 1-2 then bands of offices and flats, a roof with railings and plant, glass skybridges between close towers, locked vault rooms with loot.
- -1: the Ring Line subway under the road grid (four stations, platforms, one train, 6 cells/turn, 7-turn stops, boarding, hazard on the track), maintenance catwalks, street hatches.
- -2: sewers under every road line, ladders up to the tunnels, manholes to the street, squatter lairs (Bratva and Nasim).

**The five additions (ranked by impact on play)**, status:
1. Vertical world - built (above).
2. Transit - built as data (`transit.gd`: a ring of cells, a list of stops, a carriage chain).  An airship or air shuttle is the same object on a roof level.  Commuter NPCs riding it are not built yet.
3. Talk, trade, jobs - first cut (`economy.gd`): vendors, fixers (courier and retrieval jobs, paid on completion), two ripperdocs (sewer and tower clinic).  No factions' dialogue trees, rep or quests yet (see Faction Quest Trees doc).
4. Time pressure - first cut: Kuroda debt with daily interest, installments every three days, arrears, collectors; failing implant with tremor then seizures, serviced by a ripperdoc; clearing the debt is the placeholder win.
5. Lootable world - first cut: locked doors (theft skill), vault rooms; no terminals, hacking, furniture containers, or alarms yet.

**Ranged combat and gun mods** (`gunplay.gd` rules, `game.gd` actions, tests in `test_guns.gd`):
- Every gun has caliber, magazine, fire modes (single/burst/auto), recoil, report radius, reload time, pellets, jam chance and mod slots by class, with per-model variance.
- 18 mods in six slots (optic, muzzle, barrel, mag, under, stock): red-dot, holo, 4x and 8x scopes (accuracy and range up, handicap inside 4 tiles), smartlink, laser, foregrip, bipod, suppressor (report 5 tiles), compensator, flash hider, long/short barrel, choke, extended/drum/quick magazines, stocks.
- Typed ammunition per caliber (ball, AP, hollow-point, buckshot, slug, HE grenade, charge pack) as a loose-round pool; `x` picks the kind, `r` reloads (clears jams), `v` fire mode, `a` aim (up to 3 turns), Tab cycles targets, `m` opens the gunsmith.
- Hit chance = model + mods + skill + aiming - range - recoil within a burst - moving - implant tremor; shown live in the HUD.  Shotguns throw pellets that spread with range, launchers burst (and hurt you), shots can hit people in the line of fire, tracers are drawn.
- Mods and ammunition are sold by vendors, found as loot and in vaults, and dropped by gunmen.  Save/load keeps mods, rounds, kind and fire mode.

**Stealth, cover and movement** (`game.gd`, tests in `test_stealth.gd`):
- Stances: crawl (half speed, noticed at 0.4x, silent), crouch (0.65x, +5 aim), walk, run (Shift+direction: two cells a turn, 1.5x noticed, loud, costs stamina; a winded runner walks).  `c` crouch, `z` crawl.  Jump (`q` then a direction): two cells, three after a running start, over crates, railings, gaps and cars but not walls or people; costs stamina.
- Vision cones: every person has a facing (where they last walked; idle ones glance around).  Front cone (~120 degrees) sees fully, the flanks at 0.4 (0.8 when alerted), behind not at all unless alerted (0.35).  Witnesses with their back turned do not see a killing.  Cones of watchful unaware people are drawn on screen.
- Hearing: footsteps carry 0/1/4/9 tiles by stance; a person who hears you behind them gets suspicious and turns toward you.  Noise (gunfire, lock-picking) also turns heads.
- Quiet kills: striking an unaware person from behind does x4 (x2 from the front) and a kill is silent (witnesses only within 4 tiles); a suppressed shot at an unaware target is silent too.
- Cover: crates, dumpsters and planters (new tile ids 23-25, scattered in streets and on tower floors without ever blocking a route), railings, cars and wall corners.  Cover between shooter and target costs hit chance (20, or 32 behind low cover while crouched, 15 at a wall corner); applies both ways.  Crawling lowers enemy hit chance too.

**Tests**: pockets 19, world 12, scale 6, levels 11, game 20, vertical 37, guns 36, stealth 25, plus a 6,000-turn random soak (`tests/run_soak.gd`).  `run_all.sh` now fails if any suite fails or does not finish.

**Known gaps / next**: NPCs still shoot with class-level numbers (no mods, no reloading), no armour or wall penetration, enemies do not seek cover or flank; pursuit across levels (hunters lose you on stairs), NPCs riding the train, falling and jumping, multi-tile vehicles, 3D sight through glass floors, per-floor lighting, elevator floor selection UI, a Windows export workflow, terminals and alarms, faction dialogue and rep.
