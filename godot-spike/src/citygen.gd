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
	["crane_leg", "f_trl_crane_leg", 0, 0], ["container", "f_trl_container", 0, 1], ["bollard", "f_trl_bollard", 0, 0],
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
const M_DASH_H := 7     # dashed white lane line between two lanes that run the same way (wide roads)
const M_DASH_V := 8

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
var rail_row: int = -1                 # island city: the row of the railway tunnel's mouth (the subway keeps a station clear of it)
var rw: int = 12                       # road width: two lanes of six
var ys_w: Dictionary = {}              # horizontal road line (top row) -> its width when it is not rw (four lanes 24, six lanes 36)
var plan: Dictionary = {}              # the island city's layout (see island.city_plan); empty = the old square grid
var centre_pt := Vector2(-1.0, -1.0)   # the downtown's heart (the old city: the middle of the map) and the radius the district tests are scaled by
var rad: float = -1.0
var block_stats: Dictionary = {}       # how many blocks became what (null: nothing fits, park, core, merged, suburb): for the tests and the tuning
var dash_ofs: int = 0                  # global column of local column 0: keeps the dashes of a wide road in step with the island's own
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
var cranes: Array = []                           # harbor gantry cranes: {x0, x1, y} in local coordinates (drawn as moving overlays)
var wealth: PackedByteArray = PackedByteArray()  # per column of the map: 0 poor, 1 middle, 2 rich (empty = everything middle)
const DISTRICTS := ["lower", "middle", "upper"]

## which part of town a cell is in: 0 lower, 1 middle, 2 upper
func wealth_at(c: int) -> int:
	if wealth.is_empty():
		return 1
	return wealth[c % wealth.size()]

