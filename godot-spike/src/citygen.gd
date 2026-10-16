extends RefCounted
## Spike test 3b: one city map (256 x 256 tiles) from a seed.  A road grid with varying block widths, a core of tall mixed-use buildings,
## suburban houses and parks outside it, and a harbor on the side that faces the overworld's harbor.  Buildings are BSP rooms with doors;
## each building is placed with its door on the street side.  Produces home, work and shop markers for the NPC simulation.
const VN = preload("res://src/venues.gd")
const GROUND := 0
const ROAD := 1
const WALL := 2
const FLOOR := 3
const DOOR := 4
const WATER := 5
const PARK := 6
const AIR := 7          # open air above the ground; not walkable, transparent
const STAIRS := 8       # a stairwell cell: links to the cell above and below
const ELEVATOR := 9     # an elevator shaft cell: the same links, but a ride covers several floors
const GLASS := 10       # window or roof railing: blocks movement, not sight
const ROOF := 11
const TUNNEL := 12      # maintenance catwalk beside the tracks
const PLATFORM := 13
const TRACK := 14
const SEWER := 15       # dry catwalk in a sewer
const SLUDGE := 16      # the sewer channel
const EARTH := 17       # solid rock; opaque
const TRAIN := 18       # not stored in the map: the game draws carriages over track cells
const LADDER := 19      # links a tunnel to the sewer below, or a hatch to the street
const RAILING := 20
const MANHOLE := 21     # a street-level cover over a ladder
const LOCKED := 22      # a locked door: people with keys walk through, the player has to pick it
const CRATE := 23       # low cover: blocks movement, not sight; can be jumped
const DUMPSTER := 24
const PLANTER := 25
const BALLAST := 26     # gravel either side of a railway
const CLIFF := 27       # a sheer drop: impassable, opaque
const MOUNTAIN := 28    # a mountain wall: impassable, opaque
const TREE := 29        # a dense tree: impassable, blocks sight
const ROCKS := 30       # rough rocky ground along the coast
const FIELD := 31       # ploughed or planted field
const SAND := 32        # beach
## 1 where a tile can be walked on (indexed by tile id)
## the shops, clinics, churches and shrines add floors and furniture as tile ids from 33 up: [name, sprite, walkable, low cover]
const EXTRA := [
	["floor_checker", "t_trl_checker", 1, 0], ["floor_church", "t_trl_floor_church", 1, 0], ["floor_hinoki", "t_trl_floor_hinoki", 1, 0],
	["floor_clean", "t_trl_floor_clean", 1, 0], ["floor_marble", "t_trl_marble", 1, 0], ["floor_steel", "t_trl_floor_steel", 1, 0],
	["floor_wood", "t_trl_floor_wood", 1, 0], ["floor_tatami", "t_trl_tatami", 1, 0], ["floor_carpet", "t_trl_carpet_red", 1, 0],
	["counter", "f_trl_shop_counter", 0, 1], ["noodle_counter", "f_trl_counter_noodle", 0, 1], ["range", "f_trl_kitchen_range", 0, 0], ["fridge", "f_trl_kitchen_fridge", 0, 0],
	["sushi_case", "f_trl_sushi_case", 0, 1], ["pizza_oven", "f_trl_pizza_oven", 0, 0], ["dining_table", "f_trl_dining_table", 0, 1], ["table_plastic", "f_trl_table_plastic", 0, 1],
	["tea_table", "f_trl_tea_table", 0, 1], ["stool", "f_trl_stool_plastic", 1, 0], ["bar_stool", "f_trl_bar_stool", 1, 0], ["menu_board", "f_trl_menu_board", 0, 0],
	["samovar", "f_trl_samovar", 0, 0], ["liquor_shelf", "f_trl_liquor_shelf", 0, 1], ["hot_plate", "f_trl_hot_plate", 0, 0], ["shelf", "f_trl_shelf_clean", 0, 1],
	["produce_bin", "f_trl_produce_bin", 0, 1], ["freezer_case", "f_trl_freezer_case", 0, 1], ["checkout", "f_trl_checkout", 0, 1], ["vending", "f_trl_vending", 0, 0],
	["water_cooler", "f_trl_water_cooler", 0, 0], ["implant_chair", "f_trl_implant_chair", 0, 1], ["implant_printer", "f_trl_implant_printer", 0, 0],
	["limb_bin", "f_trl_limb_bin", 0, 1], ["autodoc", "f_trl_autodoc_imp_m", 0, 0], ["hospital_bed", "f_trl_hospital_bed", 0, 1], ["ward_bed", "f_trl_ward_bed", 0, 1],
	["scanner", "f_trl_scanner", 0, 0], ["med_cabinet", "f_trl_med_cabinet", 0, 1], ["iv_stand", "f_trl_iv_stand", 0, 0], ["reception", "f_trl_reception", 0, 1],
	["exam_couch", "f_trl_exam_couch", 0, 1], ["church_bench", "f_trl_church_bench", 0, 1], ["iconostasis", "f_trl_iconostasis", 0, 0], ["candle_stand", "f_trl_candle_stand", 0, 0],
	["analoy", "f_trl_analoy", 0, 0], ["baptismal_font", "f_trl_baptismal_font", 0, 0], ["icon_lamp", "f_trl_icon_lamp", 0, 0], ["worship_cross", "f_trl_worship_cross", 0, 0],
	["shrine", "f_trl_shrine", 0, 0], ["offering_table", "f_trl_offering_table", 0, 1], ["saisen_box", "f_trl_saisen_box", 0, 0], ["komainu", "f_trl_komainu", 0, 0],
	["lantern_stone", "f_trl_lantern_stone", 0, 0], ["chozuya", "f_trl_chozuya", 0, 0], ["ema_rack", "f_trl_ema_rack", 0, 0], ["torii", "f_trl_torii", 1, 0],
	["shimenawa", "f_trl_shimenawa_pole", 0, 0], ["bonsai", "f_trl_bonsai", 0, 0], ["fern", "f_trl_fern", 0, 0], ["aquarium", "f_trl_aquarium", 0, 0],
	["charm_counter", "f_trl_charm_counter", 0, 1], ["cabinet", "f_trl_cabinet_lacquer", 0, 1], ["neon", "f_trl_neon_pink", 0, 0],
]
const EXTRA0 := 33
static var TID: Dictionary = _tids()
static var TILE_SPRITE: Dictionary = _tile_sprites()
static var WALK: Array = _walk_table()
static var LOW_COVER: Array = _low_cover()

