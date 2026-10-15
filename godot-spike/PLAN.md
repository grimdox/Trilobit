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
