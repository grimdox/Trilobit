extends Node2D
## Draws the game around the player with the Trilobit tileset: terrain, items, cars, people with awareness marks, a target bracket.
const CG = preload("res://src/citygen.gd")
const PD = preload("res://src/paperdoll.gd")
const DS = preload("res://src/dollspec.gd")
const FG = preload("res://src/figure.gd")
const CLK = preload("res://src/clock.gd")
const DIMG = preload("res://addons/trilobit_doll/doll_image.gd")      # the layered dolls (doll-workshop), composed per look
const ADAPT = preload("res://addons/trilobit_doll/trilobit_adapter.gd")
const DOLLS_WORLD := "res://gfx/dolls32"     # the 32 px world set: drawn at TILE / 32, it is made for this size
var pd = PD.new()
var fig = FG.new()            # the old standing dolls (gfx/figure): drawn only if the layered set is missing
var dimg = null               # DollImage for DOLLS_WORLD (loaded on first use)
var _dspec := {}              # game spec -> doll spec
var game
var tileset
var TILE := 61            # screen pixels per cell: sprites are drawn at 64x64 and scaled to this, whatever the tileset's own size
var S := 61.0 / 32.0      # TILE / 32: scale for hand-placed pixel offsets
## zoom steps: tiles you see either side of you, and the tile size that fills the 1920-wide canvas
const ZOOM_NAMES := ["close", "middle", "far"]
const ZOOM_SIDE := [10, 15, 20]
const MAP_H := 837                  # the map's height in canvas pixels, above the message panel
const VIS_W := 1542.0               # the map's visible width: the canvas less the 378 px HUD panel
var shift := Vector2.ZERO           # the whole map is moved so the player's cell sits in the middle of the visible area
func set_zoom(z: int) -> void:
	z = clampi(z, 0, 2)
	TILE = int(VIS_W / float(ZOOM_SIDE[z] * 2 + 1))       # N tiles either side of you fit in the visible width
	S = TILE / 32.0
	cols = int(ceil(1920.0 / TILE))                        # draw on under the HUD so nothing is left bare
	if cols % 2 == 0:
		cols += 1
	rows = int(ceil(float(MAP_H) / TILE)) + 1
	if rows % 2 == 0:
		rows += 1
	shift = Vector2(VIS_W / 2.0 - cols * TILE / 2.0, MAP_H / 2.0 - rows * TILE / 2.0)
	position = shift
	DOLL_S = 0.95 * float(TILE) / 27.0
	queue_redraw()

var cols: int = 31         # the zoom step decides this: 15 tiles either side by default
var rows: int = 13
var font: Font = ThemeDB.fallback_font

const TERRAIN := {0: "t_sidewalk", 1: "t_pavement", 2: "t_wall", 3: "t_floor", 4: "t_door_c", 5: "t_water_dp", 6: "t_grass", 7: "",
	8: "t_stairs_up", 9: "t_elevator", 10: "t_wall_glass", 11: "t_metal_flat_roof", 12: "t_rock_floor", 13: "t_concrete", 14: "t_railroad_tie",
	15: "t_floor_metal_gangway", 16: "t_water_sh_murky_underground", 17: "t_rock", 18: "t_metal_floor", 19: "t_ladder_up_down", 20: "t_glass_railing",
	21: "t_manhole_cover", 22: "t_door_metal_locked", 23: "f_crate_c", 24: "f_dumpster", 25: "f_planter",
	26: "t_trl_gravel", 27: "t_rock_red", 28: "t_rock", 29: "t_tree", 30: "t_rock_floor", 31: "t_grass_grazed", 32: "t_sand"}
const DARK := Color(0.38, 0.4, 0.55)

func tile() -> int:
	return TILE

func _blit(id: String, pos: Vector2, mod: Color = Color.WHITE) -> bool:
	if id.begins_with("icon:"):
		if not pd.has(id):
			return false
		var ir: Rect2 = pd.rect(id)
		draw_texture_rect_region(pd.tex, Rect2(pos, ir.size * pd.scale), ir, mod)
		return true
	var sp: Array = tileset.sprite(id)
	if sp.is_empty():
		return false
	var r: Rect2 = sp[1]
	var k: float = float(sp[3]) * float(TILE) / 64.0
	draw_texture_rect_region(sp[0], Rect2(pos + sp[2] * k, r.size * k), r, mod)
	return true

func item_sprite(it) -> String:
	var id: String = it.def["id"]
	if tileset.has(id):
		return id
	if pd.has("icon:" + id):
		return "icon:" + id
	return "trl_parcel"                    # any item without its own art yet shows as a parcel

func person_sprite(i: int) -> String:
	return "trl_person_f" if game.fem[i] == 1 else "trl_person_m"

## the paper doll.  People are drawn as standing dolls (gfx/figure, three-quarter turned, mirrored when facing left); without that
## atlas, the tileset's top-down layers (facing up, centred on the cell, stacked by z and turned to the facing) or the old 32px atlas.
func doll_ready() -> bool:
	return _dolls() != null or fig.ready() or (tileset != null and tileset.has("dl:d_legs"))

func _dolls():
	if dimg == null:
		dimg = DIMG.for_library(DOLLS_WORLD)
	return dimg if dimg.ok() else null

## the doll spec for a game spec (layers, weapon, look), made once per distinct look
func doll_spec(spec: Dictionary, lib_path: String = DOLLS_WORLD):
	var key := lib_path + str(spec)
	if _dspec.has(key):
		return _dspec[key]
	var lk: Dictionary = spec["look"]
	var ds = ADAPT.spec_from_game(spec["layers"], lk, String(spec.get("weapon", "")), String(lk.get("size", "m")), lib_path)
	if bool(lk.get("hid", false)):
		ds.hair = "bald"
	if _dspec.size() > 4000:
		_dspec.clear()
	_dspec[key] = ds
	return ds

## a layered doll standing on the cell at pos: its ground point on the cell's foot point, mirrored when facing left
func _draw_doll_layered(nd, spec: Dictionary, pos: Vector2, face_dir: Vector2i, mod: Color) -> void:
	var ds = doll_spec(spec)
	var tex: Texture2D = nd.texture(ds, "%s/idle/0" % ds.grip(nd.lib))
	if tex == null:
		return
	var k := TILE / float(nd.lib.man.get("lod", 32))      # the set's own size: 32 px dolls at TILE / 32, 64 px at TILE / 64
	var kx: float = k * float((spec["look"] as Dictionary).get("build", 1.0))      # the player's build widens or slims the figure
	draw_set_transform(pos + Vector2(TILE * 0.5, TILE - 1.0), 0.0, Vector2(-kx if face_dir.x < 0 else kx, k))
	var sh := PackedVector2Array()
	for n in 12:
		sh.append(Vector2(cos(n * TAU / 12.0) * 8.5, sin(n * TAU / 12.0) * 2.4) * (float(nd.lib.man.get("lod", 32)) / 32.0))        # same size on screen for either set
	draw_colored_polygon(sh, Color(0, 0, 0, 0.32 * mod.a))
	draw_texture(tex, -nd.origin(), mod)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_doll(spec: Dictionary, pos: Vector2, face_dir: Vector2i, mod: Color = Color.WHITE) -> void:
	var nd = _dolls()
	if nd != null:
		_draw_doll_layered(nd, spec, pos, face_dir, mod)
		return
	if fig.ready():
		fig.draw(self, DS.figure_keys(spec, fig), pos, TILE / 64.0, face_dir.x < 0, mod)
		return
	if tileset != null and tileset.has("dl:d_legs"):
		_draw_doll64(spec, pos, face_dir, mod)
		return
	for l in spec["layers"]:
		var key := "doll:" + String(l)
		if pd.has(key):
			var dr: Rect2 = pd.rect(key)
			draw_texture_rect_region(pd.tex, Rect2(pos + Vector2(0, -2) * S, dr.size * pd.scale), dr, mod)
	var w: String = spec["weapon"]
	if w != "" and pd.has("icon:" + w):
		var d := Vector2(face_dir.x, face_dir.y)
		if d == Vector2.ZERO:
			d = Vector2(0, 1)
		var ang: float = d.angle()
		var left: bool = d.x < -0.1
		var hand := pos + (Vector2(9, 22) if left else Vector2(23, 22)) * S
		draw_set_transform(hand, ang, Vector2(1, -1) if left else Vector2(1, 1))
		var wr: Rect2 = pd.rect("icon:" + w)
		draw_texture_rect_region(pd.tex, Rect2(Vector2(-7, -14) * S, wr.size * pd.scale), wr, mod)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

var DOLL_S := 0.95

