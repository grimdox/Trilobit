extends RefCounted
## The island: a semi-random full-scale map in the far south-east of Russia, a little north of Japan.  Everything here is an ANALYTIC function of
## the seed (terrain(x, y) -> tile id), so any part of the island can be generated on demand and two zones always agree about their overlap.
## The island is a 5 x 3 grid of 512 x 512 zones that overlap by 64 tiles; a zone "owns" the ground that is nearest its own centre.
##   west     a harbor (port quays, warehouses, a freight yard)
##   x 335-445 a mountain range running the whole length of the island, crossed by ONE thin winding pass with the highway and the railway
##   x 520-900 the city (zone 1,1)
##   centre    a small placeholder town on the highway
##   east      open plains and fields, then a sheer cliff coast that boats cannot climb
##   north / south  open, low-lying, rocky and jagged shores
const CG = preload("res://src/citygen.gd")

const W := 2304
const H := 1408
const ZS := 512
const STRIDE := 448
const NZX := 5
const NZY := 3
const HWY_Y := 704                     # centre row of the highway: rows HWY_Y-6 .. HWY_Y+5 (the city's main street is the same twelve rows)
const PASS_X0 := 335
const PASS_X1 := 448
const PORT := Vector2i(215, 704)
const TOWN := Vector2i(1152, 704)
const HWY_X0 := 150
const HWY_X1 := 1330
const RAIL_X1 := 510                   # the railway ends at the city's freight yard
const CITY_ZONE := Vector2i(1, 1)
const MARGIN_ZONE := 72                # the city leaves this much empty ground at its edge so the next zone never shows a half-built city
const OWN_INSET := 32

var seed_value: int = 0
var _nw := FastNoiseLite.new()
var _nn := FastNoiseLite.new()
var _ns := FastNoiseLite.new()
var _ne := FastNoiseLite.new()
var _nj := FastNoiseLite.new()
var _nm := FastNoiseLite.new()
var _nf := FastNoiseLite.new()
var _nt := FastNoiseLite.new()
var _bay_depth: int = 70
var _pass_phase: float = 0.0
var _hx0: int = HWY_X0                 # the first highway column (just inland of the quay)

func _init(sd: int = 1) -> void:
	seed_value = sd
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	for n in [_nw, _nn, _ns, _ne, _nj, _nm, _nf, _nt]:
		n.seed = rng.randi()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_nw.frequency = 0.011
	_nn.frequency = 0.009
	_ns.frequency = 0.009
	_ne.frequency = 0.02
	_nj.frequency = 0.16
	_nj.fractal_octaves = 2
	_nm.frequency = 0.012
	_nf.frequency = 0.011
	_nt.frequency = 0.014
	_bay_depth = rng.randi_range(60, 80)
	_pass_phase = rng.randf_range(0.0, TAU)
	_hx0 = int(west_x(HWY_Y)) + 6

# ------------------------------------------------------------------------------------------------ zones
static func zone_origin(zx: int, zy: int) -> Vector2i:
	return Vector2i(zx * STRIDE, zy * STRIDE)

## the zone whose territory contains a global position
static func zone_owner(gx: int, gy: int) -> Vector2i:
	return Vector2i(clampi(int(floor(float(gx - OWN_INSET) / STRIDE)), 0, NZX - 1), clampi(int(floor(float(gy - OWN_INSET) / STRIDE)), 0, NZY - 1))

static func zone_name(z: Vector2i) -> String:
	if z == CITY_ZONE:
		return "the city"
	if z == Vector2i(0, 1):
		return "the harbor"
	if z == Vector2i(2, 1):
		return "the town"
	return "the wilds"

# ------------------------------------------------------------------------------------------------ the shape
func west_x(y: int) -> float:
	var x := 128.0 + 48.0 * _nw.get_noise_1d(y) + 4.0 * _nj.get_noise_2d(7.0, y)
	var d := absf(float(y - PORT.y))
	if d < 110.0:
		var k := 1.0 - d / 110.0
		x += float(_bay_depth) * minf(1.0, k * 2.2)
	return x

