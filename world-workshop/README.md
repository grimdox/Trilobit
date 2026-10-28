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
doors, windows, 72 pieces of furniture) plus 42 new ids and the 124 business and home pieces and floors below: 2215 sprites a theme with variants and facings.  The game picks the set
for each cell from its district (`theme_at` in the game's `src/view.gd`), so a street changes look where the money
changes, and falls back to its base set for what the district sets do not draw (items, animals, vehicles).

## Business and home furniture

`furniture2.py` draws the game's furniture list (`godot-spike/tools/content/furniture_list.py`): 116 pieces for cafes,
bars, shops, banks, police stations, post depots, hotels, gyms, dojos, salons, laundromats, arcades, workshops,
factories, homes and offices, and 8 floors (bare concrete, lit dance floor, rubber, training mat, office carpet,
bathroom tile, linoleum, parquet).  Each comes in three variants per theme, 1860 sprites in all.  The variant changes
the colourway and some of the build: a round or square cafe table, wooden, plastic or cardboard crates, two or three
sofa seats.  The theme changes the quality: marble, leather and brass downtown; laminate and fabric in mid-town;
patched vinyl, tape, cracked screens and dead bulbs in the slums; timber, indigo cloth and tatami in the country;
enamel and steel in industry.  The game shows one variant per room (`_room_of` in `src/view.gd`), so a cafe's chairs
and its floor match.  Fittings that stand on the back wall (shelves, lockers, screens) fill the top of the cell and
join the next cell without an outline, so a row of them reads as one.

`goods.py` draws an icon for each of the 111 shop goods (`trl_good_*`) into the item set.

## Rock and the underground

`rock.py` draws mountains (grey), cliffs (red) and the rock the tunnels run through (dark).  A rock mass is one 256 px
height field per kind (big angular faces along the rock's grain, smaller faces breaking them up, moss in the hollows,
grass tufts, cracks, mineral veins below ground), cut into 4 x 4 cells; each cell is lit with its neighbours' pixels
round it, then cut out, so light and shadow run on across cells.  The game picks the cut by the cell's place in the
repeat and the shape by which sides open onto something that is not rock, plus any inside corners: 47 shapes x 16
cuts.  An open side ends in a broken edge that is shared by every cell along it, roots hang over it, scree lies at its
foot, and on the south side the cliff face shows.  `t_rocky` is the rough rocky ground of coasts and mountain feet.

`underground.py` draws the industry set's underground (the game draws everything below ground with that set): concrete
tunnel linings and brick sewer linings in 16 shapes, tunnel walkway, station platform with its tactile edge, subway
track with its third rail (both ways), sewer catwalk, sewage, and wall fittings that the view runs along the linings
and basement walls in all four facings: pipe runs, cable trays, ductwork, electrical panels, valve stations, extract
fans, caged lamps (some dead) and graffiti (shapes and colour only, never letters); puddles, drains and rubbish on the
floor.

Windows are their district's own wall with the glazing set into it: smoked glass downtown, blue-grey in mid-town,
wired and grimy (sometimes boarded) in the slums, shoji in the country, glass block in industry.

## Item icons

A sixth set, `items`, holds a new icon for every item that is not a weapon (245: shop goods, food and drink, ammunition, weapon
mods, armour and bags, tools and job items, engines, charms), drawn by `items.py` with the same renderer.  Guns and
melee weapons keep their approved designs from the game's own generators.  The game looks a sprite up in the cell's
district set, then the icon set, then its base set.

## Running

```sh
bash update.sh                       # bake (only changed tiles are redrawn), check, copy into the game
bash run_all.sh [review_dir]         # bake, check, prove the bake is deterministic, write the review sheets
python3 tools/tilegen/bake.py sets   # bake only (all five themes in about 35 s from scratch, seconds when little changed)
python3 tools/tilegen/qa.py sets ../godot-spike/gfx/Trilobit64/tile_config.json
python3 tools/tilegen/sheets.py sets review
```

The review sheets include `furniture_<theme>.png` (every new piece and floor, its three variants side by side) and
`rooms_sample.png` (seeds 1 to 4 of a furnished room in every theme, exactly as generated).

Python 3.10+ with numpy, scipy and Pillow.  No Blender, no web services, no AI services.  The game side is plain GDScript
(Godot 4.3+, Compatibility renderer); the sets are ordinary PNG sheets with the game's `tile_config.json`.

## How a tile is made

A tile is a 64 x 64 map of height and material (`canvas.py`).  Builders raise shapes (a kerb, a bevelled panel, a dome,
a cylinder), cut seams, and apply the theme's wear (cracks, grime, moss in the joints, rust, litter) in tileable masks.
`render.py` then lights every tile by the same rules: one key light from the top left, five shades per material on a
hand-tuned OKLab ramp (cool violet shadows, warm lights: the same ramp builder as the doll workshop, so people and
places light alike), creases darker, short cast shadows to the bottom right, a 1 px dark outline on raised objects,
the city's cyan rim on their far edges, glints on metal and glass, neon and screens emissive.  Walls fill their cell (floors run right up to them) and get a south face
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
tools/tilegen/furniture2.py the business and home furniture and floors, three variants each
tools/tilegen/items.py      item icons
tools/tilegen/goods.py      shop goods icons
tools/tilegen/rock.py       mountains, cliffs, underground rock, rocky ground
tools/tilegen/underground.py tunnels, stations, sewers: linings, floors, fittings
tools/tilegen/catalog.py    every id with its builder and variants
tools/tilegen/bake.py       bake to sets/<theme> (cached per sprite in .cache/)
tools/tilegen/qa.py         checks T1-T9
tools/tilegen/sheets.py     review sheets and the random sample
tools/sync_to_game.sh       copy sets into godot-spike/gfx/tiles_<theme>
docs/ART_DIRECTION.md, docs/EXTENDING.md
```
