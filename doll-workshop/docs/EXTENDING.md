# Extending the set

Everything is data plus a few builder functions; nothing is hand-painted, so every addition is drawn on all six bodies
in every frame by the next bake.

## The loop: try, update, done

1. **Try it** (seconds): `python3 tools/dollgen/try.py g:<garment>` (or `i:<implant>`, `h:<hair>`, `o:<outfit>`,
   several at once) renders the part on every body in ten telling poses, writes `try.png` and checks that it draws in
   every frame, has no noise, keeps a dark outer edge and, with `--on full`, lets no skin through a full suit.  Add
   `--frames all` before a release, `--lod 32` for the world set.  Nothing is baked; iterate here.
2. **Update** (minutes): `bash update.sh` bakes both sets, but only parts whose inputs changed are rendered (each
   body's body, android body, garments, hair styles, implants, faces and held items are cached in `.cache/` under a
   key made from the sources and the definition they depend on).  A new garment renders that garment alone; changing
   `garments.py` renders every garment; changing the shader or the anatomy renders everything.  Then it runs every check
   and copies the runtime and both sets into the game (`tools/sync_to_game.sh`).
3. A colour preset needs no rendering at all: `bash update.sh --palette-only`.

The bake uses every core (`--jobs`, default all) and splits each body's frames into runs so one new part keeps every
worker busy.  `--no-cache` renders everything from scratch; the result is byte-identical either way.

Measured on a 2-core machine (2026-10-23): no change 17 s + 7 s; one new garment 1 min 41 s (64 px) + 41 s (32 px);
a colour preset 3 s; the checks after a bake about 5 minutes.  A cold bake (empty cache) is about 50 minutes; more cores
divide every figure.

## A colour (skin, hair, eyes, cloth, metal, lights)

Add the preset to the table in `tools/dollgen/materials.py` (for skin, `SKIN_PRESETS`), then rewrite only the palette
tables of both sets; colours never touch the sprite pixels, so no rendering is needed (seconds, not a rebake):

```sh
python3 tools/dollgen/bake.py ../godot-spike/data/items.json dolls --palette-only
python3 tools/dollgen/bake.py ../godot-spike/data/items.json dolls32 --palette-only --lod 32
```

For the generator to hand it out, add it to a list in `doll_generator.gd` (`HUMAN_SKINS`, `COLOURED_SKINS`, ...); for
the game's creation index, to `SKINS` in `trilobit_adapter.gd` in the game's order.

## A garment

Add one entry to `tools/dollgen/catalog.py`:

```python
g('field_jacket', 'Field jacket', 4,
  [dict(type='torso', mat='cloth2', t=0.7, top='high', bottom='hip', open=2.0, loose=0.4),
   dict(type='sleeves', mat='cloth2', t=0.6, len='long', cuff='cloth4'),
   dict(type='pocket', mat='cloth2', at='chest_l'), dict(type='belt', mat='cloth2', y='waist')],
  tags=('outer',))
```

Part types and options are listed at the top of `garments.py`.  `level` orders it in its layer group.  `fem=` and
`male=` give a different part list for female or male bodies.  `back=True` keeps the part behind the body (packs).
Give the generator a category for it (`CATEGORY` in `doll_generator.gd`) and add it to an archetype's pool.

## A hair style

Add a branch to `build_hair()` in `hair.py` (a cap from `_cap()`, then the style's forms in the head frame; hanging
parts follow `pose['sway']`), its name to `STYLES` / `STYLE_NAMES`, and it to an archetype's hair list.

## An implant

Write a builder in `implants.py` (solids on the skeleton; `shell()` for casings over a limb's own solids) and register
it with `imp(id, name, slots, builder, over=...)`.  Slots keep two pieces out of one place; `over=True` draws it over
clothes.  Map game ids in `GAME`.

## An eye shape or expression

Add rows to `SHAPES` or `BROWS` / `MOUTHS` in `face.py` (see the legend); they are pixel stamps, so draw them by hand.

## A pose or animation

Stances are in `grip_pose()` in `poses.py`; animations in `frame()`, `walk()`, `act()`, `down()`.  Poses are targets
(hand, foot, weapon grip and axis) solved with IK, written as functions of the body so they scale to every frame.  Aim,
strike and thrust along `AIM`.  Add durations in `DUR` and the frame count in `ANIMS`.

## A new character type (creatures, mechs, drones)

A new type is a new `BodyDef` and anatomy builder (`build_body` is the human one), a pose set, and its own catalogues;
`frame.py`, `shade.py`, `bake.py`, the manifest format and the whole runtime stay as they are.  Use another bake
directory, or extend `BODIES`.

## Checks to keep green

`bash run_all.sh` (also run by `update.sh`): the Python QA pass (Q1-Q9), the Godot data and runtime tests (including
the CPU composer the game draws with), and the pixel-fidelity check.  In the game, `tests/run_dolls.gd` checks that
every faction's people, every weapon kind and every creation colour reach the doll.
