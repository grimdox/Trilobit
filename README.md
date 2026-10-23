# Trilobit

A turn-based cyberpunk roguelike in Godot 4.3 (GDScript). The game lives in [`godot-spike/`](godot-spike/); see its README and PLAN.

The game tree contains no code, data, art or ids from Cataclysm: Dark Days Ahead. This repository began as a CDDA fork; that material survives only in older commits and, unchanged, on the `cdda-archive` branch. See `LICENSE.txt` and `THIRD_PARTY_NOTICES.md`.

- Guns: `godot-spike/tools/content/guns.py` (50 guns, seven fictional makers, Trilobit's own stats).
- Other items: `godot-spike/tools/export_items.py`, which writes `godot-spike/data/items.json`.
- Art: `godot-spike/tools/content/` generators draw the Trilobit64 tileset, paper dolls and icons.
- World tiles: [`world-workshop/`](world-workshop/) draws the five 64 px district tilesets (downtown, mid-town, slums, country, docks and sewers) and their street furniture; the game picks a set per cell by district.
- Character sprites: [`doll-workshop/`](doll-workshop/) is the standalone Godot 4.5 workshop and runtime for the layered, palette-swapped dolls the game draws people with (male and female, three frames each, a 64 px set for the creation screen and a 32 px world set), with a seeded generator, a cached incremental bake and its own tests.
