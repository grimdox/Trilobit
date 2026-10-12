# Trilobit to-do

- **Tilesets:** design an entirely new tileset for the theme (less post-apocalyptic, more Japanese cyberpunk). Needs 8-direction character sprites (`player_male_n`, `_ne`, `_e`, `_se`, `_s`, `_sw`, `_w`, `_nw`; same for `player_female`, `npc_male`, `npc_female`) and directional monster sprites. The engine already looks for these names and falls back to left/right flip.
- **Facing:** PC view cone currently limits seeing creatures only (not terrain); terrain cone, noise-search behaviour and monster directional sprites still open.