## smooth districts: a few tens of tiles across, the middle of the city leaning rich and the edges poor, with all three always present
func _make_wealth(seed_v: int) -> void:
	wealth = PackedByteArray()
	wealth.resize(size * size)
	var nz := FastNoiseLite.new()
	nz.seed = seed_v ^ 0x3a17
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.frequency = 0.011
	nz.fractal_octaves = 2
	var vals := PackedFloat32Array()
	vals.resize(size * size)
	var centre := centre_pt if rad > 0.0 else Vector2(size * 0.5, size * 0.5)
	var rr: float = rad if rad > 0.0 else size * 0.5
	var mask: PackedByteArray = plan.get("mask", PackedByteArray())
	var sample := PackedFloat32Array()
	for y in size:
		var dy: float = float(y) - centre.y
		for x in size:
			var dx: float = float(x) - centre.x
			var d: float = sqrt(dx * dx + dy * dy) / rr
			var v: float = nz.get_noise_2d(x, y) * 0.8 + (0.45 - d) * 0.5
			vals[y * size + x] = v
			if (x + y) % 3 == 0 and (mask.is_empty() or mask[y * size + x] == 1):
				sample.append(v)
	# thresholds at the 33rd and 70th percentile so each tier covers a fair share of the city
	sample.sort()
	var lo: float = sample[int(sample.size() * 0.33)]
	var hi: float = sample[int(sample.size() * 0.70)]
	for i in size * size:
		wealth[i] = 0 if vals[i] < lo else (2 if vals[i] >= hi else 1)


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
	var planned: bool = not plan.is_empty()
	if planned:
		centre_pt = plan["centre"]
		rad = float(plan["rad"])
	_make_wealth(seed)
	under = PackedByteArray()
	under.resize(size * size)
	var m := mini(grid_margin, size / 6)
	var mask: PackedByteArray = plan.get("mask", PackedByteArray())
	var water: PackedByteArray = plan.get("water", PackedByteArray())
	# the paved city area
	if planned:
		for i in size * size:
			if mask[i] == 1:
				tiles[i] = GROUND
			if water[i] == 1:
				tiles[i] = WATER
			elif water[i] == 2:
				tiles[i] = SAND
	else:
		for y in range(m, size - m):
			for x in range(m, size - m):
				tiles[y * size + x] = GROUND
	# road lines: the main east-west street runs through the middle and out to both edges (the highway joins it)
	var mid_line: int = size / 2 - rw / 2
	if planned:
		xs = plan["xs"]
		ys = plan["ys"]
		ys_w = plan["ys_w"]
		mid_line = int(plan["trunk"])
	else:
		xs = _lines(m, size - m)
		ys = _lines_around(mid_line, m, size - m)
		ys_w = {}
	var decks: Array = plan.get("decks", [])
	for lx in xs:
		for y in range(0 if not planned else 0, size):
			if not planned and (y < m or y >= size - m):
				continue
			for k in rw:
				_road_cell(lx + k, y, false, false)
	for ly in ys:
		var w: int = int(ys_w.get(ly, rw))
		var trunk: bool = ly == mid_line
		var deck: bool = trunk or decks.has(ly)
		var x0 := 0 if trunk else m
		var x1 := size if trunk else size - m
		for x in range(x0, x1):
			for k in w:
				_road_cell(x, ly + k, deck, trunk)
	_paint_lanes()
	# blocks between the lines.  Where the towers stand: the middle of the city has mega-towers that fill 2-3 blocks each way (4 to 9 blocks in
	# all); the ring around it has buildings 1-2 blocks wide (1 to 4 blocks); beyond that the suburbs.
	var centre := centre_pt if planned else Vector2(size * 0.5, size * 0.5)
	var radius: float = rad if planned else size * 0.5
	var dn := FastNoiseLite.new()
	dn.seed = seed ^ 0x6d2b
	dn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	dn.frequency = 0.018
	block_stats = {"null_list": []}
	var grid: Array = []                      # grid[i][j] = block rect or null
	for i in xs.size() - 1:
		var col: Array = []
		for j in ys.size() - 1:
			var x0: int = xs[i] + rw
			var x1: int = xs[i + 1] - 1
			var y0: int = int(ys[j]) + int(ys_w.get(ys[j], rw))
			var y1: int = ys[j + 1] - 1
			var full := true
			if planned:
				var fr = _fit_rect(x0, y0, x1, y1)
				if fr == null:
					block_stats["null_list"].append(Rect2i(x0, y0, x1 - x0, y1 - y0))
					col.append(null)
					_leave_park(x0, y0, x1, y1, null)
					continue
				full = fr == Rect2i(x0, y0, x1 - x0, y1 - y0)
				if not full:
					_leave_park(x0, y0, x1, y1, fr)
				x0 = fr.position.x
				y0 = fr.position.y
				x1 = fr.end.x
				y1 = fr.end.y
			if x1 - x0 < 12 or y1 - y0 < 12:
				col.append(null)
			else:
				var dd: float = Vector2((x0 + x1) * 0.5, (y0 + y1) * 0.5).distance_to(centre) / radius
				if planned:
					dd *= 1.0 + 0.16 * dn.get_noise_2d((x0 + x1) * 0.5, (y0 + y1) * 0.5)       # a ragged district edge
				col.append({"r": Rect2i(x0, y0, x1 - x0, y1 - y0), "d": dd, "used": false, "full": full})
		grid.append(col)
	if planned:
		_prune_streets(grid)
	var order: Array = []
	for i in grid.size():
		for j in grid[i].size():
			if grid[i][j] != null:
				order.append([i, j])
	order.sort_custom(func(a, b): return grid[a[0]][a[1]]["d"] < grid[b[0]][b[1]]["d"])
	var mega_zone := 0.30
	var tower_zone := 0.58
	if planned:
		mega_zone = 0.34
		tower_zone = 0.72
	for k in ["null", "park", "core", "merged", "suburb", "exurb"]:
		block_stats[k] = 0
	for i in grid.size():
		for j in grid[i].size():
			if grid[i][j] == null:
				block_stats["null"] += 1
	for ij in order:
		var b: Dictionary = grid[ij[0]][ij[1]]
		if b["used"]:
			continue
		var d: float = b["d"]
		var r := rng.randf()
		if r < (0.015 + d * 0.025 if planned else 0.06 + d * 0.12):
			b["used"] = true
			block_stats["park"] += 1
			var rr: Rect2i = b["r"]
			_park(rr.position.x, rr.position.y, rr.end.x, rr.end.y)
		elif d < tower_zone:
			var shapes: Array = []
			if d < mega_zone and rng.randf() < 0.8:
				shapes = [[3, 3], [3, 2], [2, 3], [2, 2]] if rng.randf() < 0.5 else [[2, 2], [3, 2], [2, 3], [3, 3]]
			elif d < tower_zone:
				var pick := rng.randf()
				shapes = [[2, 2], [2, 1], [1, 2], [1, 1]] if pick < 0.2 else ([[2, 1], [1, 1]] if pick < 0.45 else ([[1, 2], [1, 1]] if pick < 0.7 else [[1, 1]]))
			var done := false
			for sh in shapes:
				if _try_merge(grid, ij[0], ij[1], sh[0], sh[1], mid_line, mega_zone if sh[0] * sh[1] >= 4 and d < mega_zone else tower_zone):
					done = true
					break
			if done:
				block_stats["merged"] += 1
			else:
				b["used"] = true
				block_stats["core"] += 1
				var rr2: Rect2i = b["r"]
				_core_block(rr2.position.x, rr2.position.y, rr2.end.x, rr2.end.y)
		else:
			b["used"] = true
			var rr3: Rect2i = b["r"]
			# the far edge of town (exurbs) is thinly built
			var exurb: bool = planned and d > 1.0 and rr3.position.x > int(plan["river"].y)
			block_stats["exurb" if exurb else "suburb"] += 1
			_suburb_block(rr3.position.x, rr3.position.y, rr3.end.x, rr3.end.y, 0.7 if exurb else 0.97)
	if planned:
		_paint_boulevards()