static func _tids() -> Dictionary:
	var d := {}
	for k in EXTRA.size():
		d[EXTRA[k][0]] = EXTRA0 + k
	return d

static func _tile_sprites() -> Dictionary:
	var d := {}
	for k in EXTRA.size():
		d[EXTRA0 + k] = EXTRA[k][1]
	return d

static func _walk_table() -> Array:
	var w := [1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1]
	for e in EXTRA:
		w.append(e[2])
	return w

static func _low_cover() -> Array:
	var c := [20, 23, 24, 25]
	for k in EXTRA.size():
		if EXTRA[k][3] == 1:
			c.append(EXTRA0 + k)
	return c

## true for the furniture and floors of the venues (tile ids from EXTRA0)
static func is_extra(t: int) -> bool:
	return t >= EXTRA0
const OPAQUE := [2, 17, 27, 28, 29]

## lane markings painted over ROAD tiles on the ground level (a road is two lanes of six tiles: white edge, four black, yellow centre)
const M_WHITE_V := 1
const M_YELLOW_V := 2
const M_WHITE_H := 3
const M_YELLOW_H := 4
const M_RAIL_H := 5     # rail orientation, painted over TRACK tiles
const M_RAIL_V := 6

var size: int = 512
var marks: PackedByteArray             # ground-level overlay: lane lines and rail orientation (see M_*), size*size
var max_floors: int = 14               # tallest tower
var grid_margin: int = 40              # outskirts around the street grid
var tiles: PackedByteArray
var homes: PackedInt32Array
var works: PackedInt32Array
var shops: PackedInt32Array
var buildings: int = 0
var xs: Array = []                     # x of each vertical road line (left edge), y of each horizontal one
var ys: Array = []
var rw: int = 12                       # road width: two lanes of six
const LANE := 6
var towers: Array = []                 # {x0,y0,x1,y1,door} of every core building: candidates for a tall tower
# the vertical world (filled in by levels.gd): all levels stacked in one array, ground first, so a cell index says which level it is on
var zmax: int = 0                      # roof level of the tallest tower
var nlev: int = 1                      # ground + upper levels + 2 underground
var links: Dictionary = {}             # cell -> Array of cells it connects to (stairs, elevators, ladders)
var haslink: PackedByteArray = PackedByteArray()
var homes_g: PackedInt32Array = PackedInt32Array()   # markers on the ground level
var works_g: PackedInt32Array = PackedInt32Array()
var shops_g: PackedInt32Array = PackedInt32Array()
var homes_t: PackedInt32Array = PackedInt32Array()   # markers in tower floors
var works_t: PackedInt32Array = PackedInt32Array()
var shops_t: PackedInt32Array = PackedInt32Array()
var lairs: PackedInt32Array = PackedInt32Array()     # cells underground where squatters live
var vaults: Array = []                 # Array of PackedInt32Array: the cells of each locked room (loot goes here)
var movables: Array = []               # [cell, kind] props the game turns into pushable things (crates, tables, chairs)
var tower_info: Array = []             # {x0,y0,x1,y1,h,stairs,elev} per built tower
var subway: Dictionary = {}            # {ring: PackedInt32Array of track cells (level -1), stops: Array of ring indices}
var rng := RandomNumberGenerator.new()
var venues: Array = []                 # {kind, style, tier, x0, y0, x1, y1, door, keeper: cell, name}: shops, clinics, churches, shrines
var venue_plan: Array = []             # kinds still to place while the suburbs are laid out
var under: PackedByteArray = PackedByteArray()   # ground level: the floor tile under each piece of furniture

