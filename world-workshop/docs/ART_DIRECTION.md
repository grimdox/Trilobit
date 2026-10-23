# Art direction: the world

**The feel:** the same city as the dolls, Ghost in the Shell's neutral cold-lit streets with Anarchy Online's
lived-in sci-fi texture.  Neon and grit both: light is a feature, wear is a feature, and each district shows exactly as
much of both as its money allows.

## The rules every tile follows

* **Top-down, lit from the top left.**  Flat ground sits on the middle shade, so a floor never fights the objects on it.
* **Five shades per material** (plus a line colour, a cyan rim and a glint).  Shadows lean cool violet, lights warm
  yellow; a material never uses more than seven colours and a sprite never more than 56.
* **Height reads three ways:** bevel shading, a short cast shadow to the bottom right, and a 1 px dark outline where an
  object meets lower ground.  Walls also show a south face.  Ground and decals (spills, puddles) have no outline.
* **Clean clusters, no noise.**  Texture comes from deliberate pattern (slab joints, planks, rivets, tufts of grass),
  never from random single pixels; lone pixels are cleaned up after lighting (lights and glints excepted).
* **Light is emissive.**  Neon, screens, lamps and lit strips ignore the key light and are brightest at the core.
  Broken lamps and dead tubes use a dull dark material, so "broken" reads at a glance.
* **Names are colours.**  An id that names a colour shows it (`f_trl_neon_green` glows green, `t_trl_carpet_red` is red).
* **No text in sprites.**  Signs carry abstract tube motifs, never letters.

## The districts

| | materials | wear | plants | light |
|---|---|---|---|---|
| downtown | white marble, chrome, glass, gold accents | none | many: street trees in grates, flowerbeds, lawns with mowing stripes | cold white lamps, teal light lines along wall tops and faces |
| mid-town | concrete, mixed stone, painted steel | hairline cracks, a little grime | pruned trees and hedges | working lamps, pink and cyan neon |
| slums | old concrete, rusty corrugated sheet, patched plates | cracks, potholes, stains, rust, litter, spills, moss in joints | dry patchy grass, wild shrubs | many lamps broken, dead tubes, neon in four colours |
| country | timber frame, plaster, paper screens, stone, earth | weathering, moss | wild grass, flowers, pines, birches, bamboo | warm lamps, few |
| docks and sewers | riveted steel, hazard yellow, concrete, steel grating | rust, oil, grime, moss | weeds and moss | clean cold work lights, amber and cyan neon |

## Readability at game scale

The game draws 64 px tiles at 27 px on screen.  Shapes are kept large and contrasty enough to survive that: walls
24 px thick with a 9 px face, furniture with a clear top surface and outline, street furniture with a cast shadow.
`tests/shot32.gd` in the game renders the same scenes at 32 and 64 px tiles for comparison.