func _draw_doll64(spec: Dictionary, pos: Vector2, face_dir: Vector2i, mod: Color) -> void:
	var lk: Dictionary = spec["look"]
	var keys: Array = DS.base_layers(lk, bool(lk.get("hid", false)))
	keys.append_array(spec["layers"])
	var w: String = spec["weapon"]
	if w != "" and tileset.has("dl:hold:" + w):
		keys.append("hold:" + w)
	var items: Array = []
	for k in keys:
		var key := String(k)
		if not tileset.has("dl:" + key):
			continue
		var meta: Array = tileset.doll.get(key, [65, ""])
		items.append([int(meta[0]), key, String(meta[1])])
	items.sort_custom(func(a, b): return a[0] < b[0])
	var d := Vector2(face_dir.x, face_dir.y)
	if d == Vector2.ZERO:
		d = Vector2(0, 1)
	var centre := pos + Vector2(TILE, TILE) * 0.5
	draw_set_transform(centre, d.angle() + PI / 2.0, Vector2(DOLL_S, DOLL_S))
	for it in items:
		var sp: Array = tileset.sprite("dl:" + String(it[1]))
		var r: Rect2 = sp[1]
		var c := mod
		if it[2] == "skin":
			c = mod * lk["skin"]
		elif it[2] == "hair":
			c = mod * lk["hair"]
		if it[1] == "d_shadow":
			draw_set_transform(centre + Vector2(3, 4), 0.0, Vector2(DOLL_S, DOLL_S))
			draw_texture_rect_region(sp[0], Rect2(-r.size * 0.5, r.size), r, c)
			draw_set_transform(centre, d.angle() + PI / 2.0, Vector2(DOLL_S, DOLL_S))
			continue
		draw_texture_rect_region(sp[0], Rect2(-r.size * 0.5, r.size), r, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## the first solid tile below an air cell, or -1 (what you would see looking down from a window or the roof edge)
func _below(c: int) -> int:
	var s2: int = game.s2
	var local := c % s2
	var l := c / s2
	while l > 0:
		l -= 1
		var t: int = game.city.tiles[l * s2 + local]
		if t != 7:
			return t
	return -1

func _fallback(t: int) -> Color:
	match t:
		26: return Color(0.5, 0.48, 0.45)
		27: return Color(0.45, 0.3, 0.25)
		28: return Color(0.4, 0.4, 0.45)
		30: return Color(0.5, 0.48, 0.42)
		31: return Color(0.55, 0.62, 0.3)
		32: return Color(0.85, 0.8, 0.55)
	return Color(0.5, 0.5, 0.5)

## lane lines on roads and the rails and ties on a railway
func _paint_marks(c: int, pos: Vector2, T: int, mod: Color, t: int) -> void:
	var marks: PackedByteArray = game.city.marks
	var m: int = marks[c] if c < marks.size() else 0
	if m == 0 or ((m == 5 or m == 6) and tileset.index.has("t_railroad_tie.v")):
		return
	var w := 5.0 * S
	var size: int = game.size
	var white := Color(0.92, 0.92, 0.95) * mod
	var yellow := Color(0.98, 0.8, 0.15) * mod
	match m:
		1:   # white, vertical: on the outer edge, away from the black lane
			var x: float = pos.x + (T - w if game.city.tiles[c - 1] == 1 else 0.0)
			draw_rect(Rect2(x, pos.y, w, T), white)
		2:   # double yellow: the two tiles hug the centre
			var x2: float = pos.x + (T - w if marks[c + 1] == 2 else 0.0)
			draw_rect(Rect2(x2, pos.y, w, T), yellow)
		3:
			var y: float = pos.y + (T - w if game.city.tiles[c - size] == 1 else 0.0)
			draw_rect(Rect2(pos.x, y, T, w), white)
		4:
			var y2: float = pos.y + (T - w if marks[c + size] == 4 else 0.0)
			draw_rect(Rect2(pos.x, y2, T, w), yellow)
		7:   # a dashed lane line between lanes of the same direction (east-west road)
			draw_rect(Rect2(pos.x + 2 * S, pos.y, T - 4 * S, w * 0.6), white)
		8:
			draw_rect(Rect2(pos.x, pos.y + 2 * S, w * 0.6, T - 4 * S), white)
		9:   # a parking bay's divider
			draw_rect(Rect2(pos.x, pos.y, w * 0.6, T), white * 0.85)
		10:  # a bay beside a vehicle charger: green
			draw_rect(Rect2(pos.x, pos.y, w * 0.6, T), Color(0.3, 0.9, 0.5) * mod)
		5:
			for k in 4:
				draw_rect(Rect2(pos.x + k * T / 4.0 + 2 * S, pos.y + 2 * S, 4 * S, T - 4 * S), Color(0.32, 0.2, 0.12) * mod)
			draw_rect(Rect2(pos.x, pos.y + T * 0.5 - 2 * S, T, 4 * S), Color(0.7, 0.72, 0.78) * mod)
		6:
			for k in 4:
				draw_rect(Rect2(pos.x + 2 * S, pos.y + k * T / 4.0 + 2 * S, T - 4 * S, 4 * S), Color(0.32, 0.2, 0.12) * mod)
			draw_rect(Rect2(pos.x + T * 0.5 - 2 * S, pos.y, 4 * S, T), Color(0.7, 0.72, 0.78) * mod)

## is the cell at (x, y) of the same level a wall, glass wall or door (what a wall segment joins up with)?
func _joins(base: int, x: int, y: int) -> bool:
	var size: int = game.size
	if x < 0 or y < 0 or x >= size or y >= size:
		return false
	var t: int = game.city.tiles[base + y * size + x]
	return t == 2 or t == 10 or t == 4 or t == 22 or t == CG.TID["door_closed"] or t == CG.TID["window_broken"]

## one terrain cell: variants for texture, autotiled walls, doors that face along their wall, rails that turn
const WEALTH_TINT := [Color(0.80, 0.75, 0.70), Color(1, 1, 1), Color(1.10, 1.13, 1.22)]

## the district tilesets (world-workshop): every cell is drawn with the set of its district, falling back to the base
## set for anything a district set does not draw (items, animals, vehicles)
const THEMES := ["rich", "mid", "slum", "rural", "industry"]
const WEALTH_THEME := ["slum", "mid", "rich"]
var theme_sets := {}               # theme -> Tileset, or {} when the sets are missing
var base_set = null                # the base tileset (the one main.gd hands the view)
var themed := false                # drawing a cell with a district set (no wealth tint: the set is the district)

func _load_themes() -> void:
	if not theme_sets.is_empty() or tileset == null:
		return
	theme_sets["_tried"] = true
	# item icons (world-workshop) sit between the district sets and the base set: district -> items -> base
	var items_set = tileset.get_script().new()
	var below = tileset
	if items_set.load_dir("res://gfx/tiles_items"):
		items_set.fallback = tileset
		below = items_set
		theme_sets["_items"] = items_set
	for th in THEMES:
		var ts = tileset.get_script().new()
		if ts.load_dir("res://gfx/tiles_" + th):
			ts.fallback = below
			theme_sets[th] = ts

## the district a cell belongs to: the country and the docks outside the city, sewers and tunnels underground, and in
## the city its wealth (slums, mid-town, downtown)
func theme_at(c: int) -> String:
	if game.island != null and game.zone != game.island.CITY_ZONE:
		return "industry" if game.zone == game.island.PORT_ZONE else "rural"
	if c / game.s2 > game.city.zmax:
		return "industry"
	# the district of the 16 x 16 block the cell is in, so borders run straight instead of in steps across a lot
	var g: int = c % game.s2
	var bx: int = mini((g % game.size) / 16 * 16 + 8, game.size - 1)
	var by: int = mini((g / game.size) / 16 * 16 + 8, game.size - 1)
	return WEALTH_THEME[clampi(game.city.wealth_at(by * game.size + bx), 0, 2)]

## street furniture by district, drawn over the ground (it does not block): lamps and street trees along the kerb,
## neon, benches, flowerbeds, rubbish and spills along building fronts, fountains, statues and shrubs in parks, drums
## and pallets in the docks.  Chosen by a hash of the cell, so it is the same every time you pass.
const DECOR_KERB := {"rich": [[4, "f_trl_tree_street"], [9, "f_trl_streetlight"]], "mid": [[7, "f_trl_streetlight"], [13, "f_trl_tree_street"]],
	"slum": [[9, "f_trl_streetlight_broken"], [13, "f_trl_streetlight"], [17, "f_trl_trash"]], "industry": [[8, "f_trl_streetlight"], [15, "f_trl_barrels"]],
	"rural": [[19, "f_trl_streetlight"]]}
const DECOR_FRONT := {"rich": [[11, "f_trl_flowerbed"], [17, "f_trl_bench"], [23, "f_trl_neon_cyan"]],
	"mid": [[10, "neon"], [19, "f_trl_bench"], [29, "f_trl_flowerbed"]],
	"slum": [[6, "neon"], [9, "f_trl_spill_chem"], [11, "f_trl_trash"], [14, "f_trl_puddle"], [23, "f_trl_bench_broken"]],
	"industry": [[9, "f_trl_spill_oil"], [11, "f_trl_pallet"], [13, "f_trl_barrels"], [19, "neon"]],
	"rural": [[9, "f_trl_woodpile"], [15, "f_trl_fence"]]}
const DECOR_PARK := {"rich": [[23, "f_trl_flowerbed"], [61, "f_trl_fountain"], [67, "f_trl_statue"]], "mid": [[37, "f_trl_bench"], [97, "f_trl_statue"], [41, "f_trl_hedge"]],
	"slum": [[13, "f_trl_shrub_wild"], [29, "f_trl_trash"], [113, "f_trl_statue_broken"]], "industry": [[17, "f_trl_shrub_wild"], [31, "f_trl_barrels"]],
	"rural": [[53, "f_trl_haystack"], [71, "f_trl_well"], [29, "f_trl_shrub_wild"], [43, "f_trl_bamboo"]]}
const NEON_BY_THEME := {"rich": ["cyan"], "mid": ["pink", "cyan"], "slum": ["pink", "green", "violet", "red"], "industry": ["amber", "cyan"], "rural": ["amber"]}

func _decor_pick(table: Array, h: int, th: String) -> String:
	for e in table:
		if h % int(e[0]) == 0:
			var id: String = e[1]
			if id == "neon":
				var cols: Array = NEON_BY_THEME.get(th, ["pink"])
				return "f_trl_neon_" + String(cols[(h / 7) % cols.size()])
			return id
	return ""

func _decor(c: int, t: int, wx: int, wy: int, base: int) -> String:
	if not themed or c >= game.s2:
		return ""
	var th := theme_at(c)
	var h: int = ((c * 2654435761) >> 7) & 0xffffff
	var size: int = game.size
	if t == 0:
		var road := false
		var wall := false
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var x: int = wx + d.x
			var y: int = wy + d.y
			if x < 0 or y < 0 or x >= size or y >= size:
				continue
			var nt: int = game.city.tiles[base + y * size + x]
			road = road or nt == 1
			wall = wall or nt == 2 or nt == 10
		if road and not wall:
			return _decor_pick(DECOR_KERB.get(th, []), h, th)
		if wall and not road:
			return _decor_pick(DECOR_FRONT.get(th, []), h, th)
		return ""
	if t == 6:
		return _decor_pick(DECOR_PARK.get(th, []), h, th)
	if t == 13 and th == "industry":
		return _decor_pick([[13, "f_trl_barrels"], [17, "f_trl_pallet"], [29, "f_trl_generator"], [37, "f_trl_machinery"]], h, th)
	return ""

func _use_theme(c: int) -> void:
	var ts = theme_sets.get(theme_at(c)) if not theme_sets.is_empty() else null
	tileset = ts if ts != null else base_set
	themed = ts != null

func _cell_art(t: int, c: int, wx: int, wy: int, pos: Vector2, mod: Color, ground: bool) -> void:
	var T := TILE
	var wl: int = game.city.wealth_at(c)
	if not themed and wl != 1 and (t == 0 or t == 2 or t == 3 or t == 4 or t == 10):
		mod = mod * WEALTH_TINT[wl]
		if t == 3 and tileset.has("t_trl_marble") and tileset.has("t_concrete"):
			_blit(tileset.pick("t_trl_marble" if wl == 2 else "t_concrete", c), pos, mod)
			return
	var own: bool = tileset.index.has("t_wall.0")      # the Trilobit set has joined-up walls and doors
	var base: int = (c / game.s2) * game.s2
	if own and (t == 2 or t == 10):
		var m := 0
		if _joins(base, wx, wy - 1): m |= 1
		if _joins(base, wx + 1, wy): m |= 2
		if _joins(base, wx, wy + 1): m |= 4
		if _joins(base, wx - 1, wy): m |= 8
		_blit(tileset.pick("t_concrete", c), pos, mod)
		_blit(("t_wall_glass." if t == 10 else "t_wall.") + str(m), pos, mod)
		return
	if own and (t == 4 or t == 22):
		var vert: bool = _joins(base, wx, wy - 1) and _joins(base, wx, wy + 1) and not (_joins(base, wx - 1, wy) and _joins(base, wx + 1, wy))
		_blit(tileset.pick("t_floor", c), pos, mod)
		_blit(String(TERRAIN[t]) + (".v" if vert else ""), pos, mod)
		return
	if t == 14 and own:
		var mk: int = game.city.marks[c] if ground and c < game.city.marks.size() else 5
		_blit(String(TERRAIN[t]) + (".v" if mk == 6 else ""), pos, mod)
		return
	if t >= 23 and t <= 25:
		_blit(TERRAIN[0], pos, mod)
		if not _blit(tileset.pick(TERRAIN[t], c), pos, mod):
			draw_rect(Rect2(pos + Vector2(4, 4) * S, Vector2(T - 8 * S, T - 8 * S)), Color(0.5, 0.4, 0.25) * mod)
		return
	if t == 29:
		_blit(tileset.pick(TERRAIN[6], c), pos, mod)
		_blit(tileset.pick(TERRAIN[t], c), pos, mod)
		return
	if t == 1 and not tileset.variants.has("t_pavement"):
		draw_rect(Rect2(pos, Vector2(T, T)), Color(0.13, 0.13, 0.15) * mod)
		if ((c * 7919) >> 3) % 11 == 0:
			draw_rect(Rect2(pos.x + ((c % 5) * 5 + 3) * S, pos.y + ((c % 7) * 4 + 3) * S, 2 * S, 2 * S), Color(0.2, 0.2, 0.23) * mod)
	elif not _blit(tileset.pick(TERRAIN[t], c), pos, mod):
		draw_rect(Rect2(pos, Vector2(T, T)), _fallback(t) * mod)
	if ground:
		_paint_marks(c, pos, T, mod, t)

func _draw() -> void:
	if game == null or tileset == null:
		return
	var T := tile()
	var size: int = game.size
	var s2: int = game.s2
	var base: int = (game.pc / s2) * s2
	var px: int = game.lx(game.pc)
	var py: int = game.ly(game.pc)
	var cx: int = game.lx(focus_cell) if focus_cell >= 0 else px      # the camera sits on the player, or on the target you switched the view to
	var cy: int = game.ly(focus_cell) if focus_cell >= 0 else py
	var ox := cx - cols / 2 + (look_off.x if look_on else 0)
	var oy := cy - rows / 2 + (look_off.y if look_on else 0)
	var below_mod := Color(0.5, 0.55, 0.75)
	base_set = tileset if base_set == null or not (tileset in theme_sets.values()) else base_set
	_load_themes()
	for sy in rows:
		for sx in cols:
			tileset = base_set
			themed = false
			var wx := ox + sx
			var wy := oy + sy
			if wx < 0 or wy < 0 or wx >= size or wy >= size:
				if game.island != null and base == 0:
					var ot: int = game.outside_tile(wx, wy)
					var opos := Vector2(sx * T, sy * T)
					if ot == 29:
						_blit(tileset.pick(TERRAIN[6], wy * 4099 + wx), opos, DARK)
					if not _blit(tileset.pick(TERRAIN[ot], wy * 4099 + wx), opos, DARK):
						draw_rect(Rect2(opos, Vector2(T, T)), _fallback(ot) * DARK)
				continue
			var c := base + wy * size + wx
			if game.fov.explored[c] == 0:
				continue
			_use_theme(c)
			var vis: bool = game.fov.visible[c] == 1
			var mod: Color = Color.WHITE if vis else DARK
			var pos := Vector2(sx * T, sy * T)
			var t: int = game.city.tiles[c]
			if t == 7:
				var bt := _below(c)
				if bt >= 0:
					_blit(tileset.pick(TERRAIN[bt], c), pos, mod * below_mod)
				continue
			if (t == CG.TID["window_broken"] or t == CG.TID["door_closed"]) and tileset.index.has("t_door_closed"):
				_blit(tileset.pick("t_floor", c), pos, mod)
				var vert: bool = _joins(base, wx, wy - 1) and _joins(base, wx, wy + 1) and not (_joins(base, wx - 1, wy) and _joins(base, wx + 1, wy))
				var key: String = "t_window_broken" if t == CG.TID["window_broken"] else "t_door_closed"
				_blit(key + (".v" if vert and tileset.index.has(key + ".v") else ""), pos, mod)
			elif t == CG.TID["window_broken"]:
				_blit(tileset.pick("t_floor", c), pos, mod)
				for k in 3:
					draw_line(pos + Vector2(4 + k * 8, 3) * S, pos + Vector2(10 + k * 7, 29) * S, Color(0.75, 0.9, 1.0, 0.8) * mod, 1.2 * S)
				draw_rect(Rect2(pos + Vector2(2, 2) * S, Vector2(T - 4 * S, 3 * S)), Color(0.55, 0.62, 0.7) * mod)
				draw_rect(Rect2(pos + Vector2(2, T - 5 * S), Vector2(T - 4 * S, 3 * S)), Color(0.55, 0.62, 0.7) * mod)
			elif t == CG.TID["door_closed"]:
				_blit(tileset.pick("t_floor", c), pos, mod)
				draw_rect(Rect2(pos + Vector2(3, 3) * S, Vector2(T - 6 * S, T - 6 * S)), Color(0.35, 0.24, 0.14) * mod)
				draw_rect(Rect2(pos + Vector2(6, 6) * S, Vector2(T - 12 * S, T - 12 * S)), Color(0.5, 0.36, 0.22) * mod)
				draw_circle(pos + Vector2(T - 10 * S, T * 0.5), 2.2 * S, Color(0.9, 0.8, 0.4) * mod)
			elif t >= CG.EXTRA0:
				if t >= CG.EXTRA0 + 9:      # furniture stands on a floor
					var under_t: int = game.city.under[c] if c < game.city.under.size() else 3
					if under_t >= CG.EXTRA0:
						_blit(tileset.pick(String(CG.TILE_SPRITE.get(under_t, "t_floor")), c), pos, mod)
					else:
						_blit(tileset.pick(String(TERRAIN.get(under_t, "t_floor")), c), pos, mod)
				if not _blit(tileset.pick(String(CG.TILE_SPRITE.get(t, "")), c), pos, mod):
					draw_rect(Rect2(pos + Vector2(4, 4) * S, Vector2(T - 8 * S, T - 8 * S)), Color(0.5, 0.4, 0.25) * mod)
			else:
				_cell_art(t, c, wx, wy, pos, mod, c < s2)
				var dec := _decor(c, t, wx, wy, base)
				if dec != "" and tileset.index.has(dec) and not game.items_at.has(c):
					_blit(dec, pos, mod)
			if vis and game.items_at.has(c):
				var arr: Array = game.items_at[c]
				_blit(item_sprite(arr[arr.size() - 1]), pos)
	tileset = base_set
	themed = false
	# the trains: a cutaway of each carriage, tile by tile (wall/door, two floor lanes, wall/door)
	if game.transit.active():
		var tr = game.transit
		var occ: Dictionary = tr.occupancy()
		for c in occ:
			if c / s2 != base / s2:
				continue
			var wx: int = c % size - ox
			var wy: int = (c / size) % size - oy
			if wx < 0 or wy < 0 or wx >= cols or wy >= rows or game.fov.visible[c] != 1:
				continue
			var info: Array = tr.occ_unpack(int(occ[c]))
			_draw_train_tile(Vector2(wx * T, wy * T), info, tr)
	# loose things and animals
	for t in game.things:
		if t["k"] == "":
			continue
		var tc: int = t["cell"]
		if tc / s2 != base / s2 or game.fov.visible[tc] == 0:
			continue
		var tx: int = tc % size - ox
		var ty: int = (tc / size) % size - oy
		if tx < 0 or ty < 0 or tx >= cols or ty >= rows:
			continue
		var tid: String = "f_" + String(t["k"]) + ("_c" if t["k"] == "crate" else "")
		if not _blit(tid, Vector2(tx * T, ty * T)):
			draw_rect(Rect2(tx * T + 6 * S, ty * T + 6 * S, T - 12 * S, T - 12 * S), Color(0.6, 0.45, 0.25))
	for cb in game.corpses:      # placeholder body: a dark slumped shape, art to come
		var bc: int = cb["cell"]
		if bc / s2 != base / s2 or game.fov.visible[bc] == 0:
			continue
		var bx: int = bc % size - ox
		var by: int = (bc / size) % size - oy
		if bx < 0 or by < 0 or bx >= cols or by >= rows:
			continue
		if not _blit("corpse", Vector2(bx * T, by * T)):
			var bp := Vector2(bx * T, by * T)
			draw_rect(Rect2(bp.x + T * 0.15, bp.y + T * 0.38, T * 0.7, T * 0.28), Color(0.28, 0.1, 0.1))
			draw_rect(Rect2(bp.x + T * 0.1, bp.y + T * 0.42, T * 0.2, T * 0.2), Color(0.5, 0.4, 0.35))
			draw_rect(Rect2(bp.x + T * 0.15, bp.y + T * 0.38, T * 0.7, T * 0.28), Color(0.7, 0.2, 0.2, 0.6), false, 1.0)
	for k in game.critters:
		if k["k"] == "":
			continue
		var kc: int = k["cell"]
		if kc / s2 != base / s2 or game.fov.visible[kc] == 0:
			continue
		var kx: int = kc % size - ox
		var ky: int = (kc / size) % size - oy
		if kx < 0 or ky < 0 or kx >= cols or ky >= rows:
			continue
		if int(k.get("mood", 0)) == 1:         # only an angry animal is marked; ordinary dogs and cats show nothing
			_facing_mark(Vector2(kx * T, ky * T), int(k.get("face", 0)), ATT_COL[2])
		if not _blit("mon_" + String(k["k"]), Vector2(kx * T, ky * T)):
			draw_string(font, Vector2(kx * T + T * 0.3, ky * T + T * 0.7), "d" if k["k"] == "dog" else "c", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.9, 0.7, 0.4))
	# vehicles: whole bodies, a tile for every tile of the footprint
	for vi in game.vehicles.size():
		var v: Dictionary = game.vehicles[vi]
		if int(v["cell"]) / s2 != base / s2:
			continue
		_draw_body(vi, v, ox, oy, T)
	# people
	for k in game.sim.near_list.size():
		var i: int = game.sim.near_list[k]
		var c: int = game.sim.pos[i]
		if c / s2 != base / s2:
			continue
		var wx: int = c % size - ox
		var wy: int = (c / size) % size - oy
		if wx < 0 or wy < 0 or wx >= cols or wy >= rows or game.fov.visible[c] == 0:
			continue
		var pos := Vector2(wx * T, wy * T)
		if not doll_ready():
			_blit(person_sprite(i), pos)
		var fd: Array = game.DIR8[int(game.face[i]) % 8]
		_draw_doll(DS.for_person(game, i), pos, Vector2i(fd[0], fd[1]))
		if game.marked(i):                     # unaffiliated people show no indicator at all
			_awareness_glow(pos, int(game.astate[i]))
			_facing_mark(pos, int(game.face[i]), ATT_COL[game.attitude(i)])
		var glyph := ""
		var col := Color.WHITE
		match int(game.astate[i]):
			5: glyph = "~"; col = Color(0.6, 0.9, 1)
			6: glyph = "="; col = Color.WHITE
		if glyph == "":
			match int(game.eco.role[i]):
				1: glyph = "$"; col = Color(0.4, 1, 0.5)
				2: glyph = "+"; col = Color(0.4, 0.9, 1)
				3: glyph = "*"; col = Color(1, 0.8, 0.3)
				4, 5: glyph = "$"; col = Color(1, 0.7, 0.3)
				6: glyph = "+"; col = Color(0.4, 1, 0.8)
				7, 8: glyph = "^"; col = Color(0.9, 0.85, 1)
		if glyph != "":
			draw_string(font, pos + Vector2(T * 0.3, -2 * S), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col)
	# the player
	var centre := Vector2((px - ox) * T, (py - oy) * T)
	if game.in_vehicle >= 0:
		draw_circle(centre + Vector2(T / 2.0, T / 2.0), T * 0.22, Color(0.95, 0.8, 0.65))
		draw_arc(centre + Vector2(T / 2.0, T / 2.0), T * 0.22, PI, TAU, 12, Color(0.15, 0.1, 0.1), 3.0 * S)
	elif game.transit.riding < 0:
		if game.flying:
			draw_circle(centre + Vector2(T / 2.0, T * 0.9), T * 0.28, Color(0, 0, 0, 0.35))
			draw_circle(centre + Vector2(T / 2.0, T * 0.95), 5.0 * S, Color(1, 0.7, 0.2, 0.9))
		if not doll_ready():
			_blit("trl_person_player", centre)
		_draw_doll(DS.for_player(game), centre, game.facing)
	else:
		_draw_doll(DS.for_player(game), centre, game.facing, Color(1, 1, 1, 0.9))
	_draw_cranes(ox, oy, base)
	# the job target, if it is on this level
	if not game.eco.job.is_empty() and int(game.eco.job["cell"]) / s2 == base / s2:
		var jc: int = game.eco.job["cell"]
		var jr := Rect2((game.lx(jc) - ox) * T, (game.ly(jc) - oy) * T, T, T)
		draw_rect(jr, Color(1, 0.8, 0.2), false, 2.0 * S)
	# target bracket
	var tg: int = game.current_target()
	if tg >= 0:
		var c: int = game.sim.pos[tg]
		var r := Rect2((c % size - ox) * T, ((c / size) % size - oy) * T, T, T)
		draw_rect(r, Color(1, 0.2, 0.2), false, 2.0 * S)
		if game.aim_turns > 0:
			draw_rect(r.grow(3 * S), Color(1, 0.6, 0.2), false, 1.0 * S)
	# tracers from the last volley
	for tr in game.tracers:
		var a: int = tr[0]
		var b: int = tr[1]
		var pa := Vector2((a % size - ox + 0.5) * T, ((a / size) % size - oy + 0.5) * T)
		var pb := Vector2((b % size - ox + 0.5) * T, ((b / size) % size - oy + 0.5) * T)
		draw_line(pa, pb, Color(1, 0.95, 0.5) if tr[2] else Color(0.8, 0.8, 0.8, 0.6), 2.0 * S)
	if look_on:
		var lr := Rect2((px + look_off.x - ox) * T, (py + look_off.y - oy) * T, T, T)
		draw_rect(lr, Color(0.3, 0.95, 1.0), false, 3.0 * S)
		draw_rect(lr.grow(4 * S), Color(0.3, 0.95, 1.0, 0.45), false, 1.0 * S)
		if look_off != Vector2i.ZERO:
			var pr := Rect2((px - ox) * T, (py - oy) * T, T, T)
			draw_line(pr.get_center(), lr.get_center(), Color(0.3, 0.95, 1.0, 0.35), 2.0 * S)
	draw_set_transform(-shift, 0.0, Vector2.ONE)       # the message bar below the map hides anything drawn past it
	draw_rect(Rect2(0, MAP_H, 1920, 400), Color.BLACK)
	_draw_hud()