func walkable(t: int) -> bool:
	return WALK[t] == 1

func level_base(lvl: int) -> int:
	return lvl * size * size

## level index (0 ground, 1..zmax above, then -1, -2) -> z
func z_of(cell: int) -> int:
	var l: int = cell / (size * size)
	return l if l <= zmax else zmax - l

## z -> level index
func lvl_of_z(z: int) -> int:
	return z if z >= 0 else zmax - z

func generate(seed: int, _harbor_dir: Vector2 = Vector2.ZERO, sz: int = 512) -> void:
	size = sz
	rng.seed = seed
	tiles = PackedByteArray()
	tiles.resize(size * size)
	tiles.fill(PARK)
	marks = PackedByteArray()
	marks.resize(size * size)
	homes = PackedInt32Array()
	works = PackedInt32Array()
	shops = PackedInt32Array()
	buildings = 0
	towers = []
	venues = []
	venue_plan = VN.city_plan(rng)
	under = PackedByteArray()
	under.resize(size * size)
	var m := mini(grid_margin, size / 6)
	# the paved city area
	for y in range(m, size - m):
		for x in range(m, size - m):
			tiles[y * size + x] = GROUND
	# road lines: the main east-west street runs through the middle and out to both edges (the highway joins it)
	xs = _lines(m, size - m)
	ys = _lines_around(size / 2 - rw / 2, m, size - m)
	for lx in xs:
		for y in range(m, size - m):
			for k in rw:
				_set_road(lx + k, y)
	for ly in ys:
		var x0 := 0 if ly == size / 2 - rw / 2 else m
		var x1 := size if ly == size / 2 - rw / 2 else size - m
		for x in range(x0, x1):
			for k in rw:
				_set_road(x, ly + k)
	_paint_lanes()
	# blocks between the lines
	var centre := Vector2(size * 0.5, size * 0.5)
	for i in xs.size() - 1:
		for j in ys.size() - 1:
			var x0: int = xs[i] + rw
			var x1: int = xs[i + 1] - 1
			var y0: int = ys[j] + rw
			var y1: int = ys[j + 1] - 1
			if x1 - x0 < 12 or y1 - y0 < 12:
				continue
			var d := Vector2((x0 + x1) * 0.5, (y0 + y1) * 0.5).distance_to(centre) / (size * 0.5)
			var r := rng.randf()
			if r < 0.06 + d * 0.12:
				_park(x0, y0, x1, y1)
			elif d < 0.58:
				_core_block(x0, y0, x1, y1)
			else:
				_suburb_block(x0, y0, x1, y1)

## vertical road lines (left edge x) between lo and hi, block interiors of 34-48 tiles
func _lines(lo: int, hi: int) -> Array:
	var out := []
	var p := lo + rng.randi_range(0, 6)
	while p + rw + 34 < hi:
		out.append(p)
		p += rw + rng.randi_range(34, 48)
	out.append(hi - rw)
	return out

