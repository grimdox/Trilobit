# Extending the set

Everything is data plus a few builder functions; nothing is hand-painted, so every addition is drawn on all six bodies
in every frame by the next bake.

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

`bash run_all.sh`: the Python QA pass (Q1-Q9), the Godot data and runtime tests, and the pixel-fidelity check.
