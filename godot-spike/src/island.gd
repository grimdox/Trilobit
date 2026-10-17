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
const HWY_Y := 704                     # centre row of the highway.  Six lanes of six tiles (36 rows, HWY_Y-18 .. HWY_Y+17) on the plains and in the harbor,
                                       # narrowing to the old twelve rows (HWY_Y-6 .. HWY_Y+5) inside the mountain pass
const PASS_X0 := 335
const PASS_X1 := 448
const PORT := Vector2i(215, 704)
const TOWN := Vector2i(1240, 704)
const HWY_X0 := 150
const HWY_X1 := 2232                   # ... and on east to the clifftop at the coast
const HWY_N := 18                      # rows above HWY_Y that the wide highway covers, and below (HWY_S) it
const HWY_S := 17
const RAIL_BASE := 4                   # the return track's first row is this far below the highway's last row; the outbound track is four rows further
const RAIL_X1 := 510                   # the railway ends at the city's freight yard
const CITY_ZONE := Vector2i(1, 1)
const OWN_INSET := 32
const LAYOUT_VER := 2                 # bumped when the map changes shape so old saves are not read against it (1: before the city revamp)
const CZS := 704                       # the city's own map is larger than the wild zones' (every other zone is ZS x ZS)
const CITY_ORIGIN := Vector2i(448, 352)   # ... and is placed so the highway runs along its middle row
const CITY_OWN := Rect2i(480, 384, 640, 640)   # the ground the city zone owns: its whole map less 32 tiles all round
const MARGIN_ZONE := 68                # the city keeps this much empty ground at its edge (32 are the next zone's, then room to see across the border)
const BRIDGES_Y := [164, 250, 436]     # city-local top rows of the three four-lane (24 wide) bridge avenues
const AVENUE_W := 24
const AIR_Y := HWY_Y - 68             # the airstrip runs north of the highway
const BANK := 3                        # sand either side of the river

var seed_value: int = 0
var _nw := FastNoiseLite.new()
var _nn := FastNoiseLite.new()
var _ns := FastNoiseLite.new()
var _ne := FastNoiseLite.new()
var _nj := FastNoiseLite.new()
var _nm := FastNoiseLite.new()
var _nf := FastNoiseLite.new()
var _nt := FastNoiseLite.new()
var _nr := FastNoiseLite.new()
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
	_nr.frequency = 0.021
	_nr.seed = sd ^ 0x5151
	_nr.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_bay_depth = rng.randi_range(60, 80)
	_pass_phase = rng.randf_range(0.0, TAU)
	_hx0 = int(west_x(HWY_Y)) + 6
	_build_river()

# ------------------------------------------------------------------------------------------------ zones
static func zone_origin(zx: int, zy: int) -> Vector2i:
	if zx == CITY_ZONE.x and zy == CITY_ZONE.y:
		return CITY_ORIGIN
	return Vector2i(zx * STRIDE, zy * STRIDE)

## the side of a zone's square map
static func zone_size(zx: int, zy: int) -> int:
	return CZS if (zx == CITY_ZONE.x and zy == CITY_ZONE.y) else ZS

## the zone whose territory contains a global position: the city's big rectangle first, then the grid of 448-tile territories
static func zone_owner(gx: int, gy: int) -> Vector2i:
	if CITY_OWN.has_point(Vector2i(gx, gy)):
		return CITY_ZONE
	return Vector2i(clampi(int(floor(float(gx - OWN_INSET) / STRIDE)), 0, NZX - 1), clampi(int(floor(float(gy - OWN_INSET) / STRIDE)), 0, NZY - 1))

## the ground a zone owns, as a global rectangle (the grid cell it nominally owns; the city's is its own rectangle)
static func own_rect(zx: int, zy: int) -> Rect2i:
	if zx == CITY_ZONE.x and zy == CITY_ZONE.y:
		return CITY_OWN
	var x0: int = OWN_INSET + zx * STRIDE if zx > 0 else 0
	var y0: int = OWN_INSET + zy * STRIDE if zy > 0 else 0
	var x1: int = OWN_INSET + (zx + 1) * STRIDE if zx < NZX - 1 else W
	var y1: int = OWN_INSET + (zy + 1) * STRIDE if zy < NZY - 1 else H
	return Rect2i(x0, y0, x1 - x0, y1 - y0)

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

