extends RefCounted
## Spike test 3b: one city map (256 x 256 tiles) from a seed.  A road grid with varying block widths, a core of tall mixed-use buildings,
## suburban houses and parks outside it, and a harbor on the side that faces the overworld's harbor.  Buildings are BSP rooms with doors;
## each building is placed with its door on the street side.  Produces home, work and shop markers for the NPC simulation.
const VN = preload("res://src/venues.gd")
const FG = preload("res://src/furniture_gen.gd")
const BZ = preload("res://src/business.gd")
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
const EXTRA_BASE := [
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
	["terminal", "f_trl_terminal", 0, 0], ["portal", "f_trl_portal", 1, 0], ["mission_device", "f_trl_device", 0, 0],
	["charger", "f_trl_charger", 0, 0], ["gunsmith_table", "f_trl_gunsmith_table", 0, 1],
	["ev_charger_nw", "f_trl_ev_nw", 0, 0], ["ev_charger_ne", "f_trl_ev_ne", 0, 0], ["ev_charger_sw", "f_trl_ev_sw", 0, 0], ["ev_charger_se", "f_trl_ev_se", 0, 0],
	["door_closed", "t_door_closed", 1, 0], ["window_broken", "t_window_broken", 1, 0],
	["station_clock", "f_trl_station_clock", 0, 0],
]
## street props that stand in the way and give cover (the rest of the street furniture is drawn over the ground by view.gd and does not block)
const PROPS := [["street_tree", "f_trl_tree_street", 0, 1], ["street_bench", "f_trl_bench", 0, 1], ["bench_broken", "f_trl_bench_broken", 0, 1]]
static var EXTRA: Array = EXTRA_BASE + FG.NEW + PROPS
const EXTRA0 := 33
static var TID: Dictionary = _tids()
static var TILE_SPRITE: Dictionary = _tile_sprites()
static var WALK: Array = _walk_table()
static var LOW_COVER: Array = _low_cover()
static var FLOOR_IDS: Dictionary = _floor_ids()   # tile ids of the special floors (a venue's, a lobby's, a flat's)

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

## a plain floor or one of the special floors (a lobby's marble, a flat's lino, an office's carpet)
static func is_floor(t: int) -> bool:
	return t == FLOOR or FLOOR_IDS.has(t)

static func _floor_ids() -> Dictionary:
	var d := {}
	for k in EXTRA.size():
		if String(EXTRA[k][0]).begins_with("floor_"):
			d[EXTRA0 + k] = true
	return d

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
const M_BAY := 9        # a parking bay's divider line (vertical, on the tile's left edge), painted over the lot's ROAD tiles
const M_BAY_EV := 10    # the same beside a vehicle charger: drawn green

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
var keep_park: PackedByteArray = PackedByteArray()   # cells of the parks the plan chose to keep (the infill leaves them green)
var biz_count: Dictionary = {}          # how many of each business type stand so far (types not yet built are favoured, so every type turns up)
var cur_zone: String = "com"          # the district kind of the cell being built (core, com, res, ind): decides how likely a small building is a business
var org_tips: Array = []                # the loose ends of the diagonals and arcs (joined to the street network by _connect_tips)
var org: PackedByteArray = PackedByteArray()   # cells of the organic streets (diagonals, rings, meanders): kept when plain streets are pruned
var dash_ofs: int = 0                  # global column of local column 0: keeps the dashes of a wide road in step with the island's own
const LANE := 6
var towers: Array = []                 # {x0,y0,x1,y1,door} of every core building: candidates for a tall tower
# the vertical world (filled in by levels.gd): all levels stacked in one array, ground first, so a cell index says which level it is on
var zmax: int = 0                      # the top level: the tallest tower's roof plus levels.gd AIR_ABOVE of open air
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
var station_doors: PackedInt32Array = PackedInt32Array()   # the street cell of each subway station's stairs
var subway: Dictionary = {}            # {ring: PackedInt32Array of track cells (level -1), stops: Array of ring indices}
var rng := RandomNumberGenerator.new()
var houses: Array = []                 # every house: {cell, x0, y0, x1, y1} (a floor cell inside it): who lives where is decided from this and from `apartments`
var apartments: Array = []             # every flat in every tower: {cell, tower, z, rect} (for later: who lives where)
var under_up: PackedByteArray = PackedByteArray()   # while the towers are built: the floor under every cell of every level
var businesses: Array = []             # every business built (see business.gd): {type, ver, tag, tier, name, cat, x0..y1, door, side, role, jobs, staff: cells, keeper}
var signs: Array = []                  # the signs out front of every building (see signage.gd), made once the zone is built
var access: Dictionary = {}              # what access.gd found and fixed: {doors, carved, moved, dead, dropped}
var bldgs: Array = []                  # every plain building (houses, mid-rises, towers): {x0, y0, x1, y1, kind, door, side, filled}: what _building made, for the census and the signs
var venues: Array = []                 # {kind, style, tier, x0, y0, x1, y1, door, keeper: cell, name}: shops, clinics, churches, shrines
var venue_plan: Array = []             # kinds still to place while the suburbs are laid out
var under: PackedByteArray = PackedByteArray()   # ground level: the floor tile under each piece of furniture
var cranes: Array = []                           # harbor gantry cranes: {x0, x1, y} in local coordinates (drawn as moving overlays)
var chargers: PackedInt32Array = PackedInt32Array()   # the cells of the implant charging posts (one tile: for cyberized people)
var ev_chargers: PackedInt32Array = PackedInt32Array() # the north-west cell of every vehicle charging bank (two by two tiles)
var lots: Array = []                   # parking lots and charging stations: {kind, x0, y0, x1, y1, bays: [[x, y, ev]], chargers: [cell], posts: [cell]}
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
	_wvals = vals
	_wlo = lo
	_whi = hi

var _wvals: PackedFloat32Array = PackedFloat32Array()
var _wlo: float = 0.0
var _whi: float = 0.0

## Every parking lot gets a driveway: a four-wide strip of road from the middle of its nearest side out to the nearest street (not through a building).  A lot that is already
## touching a street is left as it is.  (Several offsets along each side are tried, the shortest clear run wins; the cut goes through pavement, grass and scenery only.)
func _connect_lots() -> void:
	for lot in lots:
		var x0: int = lot["x0"]
		var y0: int = lot["y0"]
		var x1: int = lot["x1"]
		var y1: int = lot["y1"]
		var touching := false
		for x in range(x0, x1 + 1):
			if (y0 > 0 and _road_outside(x, y0 - 1)) or (y1 < size - 1 and _road_outside(x, y1 + 1)):
				touching = true
		for y in range(y0, y1 + 1):
			if (x0 > 0 and _road_outside(x0 - 1, y)) or (x1 < size - 1 and _road_outside(x1 + 1, y)):
				touching = true
		if touching:
			lot["exit"] = true
			continue
		var best: Array = []
		for side in 4:
			var horiz: bool = side < 2                                      # sides 0 and 1 face up and down: the run is vertical
			var span: int = (x1 - x0) if horiz else (y1 - y0)
			for off0 in [span / 2, span / 2 + 5, span / 2 - 5, span / 4, 3 * span / 4, 4, span - 4]:
				var off: int = clampi(int(off0), 2, span - 3)
				var run: Array = _drive_run(lot, side, off)
				if not run.is_empty() and (best.is_empty() or run.size() < best.size()):
					best = run
		if not best.is_empty():
			for ci in best:
				tiles[ci] = ROAD
				marks[ci] = 0
				under[ci] = ROAD
			lot["exit"] = true
		else:
			lot["exit"] = false

func _road_outside(x: int, y: int) -> bool:
	if tiles[y * size + x] != ROAD:
		return false
	for lot in lots:
		if x >= int(lot["x0"]) and x <= int(lot["x1"]) and y >= int(lot["y0"]) and y <= int(lot["y1"]):
			return false
	return true