func north_y(x: int) -> float:
	return 150.0 + 66.0 * _nn.get_noise_1d(x) + 6.0 * _nj.get_noise_2d(x, 3.0)

func south_y(x: int) -> float:
	return float(H) - 150.0 + 66.0 * _ns.get_noise_1d(x) + 6.0 * _nj.get_noise_2d(x, 9.0)

func east_x(y: int) -> float:
	return float(W) - 56.0 + 7.0 * _ne.get_noise_1d(y)

## the highway's centre row at column x (it winds only inside the mountain pass)
func pass_yc(x: int) -> int:
	if x <= PASS_X0 - 6 or x >= PASS_X1:
		return HWY_Y
	var t := float(x - (PASS_X0 - 6)) / float(PASS_X1 - PASS_X0 + 6)
	var env := minf(minf(t * 5.0, (1.0 - t) * 3.5), 1.0)
	return HWY_Y + int(round(24.0 * env * sin(t * TAU * 1.25 + _pass_phase)))

func mtn_west(y: int) -> float:
	return 340.0 + 22.0 * _nm.get_noise_1d(y)

func mtn_east(y: int) -> float:
	return 436.0 + 12.0 * _nm.get_noise_1d(y + 5000)

static func _hash(x: int, y: int) -> int:
	return (x * 73856093 ^ y * 19349663) & 0x7fffffff

# ------------------------------------------------------------------------------------------------ the analytic map
## the road, rail and pass cut through the mountains (or -1 where there is none)
func _corridor(x: int, y: int) -> int:
	if x < _hx0 or x > HWY_X1:
		return -1
	var hy := pass_yc(x)
	var dy := y - hy
	if dy >= -6 and dy <= 5:
		return CG.ROAD
	if x <= RAIL_X1:
		# a two-track line: each track two tiles wide (rows +9..+10 north, +13..+14 south), ballast between and around.  Where the road
		# steps more than a row between columns the rails fill the gap.
		var ya := mini(pass_yc(x - 1), pass_yc(x - 2)) - hy
		var yb := maxi(pass_yc(x + 1), pass_yc(x + 2)) - hy
		var lo := mini(0, mini(ya, yb))
		var hi := maxi(0, maxi(ya, yb))
		if (dy >= 9 + lo and dy <= 10 + hi) or (dy >= 13 + lo and dy <= 14 + hi):
			return CG.TRACK
		if dy >= 8 + lo and dy <= 15 + hi:
			return CG.BALLAST
	if x >= PASS_X0 - 14 and x <= PASS_X1 + 40 and dy >= -9 and dy <= 21:
		return CG.ROCKS
	return -1

func mark(x: int, y: int) -> int:
	if x < _hx0 or x > HWY_X1:
		return 0
	var hy := pass_yc(x)
	var dy := y - hy
	if dy >= -6 and dy <= 5:
		if dy == -6 or dy == 5:
			return CG.M_WHITE_H
		if dy == -1 or dy == 0:
			return CG.M_YELLOW_H
		return 0
	if x <= RAIL_X1 and _corridor(x, y) == CG.TRACK:
		return CG.M_RAIL_H
	return 0