# ------------------------------------------------------------------------------------------------ the highway and the rail beside it
## 0 inside the mountain pass (the old twelve-row road), 1 on the open ground; it tapers over twelve columns at each end of the pass
func hwy_wide(x: int) -> float:
	if x <= PASS_X0 - 18:
		return 1.0
	if x < PASS_X0 - 6:
		return float(PASS_X0 - 6 - x) / 12.0
	if x < PASS_X1:
		return 0.0
	if x < PASS_X1 + 12:
		return float(x - PASS_X1) / 12.0
	return 1.0

func hwy_n(x: int) -> int:
	return 6 + int(round(float(HWY_N - 6) * hwy_wide(x)))

func hwy_s(x: int) -> int:
	return 5 + int(round(float(HWY_S - 5) * hwy_wide(x)))

## the first row of the return (north) track at column x; the outbound track is four rows below it
func rail_ret(x: int) -> int:
	return pass_yc(x) + hwy_s(x) + RAIL_BASE

func rail_out(x: int) -> int:
	return rail_ret(x) + 4

# ------------------------------------------------------------------------------------------------ the river
## It rises in the mountains north-west of the city, runs south-east out of the foothills, through the city (west of the downtown) and on to the
## south coast.  The centre line and the half-width are tabulated per row at start-up, so terrain() stays a cheap lookup.
const RIVER_Y0 := 238
const RIVER_PTS := [[238, 408.0, 3.0], [330, 478.0, 5.0], [410, 548.0, 7.0], [470, 606.0, 9.0], [540, 640.0, 13.0], [620, 660.0, 16.0], [704, 668.0, 17.0],
	[800, 674.0, 17.0], [900, 666.0, 18.0], [960, 672.0, 19.0], [1050, 692.0, 22.0], [1150, 712.0, 26.0], [1250, 722.0, 30.0], [1350, 730.0, 34.0]]
var _rv_x := PackedFloat32Array()       # per row: the centre line
var _rv_w := PackedFloat32Array()       # ... the half-width of the water measured across the row (so a diagonal reach is wider)
var _city_mask := PackedByteArray()

func _build_river() -> void:
	_rv_x.resize(H)
	_rv_w.resize(H)
	_rv_x.fill(-1000.0)
	_rv_w.fill(0.0)
	var pts: Array = RIVER_PTS
	var cx := PackedFloat32Array()
	var cw := PackedFloat32Array()
	cx.resize(H)
	cw.resize(H)
	for y in range(RIVER_Y0, H):
		var k := 0
		while k + 2 < pts.size() and float(y) > float(pts[k + 1][0]):
			k += 1
		var p0: Array = pts[maxi(k - 1, 0)]
		var p1: Array = pts[k]
		var p2: Array = pts[k + 1]
		var p3: Array = pts[mini(k + 2, pts.size() - 1)]
		var t: float = clampf((float(y) - float(p1[0])) / maxf(1.0, float(p2[0]) - float(p1[0])), 0.0, 1.0)
		# Catmull-Rom through the control points (parametrised by the row)
		cx[y] = _cr(float(p0[1]), float(p1[1]), float(p2[1]), float(p3[1]), t)
		cw[y] = _cr(float(p0[2]), float(p1[2]), float(p2[2]), float(p3[2]), t)
	for y in range(RIVER_Y0, H):
		var ramp: float = clampf(float(y - RIVER_Y0) / 160.0, 0.0, 1.0)
		var wob: float = 4.0 * ramp * _nr.get_noise_1d(y)
		_rv_x[y] = cx[y] + wob
	for y in range(RIVER_Y0, H):
		var slope: float = absf(_rv_x[mini(y + 2, H - 1)] - _rv_x[maxi(y - 2, RIVER_Y0)]) / 4.0
		var wob2: float = 1.2 * _nr.get_noise_1d(y + 4000)
		_rv_w[y] = maxf(2.0, (cw[y] + wob2) * sqrt(1.0 + slope * slope))

