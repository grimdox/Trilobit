# The baked set (format 1)

`dolls/` (LOD 64) and `dolls32/` (LOD 32, the world set) each hold:

* `doll_idx_<n>.png` - 2048 x 2048 greyscale pages.  A pixel value is **material x 8 + shade** (0 = empty).
  Import as lossless, no mipmaps, nearest filtering (the shipped `.import` files do this); never VRAM-compress them.
* `doll_rgba_<n>.png` - 2048 x 2048 colour pages for held items (their own palettes).
* `dolls.json` - the manifest.

## Manifest

| key | meaning |
|---|---|
| `format`, `lod`, `cell`, `origin` | 1; 64 or 32; the cell (96 or 48 px square); the ground point between the feet inside the cell |
| `groups` | draw groups back to front: back, far, body, head, held, near, hands, over |
| `bodies` | `m_s m_m m_l f_s f_m f_l` with names |
| `grips`, `anims`, `down` | the six stances; each animation's frame count, durations (ms), loop flag and event frame |
| `frames[body][frame id]` | per frame: `eye` (the face anchor), `head`, `ground`, and for armed frames `grip` (where the held item's grip goes) and `hold` (which held sprite) ; `face: false` hides the face; `repairs` counts the pixels each cleanup step changed (on the bare body, and summed over the frame's garments, hair and implants) |
| `hair`, `eye_shapes`, `expressions` | ids and names |
| `garments` | id -> name, level, the colour slots it uses (`mats`), hides_hair, hides_face, tags |
| `outfits`, `worn` | outfit presets (garments + colours), the game's worn-item ids -> garments |
| `implants`, `implant_game` | id -> name, body slots, over clothes; the game's implant ids -> implants |
| `items` | every held item id -> its stance |
| `palette` | default palette, presets (skins, hair, eyes, cloth, metal, glow), reference ramps and palettes for the runtime's port |
| `sprites` | key -> `[kind, page, x, y, w, h, ox, oy, group, sub]` (kind `i` index / `c` colour; ox, oy the offset in the cell or from the anchor) |

Frame ids: `<grip>/<anim>/<i>` (`unarmed/walk/3`), the fall `any/down/<i>`.

Sprite keys:

| key | what |
|---|---|
| `b/<body>/<frame>/<layer>` | the bare body: layers back, far (far arm), body, near (near arm), hands |
| `a/<body>/<frame>/<layer>` | the same with android panel seams |
| `g/<body>/<frame>/<garment>/<group>` | a garment's part in one draw group |
| `h/<body>/<frame>/<style>/<head or back>` | hair in front of the body, and behind it |
| `i/<body>/<frame>/<implant>/<group>` | an implant's part |
| `f/<body>/<shape>/<expression>` | a face, offset from the frame's `eye` anchor |
| `held/<item>/<hold>` | a held item, offset from the frame's `grip` anchor |

## Drawing a doll

`compose()` in `doll_library.gd` is the reference: body layers, then garments in spec order, implants, hair (unless a
garment hides it), face (unless hidden), held item; sorted by group, then `sub`, then insertion.  `sub` inside a group:
0 skin, 1 implants on the skin, 10 + level garments (underwear 0, legwear 1, footwear 2, shirt 3, jacket 4, armour 5,
straps 6), 18 implants over clothes; head: 0 face, 1 eye hardware, 2 hair, 2.5 skull hardware, 3 headwear.

## Palettes

32 rows x 8 shades.  Rows: 1 ink, 2 skin, 3 lip, 4 hair, 5 sclera, 6 iris, 7 dark (pupils, lashes), 8-11 cloth 1-4,
12-13 leather 1-2, 14 metal, 15 plates (polymer), 16 prosthetic shell, 17-18 lights, 19 underwear, 20 lenses.
Shades: 0 line, 1-5 ramp, 6 rim, 7 glint.  `doll_palette.gd` builds a palette from a colour choice exactly as the
generator does (tests compare them value for value).
