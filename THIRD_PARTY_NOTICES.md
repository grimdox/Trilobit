# Third-party notices

Everything in `godot-spike/` is Trilobit's own work except the components below.  Each one's licence text is in this repository.

| Component | Where | Licence | Licence text |
|---|---|---|---|
| Godot Engine 4.3 (the runtime in every export) | not in this repository; added by the Godot export | MIT | `licenses/Godot-MIT.txt` |
| Godot's own third-party parts (FreeType, HarfBuzz, built-in fonts and others) | inside the Godot runtime | various permissive licences | listed in Godot's `COPYRIGHT.txt`; also shown at runtime by `Engine.get_copyright_info()` |
| Noto Sans CJK JP, kana subset | `godot-spike/gfx/fonts/NotoSansJP-kana-subset.otf` | SIL Open Font License 1.1 | `godot-spike/gfx/fonts/OFL.txt` |

Before release, put these notices in the game's credits or an included text file, as MIT and OFL both ask.

## Not third-party

- Tiles, items, paper dolls, vehicles and icons are drawn by Trilobit's own Python generators in `godot-spike/tools/content/`.
- Item data (guns, melee weapons, ammunition, mods, armor, food) is defined in `godot-spike/tools/content/guns.py` and `godot-spike/tools/export_items.py`.
- The island coastline (`godot-spike/data/island_sdf.bin`) is traced from the island guide image.  Confirm you hold the rights to that image.