func terrain(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= W or y >= H:
		return CG.WATER
	var cor := _corridor(x, y)
	if cor >= 0:
		return cor
	var ex := east_x(y)
	if float(x) >= ex:
		return CG.WATER
	if float(x) > ex - 10.0:
		return CG.CLIFF
	var wx := west_x(y)
	var d_w := float(x) - wx
	if d_w < 0.0:
		return CG.WATER
	var d_n := float(y) - north_y(x)
	var d_s := south_y(x) - float(y)
	if d_w < 190.0:                      # round the west corners
		var k := (190.0 - d_w) / 190.0
		d_n -= 110.0 * k * k
		d_s -= 110.0 * k * k
	var d_ns := minf(d_n, d_s)
	if d_ns < 40.0:
		var t := d_ns + 7.0 * _nj.get_noise_2d(x, y)
		if t < 0.0:
			return CG.WATER
		if t < 22.0:
			return CG.ROCKS if _hash(x, y) % 9 != 0 else CG.TREE
		if t < 34.0 and _nj.get_noise_2d(x * 2, y * 2) > -0.1:
			return CG.ROCKS
	if d_w < 5.0:
		return CG.SAND
	# the mountain range
	var xa := mtn_west(y)
	var xb := mtn_east(y)
	if float(x) >= xa - 22.0 and float(x) <= xb + 16.0:
		if float(x) >= xa and float(x) <= xb:
			var edge := minf(float(x) - xa, xb - float(x))
			if edge > 5.0 + 4.0 * _nj.get_noise_2d(x, y):
				return CG.MOUNTAIN
			return CG.ROCKS if _hash(x, y) % 5 != 0 else CG.MOUNTAIN
		if _nj.get_noise_2d(x, y) > -0.2:
			return CG.ROCKS if _hash(x, y) % 4 != 0 else CG.TREE
	# the plains: grass, planted fields in parcels, and woods
	if x > 990:
		var fx := (x / 30) * 30
		var fy := (y / 24) * 24
		if _nf.get_noise_2d(fx, fy) > 0.1 and (x % 30) > 2 and (x % 30) < 28 and (y % 24) > 2 and (y % 24) < 22:
			return CG.FIELD
	var f := _nt.get_noise_2d(x, y)
	if f > 0.12 and _hash(x, y) % 100 < 10 + int(f * 160.0):
		return CG.TREE
	return CG.PARK

# ------------------------------------------------------------------------------------------------ zone generation
## fill a CityGen object (empty arrays) with the wild terrain of zone (zx, zy): tiles, lane marks, nothing else
func fill_terrain(c, zx: int, zy: int) -> void:
	var o := zone_origin(zx, zy)
	c.size = ZS
	c.tiles = PackedByteArray()
	c.tiles.resize(ZS * ZS)
	c.marks = PackedByteArray()
	c.marks.resize(ZS * ZS)
	for y in ZS:
		for x in ZS:
			c.tiles[y * ZS + x] = terrain(o.x + x, o.y + y)
			var m := mark(o.x + x, o.y + y)
			if m != 0:
				c.marks[y * ZS + x] = m

## named places for the map: {name, pos (global tile), kind}
func landmarks() -> Array:
	return [
		{"name": "HARBOR", "pos": Vector2i(PORT.x + 10, PORT.y - 60), "kind": "port"},
		{"name": "THE PASS", "pos": Vector2i(390, HWY_Y + 70), "kind": "pass"},
		{"name": "THE CITY", "pos": Vector2i(CITY_ZONE.x * STRIDE + ZS / 2, CITY_ZONE.y * STRIDE + ZS / 2), "kind": "city"},
		{"name": "TOWN", "pos": Vector2i(TOWN.x, TOWN.y - 85), "kind": "town"},
		{"name": "AIRSTRIP", "pos": Vector2i(1585, HWY_Y - 40), "kind": "air"},
		{"name": "PLAINS", "pos": Vector2i(1900, 420), "kind": "plain"},
		{"name": "THE CLIFFS", "pos": Vector2i(W - 150, 980), "kind": "cliff"},
		{"name": "NORTH SHORE", "pos": Vector2i(1200, 170), "kind": "shore"},
		{"name": "SOUTH SHORE", "pos": Vector2i(1200, H - 170), "kind": "shore"},
	]

## the picture for the map screen: the whole island, one pixel per `step` tiles, with the roads, rail, the city, the harbor and the town marked
func overview_image(step: int = 3) -> Image:
	var cols := {CG.WATER: Color("#123a5c"), CG.SAND: Color("#cdbd7c"), CG.ROCKS: Color("#8a8070"), CG.PARK: Color("#3f7a35"), CG.FIELD: Color("#a8a040"),
		CG.TREE: Color("#1c4a24"), CG.MOUNTAIN: Color("#6a6a78"), CG.CLIFF: Color("#a04632"), CG.ROAD: Color("#ffd24a"), CG.TRACK: Color("#ff5a5a"),
		CG.BALLAST: Color("#b0a090")}
	var iw := W / step
	var ih := H / step
	var img := Image.create(iw, ih, false, Image.FORMAT_RGB8)
	for py in ih:
		for px in iw:
			var t := terrain(px * step + step / 2, py * step + step / 2)
			var col: Color = cols.get(t, Color("#3f7a35"))
			if t == CG.MOUNTAIN and (px + py) % 3 == 0:
				col = col.lightened(0.18)
			img.set_pixel(px, py, col)
	# the highway and rail are thinner than a pixel: draw them as lines
	for x in range(_hx0, HWY_X1, step):
		var yy := pass_yc(x)
		var px := x / step
		if px < iw:
			img.set_pixel(px, yy / step, Color("#ffd24a"))
			if x <= RAIL_X1:
				img.set_pixel(px, (yy + 9) / step, Color("#ff5a5a"))
	# the city: its paved area, a grid of streets
	var o := zone_origin(CITY_ZONE.x, CITY_ZONE.y)
	var x0 := (o.x + MARGIN_ZONE) / step
	var x1 := (o.x + ZS - MARGIN_ZONE) / step
	var y0 := (o.y + MARGIN_ZONE) / step
	var y1 := (o.y + ZS - MARGIN_ZONE) / step
	for py in range(y0, y1):
		for px in range(x0, x1):
			var grid := ((px - x0) % 14 < 2) or ((py - y0) % 14 < 2)
			img.set_pixel(px, py, Color("#3a3f58") if grid else Color("#7b86b8"))
	# the harbor quays and the town
	for k in 3:
		var pyy := (PORT.y - 70 + k * 45) / step
		for q in range(-6, 1):
			img.set_pixel(clampi((int(west_x(PORT.y - 70 + k * 45)) + q * 3) / step, 0, iw - 1), pyy, Color("#e0b060"))
	var tx := TOWN.x / step
	var ty := TOWN.y / step
	for dy in range(-4, 5):
		for dx in range(-6, 7):
			img.set_pixel(tx + dx, ty + dy, Color("#d8c8a0") if (dx + dy) % 3 != 0 else Color("#8a7a5a"))
	return img

# ------------------------------------------------------------------------------------------------ whole zones
## a finished CityGen object for zone (zx, zy): the city, or wild ground with the harbor, the town or the airstrip built on it
func build_zone(zx: int, zy: int):
	var c = CG.new()
	c.rng.seed = seed_value ^ (zx * 7919 + zy * 104729)
	var z := Vector2i(zx, zy)
	if z == CITY_ZONE:
		c.grid_margin = MARGIN_ZONE
		c.rail_row = HWY_Y + 11 - zone_origin(zx, zy).y
		c.generate(seed_value, Vector2.ZERO, ZS)
		_decorate_city(c)
	else:
		fill_terrain(c, zx, zy)
		match z:
			Vector2i(0, 1): _port(c)
			Vector2i(2, 1): _town(c)
			Vector2i(3, 1): _airstrip(c)
	return c

func _put_t(c, x: int, y: int, t: int, m: int = 0) -> void:
	if x < 0 or y < 0 or x >= ZS or y >= ZS:
		return
	c.tiles[y * ZS + x] = t
	c.marks[y * ZS + x] = m

func _rect(c, x0: int, y0: int, x1: int, y1: int, t: int, only_over: Array = []) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if x < 0 or y < 0 or x >= ZS or y >= ZS:
				continue
			if not only_over.is_empty() and not (int(c.tiles[y * ZS + x]) in only_over):
				continue
			c.tiles[y * ZS + x] = t

func _clear_growth(c, x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if x < 0 or y < 0 or x >= ZS or y >= ZS:
				continue
			var t: int = c.tiles[y * ZS + x]
			if t == CG.TREE or t == CG.FIELD or t == CG.ROCKS or t == CG.SAND:
				c.tiles[y * ZS + x] = CG.PARK

## the city's edge: empty ground outside the paved area becomes the island's own terrain (so the next zone matches), and the railway ends in a freight yard
func _decorate_city(c) -> void:
	var o := zone_origin(CITY_ZONE.x, CITY_ZONE.y)
	var m: int = mini(c.grid_margin, ZS / 6)
	for y in ZS:
		for x in ZS:
			if x >= m and x < ZS - m and y >= m and y < ZS - m:
				continue
			var i := y * ZS + x
			if c.tiles[i] == CG.ROAD:
				continue
			c.tiles[i] = terrain(o.x + x, o.y + y)
			var mk := mark(o.x + x, o.y + y)
			if mk != 0:
				c.marks[i] = mk
	# the freight yard where the line ends: a loading apron south of the rails, a few containers
	var yx0 := RAIL_X1 - o.x - 36
	_rect(c, yx0, 278, RAIL_X1 - o.x, 306, CG.PLATFORM)
	for k in 3:
		_rect(c, yx0 + 4 + k * 10, 284, yx0 + 9 + k * 10, 287, CG.CRATE)
		_rect(c, yx0 + 4 + k * 10, 294, yx0 + 9 + k * 10, 297, CG.CRATE)

## the railway enters the city through a tunnel mouth, and a twin-track tunnel (each track two tiles wide, a train four wide) under the margin joins the subway loop
func rail_portal(c) -> void:
	var o := zone_origin(CITY_ZONE.x, CITY_ZONE.y)
	var ring: PackedInt32Array = c.subway["ring"]
	if ring.is_empty():
		return
	var y_out: int = HWY_Y + 13 - o.y                 # path row of the outbound (south) track; its second tile is the row below
	var y_ret: int = HWY_Y + 9 - o.y                  # ... of the return (north) track
	var xl := -1
	for cell in ring:
		if cell / ZS == y_out and (xl < 0 or cell % ZS < xl):
			xl = cell % ZS
	if xl < 0:
		return
	var px := 62                                   # transit.gd PORTAL_X
	var l1: int = c.lvl_of_z(-1) * ZS * ZS
	# the tunnel mouth: a wall across both tracks
	for y in range(y_ret - 1, y_out + 3):
		for x in [px + 1, px + 2]:
			_put_t(c, x, y, CG.WALL, 0)
	# underground: rock-cut tunnel from the portal to the ring: catwalks, the two tracks, ballast-width gap between
	for x in range(px, xl):
		for y in range(y_ret - 2, y_out + 4):
			var t: int = CG.TUNNEL
			if y == y_ret or y == y_ret + 1 or y == y_out or y == y_out + 1:
				t = CG.TRACK
			c.tiles[l1 + y * ZS + x] = t

## The harbor.  Three zones from north to south:
##   north (dy < -54)  derelict warehouses and loose crates: unaffiliated criminals
##   centre            the working port: a quay road with trucks, gantry cranes over it, container stacks, a freight siding, dock workers
##   south (dy > 54)   dormitories and sheds: the Bratva
## (dy is the row relative to PORT.y).  The harbor is the one place on the island with a lot of freight moving.
const PORT_NORTH := -54
const PORT_SOUTH := 54

static func port_band(dy: int) -> int:
	return -1 if dy < PORT_NORTH else (1 if dy > PORT_SOUTH else 0)

func _port(c) -> void:
	var o := zone_origin(0, 1)
	var sx_mid := int(west_x(PORT.y))
	# the quay follows the shore
	for gy in range(PORT.y - 100, PORT.y + 100):
		var sx := int(west_x(gy)) + 1
		for x in range(sx - 1, sx + 11):
			var lx := x - o.x
			var ly := gy - o.y
			if lx < 0 or lx >= ZS or ly < 0 or ly >= ZS:
				continue
			var t: int = c.tiles[ly * ZS + lx]
			if t == CG.WATER or t == CG.SAND or t == CG.PARK or t == CG.ROCKS or t == CG.TREE or t == CG.FIELD:
				c.tiles[ly * ZS + lx] = CG.PLATFORM
	# piers (the outer two belong to the smugglers)
	for py in [PORT.y - 70, PORT.y - 36, PORT.y + 26, PORT.y + 60]:
		var sx2 := int(west_x(py))
		_rect(c, sx2 - 26 - o.x, py - o.y, sx2 + 4 - o.x, py - o.y + 5, CG.PLATFORM, [CG.WATER, CG.SAND, CG.PLATFORM])
	_clear_growth(c, sx_mid + 8 - o.x, PORT.y - 120 - o.y, 340 - o.x, PORT.y + 110 - o.y)
	# ---- the working centre
	var rx: int = sx_mid + 6 - o.x                 # left edge (local) of the north-south quay road, 12 wide
	var y_top: int = PORT.y - 52 - o.y
	var y_bot: int = PORT.y + 52 - o.y
	for y in range(y_top, y_bot + 1):
		for k in 12:
			var m: int = CG.M_WHITE_V if (k == 0 or k == 11) else (CG.M_YELLOW_V if (k == 5 or k == 6) else 0)
			if c.tiles[y * ZS + rx + k] != CG.ROAD:
				_put_t(c, rx + k, y, CG.ROAD, m)
	c.xs = [rx]
	c.ys = [HWY_Y - 6 - o.y]
	# gantry cranes straddling the road: a leg on each side, a beam overhead drawn by the view
	c.cranes = []
	for dy in [-44, -32, -20, 20, 32, 44]:
		var gy2: int = PORT.y + dy - o.y
		_put_t(c, rx - 1, gy2, CG.TID["crane_leg"])
		_put_t(c, rx + 12, gy2, CG.TID["crane_leg"])
		c.cranes.append({"x0": rx - 1, "x1": rx + 12, "y": gy2})
	_rect(c, rx + 13, y_top, 316 - o.x, y_bot, CG.PLATFORM, [CG.PARK, CG.GROUND, CG.FIELD, CG.SAND, CG.ROCKS, CG.TREE])     # the paved yard
	# a siding east of the road and the container yard: stacks with aisles, north and south of the rails
	for x in range(rx + 14, PASS_X0 - 6 - o.x):
		for k in 8:
			var t2: int = CG.TRACK if (k == 1 or k == 2 or k == 5 or k == 6) else CG.BALLAST
			_put_t(c, x, PORT.y + 8 + k - o.y, t2, CG.M_RAIL_H if t2 == CG.TRACK else 0)
	# the tracks join at the buffer end (a loop for the trains to turn on)
	for y in range(PORT.y + 9, PORT.y + 15):
		for x in [rx + 16, rx + 17]:
			_put_t(c, x, y - o.y, CG.TRACK, CG.M_RAIL_V)
	# the Harbor Terminal: a platform along the outbound track at the buffer end of the siding
	var tx: int = rx + 16
	for x in range(tx - 2, tx + 29):
		for yy in [16, 17]:
			_put_t(c, x, PORT.y + yy - o.y, CG.PLATFORM, 0)
	var cont: int = CG.TID["container"]
	for band in [[-46, -10], [20, 50]]:
		var by: int = PORT.y + int(band[0]) - o.y
		var rows: int = (int(band[1]) - int(band[0])) / 8
		for r in rows:
			var x := rx + 18
			while x + 6 < 316 - o.x:
				if (x / 8 + r * 3) % 7 != 0:
					for yy in 3:
						for xx in 6:
							_put_t(c, x + xx, by + r * 8 + yy, cont)
				x += 9
	# dock workers: work spots along both sides of the road and in the stack aisles; two dormitories at the east end
	for k in 60:
		var wy: int = PORT.y - 50 + (k * 37) % 100 - o.y
		var wx: int = rx - 3 if k % 2 == 0 else rx + 14
		if wx >= 0 and wx < ZS and wy >= 0 and wy < ZS and c.walkable(c.tiles[wy * ZS + wx]):
			c.works.append(wy * ZS + wx)
	c._building(rx + 150, PORT.y - 28 - o.y, rx + 166, PORT.y - 14 - o.y, "house")
	c._building(rx + 150, PORT.y + 22 - o.y, rx + 166, PORT.y + 36 - o.y, "house")
	# ---- north: three derelict warehouses and loose cargo
	var wn: int = int(west_x(PORT.y - 90)) + 16 - o.x
	c._building(wn, PORT.y - 112 - o.y, mini(wn + 44, 300 - o.x), PORT.y - 84 - o.y, "core")
	c._building(wn + 56, PORT.y - 108 - o.y, mini(wn + 92, 330 - o.x), PORT.y - 70 - o.y, "core")
	c._building(wn, PORT.y - 76 - o.y, mini(wn + 30, 300 - o.x), PORT.y - 60 - o.y, "house")
	for k in 14:
		_rect(c, wn + 100 + (k * 13) % 80, PORT.y - 118 - o.y + (k * 7) % 56, wn + 101 + (k * 13) % 80, PORT.y - 117 - o.y + (k * 7) % 56, CG.CRATE, [CG.PARK, CG.GROUND])
	# ---- south: dormitories and sheds
	var ws: int = int(west_x(PORT.y + 80)) + 16 - o.x
	c._building(ws, PORT.y + 66 - o.y, ws + 16, PORT.y + 80 - o.y, "house")
	c._building(ws + 22, PORT.y + 66 - o.y, ws + 38, PORT.y + 80 - o.y, "house")
	c._building(ws + 44, PORT.y + 66 - o.y, ws + 60, PORT.y + 80 - o.y, "house")
	c._building(ws, PORT.y + 90 - o.y, ws + 34, PORT.y + 106 - o.y, "core")
	for k in 10:
		_rect(c, ws + 70 + (k * 11) % 60, PORT.y + 62 - o.y + (k * 5) % 40, ws + 71 + (k * 11) % 60, PORT.y + 63 - o.y + (k * 5) % 40, CG.CRATE, [CG.PARK, CG.GROUND])
	# the railway through the pass runs on into the harbor zone: lay it over whatever the zone put there
	for x in range(PASS_X0 - 6 - o.x, ZS):
		for gy in range(HWY_Y + 5 - o.y - 10, HWY_Y + 30 - o.y):
			var tt := _corridor(x + o.x, gy + o.y)
			if tt == CG.TRACK or tt == CG.BALLAST:
				_put_t(c, x, gy, tt, CG.M_RAIL_H if tt == CG.TRACK else 0)
	c._paint_lanes()

## the town: a crossing of the highway with one main street, four blocks of small houses, a store at the crossroads
func _town(c) -> void:
	var o := zone_origin(2, 1)
	var cx := TOWN.x - o.x - 6          # left edge of the cross street (local)
	var hy := HWY_Y - 6 - o.y           # top row of the highway (local)
	_clear_growth(c, cx - 100, hy - 80, cx + 112, hy + 92)
	var blocks := [[cx - 76, hy - 62, cx - 2, hy - 2], [cx + 14, hy - 62, cx + 88, hy - 2], [cx - 76, hy + 14, cx - 2, hy + 74], [cx + 14, hy + 14, cx + 88, hy + 74]]
	for b in blocks:
		_rect(c, b[0], b[1], b[2], b[3], CG.GROUND)
	# the cross street, ruled like every other road
	for y in range(hy - 64, hy + 78):
		for k in 12:
			var x := cx + k
			if y >= hy and y < hy + 12:
				continue
			var m := CG.M_WHITE_V if (k == 0 or k == 11) else (CG.M_YELLOW_V if (k == 5 or k == 6) else 0)
			_put_t(c, x, y, CG.ROAD, m)
	c.under = PackedByteArray()
	c.under.resize(ZS * ZS)
	c.venues = []
	c.venue_plan = preload("res://src/venues.gd").town_plan(c.rng)
	for b in blocks:
		c._suburb_block(b[0], b[1], b[2], b[3])
	# the store at the crossroads, and its yard
	c.xs = [cx]
	c.ys = [hy]

## a runway on the plains east of the town
func _airstrip(c) -> void:
	var o := zone_origin(3, 1)
	var x0 := 1480 - o.x
	var x1 := 1690 - o.x
	var y0 := HWY_Y - 8 - o.y
	_clear_growth(c, x0 - 8, y0 - 14, x1 + 8, y0 + 30)
	_rect(c, x0, y0, x1, y0 + 15, CG.GROUND)
	for x in range(x0 + 4, x1 - 3, 12):
		_rect(c, x, y0 + 7, x + 5, y0 + 8, CG.ROAD)
	_rect(c, x0 + 10, y0 + 20, x0 + 40, y0 + 26, CG.GROUND)
	c.xs = []
	c.ys = []