## facing-arrow colours by attitude towards the player: friendly green, neutral blue, hostile red
const ATT_COL := [Color(0.3, 1.0, 0.4, 0.95), Color(0.35, 0.6, 1.0, 0.95), Color(1.0, 0.25, 0.25, 0.95)]

## a glow along the edges of a tile for how aware someone is of you: unaware blue, suspicious (and searching) yellow, hunting orange
func _awareness_glow(pos: Vector2, st: int) -> void:
	var col: Color
	match st:
		0: col = Color(0.3, 0.55, 1.0)
		1, 2: col = Color(1.0, 0.9, 0.2)
		3: col = Color(1.0, 0.5, 0.1)
		_: return
	var T: float = float(tile())
	var w: float = maxf(2.0, T / 22.0)
	for k in 4:
		var a: float = 0.85 - 0.25 * k
		var r := Rect2(pos + Vector2(w * (k + 0.5), w * (k + 0.5)), Vector2(T - w * (2 * k + 1), T - w * (2 * k + 1)))
		draw_rect(r, Color(col.r, col.g, col.b, a), false, w)

## a small pointer on the edge of a tile showing which way someone faces (index into DIR8)
func _facing_mark(pos: Vector2, fi: int, col: Color) -> void:
	var d: Array = game.DIR8[fi % 8]
	var T: float = float(tile())
	var dir := Vector2(d[0], d[1]).normalized()
	var c := pos + Vector2(T, T) * 0.5 + dir * T * 0.47
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([c + dir * T * 0.14, c - dir * T * 0.1 + side * T * 0.14, c - dir * T * 0.1 - side * T * 0.14]), col)