## horizontal lines: one fixed line (the main street) and the others spaced outwards from it
func _lines_around(mid: int, lo: int, hi: int) -> Array:
	var out := [mid]
	var p := mid
	while true:
		p -= rw + rng.randi_range(34, 48)
		if p < lo + 4:
			break
		out.append(p)
	out.append(lo)
	p = mid
	while true:
		p += rw + rng.randi_range(34, 48)
		if p + rw > hi - 4:
			break
		out.append(p)
	out.append(hi - rw)
	out.sort()
	# drop lines that ended up too close to a neighbour
	var keep := []
	for v in out:
		if keep.is_empty() or int(v) - int(keep[keep.size() - 1]) >= rw + 30:
			keep.append(v)
		elif v == mid:
			keep[keep.size() - 1] = v
	return keep

func _set_road(x: int, y: int) -> void:
	if x < 0 or y < 0 or x >= size or y >= size:
		return
	tiles[y * size + x] = ROAD

## white edge line, four black tiles, a double yellow centre: painted on the marks overlay, except where two roads cross
func _paint_lanes() -> void:
	var vcol := PackedByteArray()
	vcol.resize(size)
	var hrow := PackedByteArray()
	hrow.resize(size)
	for lx in xs:
		for k in rw:
			if lx + k < size:
				vcol[lx + k] = 1
	for ly in ys:
		for k in rw:
			if ly + k < size:
				hrow[ly + k] = 1
	for lx in xs:
		for y in size:
			for k in rw:
				var x: int = lx + k
				if x >= size or tiles[y * size + x] != ROAD or hrow[y] == 1:
					continue
				if k == 0 or k == rw - 1:
					marks[y * size + x] = M_WHITE_V
				elif k == LANE - 1 or k == LANE:
					marks[y * size + x] = M_YELLOW_V
	for ly in ys:
		for x in size:
			for k in rw:
				var y: int = ly + k
				if y >= size or tiles[y * size + x] != ROAD or vcol[x] == 1:
					continue
				if k == 0 or k == rw - 1:
					marks[y * size + x] = M_WHITE_H
				elif k == LANE - 1 or k == LANE:
					marks[y * size + x] = M_YELLOW_H