static func _cr(a: float, b: float, c: float, d: float, t: float) -> float:
	return 0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t + (-a + 3.0 * b - 3.0 * c + d) * t * t * t)

## 0 dry, 1 river water, 2 river bank (sand)
func river_tile(x: int, y: int) -> int:
	if y < RIVER_Y0 or y >= H:
		return 0
	var d: float = absf(float(x) - _rv_x[y])
	var hw: float = _rv_w[y]
	if d < hw:
		return 1
	if d < hw + float(BANK):
		return 2
	return 0

## the columns the river and its banks cover on a row: (west edge, east edge) inclusive, or (-1, -1) when there is none
func river_span(y: int) -> Vector2i:
	if y < RIVER_Y0 or y >= H:
		return Vector2i(-1, -1)
	var hw: float = _rv_w[y] + float(BANK)
	return Vector2i(int(ceil(_rv_x[y] - hw)) + 1, int(floor(_rv_x[y] + hw)))

static func _hash(x: int, y: int) -> int:
	return (x * 73856093 ^ y * 19349663) & 0x7fffffff

# ------------------------------------------------------------------------------------------------ the analytic map
## the road, rail and pass cut through the mountains (or -1 where there is none)
func _corridor(x: int, y: int) -> int:
	if x < _hx0 or x > HWY_X1:
		return -1
	var hy := pass_yc(x)
	var dy := y - hy
	if dy >= -hwy_n(x) and dy <= hwy_s(x):
		return CG.ROAD
	if x <= RAIL_X1:
		# a two-track line: each track two tiles wide (the return track's rows r..r+1, the outbound track's r+4..r+5), ballast between and
		# around.  Where the road steps more than a row between columns (the pass, and the taper where the road narrows) the rails fill the gap.
		var r := rail_ret(x)
		var ya := mini(rail_ret(x - 1), rail_ret(x - 2))
		var yb := maxi(rail_ret(x + 1), rail_ret(x + 2))
		var lo := mini(r, mini(ya, yb))
		var hi := maxi(r, maxi(ya, yb))
		if (y >= lo and y <= hi + 1) or (y >= lo + 4 and y <= hi + 5):
			return CG.TRACK
		if y >= lo - 1 and y <= hi + 6:
			return CG.BALLAST
	if x >= PASS_X0 - 14 and x <= PASS_X1 + 40 and dy >= -9 and dy <= 33:
		return CG.ROCKS
	return -1

func mark(x: int, y: int) -> int:
	if x < _hx0 or x > HWY_X1:
		return 0
	var hy := pass_yc(x)
	var dy := y - hy
	var n := hwy_n(x)
	var sb := hwy_s(x)
	if dy >= -n and dy <= sb:
		return highway_mark(x, dy + n, n + sb + 1)
	if x <= RAIL_X1 and _corridor(x, y) == CG.TRACK:
		return CG.M_RAIL_H
	return 0

static func highway_mark(x: int, k: int, w: int) -> int:
	return CG._wide_mark(x, k, w) if w > 12 else (CG.M_WHITE_H if (k == 0 or k == w - 1) else (CG.M_YELLOW_H if (k == 5 or k == 6) else 0))