func _limb_color(f: float) -> Color:
	if f <= 0.0:
		return Color(0.25, 0.25, 0.28)
	return Color(0.9, 0.15, 0.15).lerp(Color(0.25, 0.85, 0.35), clampf(f, 0.0, 1.0))

func _bar(x: float, y: float, w: float, h: float, f: float, col: Color, label: String) -> void:
	draw_rect(Rect2(x, y, w, h), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(x + 1, y + 1, (w - 2) * clampf(f, 0.0, 1.0), h - 2), col)
	draw_rect(Rect2(x, y, w, h), Color(1, 1, 1, 0.35), false, 1.0)
	draw_string(font, Vector2(x + 4, y + h - 3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h) - 2, Color.WHITE)

# ---------------------------------------------------------------- the side panel (UI units: 1280x720, drawn at 1.5x)
const PANEL_W := 252.0
const PANEL_H := 558.0               # rows * TILE / 1.5
var focus_cell: int = -1               # the camera is centred on this cell (a target out of the player's own screen) instead of the player; -1 = the player
var look_on: bool = false              # the look cursor is out: the view is centred on it, not on the player
var look_off := Vector2i.ZERO          # ... this many tiles from the player
var hud_extra: String = ""            # vehicle / jet-pack line, set by main
const C_CYAN := Color(0.35, 0.85, 0.95)
const C_DIM := Color(0.55, 0.62, 0.72)

