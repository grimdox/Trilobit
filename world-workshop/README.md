# World workshop: Trilobit's district tilesets

Five 64 px tilesets that the game draws its world with, one per kind of district, plus the new street and industrial
objects that make the districts feel different.  Everything is generated from data and a few hundred lines of builders;
nothing is hand-painted, so a new tile, a new theme or a changed material is redrawn in seconds.

| theme | where the game uses it | look |
|---|---|---|
| `rich` | downtown (the city's richest districts) | white marble and sleek metal with chrome edges and teal light lines, glass everywhere, street trees and flowerbeds, fountains and statues, spotless |
| `mid` | mid-town and most streets | saw-cut concrete and mixed stone, panelled walls, working lamps, pink and cyan neon, benches, pruned hedges |
| `slum` | the poorest districts | patched and cracked concrete, rusty sheet-metal walls, potholes, broken lamps, rubbish, chemical spills at the wall foot, wild shrubs, neon in four colours |
| `rural` | outside the city | timber-frame and plaster houses, shoji screens, sliding lattice doors, dirt roads with ruts, wild grass, pines and birches, wood piles, wells, hay |
| `industry` | the docks and everything underground (sewers, tunnels) | riveted steel plate, hazard paint, bulkheads and barred gates, diamond-plate walkways, oil stains, fuel tanks, drums, pallets, machinery, murky water |

Every theme draws all 109 tile ids the world already uses (terrain, 16 joined wall shapes, 16 glass wall shapes,
doors, windows, 72 pieces of furniture) plus 42 new ids: 260 sprites a theme with variants.  The game picks the set
for each cell from its district (`theme_at` in the game's `src/view.gd`), so a street changes look where the money
changes, and falls back to its base set for what the district sets do not draw (items, animals, vehicles).

## Running

```sh
bash update.sh                       # bake (only changed tiles are redrawn), check, copy into the game
bash run_all.sh [review_dir]         # bake, check, prove the bake is deterministic, write the review sheets
python3 tools/tilegen/bake.py sets   # bake only (all five themes in about 12 s from scratch, 3 s when nothing changed)
python3 tools/tilegen/qa.py sets ../godot-spike/gfx/Trilobit64/tile_config.json
python3 tools/tilegen/sheets.py sets review
```

Python 3.10+ with numpy, scipy and Pillow.  No Blender, no web services, no AI services.  The game side is plain GDScript
(Godot 4.3+, Compatibility renderer); the sets are ordinary PNG sheets with the game's `tile_config.json`.

## How a tile is made

A tile is a 64 x 64 map of height and material (`canvas.py`).  Builders raise shapes (a kerb, a bevelled panel, a dome,
a cylinder), cut seams, and apply the theme's wear (cracks, grime, moss in the joints, rust, litter) in tileable masks.
`render.py` then lights every tile by the same rules: one key light from the top left, five shades per material on a
hand-tuned OKLab ramp (cool violet shadows, warm lights: the same ramp builder as the doll workshop, so people and
places light alike), creases darker, short cast shadows to the bottom right, a 1 px dark outline on raised objects,
the city's cyan rim on their far edges, glints on metal and glass, neon and screens emissive.  Walls get a south face
so they read as height.  Ground tiles wrap at their edges so cells join without seams.

## Files

```
tools/tilegen/canvas.py     the height/material canvas, shapes, tileable patterns and noise
tools/tilegen/render.py     the lighting and pixel rules
tools/tilegen/color.py      OKLab ramps (shared with the doll workshop)
tools/tilegen/themes.py     the five themes as data: material colours and how worn, planted and lit they are
tools/tilegen/terrain.py    ground: walkways, roads, floors, grass, water, rock, rails, stairs, lifts, ladders
tools/tilegen/walls.py      walls (16 joined shapes), glass walls, doors (open, shut, locked), windows
tools/tilegen/furniture.py  every piece of furniture the game places
tools/tilegen/props.py      the new world objects and grounds
tools/tilegen/catalog.py    every id with its builder and variants
tools/tilegen/bake.py       bake to sets/<theme> (cached per sprite in .cache/)
tools/tilegen/qa.py         checks T1-T7
tools/tilegen/sheets.py     review sheets and the random sample
tools/sync_to_game.sh       copy sets into godot-spike/gfx/tiles_<theme>
docs/ART_DIRECTION.md, docs/EXTENDING.md
```