## the cells of a 4-wide driveway from a lot's side `side` (0 up, 1 down, 2 left, 3 right) at offset `off` along it to the first street cell, or [] when a building is in the way
func _drive_run(lot: Dictionary, side: int, off: int) -> Array:
	var x0: int = lot["x0"]
	var y0: int = lot["y0"]
	var x1: int = lot["x1"]
	var y1: int = lot["y1"]
	var d := Vector2i(0, -1) if side == 0 else (Vector2i(0, 1) if side == 1 else (Vector2i(-1, 0) if side == 2 else Vector2i(1, 0)))
	var p := Vector2i(x0 + off, y0 - 1) if side == 0 else (Vector2i(x0 + off, y1 + 1) if side == 1 else (Vector2i(x0 - 1, y0 + off) if side == 2 else Vector2i(x1 + 1, y0 + off)))
	var cells: Array = []
	for k in 40:
		var cx: int = p.x + d.x * k
		var cy: int = p.y + d.y * k
		if cx < 3 or cy < 3 or cx >= size - 4 or cy >= size - 4:
			return []
		var t: int = tiles[cy * size + cx]
		if t == ROAD and _road_outside(cx, cy):
			return cells
		if t != GROUND and t != PARK and t != TREE and t != FIELD and t != SAND and t != ROCKS and t != BALLAST:
			return []
		# four wide across the run (two each side of the middle): none of it may be a wall or water
		for w in range(-1, 3):
			var wx: int = cx + (w if d.y != 0 else 0)
			var wy: int = cy + (w if d.x != 0 else 0)
			var wt: int = tiles[wy * size + wx]
			if wt != GROUND and wt != PARK and wt != TREE and wt != FIELD and wt != SAND and wt != ROCKS and wt != BALLAST and not (wt == ROAD and not (wx >= x0 and wx <= x1 and wy >= y0 and wy <= y1)):
				return []
			if wt != ROAD:
				cells.append(wy * size + wx)
	return []

## Trees and benches on the pavement are tiles: they cannot be walked through and they give cover.  A hash of the cell picks them (the same city every time), by district:
## street trees along the kerb (rich and mid-town), benches along the building fronts (broken ones in the slums) and in the mid-town parks.  Never beside a door, stairs, a ladder
## or another prop, and never where the pavement is a single tile between road and wall, so nothing is shut in and no way is blocked.
func _stamp_street_props() -> void:
	var tid_tree: int = TID["street_tree"]
	var tid_bench: int = TID["street_bench"]
	var tid_broken: int = TID["bench_broken"]
	var bad := {DOOR: true, 22: true, 8: true, 9: true, 19: true, 21: true, TID["door_closed"]: true}
	for y in range(2, size - 2):
		for x in range(2, size - 2):
			var i := y * size + x
			var t: int = tiles[i]
			if t != GROUND and t != PARK:
				continue
			var road := false
			var wall := false
			for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				var nt: int = tiles[i + d.y * size + d.x]
				road = road or nt == ROAD
				wall = wall or nt == WALL or nt == GLASS
			var h: int = ((i * 2654435761) >> 7) & 0xffffff
			var w: int = wealth_at(i)
			var pick := -1
			if t == GROUND and road and not wall:
				if w == 2 and h % 9 == 0:
					pick = tid_tree
				elif w == 1 and h % 7 != 0 and h % 17 == 0:
					pick = tid_tree
			elif t == GROUND and wall and not road:
				if w == 2 and h % 11 != 0 and h % 19 == 0:
					pick = tid_bench
				elif w == 1 and h % 23 == 0:
					pick = tid_bench
				elif w == 0 and h % 29 == 0:
					pick = tid_broken
			elif t == PARK and w == 1 and h % 37 == 0:
				pick = tid_bench
			if pick < 0:
				continue
			var clear := true
			var open_n := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nt2: int = tiles[i + dy * size + dx]
					if bad.has(nt2) or nt2 >= EXTRA0:
						clear = false
					if (dx != 0 or dy != 0) and WALK[nt2] == 1:
						open_n += 1
			# never in a narrow way: walls (or water, rock) on both sides along either axis would shut it
			if WALK[tiles[i - 1]] == 0 and WALK[tiles[i + 1]] == 0:
				clear = false
			if WALK[tiles[i - size]] == 0 and WALK[tiles[i + size]] == 0:
				clear = false
			if not clear or open_n < 6:
				continue
			under[i] = t
			tiles[i] = pick

## Districts change only at natural breaks.  Once the city is built, every block (the ground between streets, water and the edge of town: its buildings, alleys, sidewalks and parks)
## gets one wealth class, from the average of the smooth noise over the block, and every street cell takes the class of the nearest block.  So a building never has two districts
## in it, and the class changes only across a street, at an intersection, or at the river.  (Works at half resolution: the streets are four tiles wide or more.)
func _block_wealth() -> void:
	if _wvals.size() != size * size:
		return
	var n2: int = size / 2
	var mask: PackedByteArray = plan.get("mask", PackedByteArray())
	var label := PackedInt32Array()
	label.resize(n2 * n2)
	label.fill(-1)
	var brk := PackedByteArray()                       # 1 = street, water or outside the city
	brk.resize(n2 * n2)
	for y in n2:
		for x in n2:
			var br := 0
			for k in 4:
				var i: int = (y * 2 + (k >> 1)) * size + x * 2 + (k & 1)
				var t: int = tiles[i]
				if t == ROAD or t == WATER or t == SAND or (not mask.is_empty() and mask[i] == 0):
					br = 1
					break
			brk[y * n2 + x] = br
	var cls := PackedByteArray()                        # per label
	var nl := 0
	var stack := PackedInt32Array()
	for start in n2 * n2:
		if brk[start] == 1 or label[start] >= 0:
			continue
		var sum := 0.0
		var cnt := 0
		stack.clear()
		stack.append(start)
		label[start] = nl
		while not stack.is_empty():
			var c: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			var cx: int = c % n2
			var cy: int = c / n2
			sum += _wvals[(cy * 2) * size + cx * 2]
			cnt += 1
			if cx > 0 and brk[c - 1] == 0 and label[c - 1] < 0:
				label[c - 1] = nl
				stack.append(c - 1)
			if cx < n2 - 1 and brk[c + 1] == 0 and label[c + 1] < 0:
				label[c + 1] = nl
				stack.append(c + 1)
			if cy > 0 and brk[c - n2] == 0 and label[c - n2] < 0:
				label[c - n2] = nl
				stack.append(c - n2)
			if cy < n2 - 1 and brk[c + n2] == 0 and label[c + n2] < 0:
				label[c + n2] = nl
				stack.append(c + n2)
		var mean: float = sum / float(maxi(1, cnt))
		cls.append(0 if mean < _wlo else (2 if mean >= _whi else 1))
		nl += 1
	# streets and water: the class of the nearest block (a sweep outwards from the blocks)
	var w2 := PackedByteArray()
	w2.resize(n2 * n2)
	var done := PackedByteArray()
	done.resize(n2 * n2)
	var front := PackedInt32Array()
	for c in n2 * n2:
		if label[c] >= 0:
			w2[c] = cls[label[c]]
			done[c] = 1
			front.append(c)
	while not front.is_empty():
		var nxt := PackedInt32Array()
		for c in front:
			var cx: int = c % n2
			var cy: int = c / n2
			for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
				var ax: int = cx + d[0]
				var ay: int = cy + d[1]
				if ax < 0 or ay < 0 or ax >= n2 or ay >= n2:
					continue
				var a: int = ay * n2 + ax
				if done[a] == 0:
					done[a] = 1
					w2[a] = w2[c]
					nxt.append(a)
		front = nxt
	for y in size:
		for x in size:
			wealth[y * size + x] = w2[mini(y >> 1, n2 - 1) * n2 + mini(x >> 1, n2 - 1)]


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
	businesses = []
	labor_downtown = 0
	houses = []
	bldgs = []
	apartments = []
	biz_count = {}
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
	if planned:
		xs = _thin_lines(xs, ys_w, mid_line, false)
		ys = _thin_lines(ys, ys_w, mid_line, true, decks)
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
	if planned:
		_organic_roads(seed)
		_organic_city(seed)
		_paint_boulevards()
		_block_wealth()
		_connect_lots()
		_stamp_street_props()
		return
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
	chargers = PackedInt32Array()
	ev_chargers = PackedInt32Array()
	lots = []
	for ij in order:
		var b: Dictionary = grid[ij[0]][ij[1]]
		if b["used"]:
			continue
		var d: float = b["d"]
		if _lot_block(ij[0], ij[1], b["r"], d):
			b["used"] = true
			block_stats["lot"] = int(block_stats.get("lot", 0)) + 1
			continue
		var r := rng.randf()
		if r < (0.004 + d * 0.01 if planned else 0.06 + d * 0.12):
			b["used"] = true
			block_stats["park"] += 1
			var rr: Rect2i = b["r"]
			_park(rr.position.x, rr.position.y, rr.end.x, rr.end.y)
		elif d < tower_zone:
			var shapes: Array = []
			if d < mega_zone and rng.randf() < (0.25 if planned else 0.8):
				shapes = [[3, 3], [3, 2], [2, 3], [2, 2]] if rng.randf() < 0.5 else [[2, 2], [3, 2], [2, 3], [3, 3]]
			elif d < tower_zone:
				var pick := rng.randf()
				if planned and rng.randf() < 0.7:
					pick = 0.99                       # most tower-zone blocks stay single (and are cut into alley-separated buildings)
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
		_infill()
		_paint_boulevards()
	_block_wealth()
	_connect_lots()
	_stamp_street_props()

