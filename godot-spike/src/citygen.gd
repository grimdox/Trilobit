extends RefCounted
## Spike test 3b: one city map (256 x 256 tiles) from a seed.  A road grid with varying block widths, a core of tall mixed-use buildings,
## suburban houses and parks outside it, and a harbor on the side that faces the overworld's harbor.  Buildings are BSP rooms with doors;
## each building is placed with its door on the street side.  Produces home, work and shop markers for the NPC simulation.
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
const LOW_COVER := [20, 23, 24, 25]
## 1 where a tile can be walked on (indexed by tile id)
const WALK := [1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 0, 0, 0]

var size: int = 256
var tiles: PackedByteArray
var homes: PackedInt32Array
var works: PackedInt32Array
var shops: PackedInt32Array
var buildings: int = 0
var xs: Array = []                     # x of each vertical road line (left edge), y of each horizontal one
var ys: Array = []
var rw: int = 2
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
var tower_info: Array = []             # {x0,y0,x1,y1,h,stairs,elev} per built tower
var subway: Dictionary = {}            # {ring: PackedInt32Array of track cells (level -1), stops: Array of ring indices}
var rng := RandomNumberGenerator.new()

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

func generate(seed: int, harbor_dir: Vector2, sz: int = 256) -> void:
	size = sz
	rng.seed = seed
	tiles = PackedByteArray()
	tiles.resize(size * size)
	tiles.fill(GROUND)
	homes = PackedInt32Array()
	works = PackedInt32Array()
	shops = PackedInt32Array()
	buildings = 0
	towers = []
	var dir := harbor_dir.normalized() if harbor_dir.length() > 0.01 else Vector2(1, 0)
	# water: the side facing the harbor, with a wavy edge
	var nw := FastNoiseLite.new()
	nw.seed = seed ^ 0xA7E5
	nw.frequency = 0.04
	var water_w := rng.randi_range(18, 30)
	var water := PackedByteArray()
	water.resize(size * size)
	for y in size:
		for x in size:
			var p := Vector2(x - size * 0.5, y - size * 0.5)
			var proj := p.dot(dir)                         # distance along the harbor direction from the centre
			if proj > size * 0.5 - water_w + nw.get_noise_2d(x, y) * 10.0:
				water[y * size + x] = 1
				tiles[y * size + x] = WATER
	# road lines with varying block widths
	xs = _lines()
	ys = _lines()
	rw = rng.randi_range(2, 3)
	for lx in xs:
		for y in size:
			for k in rw:
				_set_road(lx + k, y, water)
	for ly in ys:
		for x in size:
			for k in rw:
				_set_road(x, ly + k, water)
	# blocks between the lines
	var centre := Vector2(size * 0.5, size * 0.5)
	for i in xs.size() - 1:
		for j in ys.size() - 1:
			var x0: int = xs[i] + rw
			var x1: int = xs[i + 1] - 1
			var y0: int = ys[j] + rw
			var y1: int = ys[j + 1] - 1
			if x1 - x0 < 6 or y1 - y0 < 6:
				continue
			if _water_in(water, x0, y0, x1, y1):
				continue
			var d := Vector2((x0 + x1) * 0.5, (y0 + y1) * 0.5).distance_to(centre) / (size * 0.5)
			var r := rng.randf()
			if r < 0.07 + d * 0.12:
				_park(x0, y0, x1, y1)
			elif d < 0.42:
				_core_block(x0, y0, x1, y1)
			else:
				_suburb_block(x0, y0, x1, y1)

func _lines() -> Array:
	var out := []
	var p := rng.randi_range(2, 6)
	while p < size - 8:
		out.append(p)
		p += rng.randi_range(14, 24)
	out.append(size - 3)
	return out

func _set_road(x: int, y: int, water: PackedByteArray) -> void:
	if x < 0 or y < 0 or x >= size or y >= size:
		return
	if water[y * size + x] == 1:
		return
	tiles[y * size + x] = ROAD

func _water_in(water: PackedByteArray, x0: int, y0: int, x1: int, y1: int) -> bool:
	for y in [y0, y1, (y0 + y1) / 2]:
		for x in [x0, x1, (x0 + x1) / 2]:
			if water[y * size + x] == 1:
				return true
	return false

func _park(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			tiles[y * size + x] = PARK

## one big mixed-use building filling the block, BSP rooms, doors on the street side
func _core_block(x0: int, y0: int, x1: int, y1: int) -> void:
	var bx0 := x0 + 1
	var by0 := y0 + 1
	var bx1 := x1 - 1
	var by1 := y1 - 1
	_building(bx0, by0, bx1, by1, "core")

func _suburb_block(x0: int, y0: int, x1: int, y1: int) -> void:
	# a row of houses along the north edge and another along the south edge of the block, yards between
	var y_rows := [[y0 + 1, y0 + 8], [y1 - 8, y1 - 1]] if y1 - y0 >= 19 else [[y0 + 1, mini(y0 + 8, y1 - 1)]]
	for row in y_rows:
		var x := x0 + 1
		while x + 7 <= x1 - 1:
			var wdt := rng.randi_range(7, 10)
			if x + wdt > x1 - 1:
				break
			if rng.randf() < 0.88:
				_building(x, row[0], x + wdt, row[1], "house")
			x += wdt + rng.randi_range(2, 4)

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
		while d < 12 and x >= 0 and y >= 0 and x < size and y < size and tiles[y * size + x] != ROAD:
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