func terrain(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= W or y >= H:
		return CG.WATER
	var cor := _corridor(x, y)
	var rv := river_tile(x, y)
	if cor >= 0:
		if cor != CG.ROAD and rv == 1:
			return CG.WATER
		return cor
	if rv != 0:
		# the highway's deck is railed where it crosses the river
		if x >= _hx0 and x <= HWY_X1:
			var dyh := y - pass_yc(x)
			if dyh == -hwy_n(x) - 1 or dyh == hwy_s(x) + 1:
				return CG.RAILING
		return CG.WATER if rv == 1 else CG.SAND
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
		{"name": "THE CITY", "pos": CITY_ORIGIN + Vector2i(CZS / 2, CZS / 2), "kind": "city"},
		{"name": "TOWN", "pos": Vector2i(TOWN.x, TOWN.y - 85), "kind": "town"},
		{"name": "AIRSTRIP", "pos": Vector2i(1585, AIR_Y - 22), "kind": "air"},
		{"name": "THE RIVER", "pos": Vector2i(int(_rv_x[1000]) + 40, 1000), "kind": "river"},
		{"name": "COAST ROAD", "pos": Vector2i(2100, HWY_Y - 60), "kind": "road"},
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
	# the rail is thinner than a pixel: draw it as a line (the highway is wide enough to show as terrain)
	for x in range(_hx0, RAIL_X1, step):
		var px := x / step
		if px < iw:
			img.set_pixel(px, rail_ret(x) / step, Color("#ff5a5a"))
	# the city: its outline, a grid of streets
	var o := zone_origin(CITY_ZONE.x, CITY_ZONE.y)
	var cm := city_mask()
	for py in range(o.y / step, (o.y + CZS) / step):
		for px in range(o.x / step, (o.x + CZS) / step):
			var lx: int = px * step - o.x + step / 2
			var ly: int = py * step - o.y + step / 2
			if cm[ly * CZS + lx] == 0 or river_tile(px * step + step / 2, py * step + step / 2) != 0:
				continue
			var t0 := terrain(px * step + step / 2, py * step + step / 2)
			if t0 == CG.ROAD:
				continue
			var grid := ((px * step) % 42 < 6) or ((py * step) % 42 < 6)
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
	c.dash_ofs = zone_origin(zx, zy).x
	if z == CITY_ZONE:
		c.grid_margin = MARGIN_ZONE
		c.rail_row = rail_ret(RAIL_X1) + 2 - zone_origin(zx, zy).y
		c.max_floors = 20
		c.plan = city_plan(c.rng)
		c.generate(seed_value, Vector2.ZERO, CZS)
		_decorate_city(c)
	else:
		fill_terrain(c, zx, zy)
		match z:
			Vector2i(0, 1): _port(c)
			Vector2i(2, 1): _town(c)
			Vector2i(3, 1): _airstrip(c)
	return c

func _put_t(c, x: int, y: int, t: int, m: int = 0) -> void:
	if x < 0 or y < 0 or x >= c.size or y >= c.size:
		return
	c.tiles[y * c.size + x] = t
	c.marks[y * c.size + x] = m

func _rect(c, x0: int, y0: int, x1: int, y1: int, t: int, only_over: Array = []) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if x < 0 or y < 0 or x >= c.size or y >= c.size:
				continue
			if not only_over.is_empty() and not (int(c.tiles[y * c.size + x]) in only_over):
				continue
			c.tiles[y * c.size + x] = t

func _clear_growth(c, x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if x < 0 or y < 0 or x >= c.size or y >= c.size:
				continue
			var t: int = c.tiles[y * c.size + x]
			if t == CG.TREE or t == CG.FIELD or t == CG.ROCKS or t == CG.SAND:
				c.tiles[y * c.size + x] = CG.PARK

## ------------------------------------------------------------------------------------------------ the city's layout
## Local coordinates (the city zone's own 512 x 512 map).  The outline is a rounded square with a ragged edge; the river runs through the
## west third, the downtown lies east of it, and everything is planned here so citygen only has to fill it in.
const DOWNTOWN := Vector2(440.0, 352.0)
const CITY_RAD := 250.0

## 1 where the city stands
func city_mask() -> PackedByteArray:
	if not _city_mask.is_empty():
		return _city_mask
	var nz := FastNoiseLite.new()
	nz.seed = seed_value ^ 0x2c2c
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.frequency = 0.05
	_city_mask.resize(CZS * CZS)
	var half: float = float(CZS) * 0.5 - float(MARGIN_ZONE)
	for y in CZS:
		for x in CZS:
			var u: float = (float(x) + 0.5 - float(CZS) * 0.5) / half
			var v: float = (float(y) + 0.5 - float(CZS) * 0.5) / half
			var ang: float = atan2(v, u)
			# the radius of the outline at this angle: 0.80 .. 1.0 of the full half-width, so the coast of the city has bays and spurs
			var big: float = clampf(nz.get_noise_2d(cos(ang) * 14.0, sin(ang) * 14.0) * 1.6, -1.0, 1.0)
			var fine: float = nz.get_noise_2d(cos(ang) * 46.0 + 300.0, sin(ang) * 46.0)
			var f: float = clampf(0.89 + 0.13 * big + 0.03 * fine, 0.70, 1.0)
			var q: float = pow(absf(u), 3.0) + pow(absf(v), 3.0)
			_city_mask[y * CZS + x] = 1 if q <= f * f * f else 0
	return _city_mask

## rows and columns of the rail where it comes up to cross the river: the return track's first row (local), the outbound track's, and the mouths
## of the two tunnels (the level-0 strip lies between xw and xe inclusive)
func rail_bridge() -> Dictionary:
	var o := zone_origin(CITY_ZONE.x, CITY_ZONE.y)
	var yr: int = rail_ret(RAIL_X1) - o.y
	var xw := CZS
	var xe := -1
	for y in range(yr - 3, yr + 9):
		var sp := river_span(o.y + y)
		if sp.x >= 0:
			xw = mini(xw, sp.x - o.x)
			xe = maxi(xe, sp.y - o.x)
	return {"y_ret": yr, "y_out": yr + 4, "xw": xw - 8, "xe": xe + 8}

## the plan the city generator builds on: outline, water, road lines (xs, ys with their widths), the bridges, ground kept free for the rail
func city_plan(rng: RandomNumberGenerator) -> Dictionary:
	var o := zone_origin(CITY_ZONE.x, CITY_ZONE.y)
	var mask := city_mask()
	var water := PackedByteArray()
	water.resize(CZS * CZS)
	var rmin := CZS
	var rmax := 0
	for y in CZS:
		for x in CZS:
			water[y * CZS + x] = river_tile(o.x + x, o.y + y)
		if y >= MARGIN_ZONE and y < CZS - MARGIN_ZONE:
			var sp := river_span(o.y + y)
			if sp.x >= 0:
				rmin = mini(rmin, sp.x - o.x)
				rmax = maxi(rmax, sp.y - o.x)
	# vertical streets about every 52 tiles; a line that would run mostly through the river is dropped (the others simply stop at the bank)
	var cand: Array = []
	_span_lines(cand, MARGIN_ZONE + 6, CZS - MARGIN_ZONE - 28, 52.0, rng)
	var xs: Array = []
	for lx in cand:
		var wet := 0
		for y in range(MARGIN_ZONE, CZS - MARGIN_ZONE):
			for k in 12:
				if water[y * CZS + int(lx) + k] != 0:
					wet += 1
					break
		if float(wet) / float(CZS - 2 * MARGIN_ZONE) < 0.30:
			xs.append(lx)
	# horizontal streets: the highway (six lanes), the three bridge avenues (four lanes) and ordinary streets in between
	var fixed: Array = []
	var trunk: int = HWY_Y - HWY_N - o.y
	fixed.append([MARGIN_ZONE + 8, 12])
	for e in BRIDGES_Y:
		fixed.append([int(e), AVENUE_W])
	fixed.append([trunk, HWY_N + HWY_S + 1])
	fixed.append([CZS - MARGIN_ZONE - 36, 12])
	fixed.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	var ys: Array = []
	var ys_w := {}
	var decks: Array = []
	for k in fixed.size():
		var e: int = fixed[k][0]
		var w: int = fixed[k][1]
		ys.append(e)
		if w != 12:
			ys_w[e] = w
		if w == AVENUE_W:
			decks.append(e)
		if k + 1 < fixed.size():
			var a_end: int = e + w
			var b_start: int = fixed[k + 1][0]
			var g: int = b_start - a_end
			var nb: int = clampi(int(round(float(g + 12) / 53.0)), 1, 9)
			while nb > 1 and (g - (nb - 1) * 12) / nb < 30:
				nb -= 1
			var block: float = float(g - (nb - 1) * 12) / float(nb)
			for i in range(1, nb):
				ys.append(a_end + int(round(float(i) * block + float(i - 1) * 12.0)) + rng.randi_range(-2, 2))
	# the rail strip: ballast and track kept clear of buildings between the two tunnel mouths
	var rb := rail_bridge()
	var res := PackedByteArray()
	res.resize(CZS * CZS)
	for y in range(int(rb["y_ret"]) - 3, int(rb["y_out"]) + 6):
		for x in range(int(rb["xw"]) - 3, int(rb["xe"]) + 4):
			if x >= 0 and x < CZS:
				res[y * CZS + x] = 1
	# ... and the railway's approach and the freight yard at its end, west of the first tunnel mouth
	for y in range(int(rb["y_ret"]) - 3, int(rb["y_ret"]) + 52):
		for x in range(0, 67):
			res[y * CZS + x] = 1
	# water is no place for a building, nor is its bank
	for y in CZS:
		for x in CZS:
			if water[y * CZS + x] != 0:
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						var yy: int = y + dy
						var xx: int = x + dx
						if yy >= 0 and yy < CZS and xx >= 0 and xx < CZS:
							res[yy * CZS + xx] = 1
	return {"mask": mask, "water": water, "reserve": res, "xs": xs, "ys": ys, "ys_w": ys_w, "decks": decks, "trunk": trunk,
		"centre": DOWNTOWN, "rad": CITY_RAD, "ring": Rect2i(366, 262, 154, 180), "river": Vector2i(rmin, rmax), "rail": rb}

## vertical lines from `first` to `last` (left edges) about `gap` apart, evenly spread with a little jitter
func _span_lines(out: Array, first: int, last: int, gap: float, rng: RandomNumberGenerator) -> void:
	if last <= first:
		out.append(first)
		return
	var n: int = maxi(1, int(round(float(last - first) / gap)))
	for i in n + 1:
		var v: int = first + int(round(float(last - first) * float(i) / float(n)))
		if i > 0 and i < n:
			v += rng.randi_range(-3, 3)
		out.append(v)

## the city's edge: ground outside the city's outline becomes the island's own terrain (so the next zone matches), the railway ends in a freight yard,
## and the river, the bridges and the rail crossing are laid over the finished city
func _decorate_city(c) -> void:
	var o := zone_origin(CITY_ZONE.x, CITY_ZONE.y)
	var mask: PackedByteArray = c.plan["mask"]
	for y in CZS:
		for x in CZS:
			var i := y * CZS + x
			if mask[i] == 1:
				if x > RAIL_X1 - o.x:
					continue
				var tc := _corridor(o.x + x, o.y + y)
				if tc != CG.TRACK and tc != CG.BALLAST:
					continue
			c.tiles[i] = terrain(o.x + x, o.y + y)
			c.marks[i] = mark(o.x + x, o.y + y)
	_bridge_rails(c, o)
	_embankment(c)
	# the freight yard where the line ends: a loading apron south of the rails, a few containers
	var yx0 := RAIL_X1 - o.x - 36
	var yy0: int = rail_out(RAIL_X1) - o.y + 12
	_rect(c, yx0, yy0, RAIL_X1 - o.x, yy0 + 28, CG.PLATFORM)
	for k in 3:
		_rect(c, yx0 + 4 + k * 10, yy0 + 6, yx0 + 9 + k * 10, yy0 + 9, CG.CRATE)
		_rect(c, yx0 + 4 + k * 10, yy0 + 16, yx0 + 9 + k * 10, yy0 + 19, CG.CRATE)

## a two-tile stone quay along the river, wherever the bank is open ground (it follows the water, so it curves where the grid does not)
func _embankment(c) -> void:
	var water: PackedByteArray = c.plan["water"]
	var n: int = c.size
	for y in range(2, n - 2):
		for x in range(2, n - 2):
			var i := y * n + x
			if water[i] != 0:
				continue
			var t: int = c.tiles[i]
			if t != CG.GROUND and t != CG.PARK:
				continue
			var near := false
			for d in [[2, 0], [-2, 0], [0, 2], [0, -2], [1, 1], [-1, -1], [1, -1], [-1, 1], [1, 0], [-1, 0], [0, 1], [0, -1]]:
				if water[(y + d[1]) * n + x + d[0]] != 0:
					near = true
					break
			if near:
				c.tiles[i] = CG.PLATFORM

## a railing along each side of a deck where the road crosses the river
func _bridge_rails(c, o: Vector2i) -> void:
	var water: PackedByteArray = c.plan["water"]
	for ly in c.ys:
		var w: int = int(c.ys_w.get(ly, c.rw))
		if w == c.rw:
			continue
		for x in CZS:
			if water[(ly + w / 2) * CZS + x] == 0:
				continue
			for yy in [ly - 1, ly + w]:
				if yy >= 0 and yy < CZS and water[yy * CZS + x] != 0:
					c.tiles[yy * CZS + x] = CG.RAILING

## the railway enters the city through a tunnel mouth, and a twin-track tunnel (each track two tiles wide, a train four wide) under the west bank joins
## the rail bridge: the line comes up into the daylight, crosses the river on its own deck beside the highway and goes down again into a second tunnel
## under the east bank, which joins the subway loop around the downtown.
func rail_portal(c) -> void:
	var o := zone_origin(CITY_ZONE.x, CITY_ZONE.y)
	var ring: PackedInt32Array = c.subway["ring"]
	if ring.is_empty():
		return
	var rb: Dictionary = c.plan["rail"]
	var y_ret: int = rb["y_ret"]                      # path row of the return (north) track; the outbound track is four rows below
	var y_out: int = rb["y_out"]
	var xw: int = rb["xw"]
	var xe: int = rb["xe"]
	var xl := -1
	for cell in ring:
		if cell / CZS == y_out and (xl < 0 or cell % CZS < xl):
			xl = cell % CZS
	if xl < 0:
		return
	var px := 62                                   # transit.gd PORTAL_X
	var l1: int = c.lvl_of_z(-1) * CZS * CZS
	# the tunnel mouths: a wall across both tracks, on the underground side of each portal
	for y in range(y_ret - 1, y_out + 3):
		for x in [px + 1, px + 2, xw - 2, xw - 1, xe + 1, xe + 2]:
			_put_t(c, x, y, CG.WALL, 0)
	# underground: rock-cut tunnel (catwalks, the two tracks, a gap between) from the first portal to the bridge and from the bridge to the ring
	for seg in [[px, xw + 1], [xe, xl]]:
		for x in range(int(seg[0]), int(seg[1])):
			for y in range(y_ret - 2, y_out + 4):
				var t: int = CG.TUNNEL
				if y == y_ret or y == y_ret + 1 or y == y_out or y == y_out + 1:
					t = CG.TRACK
				c.tiles[l1 + y * CZS + x] = t
	# in the daylight: both tracks on ballast over the land, and a railed deck over the water and its banks
	var water: PackedByteArray = c.plan["water"]
	for x in range(xw, xe + 1):
		for y in range(y_ret - 2, y_out + 4):
			var over_water: bool = water[y * CZS + x] != 0
			var t2: int = CG.BALLAST
			var mk := 0
			if y == y_ret or y == y_ret + 1 or y == y_out or y == y_out + 1:
				t2 = CG.TRACK
				mk = CG.M_RAIL_H
			elif y == y_ret - 2 or y == y_out + 3:
				t2 = CG.RAILING if over_water else CG.BALLAST
			_put_t(c, x, y, t2, mk)

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
	c.ys = [HWY_Y - HWY_N - o.y]
	c.ys_w = {HWY_Y - HWY_N - o.y: HWY_N + HWY_S + 1}
	# gantry cranes straddling the road: a leg on each side, a beam overhead drawn by the view
	c.cranes = []
	for dy in [-44, -32, -20, 20, 32, 44]:
		var gy2: int = PORT.y + dy - o.y
		_put_t(c, rx - 1, gy2, CG.TID["crane_leg"])
		_put_t(c, rx + 12, gy2, CG.TID["crane_leg"])
		c.cranes.append({"x0": rx - 1, "x1": rx + 12, "y": gy2})
	_rect(c, rx + 13, y_top, 316 - o.x, y_bot, CG.PLATFORM, [CG.PARK, CG.GROUND, CG.FIELD, CG.SAND, CG.ROCKS, CG.TREE])     # the paved yard
	# a siding east of the road and the container yard: stacks with aisles, north and south of the rails
	var rr0: int = rail_ret(PASS_X0 - 30) - 1               # the first ballast row (one above the return track)
	for x in range(rx + 14, PASS_X0 - 18 - o.x):
		for k in 8:
			var t2: int = CG.TRACK if (k == 1 or k == 2 or k == 5 or k == 6) else CG.BALLAST
			_put_t(c, x, rr0 + k - o.y, t2, CG.M_RAIL_H if t2 == CG.TRACK else 0)
	# the tracks join at the buffer end (a loop for the trains to turn on)
	for y in range(rr0 + 1, rr0 + 7):
		for x in [rx + 16, rx + 17]:
			_put_t(c, x, y - o.y, CG.TRACK, CG.M_RAIL_V)
	# the Harbor Terminal: a platform along the outbound track at the buffer end of the siding
	var tx: int = rx + 16
	for x in range(tx - 2, tx + 29):
		for yy in [rr0 + 8, rr0 + 9]:
			_put_t(c, x, yy - o.y, CG.PLATFORM, 0)
	var cont: int = CG.TID["container"]
	for band in [[-46, -22], [32, 62]]:
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
	c._building(rx + 150, PORT.y - 46 - o.y, rx + 166, PORT.y - 32 - o.y, "house")
	c._building(rx + 150, PORT.y + 36 - o.y, rx + 166, PORT.y + 50 - o.y, "house")
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
	for x in range(PASS_X0 - 18 - o.x, ZS):
		for gy in range(HWY_Y - o.y, HWY_Y + 40 - o.y):
			var tt := _corridor(x + o.x, gy + o.y)
			if tt == CG.TRACK or tt == CG.BALLAST:
				_put_t(c, x, gy, tt, CG.M_RAIL_H if tt == CG.TRACK else 0)
	c._paint_lanes()

## the town: a crossing of the highway with one main street, four blocks of small houses, a store at the crossroads
func _town(c) -> void:
	var o := zone_origin(2, 1)
	var cx := TOWN.x - o.x - 6          # left edge of the cross street (local)
	var hy := HWY_Y - HWY_N - o.y       # top row of the highway (local)
	var hw := HWY_N + HWY_S + 1         # ... and its width
	_clear_growth(c, cx - 100, hy - 80, cx + 112, hy + hw + 80)
	var blocks := [[cx - 76, hy - 62, cx - 2, hy - 2], [cx + 14, hy - 62, cx + 88, hy - 2], [cx - 76, hy + hw + 2, cx - 2, hy + hw + 62], [cx + 14, hy + hw + 2, cx + 88, hy + hw + 62]]
	for b in blocks:
		_rect(c, b[0], b[1], b[2], b[3], CG.GROUND)
	# the cross street, ruled like every other road
	for y in range(hy - 64, hy + hw + 66):
		for k in 12:
			var x := cx + k
			if y >= hy and y < hy + hw:
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
	c.ys_w = {hy: hw}

## a runway on the plains east of the town
func _airstrip(c) -> void:
	var o := zone_origin(3, 1)
	var x0 := 1480 - o.x
	var x1 := 1690 - o.x
	var y0 := AIR_Y - o.y
	_clear_growth(c, x0 - 8, y0 - 14, x1 + 8, y0 + 30)
	_rect(c, x0, y0, x1, y0 + 15, CG.GROUND)
	for x in range(x0 + 4, x1 - 3, 12):
		_rect(c, x, y0 + 7, x + 5, y0 + 8, CG.ROAD)
	_rect(c, x0 + 10, y0 + 20, x0 + 40, y0 + 26, CG.GROUND)
	c.xs = []
	c.ys = []