func _txt(x: float, y: float, t: String, size: int = 13, col: Color = Color(0.9, 0.93, 0.98), w: float = -1.0, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(font, Vector2(x, y), t, align, w, size, col)

## a tapered capsule from a to b (radius ra at a, rb at b) as a polygon, with round ends
func _capsule_pts(a: Vector2, b: Vector2, ra: float, rb: float) -> PackedVector2Array:
	var ang: float = (b - a).angle()
	var pts := PackedVector2Array()
	var n := 8
	for i in range(n + 1):
		var t: float = ang - PI * 0.5 + PI * float(i) / n
		pts.append(b + Vector2(cos(t), sin(t)) * rb)
	for i in range(n + 1):
		var t2: float = ang + PI * 0.5 + PI * float(i) / n
		pts.append(a + Vector2(cos(t2), sin(t2)) * ra)
	return pts

## one limb of the figure: shaded body colour, a highlight along the lit side, an outline, and an armour shell when it is armoured
func _limb(a: Vector2, b: Vector2, ra: float, rb: float, col: Color, armour: bool, off: bool) -> void:
	var pts := _capsule_pts(a, b, ra, rb)
	var base: Color = col.darkened(0.45)
	draw_colored_polygon(pts, base)
	var side: Vector2 = (b - a).normalized().orthogonal() * -0.28
	var hl := _capsule_pts(a + side * ra, b + side * rb, ra * 0.62, rb * 0.62)
	draw_colored_polygon(hl, col)
	var core := _capsule_pts(a + side * ra * 1.2, b + side * rb * 1.2, ra * 0.28, rb * 0.28)
	draw_colored_polygon(core, col.lightened(0.35))
	var oc := Color(0.02, 0.05, 0.08, 0.95)
	var ring := pts.duplicate()
	ring.append(pts[0])
	draw_polyline(ring, oc, 1.6)
	if armour:
		draw_polyline(ring, Color(0.45, 0.8, 1.0, 0.9), 1.0)
	if off:
		var m: Vector2 = (a + b) * 0.5
		draw_line(m + Vector2(-ra, -ra), m + Vector2(ra, ra), Color(1, 0.3, 0.3), 2.0)
		draw_line(m + Vector2(-ra, ra), m + Vector2(ra, -ra), Color(1, 0.3, 0.3), 2.0)

func _poly(pts: Array, col: Color, outline: bool = true) -> void:
	var pa := PackedVector2Array(pts)
	draw_colored_polygon(pa, col)
	if outline:
		var ring := pa.duplicate()
		ring.append(pa[0])
		draw_polyline(ring, Color(0.02, 0.05, 0.08, 0.95), 1.6)

## the vitals figure: a front-facing anatomical silhouette, every limb tinted by its health
func _draw_person(cx: float, y0: float, u: float) -> void:
	var B = game.body
	var ar := func(l: String) -> bool: return game.armor_value(l) > 0
	var P := func(x: float, y: float) -> Vector2: return Vector2(cx + x * u, y0 + y * u)
	var cc: Color = _limb_color(B.frac("chest"))
	var hc: Color = _limb_color(B.frac("head"))
	# hologram stand: a faint ring under the feet and a scan grid behind
	draw_colored_polygon(_ellipse_pts(P.call(0.0, 8.15), 1.9 * u, 0.28 * u), Color(0.2, 0.7, 0.85, 0.12))
	draw_polyline(_ellipse_pts(P.call(0.0, 8.15), 1.9 * u, 0.28 * u, true), Color(0.3, 0.85, 0.95, 0.5), 1.0)
	# legs (behind the torso): thigh then shin then foot
	for side in [-1, 1]:
		var lname: String = "r_leg" if side < 0 else "l_leg"
		var lc: Color = _limb_color(B.frac(lname))
		var off: bool = not B.ok(lname)
		var a: bool = ar.call(lname)
		_limb(P.call(side * 0.42, 3.95), P.call(side * 0.5, 5.85), 0.46 * u, 0.3 * u, lc, a, false)
		_limb(P.call(side * 0.5, 5.85), P.call(side * 0.52, 7.55), 0.28 * u, 0.2 * u, lc, a, off)
		_poly([P.call(side * 0.52 - 0.2, 7.45), P.call(side * 0.52 + 0.2, 7.45), P.call(side * 0.52 + 0.28 + side * 0.18, 8.0), P.call(side * 0.52 - 0.2 + side * 0.1, 8.02)], lc.darkened(0.3))
	# arms: upper arm, forearm, hand
	for side in [-1, 1]:
		var aname: String = "r_arm" if side < 0 else "l_arm"
		var ac: Color = _limb_color(B.frac(aname))
		var off2: bool = not B.ok(aname)
		var a2: bool = ar.call(aname)
		_limb(P.call(side * 0.98, 1.6), P.call(side * 1.28, 3.05), 0.34 * u, 0.26 * u, ac, a2, false)
		_limb(P.call(side * 1.28, 3.05), P.call(side * 1.46, 4.45), 0.25 * u, 0.17 * u, ac, a2, off2)
		_limb(P.call(side * 1.46, 4.45), P.call(side * 1.52, 4.95), 0.17 * u, 0.13 * u, ac.darkened(0.2), false, false)
	# pelvis and torso
	_poly([P.call(-0.78, 3.45), P.call(0.78, 3.45), P.call(0.66, 4.15), P.call(0.0, 4.35), P.call(-0.66, 4.15)], cc.darkened(0.5))
	var torso := [P.call(-0.98, 1.5), P.call(-0.45, 1.38), P.call(0.45, 1.38), P.call(0.98, 1.5), P.call(0.9, 2.3), P.call(0.66, 3.25), P.call(0.74, 3.6), P.call(-0.74, 3.6), P.call(-0.66, 3.25), P.call(-0.9, 2.3)]
	_poly(torso, cc.darkened(0.45))
	_poly([P.call(-0.62, 1.55), P.call(0.0, 1.5), P.call(0.0, 2.55), P.call(-0.74, 2.45)], cc, false)         # lit side of the chest
	_poly([P.call(0.0, 1.5), P.call(0.62, 1.55), P.call(0.74, 2.45), P.call(0.0, 2.55)], cc.darkened(0.2), false)
	_poly([P.call(-0.46, 2.65), P.call(-0.03, 2.65), P.call(-0.03, 3.5), P.call(-0.5, 3.4)], cc.darkened(0.12), false)   # abdomen
	_poly([P.call(0.03, 2.65), P.call(0.46, 2.65), P.call(0.5, 3.4), P.call(0.03, 3.5)], cc.darkened(0.3), false)
	draw_line(P.call(0.0, 1.5), P.call(0.0, 3.55), Color(0, 0, 0, 0.45), 1.0)                                   # sternum / midline
	draw_line(P.call(-0.55, 2.62), P.call(0.55, 2.62), Color(0, 0, 0, 0.35), 1.0)                               # ribs / belt line
	var tor: Array = torso.duplicate()
	tor.append(torso[0])
	draw_polyline(PackedVector2Array(tor), Color(0.02, 0.05, 0.08, 0.95), 1.8)
	if ar.call("chest"):
		draw_polyline(PackedVector2Array(tor), Color(0.45, 0.8, 1.0, 0.9), 1.0)
	# collar, neck and head
	_limb(P.call(0.0, 1.0), P.call(0.0, 1.42), 0.2 * u, 0.26 * u, hc.darkened(0.25), false, false)
	var hp_ := _ellipse_pts(P.call(0.0, 0.5), 0.36 * u, 0.5 * u)
	draw_colored_polygon(hp_, hc.darkened(0.45))
	draw_colored_polygon(_ellipse_pts(P.call(-0.07, 0.44), 0.24 * u, 0.4 * u), hc)
	draw_colored_polygon(_ellipse_pts(P.call(-0.12, 0.34), 0.1 * u, 0.16 * u), hc.lightened(0.35))
	draw_colored_polygon(PackedVector2Array([P.call(-0.2, 0.62), P.call(0.2, 0.62), P.call(0.13, 0.9), P.call(0.0, 0.98), P.call(-0.13, 0.9)]), hc.darkened(0.2))   # jaw
	var eye := Color(0.02, 0.05, 0.08, 0.9)
	draw_rect(Rect2(P.call(-0.2, 0.46), Vector2(0.14 * u, 0.05 * u)), eye)
	draw_rect(Rect2(P.call(0.06, 0.46), Vector2(0.14 * u, 0.05 * u)), eye)
	var hr := hp_.duplicate()
	hr.append(hp_[0])
	draw_polyline(hr, Color(0.02, 0.05, 0.08, 0.95), 1.8)
	if ar.call("head"):
		draw_polyline(hr, Color(0.45, 0.8, 1.0, 0.9), 1.0)
		draw_arc(P.call(0.0, 0.5), 0.42 * u, PI * 1.05, PI * 1.95, 14, Color(0.45, 0.8, 1.0, 0.9), 1.6)           # helmet brow
	if not B.ok("head") or not B.ok("chest"):
		_txt(cx - 20, y0 + 4.9 * u, "CRITICAL", 11, Color(1, 0.3, 0.3), 40, HORIZONTAL_ALIGNMENT_CENTER)
	# scanlines over the whole figure
	var k := 0.0
	while k < 8.2:
		draw_line(P.call(-2.0, k), P.call(2.0, k), Color(0.4, 0.9, 1.0, 0.045), 1.0)
		k += 0.12

func _ellipse_pts(c: Vector2, rx: float, ry: float, closed: bool = false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var t: float = TAU * float(i) / 24.0
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry))
	if closed:
		pts.append(pts[0])
	return pts

func _meter(x: float, y: float, w: float, h: float, f: float, col: Color, label: String, right: String = "") -> void:
	draw_rect(Rect2(x, y, w, h), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(x + 1, y + 1, (w - 2) * clampf(f, 0.0, 1.0), h - 2), col)
	draw_rect(Rect2(x + 1, y + 1, (w - 2) * clampf(f, 0.0, 1.0), (h - 2) * 0.4), Color(1, 1, 1, 0.14))
	draw_rect(Rect2(x, y, w, h), Color(1, 1, 1, 0.3), false, 1.0)
	_txt(x + 4, y + h - 3, label, int(h) - 3, Color.WHITE)
	if right != "":
		_txt(x, y + h - 3, right, int(h) - 3, Color.WHITE, w - 4, HORIZONTAL_ALIGNMENT_RIGHT)