## Parking lots and charging stations.  A lot is paved like a road and marked with bays (a bay is 4 x 6: a car is 3 wide by 5 long and has room to spare): a row of bays, an aisle six wide
## and a row facing it, 18 deep, as wide as ten bays at most.  It takes the middle of a whole block (about one block in five that is big enough and not at the very centre).
##   kind "lot"      mostly bays; one lot in three has a vehicle charging bank (2 x 2) between bays, and then a charging post for people at the end of the aisle
##   kind "station"  a charging station like a petrol station: every third slot is a vehicle charging bank, and a post for people at the aisle's end
## No random numbers are drawn (a hash of the block's place decides), so the rest of the city is the same with or without the lots.
func _lot_block(i: int, j: int, r: Rect2i, d: float) -> bool:
	if d < 0.12 or r.size.x < 30 or r.size.y < 24:
		return false
	var roll: int = (hash([size, i, j, "lot"]) & 0x7fffffff) % 100
	if roll >= 34:
		return false
	var n: int = mini(10, (r.size.x - 4) / 4)
	var ww: int = n * 4 + 2
	var spot := Rect2i(r.position.x + (r.size.x - ww) / 2, r.position.y + (r.size.y - 20) / 2, ww, 20)
	_stamp_lot("station" if roll < 6 else "lot", spot, (hash([size, i, j, "ev"]) & 0x7fffffff) % 3 == 0)
	return true

func _stamp_lot(kind: String, spot: Rect2i, with_ev: bool) -> void:
	var x0: int = spot.position.x + 1
	var y0: int = spot.position.y + 1
	var n: int = (spot.size.x - 2) / 4
	var lot := {"kind": kind, "x0": spot.position.x, "y0": spot.position.y, "x1": spot.end.x - 1, "y1": spot.end.y - 1, "bays": [], "chargers": [], "posts": []}
	for yy in range(spot.position.y, spot.end.y):
		for xx in range(spot.position.x, spot.end.x):
			tiles[yy * size + xx] = ROAD
			marks[yy * size + xx] = 0
			under[yy * size + xx] = ROAD
	var charge_slot := func(s: int) -> bool:
		if kind == "station":
			return s % 3 == 1
		return with_ev and s % 5 == 2
	for row in [0, 12]:                                   # the bay row at the top and the one at the bottom, the aisle between
		var by: int = y0 + row
		for s in n:
			var bx: int = x0 + s * 4
			var is_c: bool = charge_slot.call(s)
			var near_c: bool = (s > 0 and charge_slot.call(s - 1)) or (s < n - 1 and charge_slot.call(s + 1))
			for yy in 6:
				marks[(by + yy) * size + bx] = M_BAY_EV if (near_c or is_c) else M_BAY
			if s == n - 1:
				for yy in 6:
					marks[(by + yy) * size + bx + 4] = M_BAY_EV if is_c else M_BAY
			if is_c:
				var uy: int = by if row == 0 else by + 4
				var base_c: int = uy * size + bx + 1
				for k in 4:
					var cc: int = base_c + (k / 2) * size + (k % 2)
					tiles[cc] = TID["ev_charger_nw"] + k
				lot["chargers"].append(base_c)
				ev_chargers.append(base_c)
			else:
				lot["bays"].append([bx, by, 1 if near_c else 0])
	if with_ev or kind == "station":
		var post: int = (y0 + 8) * size + x0
		tiles[post] = TID["charger"]
		chargers.append(post)
		lot["posts"].append(post)
	lots.append(lot)

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
				if tiles[k] == ROAD and org[k] == 0:
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