func _park(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			tiles[y * size + x] = PARK

## one big mixed-use building filling the block, BSP rooms, doors on the street side
func _core_block(x0: int, y0: int, x1: int, y1: int) -> void:
	var bx0 := x0 + 2
	var by0 := y0 + 2
	var bx1 := x1 - 2
	var by1 := y1 - 2
	_building(bx0, by0, bx1, by1, "core")

func _suburb_block(x0: int, y0: int, x1: int, y1: int) -> void:
	# rows of houses along the north and south edges of the block (a third through the middle of a deep one), yards between
	var depth := 11
	var rows := [[y0 + 2, y0 + 2 + depth - 1], [y1 - 2 - depth + 1, y1 - 2]]
	if y1 - y0 >= 46:
		var mid := (y0 + y1) / 2
		rows.append([mid - depth / 2, mid + depth / 2])
	for row in rows:
		var x := x0 + 2
		while x + 9 <= x1 - 2:
			var wdt := rng.randi_range(10, 15)
			if x + wdt > x1 - 2:
				break
			var rid: int = rows.find(row)
			if rid < 2 and wdt >= 12 and not venue_plan.is_empty() and rng.randf() < 0.6:
				var kind: String = venue_plan.pop_front()
				var d := Vector2((x + x + wdt) * 0.5, (row[0] + row[1]) * 0.5).distance_to(Vector2(size * 0.5, size * 0.5)) / (size * 0.5)
				VN.stamp(self, kind, x, row[0], x + wdt, row[1], 0 if rid == 0 else 1, 0 if d > 0.8 else 1)
			elif rng.randf() < 0.9:
				_building(x, row[0], x + wdt, row[1], "house")
			x += wdt + rng.randi_range(3, 6)

func _building(bx0: int, by0: int, bx1: int, by1: int, kind: String) -> void:
	if bx1 - bx0 < 5 or by1 - by0 < 5:
		return
	buildings += 1
	for y in range(by0, by1 + 1):
		for x in range(bx0, bx1 + 1):
			tiles[y * size + x] = FLOOR
	for x in range(bx0, bx1 + 1):
		tiles[by0 * size + x] = WALL
		tiles[by1 * size + x] = WALL
	for y in range(by0, by1 + 1):
		tiles[y * size + bx0] = WALL
		tiles[y * size + bx1] = WALL
	var rooms := []
	_split(bx0 + 1, by0 + 1, bx1 - 1, by1 - 1, rooms, 0 if kind == "core" else 1)
	# a door on the wall that faces the nearest road
	var side := _street_side(bx0, by0, bx1, by1)
	var door := _wall_cell(bx0, by0, bx1, by1, side)
	tiles[door.y * size + door.x] = DOOR
	if kind == "core":
		towers.append({"x0": bx0, "y0": by0, "x1": bx1, "y1": by1, "door": door, "side": side})
	# markers: houses get one home per room with some probability; towers get several desks, flats and counters per room
	for r in rooms:
		var n := 1 if kind == "house" else maxi(1, int(r.get_area() / 6))
		for _k in n:
			var cell := Vector2i(rng.randi_range(r.position.x, r.end.x - 1), rng.randi_range(r.position.y, r.end.y - 1))
			if tiles[cell.y * size + cell.x] != FLOOR:
				continue
			var idx := cell.y * size + cell.x
			if kind == "house":
				if rooms.find(r) == 0 or rng.randf() < 0.5:
					homes.append(idx)
			else:
				var roll := rng.randf()
				if roll < 0.35:
					works.append(idx)
				elif roll < 0.47:
					shops.append(idx)
				else:
					homes.append(idx)

## the plan of an upper storey: outer wall with windows, BSP rooms with doors, no street door.  Returns {tiles, rooms}.
func floor_plan(bx0: int, by0: int, bx1: int, by1: int, plan_seed: int) -> Dictionary:
	var saved_tiles := tiles
	var saved_state := rng.state
	rng.seed = plan_seed
	tiles = PackedByteArray()
	tiles.resize(size * size)
	tiles.fill(AIR)
	for y in range(by0, by1 + 1):
		for x in range(bx0, bx1 + 1):
			tiles[y * size + x] = FLOOR
	for x in range(bx0, bx1 + 1):
		tiles[by0 * size + x] = GLASS if (x % 3 != 0) else WALL
		tiles[by1 * size + x] = GLASS if (x % 3 != 0) else WALL
	for y in range(by0, by1 + 1):
		tiles[y * size + bx0] = GLASS if (y % 3 != 0) else WALL
		tiles[y * size + bx1] = GLASS if (y % 3 != 0) else WALL
	for c in [Vector2i(bx0, by0), Vector2i(bx1, by0), Vector2i(bx0, by1), Vector2i(bx1, by1)]:
		tiles[c.y * size + c.x] = WALL
	var rooms := []
	_split(bx0 + 1, by0 + 1, bx1 - 1, by1 - 1, rooms, 0)
	var out := tiles
	tiles = saved_tiles
	rng.state = saved_state
	return {"tiles": out, "rooms": rooms}

func _street_side(bx0: int, by0: int, bx1: int, by1: int) -> int:
	# 0 N, 1 S, 2 W, 3 E: whichever side has a road nearest
	var best := 0
	var bd := 1 << 30
	var mx := (bx0 + bx1) / 2
	var my := (by0 + by1) / 2
	var cands := [[0, mx, by0 - 1, -1, 0, -1], [1, mx, by1 + 1, 1, 0, 1], [2, bx0 - 1, my, 0, -1, 2], [3, bx1 + 1, my, 0, 1, 3]]
	for c in cands:
		var d := 0
		var x: int = c[1]
		var y: int = c[2]
		while d < 24 and x >= 0 and y >= 0 and x < size and y < size and tiles[y * size + x] != ROAD:
			x += c[4]
			y += c[3]
			d += 1
		if d < bd:
			bd = d
			best = c[0]
	return best

func _wall_cell(bx0: int, by0: int, bx1: int, by1: int, side: int) -> Vector2i:
	for _t in 40:
		var c := Vector2i.ZERO
		match side:
			0: c = Vector2i(rng.randi_range(bx0 + 1, bx1 - 1), by0)
			1: c = Vector2i(rng.randi_range(bx0 + 1, bx1 - 1), by1)
			2: c = Vector2i(bx0, rng.randi_range(by0 + 1, by1 - 1))
			_: c = Vector2i(bx1, rng.randi_range(by0 + 1, by1 - 1))
		var inside: Vector2i = c + [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)][side]
		if tiles[inside.y * size + inside.x] == FLOOR:
			return c
	return Vector2i((bx0 + bx1) / 2, by0)