## the island city has a ragged edge: a street is kept only where it serves a block (or is an avenue or the highway), so the grid stops where the
## town does instead of running on into the fields
func _prune_streets(grid: Array) -> void:
	var nx: int = xs.size()
	var ny: int = ys.size()
	var blk := func(i: int, j: int) -> bool:
		return i >= 0 and j >= 0 and i < grid.size() and j < grid[0].size() and grid[i][j] != null
	var wide := func(j: int) -> bool:
		return int(ys_w.get(ys[j], rw)) != rw
	var vu: Array = []                      # vu[i][j]: the stretch of vertical street i between horizontal lines j and j+1
	for i in nx:
		var col: Array = []
		for j in ny - 1:
			col.append(blk.call(i - 1, j) or blk.call(i, j))
		vu.append(col)
	var hu: Array = []                      # hu[j][i]: the stretch of horizontal street j between vertical lines i and i+1
	for j in ny:
		var row: Array = []
		for i in nx - 1:
			row.append(wide.call(j) or blk.call(i, j - 1) or blk.call(i, j))
		hu.append(row)
	var erase := func(x0: int, y0: int, x1: int, y1: int) -> void:
		for y in range(maxi(y0, 0), mini(y1, size - 1) + 1):
			for x in range(maxi(x0, 0), mini(x1, size - 1) + 1):
				var k := y * size + x
				if tiles[k] == ROAD:
					tiles[k] = PARK
					marks[k] = 0
	var last_y: int = int(ys[ny - 1]) + int(ys_w.get(ys[ny - 1], rw))
	for i in nx:
		var x0: int = xs[i]
		erase.call(x0, 0, x0 + rw - 1, int(ys[0]) - 1)
		erase.call(x0, last_y, x0 + rw - 1, size - 1)
		for j in ny - 1:
			if not vu[i][j]:
				erase.call(x0, int(ys[j]) + int(ys_w.get(ys[j], rw)), x0 + rw - 1, int(ys[j + 1]) - 1)
	for j in ny:
		if wide.call(j):
			continue
		var y0: int = ys[j]
		erase.call(0, y0, int(xs[0]) - 1, y0 + rw - 1)
		erase.call(int(xs[nx - 1]) + rw, y0, size - 1, y0 + rw - 1)
		for i in nx - 1:
			if not hu[j][i]:
				erase.call(int(xs[i]) + rw, y0, int(xs[i + 1]) - 1, y0 + rw - 1)
	# a crossing none of whose four arms is left
	for i in nx:
		for j in ny:
			if wide.call(j):
				continue
			var any: bool = (j > 0 and vu[i][j - 1]) or (j < ny - 1 and vu[i][j]) or (i > 0 and hu[j][i - 1]) or (i < nx - 1 and hu[j][i])
			if not any:
				erase.call(int(xs[i]), int(ys[j]), int(xs[i]) + rw - 1, int(ys[j]) + rw - 1)