## Organic streets.  The plain grid is broken up in places by streets that do not follow it: diagonal avenues that cut across blocks (with a slight
## wander), arcs of ring road around the downtown, and winding lanes that follow a river bank or the edge of town.  They are painted before the blocks
## are laid out and reserved, so the blocks beside them shrink to fit (the leftover wedges become green).  Water and the reserved ground stop them.
func _organic_roads(seed_v: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v ^ 0x5eed0a
	org = PackedByteArray()
	org.resize(size * size)
	org_tips = []
	var res: PackedByteArray = plan["reserve"].duplicate()
	var mask: PackedByteArray = plan["mask"]
	var water: PackedByteArray = plan["water"]
	var ctr: Vector2 = centre_pt
	var stamp := func(pt: Vector2, rr: float) -> void:
		var ir: int = int(ceil(rr))
		for dy in range(-ir, ir + 1):
			for dx in range(-ir, ir + 1):
				if dx * dx + dy * dy > rr * rr:
					continue
				var x: int = int(pt.x) + dx
				var y: int = int(pt.y) + dy
				if x < 2 or y < 2 or x >= size - 2 or y >= size - 2:
					continue
				var i: int = y * size + x
				if mask[i] == 0 or res[i] == 1:
					continue
				if tiles[i] == ROAD or tiles[i] == GROUND or tiles[i] == PARK or tiles[i] == WATER or tiles[i] == SAND:        # a bridge over the river
					tiles[i] = ROAD
					org[i] = 1
					marks[i] = 0
	var ok := func(pt: Vector2) -> bool:
		var x: int = int(pt.x)
		var y: int = int(pt.y)
		if x < 4 or y < 4 or x >= size - 4 or y >= size - 4:
			return false
		var i: int = y * size + x
		return mask[i] == 1 and res[i] == 0
	var trunk_y: int = int(plan["trunk"])
	# diagonal avenues: chords that miss the very heart of downtown, running both ways until the city's edge or the water stops them
	var made := 0
	for k in 40:
		if made >= 4:
			break
		var ang: float = r.randf_range(0.0, TAU)
		var dirv := Vector2(cos(ang), sin(ang))
		if absf(dirv.x) > 0.9 or absf(dirv.y) > 0.9:
			continue
		made += 1
		var off: float = r.randf_range(0.28, 0.85) * rad * (1.0 if r.randf() < 0.5 else -1.0)
		var start: Vector2 = ctr + Vector2(-dirv.y, dirv.x) * off
		var ph: float = r.randf_range(0.0, TAU)
		var amp: float = r.randf_range(1.5, 4.5)
		for sgn in [1.0, -1.0]:
			var t := 0.0
			var gap := 0
			var last_ok := Vector2(-1.0, -1.0)
			while t < rad * 2.2 and gap < 12:
				var pt: Vector2 = start + dirv * (sgn * t) + Vector2(-dirv.y, dirv.x) * (amp * sin(t * 0.045 + ph))
				if ok.call(pt) and absf(pt.y - float(trunk_y) - 6.0) > 20.0:
					stamp.call(pt, 4.0)
					last_ok = pt
					gap = 0
				else:
					gap += 1
				t += 1.0
			if last_ok.x >= 0.0:
				org_tips.append(last_ok)
	# ring road: arcs about the downtown
	for k in 2:
		var rr: float = rad * r.randf_range(0.42, 0.95)
		var a0: float = r.randf_range(0.0, TAU)
		var span: float = r.randf_range(1.6, 3.4)
		var n: int = int(rr * span)
		var first_pt := Vector2(-1.0, -1.0)
		var last_pt := Vector2(-1.0, -1.0)
		for q in n:
			var a: float = a0 + span * float(q) / float(n)
			var pt: Vector2 = ctr + Vector2(cos(a), sin(a)) * (rr + 3.0 * sin(a * 5.0))
			if ok.call(pt) and absf(pt.y - float(trunk_y) - 6.0) > 20.0:
				stamp.call(pt, 4.0)
				if first_pt.x < 0.0:
					first_pt = pt
				last_pt = pt
		if first_pt.x >= 0.0:
			org_tips.append(first_pt)
			org_tips.append(last_pt)
	for i in size * size:
		if org[i] == 1:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var j: int = i + dy * size + dx
					if j >= 0 and j < size * size:
						res[j] = 1
	plan["reserve"] = res

## Leftover grass inside the city's outline (the wedges between a diagonal or ring road and the grid, the strips between the last street and the edge)
## is built over: a rectangle of free ground (up to 26 a side, at least 9) is cut into alley-separated buildings, or into rows of houses toward the
## edge of town.  The parks the plan chose, the river banks, the rail strip and the dockland (all reserved) stay green.
func _infill() -> void:
	var mask: PackedByteArray = plan["mask"]
	var res: PackedByteArray = plan["reserve"]
	if keep_park.size() != size * size:
		keep_park = PackedByteArray()
		keep_park.resize(size * size)
	var free := func(x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= size or y >= size:
			return false
		var i: int = y * size + x
		return tiles[i] == PARK and mask[i] == 1 and res[i] == 0 and keep_park[i] == 0
	var made := 0
	for y in range(2, size - 2):
		for x in range(2, size - 2):
			if not free.call(x, y):
				continue
			var w := 0
			while w < 26 and free.call(x + w, y):
				w += 1
			if w < 9:
				continue
			var h := 1
			while h < 26:
				var okrow := true
				for k in w:
					if not free.call(x + k, y + h):
						okrow = false
						break
				if not okrow:
					break
				h += 1
			if h < 9:
				continue
			var dd: float = Vector2(float(x) + w * 0.5, float(y) + h * 0.5).distance_to(centre_pt) / rad
			var x1: int = x + w - 1
			var y1: int = y + h - 1
			if dd < 0.85 or w < 14 or h < 14:
				_subdivide(x, y, x1, y1, 0)
			else:
				_suburb_block(x, y, x1, y1, 0.92)
			made += 1
	block_stats["infill"] = made

## keep every third street line (and every wide avenue, the trunk and the bridges): these are the straight arterials that carry the traffic, the sewers and
## the subway; the streets between them are the organic ones (see _organic_city)
func _thin_lines(lines: Array, wide: Dictionary, mid: int, horizontal: bool, decks: Array = []) -> Array:
	var out: Array = []
	for k in lines.size():
		var e: int = int(lines[k])
		if k == 0 or k == lines.size() - 1 or k % 3 == 1 or (horizontal and (wide.has(e) or e == mid or decks.has(e))):
			out.append(e)
	return out

## The planned city's blocks.  Streets run radially and in rings from the downtown (the edges between the cells of a Voronoi diagram whose seeds sit on
## rings round the centre, jittered and warped by noise), cut across by the straight arterials and the diagonals.  Each cell is a block, filled by packing
## rectangles: towers downtown, mid-rise outside, rows of houses toward the edge, with parking lots, kiosks and bare concrete in the odd corners.  Some
## cells are parks (more often beside the river).
func _organic_city(seed_v: int) -> void:
	var mask: PackedByteArray = plan["mask"]
	var water: PackedByteArray = plan["water"]
	var res: PackedByteArray = plan["reserve"]
	var n: int = size / 2
	var r := RandomNumberGenerator.new()
	r.seed = seed_v ^ 0x71c0de
	# --- seeds on rings
	var seeds: Array = []
	var ring_sp := 84.0
	var k := 0
	while true:
		var rr: float = float(k) * ring_sp
		if rr > rad * 2.1:
			break
		var cnt: int = 1 if k == 0 else 6 * k
		var rot: float = r.randf_range(0.0, TAU)
		for q in cnt:
			var a: float = rot + TAU * (float(q) + r.randf_range(-0.28, 0.28)) / float(cnt)
			var rj: float = rr + (r.randf_range(-20.0, 20.0) if k > 0 else 0.0)
			seeds.append(centre_pt + Vector2(cos(a), sin(a)) * rj)
		k += 1
	var bin := 96
	var nb: int = size / bin + 2
	var bins: Array = []
	bins.resize(nb * nb)
	for bi in bins.size():
		bins[bi] = []
	for si in seeds.size():
		var sp: Vector2 = seeds[si]
		var bx: int = clampi(int(sp.x) / bin, 0, nb - 1)
		var by: int = clampi(int(sp.y) / bin, 0, nb - 1)
		bins[by * nb + bx].append(si)
	var nz1 := FastNoiseLite.new()
	nz1.seed = seed_v ^ 0x11a1
	nz1.frequency = 0.012
	var nz2 := FastNoiseLite.new()
	nz2.seed = seed_v ^ 0x22b2
	nz2.frequency = 0.012
	# --- the cell of every 2x2 patch of tiles
	var cid := PackedInt32Array()
	cid.resize(n * n)
	for cy in n:
		for cx in n:
			var px: float = float(cx * 2 + 1)
			var py: float = float(cy * 2 + 1)
			if mask[(cy * 2) * size + cx * 2] == 0 and mask[(cy * 2 + 1) * size + cx * 2 + 1] == 0:
				cid[cy * n + cx] = -1
				continue
			var wx: float = px + 26.0 * nz1.get_noise_2d(px, py)
			var wy: float = py + 26.0 * nz2.get_noise_2d(px, py)
			var bx2: int = clampi(int(wx) / bin, 0, nb - 1)
			var by2: int = clampi(int(wy) / bin, 0, nb - 1)
			var best := -1
			var bd := 1.0e12
			for oy in range(-1, 2):
				var yy: int = by2 + oy
				if yy < 0 or yy >= nb:
					continue
				for ox in range(-1, 2):
					var xx: int = bx2 + ox
					if xx < 0 or xx >= nb:
						continue
					for si in bins[yy * nb + xx]:
						var sp2: Vector2 = seeds[si]
						var dx: float = sp2.x - wx
						var dy: float = sp2.y - wy
						var dd: float = dx * dx + dy * dy
						if dd < bd:
							bd = dd
							best = si
			cid[cy * n + cx] = best
	# --- streets on the cell edges (a patch whose right or lower neighbour is another cell), three patches (6 tiles) wide
	var rd := PackedByteArray()
	rd.resize(n * n)
	for cy in n - 1:
		for cx in n - 1:
			var c0: int = cid[cy * n + cx]
			if c0 < 0:
				continue
			if cid[cy * n + cx + 1] != c0 or cid[(cy + 1) * n + cx] != c0:
				rd[cy * n + cx] = 1
				rd[cy * n + cx + 1] = 1 if cid[cy * n + cx + 1] >= 0 else 0
				rd[(cy + 1) * n + cx] = 1 if cid[(cy + 1) * n + cx] >= 0 else 0
	for cy in n:
		for cx in n:
			if rd[cy * n + cx] == 0:
				continue
			for dy in 2:
				for dx in 2:
					var x: int = cx * 2 + dx
					var y: int = cy * 2 + dy
					var i: int = y * size + x
					if mask[i] == 1 and water[i] == 0 and res[i] == 0 and (tiles[i] == GROUND or tiles[i] == PARK):
						tiles[i] = ROAD
						marks[i] = 0
	# --- the perimeter ring road (a street just inside the caldera's foot, all the way round where nothing is in its way) and the quay lanes beside the
	# river, which also catch the streets that would otherwise end at the bank
	var outside := PackedByteArray()
	outside.resize(n * n)
	var wat := PackedByteArray()
	wat.resize(n * n)
	for cy in n:
		for cx in n:
			if cid[cy * n + cx] < 0:
				outside[cy * n + cx] = 1
			if water[(cy * 2) * size + cx * 2] != 0 or water[(cy * 2 + 1) * size + cx * 2 + 1] != 0:
				wat[cy * n + cx] = 1
	var d_edge: PackedByteArray = _coarse_dist(outside, n, 8)
	var d_wat: PackedByteArray = _coarse_dist(wat, n, 8)
	for cy in n:
		for cx in n:
			var ci: int = cy * n + cx
			var ring: bool = d_edge[ci] >= 2 and d_edge[ci] <= 4
			var quay: bool = wat[ci] == 0 and d_wat[ci] >= 3 and d_wat[ci] <= 5
			if not (ring or quay):
				continue
			for dy in 2:
				for dx in 2:
					var i: int = (cy * 2 + dy) * size + cx * 2 + dx
					if mask[i] == 1 and water[i] == 0 and res[i] == 0 and (tiles[i] == GROUND or tiles[i] == PARK):
						tiles[i] = ROAD
						marks[i] = 0
	# --- the loose ends of the diagonals and arcs are joined to the nearest street
	var plain := PackedByteArray()
	plain.resize(size * size)
	for i in size * size:
		if tiles[i] == ROAD and org[i] == 0:
			plain[i] = 1
	for tip in org_tips:
		_connect_tip(tip, plain, mask, res)
	# --- which tiles near a street (the pavement: two tiles either side stay bare), coarse
	var near := PackedByteArray()
	near.resize(n * n)
	for cy in range(1, n - 1):
		for cx in range(1, n - 1):
			var hit := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var x2: int = (cx + dx) * 2
					var y2: int = (cy + dy) * 2
					if tiles[y2 * size + x2] == ROAD or tiles[(y2 + 1) * size + x2 + 1] == ROAD:
						hit = true
			if hit:
				near[cy * n + cx] = 1
	# --- parks: cells chosen by a hash, more near water
	var park_cell := {}
	var house_cell := {}
	var cell_ctr := {}
	for si in seeds.size():
		var sp3: Vector2 = seeds[si]
		var dc: float = sp3.distance_to(centre_pt) / rad
		var p: float = 0.03 + 0.05 * dc
		var wet := 0
		for a2 in 8:
			var ang: float = TAU * float(a2) / 8.0
			for rr2 in [30.0, 55.0]:
				var q2: Vector2 = sp3 + Vector2(cos(ang), sin(ang)) * rr2
				if q2.x > 0 and q2.y > 0 and q2.x < size and q2.y < size and water[int(q2.y) * size + int(q2.x)] != 0:
					wet += 1
		if wet > 0:
			p += 0.42
		if dc < 0.18:
			p = 0.0
		if float(hash([seed_v, si, "pk"]) & 0xffff) / 65535.0 < p:
			if hash([seed_v, si, "hs"]) & 1 == 1:
				house_cell[si] = true           # half of the green cells are built over: houses, shacks in the poor districts
			else:
				park_cell[si] = true
	if keep_park.size() != size * size:
		keep_park = PackedByteArray()
		keep_park.resize(size * size)
	# the kind of district each cell is: the middle is "core"; further out cells are commercial, residential or industrial (industry sits well out, and near the river)
	var cell_zone := {}
	for si in seeds.size():
		var sp4: Vector2 = seeds[si]
		var dc4: float = sp4.distance_to(centre_pt) / rad
		var roll4: int = hash([seed_v, si, "zn"]) & 0x7fffffff
		var zk := "com"
		if dc4 < 0.42:
			zk = "core"
		else:
			var pr: int = roll4 % 100
			if dc4 > 0.55 and pr < 15:
				zk = "ind"
			elif pr < 15 + (35 if dc4 < 0.75 else 55):
				zk = "res"
		cell_zone[si] = zk
	var nstat := {"park": 0, "core": 0, "mid": 0, "suburb": 0, "lot": 0, "kiosk": 0, "ind": 0}
	nstat["park"] = park_cell.size()
	var freeb := PackedByteArray()
	freeb.resize(size * size)
	var housing := PackedByteArray()
	housing.resize(size * size)
	for y in range(2, size - 2):
		for x in range(2, size - 2):
			var i2: int = y * size + x
			if tiles[i2] != GROUND or mask[i2] == 0 or res[i2] == 1 or near[(y >> 1) * n + (x >> 1)] == 1:
				continue
			var c1: int = cid[(y >> 1) * n + (x >> 1)]
			if c1 < 0:
				continue
			if park_cell.has(c1):
				tiles[i2] = PARK
				keep_park[i2] = 1
				continue
			freeb[i2] = 1
			if house_cell.has(c1):
				housing[i2] = 1
	# --- pack rectangles into the free ground
	var dn := FastNoiseLite.new()
	dn.seed = seed_v ^ 0x6d2b
	dn.frequency = 0.018
	var mega := 0.34
	var tower_zone := 0.72
	for y in range(2, size - 2):
		for x in range(2, size - 2):
			if freeb[y * size + x] == 0:
				continue
			var dd: float = Vector2(float(x), float(y)).distance_to(centre_pt) / rad
			dd *= 1.0 + 0.16 * dn.get_noise_2d(float(x), float(y))
			var cap: int = 68 if dd < mega else (34 if dd < tower_zone else 40)
			var w := 0
			while w < cap and freeb[y * size + x + w] == 1:
				w += 1
			if w < 9:
				continue
			var h := 1
			while h < cap:
				var okrow := true
				for kx in w:
					if freeb[(y + h) * size + x + kx] == 0:
						okrow = false
						break
				if not okrow:
					break
				h += 1
			if h < 9:
				continue
			var x1: int = x + w - 1
			var y1: int = y + h - 1
			var made_lot := false
			var czone: String = cell_zone.get(cid[(y >> 1) * n + (x >> 1)], "com")
			if housing[y * size + x] == 1:
				czone = "res"
			cur_zone = czone
			if (czone == "core" or czone == "com") and w >= 14 and h >= 13 and rng.randf() < 0.5:
				# a type that has not been built yet takes the plot if it fits (so the big ones, hotels and banks and clubs, all turn up)
				var want := ""
				var wside: int = _street_side(x, y, x1, y1)
				for tid in BZ.TYPES:
					if int(biz_count.get(tid, 0)) == 0 and BZ.TYPES[tid]["zone"] != "ind" and (not BZ.TYPES[tid].has("wealth_max") or _plot_wealth(x, y, x1, y1) <= int(BZ.TYPES[tid]["wealth_max"])) and (not BZ.TYPES[tid].has("wealth_min") or _plot_wealth(x, y, x1, y1) >= int(BZ.TYPES[tid]["wealth_min"])) and not BZ.fitting_side(tid, w, h, wside).is_empty():
						want = tid
						break
				if want != "":
					var wrect = _stamp_business(want, x, y, x1, y1, wside)
					if wrect != null:
						for yy in range(maxi(wrect.position.y - 1, 0), mini(wrect.end.y + 1, size - 1)):
							for xx in range(maxi(wrect.position.x - 1, 0), mini(wrect.end.x + 1, size - 1)):
								freeb[yy * size + xx] = 0
						continue
			if czone == "ind" and w >= 12 and h >= 12:
				var iside: int = _street_side(x, y, x1, y1)
				var iid: String = _pick_business(w, h, iside, "ind")
				if iid != "":
					var irect = _stamp_business(iid, x, y, x1, y1, iside)
					if irect != null:
						for yy in range(maxi(irect.position.y - 1, 0), mini(irect.end.y + 1, size - 1)):
							for xx in range(maxi(irect.position.x - 1, 0), mini(irect.end.x + 1, size - 1)):
								freeb[yy * size + xx] = 0
						nstat["ind"] += 1
						continue
			if dd >= 0.12 and czone != "ind" and housing[y * size + x] == 0 and w >= 22 and h >= 22 and (hash([size, x / 8, y / 8, "lot"]) & 0x7fffffff) % 100 < 85:
				var nbay: int = mini(10, (w - 4) / 4)
				var ww: int = nbay * 4 + 2
				var roll: int = (hash([size, x / 8, y / 8, "lk"]) & 0x7fffffff) % 100
				_stamp_lot("station" if roll < 40 and nbay >= 7 else "lot", Rect2i(x + (w - ww) / 2, y + (h - 20) / 2, ww, 20), (hash([size, x, y, "ev"]) & 0x7fffffff) % 3 == 0)
				nstat["lot"] += 1
				made_lot = true
			elif dd < mega and w >= 60 and h >= 60 and r.randf() < 0.55:
				_building(x + 2, y + 2, x1 - 2, y1 - 2, "core")
				nstat["core"] += 1
			elif dd < 0.5 and w >= 30 and h >= 30 and r.randf() < 0.55:
				_building(x + 2, y + 2, x1 - 2, y1 - 2, "core")          # a downtown tower on its own plot
				nstat["core"] += 1
			elif housing[y * size + x] == 1 and w >= 12 and h >= 12:
				_suburb_block(x, y, x1, y1, 0.95)
				nstat["suburb"] += 1
			elif dd < tower_zone or w < 14 or h < 14:
				_subdivide(x, y, x1, y1, 0)
				nstat["mid"] += 1
			else:
				var exurb: bool = dd > 1.0
				_suburb_block(x, y, x1, y1, 0.7 if exurb else 0.95)
				nstat["suburb"] += 1
			for yy in range(y, y1 + 1):
				for xx in range(x, x1 + 1):
					freeb[yy * size + xx] = 0
	# --- kiosks and small shops in the corners that were left (6x6 to 9x9), then bare concrete
	for y in range(2, size - 2):
		for x in range(2, size - 2):
			if freeb[y * size + x] == 0:
				continue
			var w2 := 0
			while w2 < 9 and freeb[y * size + x + w2] == 1:
				w2 += 1
			if w2 < 6:
				continue
			var h2 := 1
			while h2 < 9:
				var ok2 := true
				for kx2 in w2:
					if freeb[(y + h2) * size + x + kx2] == 0:
						ok2 = false
						break
				if not ok2:
					break
				h2 += 1
			if h2 < 6:
				continue
			_building(x, y, x + w2 - 1, y + h2 - 1, "mid")
			nstat["kiosk"] += 1
			for yy2 in range(y, y + h2):
				for xx2 in range(x, x + w2):
					freeb[yy2 * size + xx2] = 0
	block_stats = {"null": 0, "park": nstat["park"], "core": nstat["core"] + nstat["mid"], "merged": nstat["core"], "suburb": nstat["suburb"], "exurb": 0, "lot": nstat["lot"], "kiosk": nstat["kiosk"], "ind": nstat["ind"], "biz": businesses.size(), "null_list": []}


## distance (in coarse patches, up to `maxd`) of every patch from the nearest patch with src == 1; 255 beyond
func _coarse_dist(src: PackedByteArray, n: int, maxd: int) -> PackedByteArray:
	var d := PackedByteArray()
	d.resize(n * n)
	d.fill(255)
	var q: Array = []
	for i in n * n:
		if src[i] == 1:
			d[i] = 0
			q.append(i)
	var head := 0
	while head < q.size():
		var i: int = q[head]
		head += 1
		var dv: int = d[i]
		if dv >= maxd:
			continue
		var x: int = i % n
		var y: int = i / n
		for o in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nx: int = x + o[0]
			var ny: int = y + o[1]
			if nx < 0 or ny < 0 or nx >= n or ny >= n:
				continue
			var j: int = ny * n + nx
			if d[j] == 255:
				d[j] = dv + 1
				q.append(j)
	return d

## join a loose end to the street network: nothing to do if a plain street is within 5 tiles; otherwise lay a street straight to the nearest one (up to 90 away)
func _connect_tip(tip: Vector2, plain: PackedByteArray, mask: PackedByteArray, res: PackedByteArray) -> void:
	var tx: int = int(tip.x)
	var ty: int = int(tip.y)
	var target := Vector2i(-1, -1)
	for rr in range(1, 91, 2):
		var best := 1 << 30
		for k in range(-rr, rr + 1, 2):
			for p in [Vector2i(tx + k, ty - rr), Vector2i(tx + k, ty + rr), Vector2i(tx - rr, ty + k), Vector2i(tx + rr, ty + k)]:
				if p.x < 1 or p.y < 1 or p.x >= size - 1 or p.y >= size - 1:
					continue
				if plain[p.y * size + p.x] == 1:
					var dd: int = (p.x - tx) * (p.x - tx) + (p.y - ty) * (p.y - ty)
					if dd < best:
						best = dd
						target = p
		if target.x >= 0:
			if rr <= 6:
				return                      # already touching
			break
	if target.x < 0:
		return
	var len: int = maxi(absi(target.x - tx), absi(target.y - ty))
	for s in range(0, len + 1):
		var x: int = tx + (target.x - tx) * s / len
		var y: int = ty + (target.y - ty) * s / len
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				if dx * dx + dy * dy > 9:
					continue
				var xx: int = x + dx
				var yy: int = y + dy
				if xx < 1 or yy < 1 or xx >= size - 1 or yy >= size - 1:
					continue
				var i: int = yy * size + xx
				if mask[i] == 1 and res[i] == 0 and (tiles[i] == GROUND or tiles[i] == PARK):
					tiles[i] = ROAD
					marks[i] = 0

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
	if w * h == 1 and not plan.is_empty():
		_core_block(r0.position.x, r0.position.y, r0.end.x, r0.end.y)
	else:
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
	if keep_park.size() != size * size:
		keep_park = PackedByteArray()
		keep_park.resize(size * size)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			tiles[y * size + x] = PARK
			keep_park[y * size + x] = 1

## one big mixed-use building filling the block, BSP rooms, doors on the street side
func _core_block(x0: int, y0: int, x1: int, y1: int) -> void:
	# downtown: one block in four keeps a single big tower, the rest are cut by 1-2 tile alleys into a cluster of mid-size buildings
	if plan.is_empty() or rng.randf() < 0.25:
		_building(x0 + 2, y0 + 2, x1 - 2, y1 - 2, "core")
		return
	_subdivide(x0 + 1, y0 + 1, x1 - 1, y1 - 1, 0)

## cut a rectangle into buildings with alleys (1 or 2 tiles of open ground) between them.  A building up to about 22 tiles a side is built; a larger one is split
## across its longer side.  A building of 260+ tiles may still be a tower; the rest are mid-rise (shops, offices and flats, no tower of their own).
func _subdivide(x0: int, y0: int, x1: int, y1: int, depth: int) -> void:
	var w: int = x1 - x0 + 1
	var h: int = y1 - y0 + 1
	if w < 7 or h < 7:
		return
	var limit: int = 18 + rng.randi_range(0, 6) + (8 if (not plan.is_empty() and (cur_zone == "core" or cur_zone == "com") and rng.randf() < 0.22) else 0)
	if (w <= limit and h <= limit) or depth > 4:
		var kind := "mid"
		var dc: float = Vector2((x0 + x1) * 0.5, (y0 + y1) * 0.5).distance_to(centre_pt) / rad if rad > 0.0 else 1.0
		if not plan.is_empty() and not (dc < 0.5 and w * h >= 150) and _leaf_business(x0, y0, x1, y1):
			return
		if dc < 0.5 and w * h >= 150 and rng.randf() < (0.8 if dc < 0.3 else 0.5):
			kind = "core"                   # the middle of the city is towers
		elif w * h >= 260 and rng.randf() < 0.3:
			kind = "core"
		_building(x0, y0, x1, y1, kind)
		return
	var alley: int = 1 + (1 if rng.randf() < 0.3 else 0)
	if w >= h:
		var cut: int = x0 + int(float(w) * rng.randf_range(0.38, 0.62))
		_subdivide(x0, y0, cut - 1, y1, depth + 1)
		_subdivide(cut + alley, y0, x1, y1, depth + 1)
	else:
		var cut2: int = y0 + int(float(h) * rng.randf_range(0.38, 0.62))
		_subdivide(x0, y0, x1, cut2 - 1, depth + 1)
		_subdivide(x0, cut2 + alley, x1, y1, depth + 1)

const LEGACY_TYPE := {"restaurant": "restaurant", "grocery": "grocery", "implant": "implant_shop", "cyberdoc": "cyberdoc", "clinic": "clinic", "church": "church", "temple": "shrine"}

## a small building that is a business (shop, bar, office-counter, gym, ...) instead of a plain mid-rise: decided by the district kind and what fits
func _leaf_business(x0: int, y0: int, x1: int, y1: int) -> bool:
	var w: int = x1 - x0 + 1
	var h: int = y1 - y0 + 1
	if w < 8 or h < 8:
		return false
	var pb: float = {"core": 0.97, "com": 0.95, "res": 0.5, "ind": 0.92}.get(cur_zone, 0.6)
	var forced := ""
	if not venue_plan.is_empty() and cur_zone != "ind" and cur_zone != "res":
		forced = LEGACY_TYPE.get(venue_plan[0], "")
		pb = 1.0
	if rng.randf() > pb:
		return false
	var side: int = _street_side(x0, y0, x1, y1)
	_pick_wealth = _plot_wealth(x0, y0, x1, y1)
	if forced == "" and cur_zone != "ind" and _pick_wealth == 2 and labor_downtown < LABOR_DOWNTOWN and not BZ.fitting_side("labor_center", w, h, side).is_empty() and (hash([x0, y0, size, "lcd"]) & 0x7fffffff) % 100 < 25:
		labor_downtown += 1
		return _stamp_business("labor_center", x0, y0, x1, y1, side) != null     # (a few labor centers downtown too: the towers' people need work as much as the slums)
	if forced == "" and cur_zone != "ind" and _pick_wealth <= 1 and int(biz_count.get("labor_center", 0)) < LABOR_MIN and not BZ.fitting_side("labor_center", w, h, side).is_empty() and rng.randf() < 0.3:
		return _stamp_business("labor_center", x0, y0, x1, y1, side) != null     # (the quota of labor centers: taken by plots in the middle and lower districts that have room)
	if forced == "" and cur_zone != "ind" and _pick_wealth >= 1 and int(biz_count.get("temp_agency", 0)) < TEMP_MIN and not BZ.fitting_side("temp_agency", w, h, side).is_empty() and rng.randf() < 0.3:
		return _stamp_business("temp_agency", x0, y0, x1, y1, side) != null      # (the quota of temp agencies: plots in the middle and rich districts that have room)
	if forced == "" and cur_zone != "ind" and int(biz_count.get("cyberdoc", 0)) < _cyberdoc_min() and not BZ.fitting_side("cyberdoc", w, h, side).is_empty() and rng.randf() < 0.25:
		return _stamp_business("cyberdoc", x0, y0, x1, y1, side) != null         # (the quota of cyberdoc offices: any district that has a plot with room)
	if forced == "implant_shop" and rng.randf() < 0.5:
		forced = "implant_body"                                                   # (the two implant stores: eyes/spine/head, and the rest of the body)
	var id := forced if forced != "" and not BZ.fitting_side(forced, w, h, side).is_empty() else _pick_business(w, h, side, "ind" if cur_zone == "ind" else "")
	if id == "":
		return false
	if forced != "" and id == forced:
		venue_plan.pop_front()
	return _stamp_business(id, x0, y0, x1, y1, side) != null

## choose a business type for a w x h rectangle, weighted by how well the district kind suits it
var _pick_wealth: int = 1               # the district wealth (0 poor .. 2 rich) of the plot a business is being chosen for

## the richest district any column of a plot reaches (a plot that reaches into a rich district counts as rich)
func _plot_wealth(x0: int, y0: int, x1: int, y1: int) -> int:
	var m := 0
	for wy in range(y0, y1 + 1):
		for wx in range(x0, x1 + 1):
			m = maxi(m, wealth_at(wy * size + wx))
	return m

const CYBERDOC_MIN := 12                   # cyberdoc offices the island city (1536 tiles a side) has at least, spread through all districts; smaller cities scale with their area (at least 3)

func _cyberdoc_min() -> int:
	return clampi(int(float(CYBERDOC_MIN) * float(size) * float(size) / (1536.0 * 1536.0)), 3, CYBERDOC_MIN)
const LABOR_DOWNTOWN := 4                   # labor centers placed in the rich downtown districts (a few)
var labor_downtown: int = 0
const TEMP_MIN := 20                       # temp agencies every city has at least (the middle and rich districts)
const LABOR_MIN := 25                      # labor centers every city has at least (the middle and lower districts)

func _pick_business(w: int, h: int, side: int, zones_only: String = "") -> String:
	var weights: Array = []
	var total := 0.0
	for id in BZ.TYPES:
		var T: Dictionary = BZ.TYPES[id]
		if BZ.fitting_side(id, w, h, side).is_empty():
			continue
		var tz: String = T["zone"]
		var wt: float = float(T["w"])
		if T.has("wealth_max") and _pick_wealth > int(T["wealth_max"]):
			continue                                       # (a labor center stands in the middle and lower districts only)
		if T.has("wealth_min") and _pick_wealth < int(T["wealth_min"]):
			continue                                       # (a temp agency stands in the middle and rich districts only)
		if zones_only != "":
			if tz != zones_only:
				continue
		else:
			if tz == "ind":
				continue
			match cur_zone:
				"core": wt *= (3.0 if tz == "core" else (1.6 if tz == "any" else (1.0 if tz == "mid" else 0.2)))
				"com": wt *= (3.0 if tz == "mid" else (2.0 if tz == "any" else (1.2 if tz == "core" else 0.8)))
				"res": wt *= (3.0 if tz == "any" else (1.0 if tz == "mid" else (0.6 if tz == "edge" else 0.1)))
		var have: int = int(biz_count.get(id, 0))
		wt *= 5.0 if have == 0 else (2.0 if have < 3 else 1.0)
		if id == "cyberdoc" and have < _cyberdoc_min():
			wt *= 14.0                                     # (picked far more often until the city has CYBERDOC_MIN of them)
		if id == "temp_agency" and have < TEMP_MIN:
			wt *= 14.0                                     # (every city has at least TEMP_MIN temp agencies)
		if id == "labor_center" and have < LABOR_MIN:
			wt *= 14.0                                     # (every city has at least LABOR_MIN labor centers: they are picked far more often until it does)
		weights.append([id, wt])
		total += wt
	if weights.is_empty():
		return ""
	var roll: float = rng.randf() * total
	for e in weights:
		roll -= float(e[1])
		if roll <= 0.0:
			return String(e[0])
	return String(weights[weights.size() - 1][0])

## build business `id` inside the rectangle (x0,y0)-(x1,y1), centred on the side away from the door's street
func _stamp_business(id: String, x0: int, y0: int, x1: int, y1: int, side: int):
	var w: int = x1 - x0 + 1
	var h: int = y1 - y0 + 1
	var fits: Array = BZ.fitting_side(id, w, h, side)
	if fits.is_empty():
		return null
	var ver: int = fits[rng.randi() % fits.size()]
	if fits.size() > 1 and rng.randf() < 0.5:
		ver = fits[fits.size() - 1]                       # leans to the bigger version when there is room
	var sz: Vector2i = BZ.size_of(id, ver, side)
	var px: int = x0 + (w - sz.x) / 2
	var py: int = y0 + (h - sz.y) / 2
	match side:
		0: py = y0
		1: py = y1 - sz.y + 1
		2: px = x0
		_: px = x1 - sz.x + 1
	BZ.stamp(self, id, ver, px, py, side)
	biz_count[id] = int(biz_count.get(id, 0)) + 1
	return Rect2i(px, py, sz.x, sz.y)

func _suburb_block(x0: int, y0: int, x1: int, y1: int, density: float = 0.9) -> void:
	# rows of houses across the whole block with a 1-2 tile alley between rows and between houses.  The island city packs them: small houses, rows as
	# deep as the block allows.  (The alleys run out to the sidewalk at the block's edge, so every house is reachable.)
	var packed: bool = not plan.is_empty()
	var rows: Array = []
	if packed:
		var y: int = y0 + 2
		while true:
			var depth: int = rng.randi_range(8, 10) if wealth_at(y * size + x0) != 0 else rng.randi_range(6, 8)      # shacks in the poor districts
			if y + depth - 1 > y1 - 2:
				break
			rows.append([y, y + depth - 1])
			y += depth + (1 if rng.randf() < 0.7 else 2)
	else:
		var depth0 := 11
		rows = [[y0 + 2, y0 + 2 + depth0 - 1], [y1 - 2 - depth0 + 1, y1 - 2]]
		if y1 - y0 >= 46:
			var mid := (y0 + y1) / 2
			rows.append([mid - depth0 / 2, mid - depth0 / 2 + depth0 - 1])
	for rid in rows.size():
		var row: Array = rows[rid]
		var x := x0 + 2
		while x + (6 if packed else 9) <= x1 - 2:
			var wdt := (rng.randi_range(7, 11) if wealth_at(row[0] * size + x) != 0 else rng.randi_range(6, 8)) if packed else rng.randi_range(10, 15)
			if x + wdt > x1 - 2:
				break
			if rid < 2 and wdt >= 10 and not venue_plan.is_empty() and rng.randf() < 0.6 and (wdt >= 12 or packed):
				var kind: String = venue_plan.pop_front()
				VN.stamp(self, kind, x, row[0], x + wdt, row[1], 0 if rid == 0 else 1, 0 if wealth_at(row[0] * size + x) == 0 else 1)
			elif rng.randf() < density:
				_building(x, row[0], x + wdt, row[1], "house")
			x += wdt + ((1 if rng.randf() < 0.7 else 2) if packed else rng.randi_range(3, 6))

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

const EMPTY_SHARE := 0.09              # the share of plain buildings left bare (condemned, for rent, gutted)

## furnish the rooms of a plain building as a home.  The first room is the living room (kitchen along a wall, sofa, a table), the others bedrooms and odd rooms.  Furniture only
## goes on the cells along the walls, never beside a door, so the middle of every room stays open.  Returns whether anything was placed.
func _furnish_home(rooms: Array, door: Vector2i, kind: String, frng: RandomNumberGenerator) -> bool:
	var placed := 0
	var di := 0
	if under.size() != size * size:
		under = PackedByteArray()
		under.resize(size * size)
	var rich: bool = wealth_at(door.y * size + door.x) >= 1
	for r in rooms:
		var rect: Rect2i = r
		if rect.size.x < 3 or rect.size.y < 2:
			continue
		var edge: Array = []
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if x != rect.position.x and x != rect.end.x - 1 and y != rect.position.y and y != rect.end.y - 1:
					continue
				if tiles[y * size + x] != FLOOR:
					continue
				var nd := false
				for oy in range(-1, 2):
					for ox in range(-1, 2):
						if tiles[(y + oy) * size + x + ox] == DOOR:
							nd = true
				if not nd:
					edge.append(Vector2i(x, y))
		for k in range(edge.size() - 1, 0, -1):
			var j: int = frng.randi() % (k + 1)
			var tmp = edge[k]
			edge[k] = edge[j]
			edge[j] = tmp
		var items: Array = []
		var living: bool = di == 0 or (rooms.size() == 1)
		if living:
			items = ["kitchen_counter", "kitchen_sink", "fridge", "sofa", "tv_stand", "coffee_table"] if rich else ["kitchen_counter", "hot_plate", "kotatsu", "sofa"]
			if rooms.size() == 1 or rect.get_area() < 14:
				items.append("bed_single")
			items.append("shoe_rack")
		else:
			items = ["bed_double" if rich else "bed_single", "wardrobe", "dresser"] if di % 3 != 2 else ["desk", "bookshelf", "cabinet"]
		di += 1
		var n: int = mini(items.size(), maxi(2, edge.size() / 3))
		for k in n:
			if k >= edge.size():
				break
			var nm: String = items[k]
			if not TID.has(nm):
				continue
			var c: Vector2i = edge[k]
			tiles[c.y * size + c.x] = TID[nm]
			under[c.y * size + c.x] = FLOOR
			placed += 1
	return placed > 0

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
	_split(bx0 + 1, by0 + 1, bx1 - 1, by1 - 1, rooms, 0 if (kind == "core" or kind == "mid") else 1)
	# a door on the wall that faces the nearest road
	var side := _street_side(bx0, by0, bx1, by1)
	var door := _wall_cell(bx0, by0, bx1, by1, side)
	tiles[door.y * size + door.x] = DOOR
	var rec := {"x0": bx0, "y0": by0, "x1": bx1, "y1": by1, "kind": kind, "door": door, "side": side, "filled": false}
	bldgs.append(rec)
	if kind != "core":
		var frng := RandomNumberGenerator.new()                           # (its own random stream: the rest of the city is laid out the same with or without the furniture)
		frng.seed = hash([bx0, by0, size, "home"])
		if frng.randf() >= EMPTY_SHARE:
			rec["filled"] = _furnish_home(rooms, door, kind, frng)
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
	if kind == "house":
		var hc := Vector2i((bx0 + bx1) / 2, (by0 + by1) / 2)
		var best := -1
		var bd := 1 << 30
		for y in range(by0 + 1, by1):
			for x in range(bx0 + 1, bx1):
				if tiles[y * size + x] == FLOOR:
					var dd := absi(x - hc.x) + absi(y - hc.y)
					if dd < bd:
						bd = dd
						best = y * size + x
		if best >= 0:
			houses.append({"cell": best, "x0": bx0, "y0": by0, "x1": bx1, "y1": by1})

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
	pal.resize(256)
	for k in 256:
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