## BSP: split until rooms are small, keep the room rectangles, put a door in each wall line after the children exist
func _split(x0: int, y0: int, x1: int, y1: int, rooms: Array, depth: int) -> void:
	var wdt := x1 - x0 + 1
	var hgt := y1 - y0 + 1
	var minr := 4
	var can_v := wdt >= minr * 2 + 1
	var can_h := hgt >= minr * 2 + 1
	if (not can_v and not can_h) or (depth > 0 and rng.randf() < 0.18 * depth) or depth > 4:
		rooms.append(Rect2i(x0, y0, wdt, hgt))
		return
	var vertical := can_v and (not can_h or wdt > hgt or rng.randf() < 0.5)
	if vertical:
		var sx := rng.randi_range(x0 + minr, x1 - minr)
		for y in range(y0, y1 + 1):
			tiles[y * size + sx] = WALL
		_split(x0, y0, sx - 1, y1, rooms, depth + 1)
		_split(sx + 1, y0, x1, y1, rooms, depth + 1)
		_door_line(sx, y0, y1, true)
	else:
		var sy := rng.randi_range(y0 + minr, y1 - minr)
		for x in range(x0, x1 + 1):
			tiles[sy * size + x] = WALL
		_split(x0, y0, x1, sy - 1, rooms, depth + 1)
		_split(x0, sy + 1, x1, y1, rooms, depth + 1)
		_door_line(sy, x0, x1, false)

func _door_line(fixed: int, a: int, b: int, vertical: bool) -> void:
	var cands := []
	for k in range(a, b + 1):
		var c := Vector2i(fixed, k) if vertical else Vector2i(k, fixed)
		var n1 := c + (Vector2i(-1, 0) if vertical else Vector2i(0, -1))
		var n2 := c + (Vector2i(1, 0) if vertical else Vector2i(0, 1))
		if tiles[n1.y * size + n1.x] == FLOOR and tiles[n2.y * size + n2.x] == FLOOR:
			cands.append(c)
	if cands.is_empty():
		return
	var d: Vector2i = cands[rng.randi() % cands.size()]
	tiles[d.y * size + d.x] = DOOR

## fraction of the markers reachable on foot from the first road tile (BFS)
func reachable_fraction() -> float:
	var start := -1
	for i in tiles.size():
		if tiles[i] == ROAD:
			start = i
			break
	var seen := PackedByteArray()
	seen.resize(size * size)
	var q := PackedInt32Array([start])
	seen[start] = 1
	var head := 0
	while head < q.size():
		var cur := q[head]
		head += 1
		var cx := cur % size
		var cy := cur / size
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nx: int = cx + d[0]
			var ny: int = cy + d[1]
			if nx < 0 or ny < 0 or nx >= size or ny >= size:
				continue
			var ni := ny * size + nx
			if seen[ni] == 0 and walkable(tiles[ni]):
				seen[ni] = 1
				q.append(ni)
	var tot := 0
	var ok := 0
	for arr in [homes, works, shops]:
		for i in arr:
			tot += 1
			if seen[i] == 1:
				ok += 1
	return float(ok) / maxf(1.0, float(tot))

func save_png(path: String, scale: int = 3) -> void:
	var pal := [Color("#6b6b73"), Color("#2a2a30"), Color("#d8d8e0"), Color("#9a8f7a"), Color("#e0a030"), Color("#1d4f91"), Color("#4a9a4a")]
	pal.resize(128)
	for k in 128:
		if pal[k] == null:
			pal[k] = Color("#554455")
	var img := Image.create(size * scale, size * scale, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			img.fill_rect(Rect2i(x * scale, y * scale, scale, scale), pal[tiles[y * size + x]])
	for i in homes:
		img.fill_rect(Rect2i((i % size) * scale, (i / size) * scale, scale, scale), Color("#3cf"))
	for i in works:
		img.fill_rect(Rect2i((i % size) * scale, (i / size) * scale, scale, scale), Color("#f33"))
	for i in shops:
		img.fill_rect(Rect2i((i % size) * scale, (i / size) * scale, scale, scale), Color("#fe3"))
	img.save_png(path)