## is this cell somewhere a building may not stand?  (outside the city's outline, in or beside the river, on the rail strip)
func _bad(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= size or y >= size:
		return true
	var i := y * size + x
	var mask: PackedByteArray = plan["mask"]
	if mask[i] == 0:
		return true
	var res: PackedByteArray = plan["reserve"]
	return res[i] == 1

## the largest rectangle inside [x0..x1] x [y0..y1] (inclusive) with no bad cell, as Rect2i(x, y, w, h) with the same inclusive-end convention
## as the blocks; null when it would be smaller than 12 either way
func _fit_rect(x0: int, y0: int, x1: int, y1: int):
	var w := x1 - x0 + 1
	var h := y1 - y0 + 1
	if w < 16 or h < 16:
		return null
	var heights := PackedInt32Array()
	heights.resize(w)
	var best_area := 0
	var best := Rect2i()
	for row in h:
		var y := y0 + row
		for cx in w:
			heights[cx] = 0 if _bad(x0 + cx, y) else heights[cx] + 1
		# largest rectangle in the histogram ending on this row
		var stack: Array = []
		for cx in w + 1:
			var cur: int = heights[cx] if cx < w else 0
			var start := cx
			while not stack.is_empty() and int(stack[stack.size() - 1][1]) >= cur:
				var top: Array = stack.pop_back()
				var area: int = int(top[1]) * (cx - int(top[0]))
				if area > best_area and int(top[1]) >= 16 and cx - int(top[0]) >= 16:
					best_area = area
					best = Rect2i(x0 + int(top[0]), y - int(top[1]) + 1, cx - int(top[0]) - 1, int(top[1]) - 1)
				start = int(top[0])
			stack.append([start, cur])
	if best_area == 0:
		return null
	return best

## the part of a block that no building uses becomes grass (the river bank, the edge of town) rather than bare paving
func _leave_park(x0: int, y0: int, x1: int, y1: int, keep) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if keep != null and x >= keep.position.x and x <= keep.end.x and y >= keep.position.y and y <= keep.end.y:
				continue
			var i := y * size + x
			if tiles[i] == GROUND:
				tiles[i] = PARK

## a road tile, except on water (a deck carries the road over it) and outside the city's outline (the trunk road, the highway, runs on)
func _road_cell(x: int, y: int, deck: bool, trunk: bool) -> void:
	if x < 0 or y < 0 or x >= size or y >= size:
		return
	var i := y * size + x
	if not plan.is_empty():
		var mask: PackedByteArray = plan["mask"]
		if mask[i] == 0 and not trunk:
			return
		var t: int = tiles[i]
		if (t == WATER or t == SAND) and not deck:
			return
	tiles[i] = ROAD

## fill w x h blocks starting at grid[i][j] with ONE building (the streets between them are built over).  False when they do not all fit.
func _try_merge(grid: Array, i: int, j: int, w: int, h: int, mid_line: int, dmax: float) -> bool:
	if i + w > grid.size() or j + h > grid[0].size():
		return false
	for a in w:
		for b in h:
			var blk = grid[i + a][j + b]
			if blk == null or blk["used"] or float(blk["d"]) > dmax + 0.12:
				return false
			if not plan.is_empty() and not bool(blk["full"]):
				return false
	# never over the main street (or any avenue or the highway), and the blocks must be next to each other (no skipped line)
	for b in h - 1:
		if ys[j + b + 1] == mid_line or int(ys_w.get(ys[j + b + 1], rw)) != rw:
			return false
	if ys[j] == mid_line and h > 1 and false:
		return false
	for a in w:
		for b in h:
			grid[i + a][j + b]["used"] = true
	var r0: Rect2i = grid[i][j]["r"]
	var r1: Rect2i = grid[i + w - 1][j + h - 1]["r"]
	if w * h > 1:
		for y in range(r0.position.y, r1.end.y + 1):
			for x in range(r0.position.x, r1.end.x + 1):
				var t: int = tiles[y * size + x]
				if t == ROAD:
					tiles[y * size + x] = GROUND
				marks[y * size + x] = 0
	_building(r0.position.x + 2, r0.position.y + 2, r1.end.x - 2, r1.end.y - 2, "core")
	return true

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

## the width of the road whose left (or top) edge is `e`: the grid's twelve, or a wider avenue or highway
func line_w(e: int, horizontal: bool) -> int:
	return int(ys_w.get(e, rw)) if horizontal else rw

func _set_road(x: int, y: int) -> void:
	if x < 0 or y < 0 or x >= size or y >= size:
		return
	tiles[y * size + x] = ROAD

## white edge line, four black tiles, a double yellow centre: painted on the marks overlay, except where two roads cross.  Wider roads (four
## and six lanes) get a dashed white line between the lanes of one direction.
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
		for k in int(ys_w.get(ly, rw)):
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
		var w: int = int(ys_w.get(ly, rw))
		for x in size:
			for k in w:
				var y: int = ly + k
				if y >= size or tiles[y * size + x] != ROAD:
					continue
				# a vertical street crossing here (it may have been clipped by the river or pruned: then there is no crossing to leave clear)
				if vcol[x] == 1 and (ly == 0 or tiles[(ly - 1) * size + x] == ROAD or ly + w >= size or tiles[(ly + w) * size + x] == ROAD):
					continue
				var mk := 0
				if w == rw:
					if k == 0 or k == rw - 1:
						mk = M_WHITE_H
					elif k == LANE - 1 or k == LANE:
						mk = M_YELLOW_H
				else:
					mk = _wide_mark(x + dash_ofs, k, w)
				marks[y * size + x] = mk

## the paint across a road of width w that runs east-west: white edges, a double yellow centre, dashes between the lanes of one direction
static func _wide_mark(gx: int, k: int, w: int) -> int:
	if k == 0 or k == w - 1:
		return M_WHITE_H
	if k == w / 2 - 1 or k == w / 2:
		return M_YELLOW_H
	if k % LANE == 0 and (gx / 3) % 2 == 0:
		return M_DASH_H
	return 0

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

func _suburb_block(x0: int, y0: int, x1: int, y1: int, density: float = 0.9) -> void:
	# rows of houses along the north and south edges of the block (a third through the middle of a deep one), yards between.  The island city packs
	# them: three rows wherever the block is deep enough, houses close together.
	var depth := 11
	var h: int = y1 - y0 + 1
	var packed: bool = not plan.is_empty()
	var rows := [[y0 + 2, y0 + 2 + depth - 1], [y1 - 2 - depth + 1, y1 - 2]]
	if (h >= 40) if packed else (y1 - y0 >= 46):
		var free: int = (y1 - 2 - depth) - (y0 + 2 + depth)          # the rows between the north and the south row
		var md: int = mini(depth - 1, free - 4) if packed else depth
		var mid := (y0 + y1) / 2
		rows.append([mid - md / 2, mid - md / 2 + md - 1])
	for row in rows:
		var x := x0 + 2
		while x + 9 <= x1 - 2:
			var wdt := rng.randi_range(9, 13) if packed else rng.randi_range(10, 15)
			if x + wdt > x1 - 2:
				break
			var rid: int = rows.find(row)
			if rid < 2 and wdt >= 12 and not venue_plan.is_empty() and rng.randf() < 0.6:
				var kind: String = venue_plan.pop_front()
				VN.stamp(self, kind, x, row[0], x + wdt, row[1], 0 if rid == 0 else 1, 0 if wealth_at(row[0] * size + x) == 0 else 1)
			elif rng.randf() < density:
				_building(x, row[0], x + wdt, row[1], "house")
			x += wdt + (rng.randi_range(2, 4) if packed else rng.randi_range(3, 6))

## the riverside boulevards (island city): a two-lane street along each bank, white edges and a double yellow centre, painted wherever there is not
## already a street (the crossings keep the cross street's own paint)
func _paint_boulevards() -> void:
	for key in ["blv_w", "blv_e"]:
		var band: PackedInt32Array = plan[key]
		for y in size:
			var bx: int = band[y]
			if bx < 0:
				continue
			for k in rw:
				var x: int = bx + k
				var i: int = y * size + x
				var t: int = tiles[i]
				if t == ROAD or t == WATER or t == SAND or t == WALL or t == FLOOR or t == DOOR:
					continue
				tiles[i] = ROAD
				if k == 0 or k == rw - 1:
					marks[i] = M_WHITE_V
				elif k == LANE - 1 or k == LANE:
					marks[i] = M_YELLOW_V
				else:
					marks[i] = 0

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