## the right-hand panel, as a sidebar: where and when, the (purchasable) nav slot, the body, the meters, status effects and gear.
## There is deliberately no minimap: that is an implant to buy.
func _draw_hud() -> void:
	draw_set_transform(-shift, 0.0, Vector2(1.5, 1.5))
	var W: float = 1920.0 / 1.5
	var x0: float = W - PANEL_W
	var xi: float = x0 + 10.0
	var wi: float = PANEL_W - 20.0
	draw_rect(Rect2(x0, 0, PANEL_W, PANEL_H), Color(0.03, 0.04, 0.08, 0.86))
	draw_rect(Rect2(x0, 0, 2, PANEL_H), Color(0.25, 0.8, 0.95, 0.55))
	draw_rect(Rect2(x0, PANEL_H - 2, PANEL_W, 2), Color(0.25, 0.8, 0.95, 0.35))
	var B = game.body
	# where and when
	var where: String = game.zname(game.pc)
	var tw: Dictionary = game.tower_at(game.pc) if game.z_of(game.pc) > 0 else {}
	if not tw.is_empty():
		where += " (%d)" % int(tw["h"])
	var who: String = game.player_name.strip_edges()
	_txt(xi, 17, who if who != "" else "UNNAMED", 15, Color.WHITE if who != "" else C_DIM, wi)
	_txt(xi, 33, where.to_upper(), 12, C_CYAN, wi)
	_txt(xi, 52, game.time_text(), 16, Color.WHITE)
	_txt(xi + 80, 52, "Day %d   Turn %d" % [CLK.day_of(game.sim.tick), game.turn], 11, C_DIM)
	_txt(xi, 52, "¥%d" % game.yen, 14, Color(0.95, 0.85, 0.4), wi, HORIZONTAL_ALIGNMENT_RIGHT)
	# the nav slot: an empty implant bay
	var ny := 60.0
	draw_rect(Rect2(xi, ny, wi, 50), Color(0.02, 0.03, 0.06, 0.9))
	var dash := 0.0
	while dash < wi:
		draw_line(Vector2(xi + dash, ny), Vector2(xi + minf(dash + 6.0, wi), ny), Color(0.35, 0.5, 0.6, 0.7), 1.0)
		draw_line(Vector2(xi + dash, ny + 50), Vector2(xi + minf(dash + 6.0, wi), ny + 50), Color(0.35, 0.5, 0.6, 0.7), 1.0)
		dash += 10.0
	_txt(xi, ny + 21, "NAV IMPLANT: NOT INSTALLED", 12, C_DIM, wi, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(xi, ny + 37, "minimap available from a ripperdoc", 11, Color(0.4, 0.46, 0.55), wi, HORIZONTAL_ALIGNMENT_CENTER)
	# the figure and the limb readouts
	var fy: float = 116.0
	_draw_person(x0 + 62.0, fy, 21.0)
	var names := {"head": "HEAD", "chest": "CHEST", "l_arm": "L ARM", "r_arm": "R ARM", "l_leg": "L LEG", "r_leg": "R LEG"}
	var k := 0
	for l in game.BODY.LIMBS:
		var by: float = fy + 6.0 + float(k) * 30.0
		var av: int = game.armor_value(l)
		var f: float = B.frac(l)
		_txt(x0 + 124, by + 8, names[l], 11, C_DIM)
		if av > 0:
			_txt(x0 + 124, by + 8, "armor %d" % av, 11, Color(0.5, 0.78, 1.0), 118, HORIZONTAL_ALIGNMENT_RIGHT)
		_meter(x0 + 124, by + 11, 118, 13, f, _limb_color(f), "OFF" if not B.ok(l) else "", "%d/%d" % [int(B.hp[l]), int(B.mx[l])])
		k += 1
	# the meters
	var my: float = fy + 190.0
	var pcap: float = game.power_cap()
	if pcap > 0.0:
		var pf: float = game.power_left() / pcap
		_meter(xi, my, wi, 16, pf, Color(0.95, 0.8, 0.2) if pf > 0.25 else Color(0.95, 0.35, 0.25), "POWER", "%d kJ  %dh" % [int(game.power_left()), int(game.power_hours())])
	else:
		_meter(xi, my, wi, 16, 1.0, Color(0.45, 0.6, 0.5), "HUMAN", "no implants")
	var ars: Dictionary = game.armor_status()
	var broken := false
	for l in game.BODY.LIMBS:
		for p in game.armor_pieces(l):
			if int(p["left"]) <= 0:
				broken = true
	var amax: int = int(ars["max"])
	_meter(xi, my + 20, wi, 16, (float(ars["left"]) / float(maxi(1, amax))) if amax > 0 else 0.0, Color(0.35, 0.65, 0.95) if not broken else Color(0.9, 0.55, 0.2), "ARMOR %d" % int(ars["value"]), ("BROKEN" if broken else "%d / %d" % [int(ars["left"]), amax]))
	var stf: float = float(game.stamina) / float(game.STAMINA_MAX)
	_meter(xi, my + 40, wi, 16, stf, Color(0.9, 0.78, 0.25) if stf > 0.25 else Color(0.9, 0.45, 0.2), "STAMINA", "%s  %d AP" % [game.stance_name(), game.ap_rate()])
	# hunger and thirst: full when you have just eaten or drunk, empty (and a status effect) when the clock runs out
	var nt: Array = game.need_timers()
	var ff: float = float(nt[0]) / float(game.HUNGER_AFTER)
	var tf: float = float(nt[1]) / float(game.THIRST_AFTER)
	_meter(xi, my + 62, wi * 0.5 - 3, 14, ff, Color(0.75, 0.55, 0.25) if not game.hungry() else Color(0.8, 0.2, 0.2), "FOOD", "HUNGRY" if game.hungry() else CLK.span_text(nt[0]))
	_meter(xi + wi * 0.5 + 3, my + 62, wi * 0.5 - 3, 14, tf, Color(0.3, 0.6, 0.9) if not game.thirsty() else Color(0.8, 0.2, 0.2), "WATER", "THIRSTY" if game.thirsty() else CLK.span_text(nt[1]))
	# status effects
	var ey: float = my + 94.0
	var fx: float = xi
	var effects: Array = []
	for e in game.status_effects():
		effects.append([e + " -20%", Color(0.95, 0.5, 0.3)])
	if game.drunk_left > 0:
		effects.append(["Drunk", Color(0.9, 0.75, 0.3)])
	if game.bless_left > 0:
		effects.append(["Blessed", Color(0.7, 0.9, 1.0)])
	if game.transit.riding >= 0:
		effects.append(["On train", C_CYAN])
	if effects.is_empty():
		_txt(xi, ey + 11, "No status effects", 11, Color(0.4, 0.46, 0.55))
	for e in effects:
		var tw2: float = font.get_string_size(String(e[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 12.0
		if fx + tw2 > xi + wi:
			fx = xi
			ey += 18.0
		draw_rect(Rect2(fx, ey, tw2, 15), Color(0.1, 0.12, 0.18, 0.95))
		draw_rect(Rect2(fx, ey, 3, 15), e[1])
		_txt(fx + 7, ey + 12, String(e[0]), 12, e[1])
		fx += tw2 + 4.0
	# gear and movement
	var gy: float = ey + 30.0
	draw_line(Vector2(xi, gy - 8), Vector2(xi + wi, gy - 8), Color(0.3, 0.45, 0.55, 0.5), 1.0)
	var mv: String = game.stance_name()
	_txt(xi, gy + 4, "SPEED", 11, C_DIM)
	_txt(xi, gy + 4, "%d%%  (%s)" % [int(round(game.speed_mult() * 100.0)), mv], 12, Color(1, 0.6, 0.4) if game.speed_mult() < 1.0 else Color.WHITE, wi, HORIZONTAL_ALIGNMENT_RIGHT)
	_txt(xi, gy + 20, "PACK", 11, C_DIM)
	_txt(xi, gy + 20, "%d / %d tiles" % [game.inv.used(), game.inv.capacity()], 12, Color.WHITE, wi, HORIZONTAL_ALIGNMENT_RIGHT)
	_txt(xi, gy + 38, game.gun_line(), 12, Color(0.95, 0.88, 0.7), wi)
	if hud_extra != "":
		_txt(xi, gy + 55, hud_extra.strip_edges(), 11, C_CYAN, wi)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## a vehicle drawn tile by tile from its template
func _draw_body(vi: int, v: Dictionary, ox: int, oy: int, T: int) -> void:
	var size: int = game.size
	var kind: String = v["kind"]
	var dirn: int = int(v["dir"])
	var offs: Array = game.vs.offsets(kind, dirn)
	var a: int = int(v["cell"])
	var ax: int = a % size
	var ay: int = (a / size) % size
	var base: int = (a / game.s2) * game.s2
	var col: Color = v["color"]
	var wreck: bool = v["wreck"]
	var occupied := {}
	var any_vis := false
	for o in offs:
		occupied[Vector2i(o[0], o[1])] = String(o[2])
		var c: int = base + (ay + o[1]) * size + ax + o[0]
		if c >= 0 and c < game.total and game.fov.visible[c] == 1:
			any_vis = true
	if not any_vis:
		return
	if _draw_body_sprite(vi, v, ox, oy, T):
		return
	var shade := Color(0, 0, 0, 0.28)
	var front: Vector2i = game.vs.fwd(kind, dirn)
	# a soft shadow under anything in the air
	var airborne: bool = bool(v.get("air", false))
	for o in offs:
		var px: float = float(ax + o[0] - ox) * T
		var py: float = float(ay + o[1] - oy) * T
		if px < -T or py < -T or px > cols * T or py > rows * T:
			continue
		var ch: String = String(o[2])
		var r := Rect2(px, py, T, T)
		var cc: Color = col
		match ch:
			"E": cc = col.darkened(0.18)
			"T": cc = col.lightened(0.06)
			"P": cc = col.lightened(0.25)
			"H": cc = col.darkened(0.35)
			"L": cc = Color(0.28, 0.3, 0.34)
			"C": cc = Color(0.17, 0.2, 0.26)
			"K": cc = Color(0.35, 0.55, 0.7)
		if airborne:
			draw_rect(Rect2(px + 4 * S, py + T * 0.55, T, T), shade)
		draw_rect(r, cc)
		# panel seams
		match ch:
			"E":
				for k in 3:
					var gx: float = px + 6 * S + k * (T - 12 * S) / 2.0
					if dirn % 2 == 0:
						draw_line(Vector2(gx, py + 5 * S), Vector2(gx, py + T - 5 * S), cc.darkened(0.4), 2.0 * S)
					else:
						draw_line(Vector2(px + 5 * S, py + 6 * S + k * (T - 12 * S) / 2.0), Vector2(px + T - 5 * S, py + 6 * S + k * (T - 12 * S) / 2.0), cc.darkened(0.4), 2.0 * S)
			"T":
				draw_rect(r.grow(-6 * S), cc.darkened(0.12), false, 1.5 * S)
			"C":
				draw_rect(r.grow(-5 * S), Color(0.28, 0.33, 0.42))
			"W":
				var wr := Rect2(px + 6 * S, py + 3 * S, T - 12 * S, T - 6 * S) if dirn % 2 == 0 else Rect2(px + 3 * S, py + 6 * S, T - 6 * S, T - 12 * S)
				draw_rect(wr, Color(0.06, 0.06, 0.07))
			"L":
				draw_rect(r.grow(-7 * S), Color(0.15, 0.16, 0.19))
			"P":
				draw_line(Vector2(px + 3 * S, py + 3 * S), Vector2(px + T - 3 * S, py + T - 3 * S), cc.darkened(0.25), 1.0 * S)
			"H":
				draw_circle(r.get_center(), T * 0.28, Color(0.9, 0.3, 0.2))
		# the outer edge of the whole body
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			if not occupied.has(Vector2i(o[0], o[1]) + d):
				var e0 := Vector2(px, py)
				var e1 := Vector2(px, py)
				if d == Vector2i(0, -1):
					e1 = Vector2(px + T, py)
				elif d == Vector2i(1, 0):
					e0 = Vector2(px + T, py)
					e1 = Vector2(px + T, py + T)
				elif d == Vector2i(0, 1):
					e0 = Vector2(px, py + T)
					e1 = Vector2(px + T, py + T)
				else:
					e1 = Vector2(px, py + T)
				draw_line(e0, e1, Color(0, 0, 0, 0.8), 2.0 * S)
		# lights: headlamps on the front tiles, brake lamps on the back
		if kind == "car" or kind == "truck":
			var f_axis: int = o[0] * front.x + o[1] * front.y
			var maxf := -99
			var minf := 99
			for o2 in offs:
				var fa: int = o2[0] * front.x + o2[1] * front.y
				maxf = maxi(maxf, fa)
				minf = mini(minf, fa)
			if f_axis == maxf and (ch == "E"):
				draw_circle(Vector2(px, py) + Vector2(T / 2.0, T / 2.0) + Vector2(front) * (T * 0.32), 3.5 * S, Color(1, 1, 0.75))
			elif f_axis == minf and ch == "T":
				draw_circle(Vector2(px, py) + Vector2(T / 2.0, T / 2.0) - Vector2(front) * (T * 0.32), 3.0 * S, Color(0.9, 0.15, 0.15))
		# damage: cracks on tiles of a hurt part, smoke from a hurt engine
		var part: String = String(game.vs.PART_OF.get(ch, "body"))
		var pct: int = game.vs.part_pct(v, part)
		if pct < 55 and not wreck:
			draw_line(Vector2(px + 6 * S, py + 8 * S), Vector2(px + T * 0.55, py + T * 0.6), Color(0, 0, 0, 0.7), 1.5 * S)
			draw_line(Vector2(px + T * 0.55, py + T * 0.6), Vector2(px + T - 6 * S, py + T - 10 * S), Color(0, 0, 0, 0.7), 1.5 * S)
		if pct < 30 and ch == "E":
			draw_circle(Vector2(px + T * 0.5, py + T * 0.3), 6.0 * S, Color(0.15, 0.15, 0.15, 0.55))
			draw_circle(Vector2(px + T * 0.62, py), 8.0 * S, Color(0.2, 0.2, 0.2, 0.4))
		if wreck:
			draw_rect(r, Color(0, 0, 0, 0.35))
	# the rotor of a helicopter: a disc and two blades
	if kind == "heli":
		var cx: float = (float(ax - ox) + 0.5) * T
		var cy: float = (float(ay - oy) + 1.2) * T
		if dirn == 1: cx -= T * 0.5
		var ang: float = float(game.turn) * 0.9
		if not wreck:
			draw_circle(Vector2(cx, cy), T * 3.0, Color(1, 1, 1, 0.06))
			for k in 2:
				var aa: float = ang + k * PI / 2.0
				draw_line(Vector2(cx, cy) - Vector2(cos(aa), sin(aa)) * T * 3.0, Vector2(cx, cy) + Vector2(cos(aa), sin(aa)) * T * 3.0, Color(0.9, 0.92, 0.96, 0.75), 3.0 * S)
	if wreck:
		var ctr := Vector2((float(ax - ox) + 0.5) * T, (float(ay - oy) + 0.5) * T)
		draw_circle(ctr + Vector2(0, -T * 0.6), 9.0 * S, Color(0.15, 0.15, 0.15, 0.5))
		draw_circle(ctr + Vector2(T * 0.3, -T * 1.2), 12.0 * S, Color(0.2, 0.2, 0.2, 0.35))


## the harbor's gantry cranes: a beam across the quay road with a trolley that runs back and forth carrying a container
## one tile of a carriage seen from above, cut away so the inside shows.  info = [train, car, position along the car (0 is the front), lane]
const TRAIN_LIVERY := [Color(0.85, 0.2, 0.35), Color(0.2, 0.62, 0.85), Color(0.9, 0.7, 0.2)]
func _draw_train_tile(p: Vector2, info: Array, tr) -> void:
	var T: float = float(TILE)
	var j: int = int(info[0])
	var k: int = int(info[1])
	var i: int = int(info[2])
	var l: int = int(info[3])
	var horiz: bool = tr.axis_at(j, k, i) == 0
	var fwd: Vector2i = tr.dir_at(j, k, i)
	var col: Color = TRAIN_LIVERY[j % TRAIN_LIVERY.size()]
	var open: bool = tr.dwell_of(j) > 0
	var door: bool = (l == 0 or l == 3) and (i == tr.DOOR_A or i == tr.DOOR_B)
	var wall: bool = l == 0 or l == 3
	if _draw_train_sprite(p, j, k, i, l, horiz, fwd, col, open and door):
		if k == 0 and i == 0 and (l == 1 or l == 2):
			var nose0: Vector2 = p + Vector2(T, T) * 0.5 + Vector2(fwd) * (T * 0.46)
			draw_circle(nose0, 5.0 * S, Color(1, 0.95, 0.6))
			draw_circle(nose0, 11.0 * S, Color(1, 0.95, 0.6, 0.22))
		_draw_passenger(p, j, k, i, l, tr)
		return
	# `a` runs along the train, `c` across it: build rects in train space, then map to the screen
	var along: Vector2 = Vector2(1, 0) if horiz else Vector2(0, 1)
	var across: Vector2 = Vector2(0, 1) if horiz else Vector2(1, 0)
	var R := func(a0: float, a1: float, c0: float, c1: float) -> Rect2:
		var p0: Vector2 = p + along * a0 * T + across * c0 * T
		var p1: Vector2 = p + along * a1 * T + across * c1 * T
		return Rect2(Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y)), Vector2(absf(p1.x - p0.x), absf(p1.y - p0.y)))
	if wall and not (door and open):
		# the outer wall: a metal skin with a livery stripe and a window, a sliding door when closed
		draw_rect(R.call(0, 1, 0, 1), Color(0.62, 0.65, 0.72))
		var outer0: float = 0.0 if l == 0 else 0.0
		var edge_c: float = 0.0 if l == 0 else 0.78
		draw_rect(R.call(0, 1, edge_c, edge_c + 0.22), Color(0.3, 0.33, 0.4))
		var sc0: float = 0.28 if l == 0 else 0.5
		draw_rect(R.call(0, 1, sc0, sc0 + 0.14), col)
		if door:
			draw_rect(R.call(0.06, 0.94, 0.12, 0.88), Color(0.45, 0.5, 0.58))
			draw_rect(R.call(0.46, 0.54, 0.12, 0.88), Color(0.15, 0.17, 0.22))
			draw_rect(R.call(0.12, 0.4, 0.3, 0.62), Color(0.18, 0.3, 0.45))
			draw_rect(R.call(0.6, 0.88, 0.3, 0.62), Color(0.18, 0.3, 0.45))
		else:
			draw_rect(R.call(0.12, 0.88, 0.26 if l == 0 else 0.38, 0.62 if l == 0 else 0.74), Color(0.14, 0.26, 0.4))
			draw_rect(R.call(0.12, 0.88, 0.26 if l == 0 else 0.38, 0.36 if l == 0 else 0.48), Color(0.4, 0.65, 0.88))
		draw_rect(R.call(0, 1, 0, 1), Color(0, 0, 0, 0.35), false, 1.0)
		_train_end_marks(R, i, k, l, tr)
		return
	# floor
	draw_rect(R.call(0, 1, 0, 1), Color(0.34, 0.37, 0.43) if (i + k) % 2 == 0 else Color(0.31, 0.34, 0.4))
	draw_rect(R.call(0, 1, 0, 0.06) if l != 2 else R.call(0, 1, 0.94, 1), Color(0, 0, 0, 0.18))
	if wall:
		draw_rect(R.call(0, 1, 0.9, 1) if l == 0 else R.call(0, 1, 0, 0.1), col)         # open doorway: the livery stripe on the sill
	elif i != tr.DOOR_A and i != tr.DOOR_B:
		# bench along the wall side
		var c0: float = 0.04 if l == 1 else 0.58
		draw_rect(R.call(0.1, 0.9, c0, c0 + 0.38), Color(0.2, 0.24, 0.34))
		draw_rect(R.call(0.14, 0.86, c0 + (0.04 if l == 1 else 0.2), c0 + (0.18 if l == 1 else 0.34)), col.darkened(0.15))
	else:
		draw_rect(R.call(0.45, 0.55, 0.4, 0.6), Color(0.85, 0.85, 0.9))                  # handrail
	_train_end_marks(R, i, k, l, tr)
	if k == 0 and i == 0 and (l == 1 or l == 2):
		var nose: Vector2 = p + Vector2(T, T) * 0.5 + Vector2(fwd) * (T * 0.46)
		draw_circle(nose, 5.0 * S, Color(1, 0.95, 0.6))
		draw_circle(nose, 11.0 * S, Color(1, 0.95, 0.6, 0.22))

## a commuter standing in a carriage cell (see Transit.passenger), drawn as a person facing across the aisle
func _draw_passenger(p: Vector2, j: int, k: int, i: int, l: int, tr) -> void:
	var h: int = tr.passenger(j, k, i, l)
	if h < 0 or not doll_ready():
		return
	var faces := [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	_draw_doll(DS.for_commuter(h), p, faces[(h >> 6) % 4])

## the painted carriage (veh_train_* / veh_trainopen_*: the u, p and o layers, the paint tinted with the train's livery): one 64 px tile of it, turned
## to the train's heading.  Sprite tile (lane, position): north and east take (l, i), south and west (3 - l, i); turned 0, 90, 180 and -90 degrees.
func _draw_train_sprite(p: Vector2, j: int, k: int, i: int, l: int, horiz: bool, fwd: Vector2i, col: Color, doorway: bool) -> bool:
	var kind := "trainopen" if doorway else "train"
	var tu = _veh_tex(kind, "u")
	var tp = _veh_tex(kind, "p")
	var to = _veh_tex(kind, "o")
	if tu == null or tp == null or to == null:
		return false
	var ang: float = 0.0
	var sx: int = l
	if horiz:
		ang = PI / 2.0 if fwd.x >= 0 else -PI / 2.0
		sx = l if fwd.x >= 0 else 3 - l
	elif fwd.y > 0:
		ang = PI
		sx = 3 - l
	var T: float = float(TILE)
	var kk: float = T / 64.0
	var src := Rect2(float(sx) * 64.0, float(i) * 64.0, 64.0, 64.0)
	var tint: Color = col * 1.12
	tint.a = 1.0
	draw_set_transform(p + Vector2(T, T) * 0.5, ang, Vector2(kk, kk))
	var dst := Rect2(-32.0, -32.0, 64.0, 64.0)
	draw_texture_rect_region(tu, dst, src)
	draw_texture_rect_region(tp, dst, src, tint)
	draw_texture_rect_region(to, dst, src)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true

## the bulkhead at each end of a carriage
func _train_end_marks(R: Callable, i: int, k: int, l: int, tr) -> void:
	if i == 0 or i == tr.CAR_LEN - 1:
		var a0: float = 0.0 if i == 0 else 0.9
		draw_rect(R.call(a0, a0 + 0.1, 0, 1), Color(0.08, 0.09, 0.12, 0.85))
		if l == 1 or l == 2:
			draw_rect(R.call(a0 - (0.0 if i == 0 else 0.0), a0 + 0.1, 0.3, 0.7), Color(0.18, 0.2, 0.26, 0.9))

func _draw_cranes(ox: int, oy: int, base: int) -> void:
	if base != 0 or game.city.cranes.is_empty():
		return
	var T := TILE
	var turn_f: float = float(game.turn) * 0.045
	for k in game.city.cranes.size():
		var cr: Dictionary = game.city.cranes[k]
		var cy: int = int(cr["y"]) - oy
		if cy < -2 or cy > rows + 1:
			continue
		var x0: int = int(cr["x0"])
		var x1: int = int(cr["x1"])
		if x1 - ox < -1 or x0 - ox > cols:
			continue
		for x in range(x0 + 1, x1):
			var sx: int = x - ox
			if sx >= 0 and sx < cols:
				_blit("f_trl_crane_beam", Vector2(sx * T, cy * T))
		var u: float = 0.5 + 0.5 * sin(turn_f + float(k) * 1.7)
		var tx: float = (float(x0 + 1) + u * float(x1 - x0 - 2) - float(ox)) * T
		var carrying: bool = cos(turn_f + float(k) * 1.7) > 0.0
		if carrying and tileset.has("f_trl_container.0"):
			var sp: Array = tileset.sprite("f_trl_container." + str(k % 4))
			if not sp.is_empty():
				var r: Rect2 = sp[1]
				draw_texture_rect_region(sp[0], Rect2(Vector2(tx + 8, cy * T + 12), r.size * 0.8), r, Color(1, 1, 1, 0.95))
		_blit("f_trl_crane_trolley", Vector2(tx, cy * T))


var veh_tex: Dictionary = {}
const HELI_MAST := Vector2(0, -70)     # where the helicopter's rotor mast is, in sprite pixels from the middle of the body

func _veh_tex(kind: String, layer: String):
	var key := "veh_%s_%s" % [kind, layer]
	if not veh_tex.has(key):
		veh_tex[key] = tileset._load_tex("res://gfx/Trilobit64/veh/%s.png" % key) if tileset != null and tileset.has("t_trl_marble") else null
	return veh_tex[key]

## the painted vehicle: shadow/wheels, the tinted paint, glass and lights; the whole stack is turned to the vehicle's heading
func _draw_body_sprite(vi: int, v: Dictionary, ox: int, oy: int, T: int) -> bool:
	var kind: String = v["kind"]
	var tu = _veh_tex(kind, "u")
	var tp = _veh_tex(kind, "p")
	var to = _veh_tex(kind, "o")
	if tu == null or tp == null or to == null:
		return false
	var dirn: int = int(v["dir"])
	var wreck: bool = v["wreck"]
	var tc: Vector2 = game.vs.true_center(kind, int(v["cell"]), dirn)
	var ctr := Vector2((tc.x - float(ox)) * T, (tc.y - float(oy)) * T)
	var rot_step: float = PI / 4.0 if game.vs.is_g8(kind) else PI / 2.0
	var k: float = float(T) / 64.0
	var tint: Color = Color(0.32, 0.30, 0.30) if wreck else (v["color"] as Color) * 1.12
	tint.a = 1.0
	var plain := Color(0.34, 0.32, 0.32) if wreck else Color.WHITE
	var airborne: bool = bool(v.get("air", false))
	if airborne:
		draw_set_transform(ctr + Vector2(10, 24) * k, float(dirn) * rot_step, Vector2(k, k))
		draw_texture(tu, -tu.get_size() * 0.5, Color(0, 0, 0, 0.35))
	draw_set_transform(ctr, float(dirn) * rot_step, Vector2(k, k))
	draw_texture(tu, -tu.get_size() * 0.5, plain)
	draw_texture(tp, -tp.get_size() * 0.5, tint)
	draw_texture(to, -to.get_size() * 0.5, plain)
	# damage: soot over the paint and smoke from a hurt engine
	var body_pct: int = game.vs.part_pct(v, "body")
	if body_pct < 55 and not wreck:
		draw_texture(tp, -tp.get_size() * 0.5, Color(0, 0, 0, 0.35))
	if kind == "heli" and not wreck:
		var ang: float = float(game.turn) * 0.9
		var r := 3.3 * 64.0
		draw_circle(HELI_MAST, r, Color(1, 1, 1, 0.05))
		for b in 2:
			var aa: float = ang + float(b) * PI / 2.0
			var d := Vector2(cos(aa), sin(aa)) * r
			draw_line(HELI_MAST - d, HELI_MAST + d, Color(0.1, 0.11, 0.13, 0.55), 9.0)
			draw_line(HELI_MAST - d, HELI_MAST + d, Color(0.85, 0.88, 0.93, 0.55), 5.0)
		draw_circle(HELI_MAST, 12.0, Color(0.18, 0.2, 0.24))
		draw_circle(HELI_MAST, 6.0, Color(0.6, 0.63, 0.68))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the driving marker: a green orb on the roof of the car or truck you are driving (the driver is not drawn); it stays upright however the vehicle turns
	if int(v["driver"]) == -2 and game.vs.is_g8(kind) and not wreck:
		var mk = _veh_tex("drive", "mark")
		if mk != null:
			var mp: Vector2 = ctr
			if kind != "car":
				var sx := 0.0
				var sy := 0.0
				var sn := 0
				for o in game.vs.offsets(kind, dirn):
					if String(o[2]) == "C":
						sx += float(o[0])
						sy += float(o[1])
						sn += 1
				var an := int(v["cell"])
				mp = Vector2((float(an % game.size) + 0.5 + sx / maxf(1.0, float(sn)) - float(ox)) * T, (float((an % game.s2) / game.size) + 0.5 + sy / maxf(1.0, float(sn)) - float(oy)) * T)
			var msz: float = 1.7 * float(T)
			draw_texture_rect(mk, Rect2(mp - Vector2(msz, msz) * 0.5, Vector2(msz, msz)), false)
	if wreck or game.vs.part_pct(v, "engine") < 30:
		draw_circle(ctr + Vector2(0, -T * 0.6), 9.0 * S, Color(0.15, 0.15, 0.15, 0.5))
		draw_circle(ctr + Vector2(T * 0.3, -T * 1.2), 12.0 * S, Color(0.2, 0.2, 0.2, 0.35))
	return true
