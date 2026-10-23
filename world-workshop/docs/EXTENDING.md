# Extending the world

## The loop

1. Write or change a builder (below) and preview it: render it in all themes with the snippet in `sheets.py`'s
   `compare()` or just run `bash update.sh` (seconds: only what changed is drawn again).
2. `bash update.sh` bakes, runs the checks and copies the sets into the game.  `bash run_all.sh review` also proves the
   bake deterministic and writes the review sheets.
3. In the game, `tests/run_tiles.gd` checks that every sprite the world asks for is in every district set.

Measured on a 2-core machine: all five themes from scratch 12 s; one changed builder about the same (every sprite that
builder draws, five times); a theme's colours alone a few seconds; the checks 8 s; the review sheets 10 s.

## A new tile or object

Write a builder `(theme, rng) -> Tile` (or `(theme, rng, variant)` for ground) in `props.py` (or the module it belongs
to), using the canvas shapes:

```python
def lamp_post(theme, rng):
    t = F.piece()                                              # an object over a floor
    t.slab(Tile.disk_mask(32, 32, 6), 'dark_steel', 24, profile='dome')
    t.emit(Tile.disk_mask(32, 32, 3), 'lamp')                  # emissive
    return F.finish(t, theme, rng)                             # the theme's wear and a contact shadow
```

Name materials by role (`body`, `top`, `trim`, `accent`, `walk`, `wall`, ...) so each theme draws its own version, or
by what they are (`brass`, `lacquer_red`, `neon_green`) when the object is that everywhere.  Add the id to `BUILDERS`
(or `GROUND`) and it is in every theme from the next bake.  If the id names a colour, QA T6 checks it shows it.

For the game to place it, add it to the view's district tables (`DECOR_KERB`, `DECOR_FRONT`, `DECOR_PARK` in
`src/view.gd`) or to the world generator as a real tile (a new `EXTRA` entry in `src/citygen.gd`).

## A new theme

Copy a theme in `themes.py`, change its materials and its `wear`, `cracks`, `grime`, `moss`, `rust`, `litter`,
`plants`, `lights` and `neon`, add it to `ORDER`.  Where a builder draws something genuinely different per theme (walls,
walkways), add a branch.  Then give it a place in the game's `theme_at`.

## Checks

QA (`qa.py`): T1 coverage, T2 seams, T3 palette discipline, T4 noise, T5 outlines, T6 colour names, T7 every theme
distinct.  All must pass.
