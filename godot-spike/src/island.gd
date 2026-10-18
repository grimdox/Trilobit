extends RefCounted
## The island: a seeded, full-scale map in the far south-east of Russia, a little north of Japan.  Everything here is an ANALYTIC function of the seed
## (terrain(x, y) -> tile id), so any part of the island can be generated on demand and two zones always agree about their overlap.
## The outline comes from a template (data/island_sdf.bin, drawn from the design guide: a long island tapering to a point in the north, a wide southern
## bay between two capes) that every seed warps a little; the rest is laid over it:
##   the caldera   a ring of mountains round the city, open to the south bay, merged with the west range and the range that runs on south to the cape
##   west          the ferry port, and a long pass through the merged range with the highway and the railway
##   the city      zone (5, 9): a big organic city on a river, its south shore a working harbor
##   north         a road up the valley farms past the town to the north point
##   east          the airstrip, lagoons and a sprawl of heavy industry on the east peninsula, and a coast road to the east cape
## Scale: one pixel of the guide image is 4.4 tiles (see README).
const CG = preload("res://src/citygen.gd")

const W := 4400
const H := 7750
const ZS := 512
const STRIDE := 448
const NZX := 10
const NZY := 18
const TS := 11.636                     # tiles per pixel of the coast template
const TPX := 150.0                     # island coordinate of the template's first pixel (both axes)
const TW := 350
const TH := 640
const GRID := 24                       # the coarse fields (coast, mountain mass) have one value per 24 x 24 tiles and are interpolated
const GXN := 186
const GYN := 326
const HWY_Y := 4395                    # centre row of the highway.  Six lanes of six tiles (36 rows, HWY_Y-18 .. HWY_Y+17) on the plains and in the harbor,
                                       # narrowing to the old twelve rows (HWY_Y-6 .. HWY_Y+5) inside the mountain pass
const PASS_X1 := 1890                  # the pass ends where the city's map begins
const HWY_N := 18                      # rows above HWY_Y that the wide highway covers, and below (HWY_S) it
const HWY_S := 17
const RAIL_BASE := 4                   # the return track's first row is this far below the highway's last row; the outbound track is four rows further
const RAIL_X1 := 1952                  # the railway ends at the city's freight yard
const CITY_ZONE := Vector2i(5, 9)
const OWN_INSET := 32
const LAYOUT_VER := 4                  # bumped when the map changes shape so old saves are not read against it (1: before the city revamp, 2: before the big seeded city, 3: before the island remake)
const TOWN := Vector2i(2129, 2960)     # the town stands where the north road crosses the valley farms
const TOWN_ZONE := Vector2i(4, 6)
const AIR_ZONE := Vector2i(7, 10)
const AIR_X0 := 3190                   # the runway's west end
const AIR_Y := 4770
const IND_RECT := Rect2i(3105, 4770, 836, 1035)   # the heavy-industry sprawl on the east peninsula (with its lagoons)
const CZS := 1024                      # the city's own map is larger than the wild zones' (every other zone is ZS x ZS)
const CITY_ORIGIN := Vector2i(1890, 3883)   # ... and is placed so the highway runs along its middle row
const CITY_OWN := Rect2i(1922, 3915, 960, 960)   # the ground the city zone owns: its whole map less 32 tiles all round
const MARGIN_ZONE := 68                # the city keeps this much empty ground at its edge (32 are the next zone's, then room to see across the border)
const AVENUE_W := 24
const BANK := 3                        # sand either side of the river
const CITY_CX := 2402                  # the middle of the caldera
const NORTH_ROAD_X := 2310             # the north road's x where it meets the city (city-local 420)
const HARB_Y0 := 880                   # city-local row of the harbor's quay (the seed moves it a little)

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
var PORT := Vector2i(0, HWY_Y)         # the harbor's centre: set from the seed's west coast at the highway's row
var PORT_ZONE := Vector2i(1, 9)
var PASS_X0: int = 800                 # the first column of the mountain pass (just inland of the port)
var HWY_X1: int = 3000                 # the highway's last column (the east coast, past the city)
var _hx0: int = 0                      # the first highway column (just inland of the quay)
# the parts of the city's layout that the seed chooses (see _seed_layout): the river's course, the three bridge avenues, the downtown
var river_pts: Array = []
var bridges_y: Array = []              # city-local top rows of the three four-lane (24 wide) bridge avenues
var downtown := Vector2.ZERO           # city-local heart of the downtown
var city_ring := Rect2i()              # the subway loop round it
var harb_y: int = HARB_Y0              # city-local row of the harbor's quay
var _bay_dx: float = 0.0               # how far the harbor inlet's middle is off the caldera's
var _blv: Dictionary = {}              # the riverside boulevards (see boulevards())
# terrain() runs for every tile of every zone: what depends on one column alone is tabulated once (see _tabulate), the coast and the mountain mass
# are coarse fields (one value per GRID tiles, interpolated), and the long roads are one column (or row) per row (or column)
var _c_hy := PackedInt32Array()        # per column: the highway's centre row, its rows above and below it, the first row of the return rail
var _c_hn := PackedInt32Array()
var _c_hs := PackedInt32Array()
var _c_rr := PackedInt32Array()
var _tpl := PackedByteArray()          # the coast template
var _g_sd := PackedFloat32Array()      # coarse: signed distance to the coast in tiles (> 0 on land)
var _g_mt := PackedFloat32Array()      # coarse: mountain mass 0 .. 1
var _roads_v: Array = []               # north-south roads: per row the left column of the 12-wide road, or -1
var _roads_h: Array = []               # east-west roads (none yet)
var _pwx := PackedFloat64Array()       # the harbor's coast at each row within 110 of the port (with its bay)
var _lagoons: Array = []               # [cx, cy, rx, ry] water bodies of the east peninsula
var _ridges: Array = []                # the mountain ranges: [[x, y, half width], ...] each

func _init(sd: int = 1) -> void:
	seed_value = sd
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	for n in [_nw, _nn, _ns, _ne, _nj, _nm, _nf, _nt]:
		n.seed = rng.randi()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_nw.frequency = 0.011
	_nn.frequency = 0.006
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
	var lay := RandomNumberGenerator.new()           # its own stream: the layout draws do not disturb the terrain noise above
	lay.seed = sd ^ 0x7a11c0
	harb_y = HARB_Y0 + lay.randi_range(-20, 24)
	_bay_dx = lay.randf_range(-70.0, 70.0)
	_seed_shapes(lay)
	_build_fields()
	PORT = Vector2i(int(_coast_west(HWY_Y)) + 17 + _bay_depth, HWY_Y)
	PORT_ZONE = Vector2i((PORT.x - OWN_INSET) / STRIDE, (PORT.y - OWN_INSET) / STRIDE)
	_build_port_coast()
	_hx0 = int(west_x(HWY_Y)) + 6
	PASS_X0 = PORT.x + 120
	HWY_X1 = _east_end()
	_tabulate()
	_build_roads()
	_seed_layout_river(lay)
	_build_river()
	_seed_layout_city(lay)

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

func zone_name(z: Vector2i) -> String:
	match zone_kind(z):
		"city": return "the city"
		"port": return "the ferry port"
		"town": return "the town"
		"air": return "the airstrip"
		"industry": return "the industrial flats"
	return "the wilds"

# ------------------------------------------------------------------------------------------------ the shape
## a point of the design guide (its pixels) as an island coordinate: one guide pixel is 4.4 tiles
static func g2t(gx: float, gy: float) -> Vector2:
	return Vector2(gx * 4.4 - 722.7, gy * 4.4 - 664.5)

## what the seed decides about the mountains and the lagoons: every ridge point wanders a little, as does each lagoon
func _seed_shapes(r: RandomNumberGenerator) -> void:
	# [guide x, guide y, half width in tiles]: the west range from the north, joining the caldera; and the range running on south to the cape
	var north_ridge := [[492, 330, 60.0], [480, 430, 90.0], [462, 560, 130.0], [445, 700, 160.0], [432, 820, 170.0], [436, 940, 165.0], [470, 1030, 150.0], [480, 1085, 150.0]]
	var south_ridge := [[600, 1250, 120.0], [540, 1330, 140.0], [470, 1440, 140.0], [425, 1550, 125.0], [400, 1650, 105.0], [388, 1740, 80.0], [386, 1800, 40.0]]
	_ridges = []
	for rd in [north_ridge, south_ridge]:
		var pts: Array = []
		for p in rd:
			var t: Vector2 = g2t(float(p[0]), float(p[1]))
			pts.append([t.x + r.randf_range(-36.0, 36.0), t.y + r.randf_range(-24.0, 24.0), float(p[2]) * (1.0 + r.randf_range(-0.12, 0.12))])
		_ridges.append(pts)
	# the lagoons of the east peninsula: [centre x, centre y, half width, half height]
	_lagoons = []
	for lg in [[890, 1320, 123.0, 211.0], [965, 1262, 80.0, 80.0], [905, 1415, 70.0, 48.0]]:
		var c: Vector2 = g2t(float(lg[0]), float(lg[1]))
		_lagoons.append([c.x + r.randf_range(-40.0, 40.0), c.y + r.randf_range(-40.0, 40.0), float(lg[2]) * (1.0 + r.randf_range(-0.15, 0.15)), float(lg[3]) * (1.0 + r.randf_range(-0.15, 0.15))])

## the template's signed distance to the coast (tiles, > 0 on land) at an island point, bilinear
func _tpl_sd(x: float, y: float) -> float:
	var u: float = (x - TPX) / TS
	var v: float = (y - TPX) / TS
	var out := 0.0
	if u < 0.0:
		out = maxf(out, -u)
		u = 0.0
	if v < 0.0:
		out = maxf(out, -v)
		v = 0.0
	if u > float(TW - 1) - 0.01:
		out = maxf(out, u - float(TW - 1) + 0.01)
		u = float(TW - 1) - 0.01
	if v > float(TH - 1) - 0.01:
		out = maxf(out, v - float(TH - 1) + 0.01)
		v = float(TH - 1) - 0.01
	var i: int = int(u)
	var j: int = int(v)
	var fx: float = u - float(i)
	var fy: float = v - float(j)
	var k: int = j * TW + i
	var a: float = lerpf(float(_tpl[k]), float(_tpl[k + 1]), fx)
	var b: float = lerpf(float(_tpl[k + TW]), float(_tpl[k + TW + 1]), fx)
	return ((lerpf(a, b, fy) - 128.0) / 3.0 - out) * TS

## the harbor inlet that cuts into the template's coast south of the city: water south of the harbor's quay row inside the caldera's width, and
## blending back to the template's own coast over the next 360 tiles to either side
func _bay_sd(x: float, y: float) -> float:
	var dx: float = absf(x - (float(CITY_CX) + _bay_dx))
	var w: float = 1.0 - smoothstep(560.0, 800.0, dx)
	if w <= 0.0:
		return 9000.0
	var side: float = clampf((dx - 380.0) / 240.0, 0.0, 1.0)          # the inlet's shores curve away south at the sides
	var hy: float = float(CITY_ORIGIN.y + harb_y) + 24.0 * _nw.get_noise_2d(x * 0.5, 4000.0) + 330.0 * side * side
	return lerpf(9000.0, hy - y, w) if w < 1.0 else hy - y

func _build_fields() -> void:
	var f := FileAccess.open("res://data/island_sdf.bin", FileAccess.READ)
	_tpl = f.get_buffer(TW * TH)
	f.close()
	_g_sd.resize(GXN * GYN)
	_g_mt.resize(GXN * GYN)
	var cc := Vector2(float(CITY_CX), float(HWY_Y))
	# the merged massif joining the west range to the caldera's west rim, across the pass
	var mc: Vector2 = Vector2(1450.0, float(HWY_Y))
	for gy in GYN:
		for gx in GXN:
			var x: float = float(gx * GRID)
			var y: float = float(gy * GRID)
			var sd: float = _tpl_sd(x, y) + 46.0 * _nw.get_noise_2d(x, y) + 20.0 * _nn.get_noise_2d(x, y + 777.0)
			sd = minf(sd, _bay_sd(x, y))
			_g_sd[gy * GXN + gx] = sd
			var m := 0.0
			if sd > -60.0:
				m = _mountain_mass(x, y, cc, mc)
			_g_mt[gy * GXN + gx] = m

func _mountain_mass(x: float, y: float, cc: Vector2, mc: Vector2) -> float:
	var m := 0.0
	# the caldera's ring, open to the south
	var dx: float = x - cc.x
	var dy: float = y - cc.y
	var r: float = sqrt(dx * dx + dy * dy)
	if r > 440.0 and r < 700.0:
		var v: float = clampf((1.0 - absf(r - 570.0) / 100.0) * 1.6, 0.0, 1.0)
		var south: float = absf(atan2(dx, dy))                         # 0 straight south
		v *= smoothstep(0.55, 1.15, south)
		m = maxf(m, v)
	# the massif across the pass
	var ex: float = (x - mc.x) / 620.0
	var ey: float = (y - mc.y) / 400.0
	var e: float = sqrt(ex * ex + ey * ey)
	if e < 1.0:
		m = maxf(m, clampf((1.0 - e) / 0.35, 0.0, 1.0))
	# the two ranges
	for rd in _ridges:
		for k in rd.size() - 1:
			var p: Array = rd[k]
			var q: Array = rd[k + 1]
			var hwm: float = maxf(float(p[2]), float(q[2]))
			if x < minf(float(p[0]), float(q[0])) - hwm or x > maxf(float(p[0]), float(q[0])) + hwm or y < minf(float(p[1]), float(q[1])) - hwm or y > maxf(float(p[1]), float(q[1])) + hwm:
				continue
			var ax: float = float(p[0])
			var ay: float = float(p[1])
			var bx: float = float(q[0]) - ax
			var by: float = float(q[1]) - ay
			var t: float = clampf(((x - ax) * bx + (y - ay) * by) / (bx * bx + by * by), 0.0, 1.0)
			var px: float = ax + bx * t - x
			var py: float = ay + by * t - y
			var d: float = sqrt(px * px + py * py)
			var hw: float = lerpf(float(p[2]), float(q[2]), t)
			m = maxf(m, clampf((1.0 - d / hw) / 0.45, 0.0, 1.0))
	return m

## bilinear sample of a coarse field
func _samp(arr: PackedFloat32Array, x: int, y: int) -> float:
	var fx: float = float(x) / float(GRID)
	var fy: float = float(y) / float(GRID)
	var ix: int = int(fx)
	var iy: int = int(fy)
	var ax: float = fx - float(ix)
	var ay: float = fy - float(iy)
	var i: int = iy * GXN + ix
	return lerpf(lerpf(arr[i], arr[i + 1], ax), lerpf(arr[i + GXN], arr[i + GXN + 1], ax), ay)

## the signed coast distance at a tile: the coarse field with a ragged edge
func _sd_at(x: int, y: int) -> float:
	return _samp(_g_sd, x, y) + 7.0 * _nj.get_noise_2d(x, y)

## the first land column of a row, scanning in from the west (before the port's bay is cut)
func _coast_west(y: int) -> float:
	var x := 0
	while x < 3000 and _sd_at(x, y) <= 0.0:
		x += 6
	while x > 0 and _sd_at(x - 1, y) > 0.0:
		x -= 1
	return float(x)

func _coast_east(y: int, from_x: int) -> float:
	var x: int = from_x
	while x < W - 2 and _sd_at(x, y) > 0.0:
		x += 4
	return float(x)

## the port's coast: the template's west coast pushed east by a bay (deepest at the port's row, 110 rows each side), tabulated for the rows it covers
func _build_port_coast() -> void:
	_pwx.resize(221)
	for k in 221:
		var y: int = PORT.y - 110 + k
		var d: float = absf(float(y - PORT.y))
		var shift: float = float(_bay_depth) * minf(1.0, (1.0 - d / 110.0) * 2.2) if d < 110.0 else 0.0
		_pwx[k] = _coast_west(y) + shift

## the harbor's coast at a row (within 110 of the port): the first land column, bay included
func west_x(y: int) -> float:
	var k: int = y - (PORT.y - 110)
	if k >= 0 and k < 221 and not _pwx.is_empty():
		return _pwx[k]
	return _coast_west(y)

## where the highway meets the east coast, east of the city
func _east_end() -> int:
	var x: int = CITY_ORIGIN.x + CZS
	while x < W - 2 and _sd_at(x, HWY_Y) > 30.0:
		x += 2
	return maxi(x, CITY_ORIGIN.x + CZS + 24)

func _tabulate() -> void:
	var hy := PackedInt32Array()
	var hn := PackedInt32Array()
	var hs := PackedInt32Array()
	var rr := PackedInt32Array()
	for x in W:                          # (the lookups below are still empty while these are computed, so every call computes)
		var yc: int = pass_yc(x)
		var s: int = hwy_s(x)
		hy.append(yc)
		hn.append(hwy_n(x))
		hs.append(s)
		rr.append(yc + s + RAIL_BASE)
	_c_hy = hy
	_c_hn = hn
	_c_hs = hs
	_c_rr = rr

## the highway's centre row at column x (it winds only inside the mountain pass)
func pass_yc(x: int) -> int:
	if x >= 0 and x < W and not _c_hy.is_empty():
		return _c_hy[x]
	if x <= PASS_X0 - 6 or x >= PASS_X1:
		return HWY_Y
	var t := float(x - (PASS_X0 - 6)) / float(PASS_X1 - PASS_X0 + 6)
	var env := minf(minf(t * 8.0, (1.0 - t) * 6.0), 1.0)
	return HWY_Y + int(round(40.0 * env * sin(t * TAU * 3.3 + _pass_phase)))

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
	if x >= 0 and x < W and not _c_hn.is_empty():
		return _c_hn[x]
	return 6 + int(round(float(HWY_N - 6) * hwy_wide(x)))

func hwy_s(x: int) -> int:
	if x >= 0 and x < W and not _c_hs.is_empty():
		return _c_hs[x]
	return 5 + int(round(float(HWY_S - 5) * hwy_wide(x)))

## the first row of the return (north) track at column x; the outbound track is four rows below it
func rail_ret(x: int) -> int:
	if x >= 0 and x < W and not _c_rr.is_empty():
		return _c_rr[x]
	return pass_yc(x) + hwy_s(x) + RAIL_BASE

func rail_out(x: int) -> int:
	return rail_ret(x) + 4

# ------------------------------------------------------------------------------------------------ the river
## It rises in the mountains north-west of the city, runs south-east out of the foothills, through the city (west of the downtown) and on to the
## south coast.  The centre line and the half-width are tabulated per row at start-up, so terrain() stays a cheap lookup.
## Its control points are city-local [row, column, half width]: the old river's course, which the city plan was drawn round; the source is in the
## caldera's north rim and the mouth is in the harbor.
const RIVER_PTS := [[96, 96.0, 3.0], [168, 122.0, 4.0], [218, 142.0, 7.0], [278, 212.0, 9.0], [348, 258.0, 13.0], [428, 284.0, 16.0], [512, 294.0, 17.0],
	[608, 300.0, 17.0], [708, 292.0, 18.0], [768, 298.0, 19.0], [858, 316.0, 22.0], [958, 336.0, 26.0], [1058, 344.0, 30.0]]
var RIVER_Y0: int = CITY_ORIGIN.y + 96
var RIVER_Y1: int = CITY_ORIGIN.y + HARB_Y0
## the control points as this seed drew them: the whole middle of the river slides east or west, each bend wanders and the width varies, but it
## always rises in the mountains, runs through the city and reaches the harbor
func _seed_layout_river(r: RandomNumberGenerator) -> void:
	var shift: float = r.randf_range(-56.0, 64.0)
	river_pts = []
	RIVER_Y1 = CITY_ORIGIN.y + harb_y - 2
	for k in RIVER_PTS.size():
		var p: Array = RIVER_PTS[k]
		var t: float = clampf(float(int(p[0]) - 96) / 320.0, 0.0, 1.0)      # 0 at the source, 1 once the river is in the city
		var jx: float = r.randf_range(-24.0, 24.0) * t
		var jw: float = 1.0 + r.randf_range(-0.14, 0.14)
		river_pts.append([int(p[0]) + CITY_ORIGIN.y, float(p[1]) + shift * t + jx + float(CITY_ORIGIN.x), float(p[2]) * jw])
var _rv_x := PackedFloat32Array()       # per row: the centre line
var _rv_w := PackedFloat32Array()       # ... the half-width of the water measured across the row (so a diagonal reach is wider)
var _city_mask := PackedByteArray()

func _build_river() -> void:
	_rv_x.resize(H)
	_rv_w.resize(H)
	_rv_x.fill(-1000.0)
	_rv_w.fill(0.0)
	var pts: Array = river_pts
	var cx := PackedFloat32Array()
	var cw := PackedFloat32Array()
	cx.resize(H)
	cw.resize(H)
	for y in range(RIVER_Y0, RIVER_Y1 + 1):
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
	for y in range(RIVER_Y0, RIVER_Y1 + 1):
		var ramp: float = clampf(float(y - RIVER_Y0) / 160.0, 0.0, 1.0)
		var wob: float = 4.0 * ramp * _nr.get_noise_1d(y)
		_rv_x[y] = cx[y] + wob
	for y in range(RIVER_Y0, RIVER_Y1 + 1):
		var slope: float = absf(_rv_x[mini(y + 2, H - 1)] - _rv_x[maxi(y - 2, RIVER_Y0)]) / 4.0
		var wob2: float = 1.2 * _nr.get_noise_1d(y + 4000)
		_rv_w[y] = maxf(2.0, (cw[y] + wob2) * sqrt(1.0 + slope * slope))

static func _cr(a: float, b: float, c: float, d: float, t: float) -> float:
	return 0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t + (-a + 3.0 * b - 3.0 * c + d) * t * t * t)

## 0 dry, 1 river water, 2 river bank (sand)
func river_tile(x: int, y: int) -> int:
	if y < RIVER_Y0 or y > RIVER_Y1:
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
	if y < RIVER_Y0 or y > RIVER_Y1:
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
	var hy: int = _c_hy[x]
	var dy := y - hy
	if dy >= -_c_hn[x] and dy <= _c_hs[x]:
		return CG.ROAD
	if x > RAIL_X1 and (x < PASS_X0 - 14 or x > PASS_X1 + 40):
		return -1                                # open ground beyond the railway's end: nothing but the highway
	if x <= RAIL_X1:
		# a two-track line: each track two tiles wide (the return track's rows r..r+1, the outbound track's r+4..r+5), ballast between and
		# around.  Where the road steps more than a row between columns (the pass, and the taper where the road narrows) the rails fill the gap.
		var r: int = _c_rr[x]
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
	for rd in _roads_v:
		var l: int = rd[y]
		if l >= 0 and x >= l and x < l + 12:
			var k: int = x - l
			return CG.M_WHITE_V if (k == 0 or k == 11) else (CG.M_YELLOW_V if (k == 5 or k == 6) else 0)
	if x < _hx0 or x > HWY_X1:
		return 0
	var dy: int = y - _c_hy[x]
	var n: int = _c_hn[x]
	var sb: int = _c_hs[x]
	if dy >= -n and dy <= sb:
		return highway_mark(x, dy + n, n + sb + 1)
	if x <= RAIL_X1 and _corridor(x, y) == CG.TRACK:
		return CG.M_RAIL_H
	return 0

func highway_mark(x: int, k: int, w: int) -> int:
	return CG._wide_mark(x, k, w) if w > 12 else (CG.M_WHITE_H if (k == 0 or k == w - 1) else (CG.M_YELLOW_H if (k == 5 or k == 6) else 0))

# ------------------------------------------------------------------------------------------------ the long roads
## a north-south road through control points (island x, y; y ascending): the left column of a 12-wide road at every row it covers
func _road_v(pts: Array) -> PackedInt32Array:
	var arr := PackedInt32Array()
	arr.resize(H)
	arr.fill(-1)
	var xs := PackedFloat32Array()
	xs.resize(H)
	var y0: int = int(pts[0].y)
	var y1: int = int(pts[pts.size() - 1].y)
	for y in range(y0, y1 + 1):
		var k := 0
		while k + 2 < pts.size() and float(y) > pts[k + 1].y:
			k += 1
		var p0: Vector2 = pts[maxi(k - 1, 0)]
		var p1: Vector2 = pts[k]
		var p2: Vector2 = pts[k + 1]
		var p3: Vector2 = pts[mini(k + 2, pts.size() - 1)]
		var t: float = clampf((float(y) - p1.y) / maxf(1.0, p2.y - p1.y), 0.0, 1.0)
		xs[y] = _cr(p0.x, p1.x, p2.x, p3.x, t)
	for y in range(y0 + 1, y1 + 1):                 # a car can follow it: at most a column a row
		xs[y] = clampf(xs[y], xs[y - 1] - 1.0, xs[y - 1] + 1.0)
	for y in range(y1 - 1, y0 - 1, -1):
		xs[y] = clampf(xs[y], xs[y + 1] - 1.0, xs[y + 1] + 1.0)
	for y in range(y0, y1 + 1):
		arr[y] = int(round(xs[y])) - 6
	return arr

func _build_roads() -> void:
	_roads_v = []
	var org: Vector2i = CITY_ORIGIN
	# the north road: from the city's north edge up the valley, through the town, to the north point
	var np: Array = []
	for g in [[503, 255], [515, 300], [540, 400], [570, 500], [600, 600], [622, 700], [640, 780]]:
		np.append(g2t(float(g[0]), float(g[1])))
	np.append(Vector2(float(TOWN.x), float(TOWN.y) - 110.0))
	np.append(Vector2(float(TOWN.x), float(TOWN.y)))
	np.append(Vector2(float(TOWN.x), float(TOWN.y) + 110.0))
	np.append(Vector2(2160.0, 3160.0))
	np.append(Vector2(2250.0, 3420.0))
	np.append(Vector2(float(NORTH_ROAD_X), float(org.y) - 60.0))
	np.append(Vector2(float(NORTH_ROAD_X), float(org.y) + 140.0))
	_roads_v.append(_road_v(np))
	# the west coast road: from the harbor's quay road south to the west cape
	var wp: Array = [Vector2(float(PORT.x) + 7.0, float(PORT.y) + 56.0)]
	for g in [[345, 1190], [318, 1270], [302, 1370], [296, 1470], [304, 1570], [324, 1670], [352, 1750], [378, 1785]]:
		wp.append(g2t(float(g[0]), float(g[1])))
	_roads_v.append(_road_v(wp))
	# the east coast road: from the highway's end south round the bay to the east cape
	var ep: Array = [Vector2(float(HWY_X1) - 8.0, float(HWY_Y) + float(HWY_S) + 4.0)]
	for g in [[846, 1200], [840, 1290], [852, 1360], [884, 1420], [940, 1470], [990, 1530], [1010, 1620], [990, 1720], [972, 1780]]:
		ep.append(g2t(float(g[0]), float(g[1])))
	_roads_v.append(_road_v(ep))

func terrain(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= W or y >= H:
		return CG.WATER
	var cor := _corridor(x, y)
	var rv := 0                                  # the river (river_tile, inlined: this runs for every tile of the island)
	if y >= RIVER_Y0 and y <= RIVER_Y1:
		var dd: float = absf(float(x) - _rv_x[y])
		var hwr: float = _rv_w[y]
		if dd < hwr:
			rv = 1
		elif dd < hwr + float(BANK):
			rv = 2
	if cor >= 0:
		if cor != CG.ROAD and rv == 1:
			return CG.WATER
		return cor
	if rv != 0:
		# the highway's deck is railed where it crosses the river
		if x >= _hx0 and x <= HWY_X1:
			var dyh: int = y - _c_hy[x]
			if dyh == -_c_hn[x] - 1 or dyh == _c_hs[x] + 1:
				return CG.RAILING
		return CG.WATER if rv == 1 else CG.SAND
	var nj: float = _nj.get_noise_2d(x, y)
	var sd: float = _samp(_g_sd, x, y) + 7.0 * nj
	var pk: int = y - (PORT.y - 110)
	if pk >= 0 and pk <= 220:                    # the harbor's bay is cut into the coast
		var wx: float = _pwx[pk]
		if float(x) < wx:
			return CG.WATER
		if float(x) < wx + 5.0:
			return CG.SAND
		if x < PORT.x + 400:
			sd = maxf(sd, 40.0)
	if sd < 0.0:
		return CG.WATER
	if sd < 5.0:
		return CG.SAND
	if sd < 20.0:
		return CG.ROCKS if _hash(x, y) % 7 != 0 else (CG.TREE if _hash(x + 1, y) % 3 == 0 else CG.SAND)
	if sd < 34.0 and _nj.get_noise_2d(x * 2, y * 2) > -0.1:
		return CG.ROCKS
	if x > 2900 and y > 4600:                    # the east peninsula's lagoons
		for lg in _lagoons:
			var ex: float = (float(x) - lg[0]) / lg[2]
			var ey: float = (float(y) - lg[1]) / lg[3]
			var e: float = (ex * ex + ey * ey) * (1.0 + 0.3 * nj)
			if e < 1.0:
				return CG.WATER
			if e < 1.16:
				return CG.SAND
	for rd in _roads_v:
		var l: int = rd[y]
		if l >= 0 and x >= l and x < l + 12:
			return CG.ROAD
	# the mountains: the caldera's ring, the west range and the range that runs on south
	var m: float = _samp(_g_mt, x, y)
	if m > 0.12:
		m += 0.10 * _nm.get_noise_2d(x, y)
		for rd2 in _roads_v:                     # a road keeps a pass open through them
			var l2: int = rd2[y]
			if l2 >= 0:
				m *= smoothstep(10.0, 70.0, absf(float(x - l2 - 6)))
		if x >= _hx0 and x <= HWY_X1:
			var dyc: int = y - _c_hy[x]
			if dyc >= -9 and dyc <= 33 and m > 0.3:
				return CG.ROCKS
		if m > 0.62:
			return CG.MOUNTAIN
		if m > 0.45:
			return CG.MOUNTAIN if _hash(x, y) % 3 != 0 else CG.ROCKS
		if m > 0.30:
			return CG.ROCKS if _hash(x, y) % 4 != 0 else CG.TREE
		if m > 0.2 and nj > -0.2:
			return CG.ROCKS if _hash(x, y) % 4 != 0 else CG.TREE
	# the heavy-industry sprawl: bare ground, no trees
	if IND_RECT.has_point(Vector2i(x, y)) and _nf.get_noise_2d(x * 0.6, y * 0.6 + 900.0) > -0.2:
		return CG.GROUND if _nf.get_noise_2d(x, y) > -0.25 else (CG.ROCKS if _hash(x, y) % 3 == 0 else CG.GROUND)
	# the valley farms: planted fields in parcels
	var fxv: float = (float(x) - 2005.0) / 308.0
	var fyv: float = (float(y) - 2811.0) / 396.0
	if fxv * fxv + fyv * fyv < 1.0 + 0.25 * nj:
		var fx := (x / 30) * 30
		var fy := (y / 24) * 24
		if _nf.get_noise_2d(fx, fy) > 0.0 and (x % 30) > 2 and (x % 30) < 28 and (y % 24) > 2 and (y % 24) < 22:
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
			var tt: int = terrain(o.x + x, o.y + y)
			c.tiles[y * ZS + x] = tt
			if tt == CG.ROAD or tt == CG.TRACK:
				var m := mark(o.x + x, o.y + y)
				if m != 0:
					c.marks[y * ZS + x] = m

## named places for the map: {name, pos (global tile), kind}
func landmarks() -> Array:
	var mid_ridge: Array = _ridges[0][3]
	var sr: Array = _ridges[1][3]
	var l0: Array = _lagoons[0]
	return [
		{"name": "FERRY PORT", "pos": Vector2i(PORT.x - 40, PORT.y - 130), "kind": "port"},
		{"name": "WEST PASS", "pos": Vector2i((PASS_X0 + PASS_X1) / 2, HWY_Y + 110), "kind": "pass"},
		{"name": "THE CITY", "pos": Vector2i(CITY_CX, HWY_Y - 40), "kind": "city"},
		{"name": "CITY HARBOR", "pos": Vector2i(CITY_CX - 30, CITY_ORIGIN.y + harb_y + 90), "kind": "port"},
		{"name": "THE CALDERA", "pos": Vector2i(CITY_CX - 40, HWY_Y - 640), "kind": "ring"},
		{"name": "TOWN", "pos": Vector2i(TOWN.x + 70, TOWN.y - 40), "kind": "town"},
		{"name": "VALLEY FARMS", "pos": Vector2i(1930, 2560), "kind": "plain"},
		{"name": "NORTH POINT", "pos": Vector2i(1560, 420), "kind": "shore"},
		{"name": "WEST RANGE", "pos": Vector2i(int(mid_ridge[0]) - 90, int(mid_ridge[1])), "kind": "range"},
		{"name": "AIRSTRIP", "pos": Vector2i(AIR_X0 + 60, AIR_Y - 40), "kind": "air"},
		{"name": "INDUSTRIAL FLATS", "pos": Vector2i(IND_RECT.position.x + 220, IND_RECT.position.y + 520), "kind": "industry"},
		{"name": "LAGOONS", "pos": Vector2i(int(l0[0]) - 40, int(l0[1]) - int(l0[3]) - 20), "kind": "lagoon"},
		{"name": "SOUTH BAY", "pos": Vector2i(2050, 6000), "kind": "water"},
		{"name": "WEST CAPE", "pos": Vector2i(int(sr[0]) - 80, 7200), "kind": "cape"},
		{"name": "EAST CAPE", "pos": Vector2i(3600, 7150), "kind": "cape"},
		{"name": "THE RIVER", "pos": Vector2i(int(_rv_x[CITY_ORIGIN.y + 560]) + 40, CITY_ORIGIN.y + 560), "kind": "river"},
	]

## the chart for the map screen: the whole island drawn from this seed, one pixel per `step` tiles: the coast and the ranges, the caldera's city shaded by
## district, the river, the bridges, the subway ring, the long roads and the rail
func overview_image(step: int = 8) -> Image:
	var cols := {CG.WATER: Color("#0b2540"), CG.SAND: Color("#cdbd7c"), CG.ROCKS: Color("#8a8070"), CG.PARK: Color("#3f7a35"), CG.FIELD: Color("#a8a040"),
		CG.TREE: Color("#1c4a24"), CG.MOUNTAIN: Color("#6a6a78"), CG.CLIFF: Color("#a04632"), CG.ROAD: Color("#ffd24a"), CG.TRACK: Color("#ff5a5a"),
		CG.BALLAST: Color("#b0a090"), CG.GROUND: Color("#6b6a5a"), CG.RAILING: Color("#ffd24a")}
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
	# the city: its outline shaded by district (towers at the heart, mid-rise, suburbs, exurbs), the street grid over it
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
			var dd: float = Vector2(lx, ly).distance_to(downtown) / CITY_RAD
			var base := Color("#e8f0ff") if dd < 0.34 else (Color("#9aa6d8") if dd < 0.72 else (Color("#6f7aa8") if dd < 1.0 else Color("#58627f")))
			var grid := ((px * step) % 56 < step) or ((py * step) % 56 < step)
			img.set_pixel(px, py, base.darkened(0.4) if grid else base)
	# the harbor's quay along the city's south shore
	for x in range(o.x + 140, o.x + CZS - 140, step):
		var qx := x / step
		for dy in range(-3, 1):
			var qy: int = clampi((o.y + harb_y - 14) / step + dy, 0, ih - 1)
			if img.get_pixel(qx, qy) != cols[CG.WATER]:
				img.set_pixel(qx, qy, Color("#e0b060"))
	# the subway loop, the bridges, the riverside boulevards
	var rr := Rect2i(city_ring.position + Vector2i(o), city_ring.size)
	for x in range(rr.position.x, rr.end.x, step):
		for yy in [rr.position.y, rr.end.y]:
			img.set_pixel(clampi(x / step, 0, iw - 1), clampi(yy / step, 0, ih - 1), Color("#40e0d0"))
	for y in range(rr.position.y, rr.end.y, step):
		for xx in [rr.position.x, rr.end.x]:
			img.set_pixel(clampi(xx / step, 0, iw - 1), clampi(y / step, 0, ih - 1), Color("#40e0d0"))
	for by in bridges_y:
		var gy: int = int(by) + o.y + 12
		var sp: Vector2i = river_span(gy)
		if sp.x >= 0:
			for x in range(sp.x - 8, sp.y + 9, 2):
				for k in range(-1, 2):
					img.set_pixel(clampi(x / step, 0, iw - 1), clampi(gy / step + k, 0, ih - 1), Color("#ffd24a"))
	var bl := boulevards()
	for side in ["w", "e"]:
		var arr: PackedInt32Array = bl[side]
		for y in range(0, arr.size(), step):
			if arr[y] >= 0:
				img.set_pixel(clampi((arr[y] + BLV_W / 2 + o.x) / step, 0, iw - 1), clampi((y + o.y) / step, 0, ih - 1), Color("#ffe9a0"))
	# the long roads and the rail, thinner than a pixel at this scale: drawn as lines
	for rd in _roads_v:
		for y in range(0, H, step):
			if rd[y] >= 0:
				img.set_pixel(clampi((rd[y] + 6) / step, 0, iw - 1), y / step, Color("#ffd24a"))
	for x in range(_hx0, RAIL_X1, step):
		img.set_pixel(clampi(x / step, 0, iw - 1), clampi(rail_ret(x) / step, 0, ih - 1), Color("#ff5a5a"))
	for x in range(_hx0, HWY_X1, step):
		img.set_pixel(clampi(x / step, 0, iw - 1), clampi(pass_yc(x) / step, 0, ih - 1), Color("#ffd24a"))
	# the ferry port's quay, the town and the airstrip
	for k in 3:
		var pyy := (PORT.y - 70 + k * 45) / step
		for q in range(-6, 1):
			img.set_pixel(clampi((int(west_x(PORT.y - 70 + k * 45)) + q * 3) / step, 0, iw - 1), pyy, Color("#e0b060"))
	for dy in range(-4, 5):
		for dx in range(-6, 7):
			img.set_pixel(clampi(TOWN.x / step + dx, 0, iw - 1), clampi(TOWN.y / step + dy, 0, ih - 1), Color("#d8c8a0") if (dx + dy) % 3 != 0 else Color("#8a7a5a"))
	for x in range(AIR_X0, AIR_X0 + 210, step):
		img.set_pixel(clampi(x / step, 0, iw - 1), clampi(AIR_Y / step, 0, ih - 1), Color("#ffffff"))
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
		_south_harbor(c)
	else:
		fill_terrain(c, zx, zy)
		match zone_kind(z):
			"port": _port(c)
			"town": _town(c)
			"air": _airstrip(c)
			"industry": _industry(c, zx, zy)
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
const CITY_RAD := 360.0                # the district tests (towers, mid-rise, suburbs, exurbs) are fractions of this distance from the downtown
const BLV_W := 12                      # a riverside boulevard is a two-lane street ...
const BLV_GAP := 4                     # ... this far back from the bank (room for the quay and a promenade)
const RING_W := 200
const RING_H := 230

## what the seed decides about the city: which three rows the bridge avenues take, where the downtown stands and the subway loop round it
func _seed_layout_city(r: RandomNumberGenerator) -> void:
	var trunk: int = HWY_Y - HWY_N - CITY_ORIGIN.y
	var hw: int = HWY_N + HWY_S + 1
	# the rows where the river runs inside the city's outline (a bridge needs water to cross): from where it enters to where it leaves
	var mask := city_mask()
	var first := -1
	var last := -1
	for y in range(MARGIN_ZONE, CZS - MARGIN_ZONE):
		var sp := river_span(CITY_ORIGIN.y + y)
		if sp.x < 0:
			continue
		var cx: int = (sp.x + sp.y) / 2 - CITY_ORIGIN.x
		if cx - 30 >= 0 and cx + 30 < CZS and mask[y * CZS + cx - 30] == 1 and mask[y * CZS + cx + 30] == 1:
			if first < 0:
				first = y
			last = y
	first = maxi(first, MARGIN_ZONE + 20) if first >= 0 else trunk - 250
	last = mini(last, harb_y - 110) if last >= 0 else trunk + hw + 250
	var n_lo: int = first + 10                 # avenues north of the highway lie between the river's entry and the highway ...
	var n_hi: int = trunk - 90
	var s_lo: int = trunk + hw + 90            # ... and south of it between the highway and the river's exit
	var s_hi: int = last - 34
	if n_hi - n_lo < 120:
		n_lo = n_hi - 120
	if s_hi - s_lo < 120:
		s_hi = s_lo + 120
	if r.randi() % 2 == 0:                  # two avenues north of the highway and one south ...
		var b2: int = n_hi - r.randi_range(0, 24)
		var b1: int = n_lo + r.randi_range(0, maxi(0, (b2 - 100) - n_lo))
		var b3: int = s_lo + r.randi_range(0, maxi(0, (s_hi - s_lo) * 6 / 10))
		bridges_y = [b1, b2, b3]
	else:                                    # ... or one north and two south
		var b1: int = n_lo + r.randi_range(0, maxi(0, (n_hi - n_lo) * 7 / 10))
		var b2: int = s_lo + r.randi_range(0, 30)
		var b3: int = b2 + 100 + r.randi_range(0, maxi(0, s_hi - (b2 + 100)))
		bridges_y = [b1, b2, b3]
	var yc: int = 520 + r.randi_range(-52, 72)
	var rx_e := 0.0
	for y in range(yc - RING_H / 2 - 20, yc + RING_H / 2 + 21):
		var sp := river_span(CITY_ORIGIN.y + y)
		if sp.x >= 0:
			rx_e = maxf(rx_e, float(sp.y - CITY_ORIGIN.x))
	var xc: float = rx_e + 52.0 + float(RING_W) * 0.5 + r.randf_range(8.0, 120.0)
	downtown = Vector2(xc, float(yc))
	city_ring = Rect2i(int(xc) - RING_W / 2, yc - RING_H / 2, RING_W, RING_H)

## the riverside boulevards: a street 12 wide on each bank that follows the water (a smoothed copy of the bank, so it curves where the grid does not).
## {"w": west bank, "e": east bank}, each the left column of the band at every city-local row (-1 where there is none).  They stop at the outline of
## the city, at the highway and at the rail bridge.
func boulevards() -> Dictionary:
	if not _blv.is_empty():
		return _blv
	var o := CITY_ORIGIN
	var mask := city_mask()
	var rb := rail_bridge()
	var skip_lo: int = HWY_Y - HWY_N - o.y - 2
	var skip_hi: int = int(rb["y_out"]) + 8
	for side in 2:
		var raw := PackedFloat32Array()
		raw.resize(CZS)
		raw.fill(-1.0)
		for y in range(MARGIN_ZONE, CZS - MARGIN_ZONE):
			var sp := river_span(o.y + y)
			if sp.x >= 0:
				raw[y] = float(sp.x - o.x - BLV_GAP - BLV_W) if side == 0 else float(sp.y - o.x + 1 + BLV_GAP)
		var out := PackedInt32Array()
		out.resize(CZS)
		out.fill(-1)
		var prev := -1
		for y in range(MARGIN_ZONE, CZS - MARGIN_ZONE):
			if raw[y] < 0.0:
				prev = -1
				continue
			var acc := 0.0
			var n := 0
			for d in range(-8, 9):
				var yy: int = y + d
				if yy >= 0 and yy < CZS and raw[yy] >= 0.0:
					acc += raw[yy]
					n += 1
			var v: int = int(round(acc / float(n)))
			if prev >= 0:
				v = clampi(v, prev - 1, prev + 1)       # the band moves at most a column a row: a car can follow it
			prev = v
			if y >= skip_lo and y <= skip_hi:
				continue
			if v < 0 or v + BLV_W >= CZS or mask[y * CZS + v] == 0 or mask[y * CZS + v + BLV_W - 1] == 0:
				continue
			out[y] = v
		# a stub of fewer than 40 rows is not a boulevard
		var y2 := 0
		while y2 < CZS:
			if out[y2] < 0:
				y2 += 1
				continue
			var y3 := y2
			while y3 < CZS and out[y3] >= 0:
				y3 += 1
			if y3 - y2 < 40:
				for yy in range(y2, y3):
					out[yy] = -1
			y2 = y3
		_blv["w" if side == 0 else "e"] = out
	return _blv

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
	# the radius of the outline at each angle: 0.70 .. 1.0 of the full half-width, so the coast of the city has bays and spurs; tabulated once
	var nang := 2048
	var fr := PackedFloat32Array()
	fr.resize(nang)
	for k in nang:
		var ang: float = (float(k) + 0.5) / float(nang) * TAU - PI
		var big: float = clampf(nz.get_noise_2d(cos(ang) * 14.0, sin(ang) * 14.0) * 1.6, -1.0, 1.0)
		var fine: float = nz.get_noise_2d(cos(ang) * 46.0 + 300.0, sin(ang) * 46.0)
		var f: float = clampf(0.89 + 0.13 * big + 0.03 * fine, 0.70, 1.0)
		fr[k] = f * f * f
	for y in CZS:
		var v: float = (float(y) + 0.5 - float(CZS) * 0.5) / half
		var v3: float = pow(absf(v), 3.0)
		for x in CZS:
			var u: float = (float(x) + 0.5 - float(CZS) * 0.5) / half
			var q: float = pow(absf(u), 3.0) + v3
			if q > 1.0:
				continue
			var k2: int = clampi(int((atan2(v, u) + PI) / TAU * float(nang)), 0, nang - 1)
			_city_mask[y * CZS + x] = 1 if q <= fr[k2] else 0
	for y in range(harb_y - 28, CZS):                  # the quay is the city's south edge
		for x in CZS:
			_city_mask[y * CZS + x] = 0
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
	_span_lines(cand, MARGIN_ZONE + 6, CZS - MARGIN_ZONE - 28, 54.0, rng)
	var blv := boulevards()
	var xs: Array = []
	for lx in cand:
		var wet := 0
		var beside := 0                 # rows where a riverside boulevard runs on top of the line
		for y in range(MARGIN_ZONE, CZS - MARGIN_ZONE):
			for k in 12:
				if water[y * CZS + int(lx) + k] != 0:
					wet += 1
					break
			for key in ["w", "e"]:
				var bx: int = (blv[key] as PackedInt32Array)[y]
				if bx >= 0 and bx < int(lx) + 15 and bx + BLV_W > int(lx) - 3:
					beside += 1
		if float(wet) / float(CZS - 2 * MARGIN_ZONE) < 0.30 and beside < 120:
			xs.append(lx)
	# the north road comes down into the city on its own street: the grid gives way to it
	var nx: int = NORTH_ROAD_X - 6 - CITY_ORIGIN.x
	xs = xs.filter(func(lx): return absi(int(lx) - nx) >= 34)
	xs.append(nx)
	xs.sort()
	# horizontal streets: the highway (six lanes), the three bridge avenues (four lanes) and ordinary streets in between
	var fixed: Array = []
	var trunk: int = HWY_Y - HWY_N - o.y
	fixed.append([MARGIN_ZONE + 8, 12])
	for e in bridges_y:
		fixed.append([int(e), AVENUE_W])
	fixed.append([trunk, HWY_N + HWY_S + 1])
	fixed.append([harb_y - 78, 12])
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
			var nb: int = clampi(int(round(float(g + 12) / 54.0)), 1, 12)
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
	# the dockland along the south shore is kept for the harbor: containers, sheds and cranes, not blocks (see _south_harbor)
	for y in range(harb_y - 132, mini(harb_y, CZS)):
		for x in CZS:
			res[y * CZS + x] = 1
	# the riverside boulevards are streets: nothing is built on them
	for key in ["w", "e"]:
		var bw: PackedInt32Array = blv[key]
		for y in CZS:
			if bw[y] >= 0:
				for x in range(maxi(bw[y] - 2, 0), mini(bw[y] + BLV_W + 2, CZS)):
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
		"centre": downtown, "rad": CITY_RAD, "ring": city_ring, "river": Vector2i(rmin, rmax), "rail": rb, "blv_w": blv["w"], "blv_e": blv["e"]}

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
	var o := zone_origin(CITY_ZONE.x, CITY_ZONE.y)
	var offs := [[2, 0], [-2, 0], [0, 2], [0, -2], [1, 1], [-1, -1], [1, -1], [-1, 1], [1, 0], [-1, 0], [0, 1], [0, -1]]
	# every open tile within two of the water becomes quay: walk the water (only the rows the river crosses) and mark its neighbours
	for y in range(2, n - 2):
		var sp := river_span(o.y + y)
		if sp.x < 0:
			continue
		for x in range(maxi(sp.x - o.x - 2, 2), mini(sp.y - o.x + 3, n - 2)):
			var i := y * n + x
			if water[i] == 0:
				continue
			for d in offs:
				var j: int = i + d[1] * n + d[0]
				if water[j] != 0:
					continue
				var t: int = c.tiles[j]
				if t == CG.GROUND or t == CG.PARK:
					c.tiles[j] = CG.PLATFORM

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
	# the West Bank station: platforms along both trains in the tunnel under the west bank, a stair to the street from each
	rb["xst"] = _west_station(c, y_ret, y_out, px, xw)
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

## The West Bank station in the tunnel between the harbor portal and the rail bridge: a platform (two tiles deep, 30 long) beside each train, flush with the
## car walls, and a stair from each platform up to the street (the north one comes up on the pavement just south of the highway, the south one through a
## short passage under the block).  Returns the local column of the middle of the platforms, or -1 when no street tile suits.
func _west_station(c, y_ret: int, y_out: int, px: int, xw: int) -> int:
	var l1: int = c.lvl_of_z(-1) * CZS * CZS
	var xc0: int = (px + xw) / 2
	for off in [0, 10, -10, 20, -20, 30, -30, 40, -40]:
		var xc: int = xc0 + off
		if xc - 17 <= px + 4 or xc + 17 >= xw - 4:
			continue
		var xn := -1                                     # a street tile above the north platform's outer row
		for dx in range(-9, 10):
			var tn: int = c.tiles[(y_ret - 3) * CZS + xc + dx]
			if tn == CG.GROUND or tn == CG.PARK:
				xn = xc + dx
				break
		if xn < 0:
			continue
		var xs2 := -1                                    # ... and one south of the south platform, up to 40 tiles away
		var ys2 := -1
		for dist in range(1, 41):
			for dx in range(-9, 10):
				var ts: int = c.tiles[(y_out + 4 + dist) * CZS + xc + dx]
				if ts == CG.GROUND or ts == CG.PARK:
					xs2 = xc + dx
					ys2 = y_out + 4 + dist
					break
			if xs2 >= 0:
				break
		if xs2 < 0:
			continue
		for x in range(xc - 15, xc + 15):
			for yy in [y_ret - 3, y_ret - 2, y_out + 3, y_out + 4]:
				var q: int = l1 + yy * CZS + x
				if c.tiles[q] == CG.EARTH or c.tiles[q] == CG.TUNNEL:
					c.tiles[q] = CG.PLATFORM
		# north stair: the surface tile and the platform's outer row at the same place
		_stair(c, l1, xn, y_ret - 3)
		# south stair: a passage from the south platform's outer row to under the stair
		for yy in range(y_out + 5, ys2):
			var q2: int = l1 + yy * CZS + xs2
			if c.tiles[q2] == CG.EARTH:
				c.tiles[q2] = CG.TUNNEL
		_stair(c, l1, xs2, ys2)
		return xc
	return -1

func _stair(c, l1: int, x: int, y: int) -> void:
	var up: int = y * CZS + x
	var down: int = l1 + up
	c.tiles[up] = CG.STAIRS
	c.tiles[down] = CG.STAIRS
	for pair in [[up, down], [down, up]]:
		if not c.links.has(pair[0]):
			c.links[pair[0]] = []
		c.links[pair[0]].append(pair[1])
		c.haslink[pair[0]] = 1

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
	var o := zone_origin(PORT_ZONE.x, PORT_ZONE.y)
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
	_clear_growth(c, sx_mid + 8 - o.x, PORT.y - 120 - o.y, (PORT.x + 125) - o.x, PORT.y + 110 - o.y)
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
	_rect(c, rx + 13, y_top, (PORT.x + 101) - o.x, y_bot, CG.PLATFORM, [CG.PARK, CG.GROUND, CG.FIELD, CG.SAND, CG.ROCKS, CG.TREE])     # the paved yard
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
			while x + 6 < (PORT.x + 101) - o.x:
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
	c._building(wn, PORT.y - 112 - o.y, mini(wn + 44, (PORT.x + 85) - o.x), PORT.y - 84 - o.y, "core")
	c._building(wn + 56, PORT.y - 108 - o.y, mini(wn + 92, (PORT.x + 115) - o.x), PORT.y - 70 - o.y, "core")
	c._building(wn, PORT.y - 76 - o.y, mini(wn + 30, (PORT.x + 85) - o.x), PORT.y - 60 - o.y, "house")
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

## the town: the north road crosses one main street; four blocks of small houses, a store at the crossroads
func _town(c) -> void:
	var o := zone_origin(TOWN_ZONE.x, TOWN_ZONE.y)
	var rd: PackedInt32Array = _roads_v[0]
	var rx: int = rd[TOWN.y] - o.x                   # left edge (local) of the north road, 12 wide, straight through the town
	var cs: int = TOWN.y - o.y - 6                   # top row of the cross street
	_clear_growth(c, rx - 110, cs - 90, rx + 122, cs + 100)
	var blocks := [[rx - 76, cs - 62, rx - 2, cs - 2], [rx + 14, cs - 62, rx + 88, cs - 2], [rx - 76, cs + 14, rx - 2, cs + 74], [rx + 14, cs + 14, rx + 88, cs + 74]]
	for b in blocks:
		_rect(c, b[0], b[1], b[2], b[3], CG.GROUND)
	# the cross street, ruled like every other road
	for x in range(rx - 90, rx + 104):
		for k in 12:
			if x >= rx and x < rx + 12:
				continue
			var m := CG.M_WHITE_H if (k == 0 or k == 11) else (CG.M_YELLOW_H if (k == 5 or k == 6) else 0)
			_put_t(c, x, cs + k, CG.ROAD, m)
	c.under = PackedByteArray()
	c.under.resize(ZS * ZS)
	c.venues = []
	c.venue_plan = preload("res://src/venues.gd").town_plan(c.rng)
	for b in blocks:
		c._suburb_block(b[0], b[1], b[2], b[3])
	c.xs = [rx]
	c.ys = [cs]
	c.ys_w = {}

## a runway on the plains east of the town
func _airstrip(c) -> void:
	var o := zone_origin(AIR_ZONE.x, AIR_ZONE.y)
	var x0 := AIR_X0 - o.x
	var x1 := AIR_X0 + 210 - o.x
	var y0 := AIR_Y - o.y
	_clear_growth(c, x0 - 8, y0 - 14, x1 + 8, y0 + 30)
	_rect(c, x0, y0, x1, y0 + 15, CG.GROUND)
	for x in range(x0 + 4, x1 - 3, 12):
		_rect(c, x, y0 + 7, x + 5, y0 + 8, CG.ROAD)
	_rect(c, x0 + 10, y0 + 20, x0 + 40, y0 + 26, CG.GROUND)
	c.xs = []
	c.ys = []

## The city's south shore is its harbor: the blocks give way to a dockland of container yards, sheds and a paved apron to the quay, with gantry cranes
## on piers that run out into the bay.  (The west port is the old working harbor; this is the big one.)  Local city coordinates.
func _south_harbor(c) -> void:
	var n: int = c.size
	var mask: PackedByteArray = c.plan["mask"]
	var cont: int = CG.TID["container"]
	var open_t := [CG.GROUND, CG.PARK, CG.SAND, CG.ROCKS, CG.TREE, CG.FIELD, CG.PLATFORM]
	var coast := PackedInt32Array()
	coast.resize(n)
	coast.fill(-1)
	for x in n:
		for y in range(harb_y - 60, n):
			if c.tiles[y * n + x] == CG.WATER:
				coast[x] = y
				break
	# the apron: paving from the last blocks to the water
	for x in n:
		var yc: int = coast[x]
		if yc < 0:
			continue
		for y in range(harb_y - 30, yc):
			if int(c.tiles[y * n + x]) in open_t:
				c.tiles[y * n + x] = CG.PLATFORM
	# container stacks in rows 3 tall with an aisle between, 6 long with a gap, wherever there is room away from the streets
	var y_lo: int = harb_y - 130
	var stacks := 0
	for y in range(y_lo, harb_y + 30, 5):
		for x in range(6, n - 16, 9):
			var yc2: int = coast[x] if coast[x] > 0 else n
			if y + 4 > yc2 - 10:
				continue
			if mask[mini(y, n - 1) * n + x] == 0 and y < harb_y - 30:
				continue
			var ok := true
			for yy in range(y - 1, y + 4):
				for xx in range(x - 1, x + 7):
					if xx < 0 or xx >= n or yy < 0 or yy >= n:
						ok = false
						break
					var t: int = c.tiles[yy * n + xx]
					if not (t == CG.GROUND or t == CG.PLATFORM or t == CG.PARK):
						ok = false
						break
				if not ok:
					break
			if not ok or c.rng.randi() % 4 == 0:
				continue
			for yy in 3:
				for xx in 6:
					c.tiles[(y + yy) * n + x + xx] = cont
			stacks += 1
	# sheds for the dock workers on the yard's north edge
	var made := 0
	for _t in 80:
		if made >= 4:
			break
		var bx: int = c.rng.randi_range(40, n - 80)
		var by: int = y_lo - 6 - c.rng.randi_range(0, 10)
		var okb := true
		for yy in range(by - 1, by + 16):
			for xx in range(bx - 1, bx + 18):
				if yy < 0 or yy >= n or xx < 0 or xx >= n or mask[yy * n + xx] == 0 or c.tiles[yy * n + xx] != CG.GROUND:
					okb = false
					break
			if not okb:
				break
		if okb:
			c._building(bx, by, bx + 16, by + 14, "house")
			made += 1
	# the quay's edge, the piers and the cranes
	var xmin := n
	var xmax := 0
	for x in n:
		if coast[x] > 0 and coast[x] < n - 40 and mask[(harb_y - 60) * n + x] == 1:
			xmin = mini(xmin, x)
			xmax = maxi(xmax, x)
	c.cranes = []
	var npier := 6
	for k in npier:
		var px: int = xmin + 40 + (xmax - xmin - 90) * k / (npier - 1)
		var yc3: int = coast[clampi(px, 0, n - 1)]
		if yc3 < 0:
			continue
		for yy in range(yc3, mini(yc3 + 46, n)):
			for xx in range(px, px + 8):
				if c.tiles[yy * n + xx] == CG.WATER:
					c.tiles[yy * n + xx] = CG.PLATFORM
		_put_t(c, px - 1, yc3 - 8, CG.TID["crane_leg"])
		_put_t(c, px + 8, yc3 - 8, CG.TID["crane_leg"])
		c.cranes.append({"x0": px - 1, "x1": px + 8, "y": yc3 - 8})
	for x in range(xmin, xmax, 7):
		var yc4: int = coast[x]
		if yc4 > 1 and c.tiles[(yc4 - 1) * n + x] == CG.PLATFORM:
			c.tiles[(yc4 - 1) * n + x] = CG.TID["bollard"]
	# work spots for the dockers
	var wk := 0
	for _t in 400:
		if wk >= 60:
			break
		var wx: int = c.rng.randi_range(8, n - 8)
		var wy: int = c.rng.randi_range(y_lo, harb_y + 20)
		var cell: int = wy * n + wx
		if wy < n and c.tiles[cell] == CG.PLATFORM or c.tiles[cell] == CG.GROUND:
			c.works.append(cell)
			wk += 1

## zone kind by position: "city", "port" (the ferry port in the west), "town", "air", "industry" (the east peninsula's sprawl) or "wild"
func zone_kind(z: Vector2i) -> String:
	if z == CITY_ZONE:
		return "city"
	if z == PORT_ZONE:
		return "port"
	if z == TOWN_ZONE:
		return "town"
	if z == AIR_ZONE:
		return "air"
	if IND_RECT.grow(60).has_point(own_rect(z.x, z.y).get_center()):
		return "industry"
	return "wild"

## The industrial flats on the east peninsula: a lagoon shore with a sprawl of heavy industry on it, nothing planned and nothing tidy.  Service roads on a
## loose grid, and between them whatever the seed felt like: container yards, tank and silo pads, shed rows, pipe racks, scrap and slag, drainage pools.
func _industry(c, zx: int, zy: int) -> void:
	var o := zone_origin(zx, zy)
	var rng: RandomNumberGenerator = c.rng
	var xs: Array = []
	var ys: Array = []
	var x := 24 + rng.randi() % 50
	while x < ZS - 40:
		xs.append(x)
		x += 84 + rng.randi() % 70
	var y := 24 + rng.randi() % 50
	while y < ZS - 40:
		ys.append(y)
		y += 84 + rng.randi() % 70
	var land := func(t: int) -> bool:
		return t != CG.WATER and t != CG.SAND and t != CG.MOUNTAIN and t != CG.CLIFF and t != CG.ROAD and t != CG.TRACK
	for lx in xs:
		for yy in ZS:
			for k in 12:
				if int(c.tiles[yy * ZS + lx + k]) == CG.WATER or int(c.tiles[yy * ZS + lx + k]) == CG.SAND:
					continue
				if (yy % 53) < 42 or rng.randf() < 0.3:        # the odd gap: a road that peters out
					_put_t(c, lx + k, yy, CG.ROAD, CG.M_WHITE_V if (k == 0 or k == 11) else (CG.M_YELLOW_V if (k == 5 or k == 6) else 0))
	for ly in ys:
		for xx in ZS:
			for k in 12:
				var t0: int = c.tiles[(ly + k) * ZS + xx]
				if t0 == CG.WATER or t0 == CG.SAND:
					continue
				if (xx % 61) < 48 or rng.randf() < 0.3:
					_put_t(c, xx, ly + k, CG.ROAD, CG.M_WHITE_H if (k == 0 or k == 11) else (CG.M_YELLOW_H if (k == 5 or k == 6) else 0))
	var cont: int = CG.TID["container"]
	var homes_made := 0
	for i in xs.size() - 1:
		for j in ys.size() - 1:
			var x0: int = xs[i] + 14
			var x1: int = xs[i + 1] - 2
			var y0: int = ys[j] + 14
			var y1: int = ys[j + 1] - 2
			if x1 - x0 < 30 or y1 - y0 < 30:
				continue
			var wet := 0
			var tot := 0
			for yy in range(y0, y1, 4):
				for xx in range(x0, x1, 4):
					tot += 1
					var tt: int = c.tiles[yy * ZS + xx]
					if tt == CG.WATER or tt == CG.SAND or tt == CG.MOUNTAIN or tt == CG.CLIFF:
						wet += 1
			if wet * 3 > tot:
				continue
			var kind: int = rng.randi() % 8
			match kind:
				0, 7:                                       # a container yard, stacks askew
					var yy2 := y0
					while yy2 + 4 < y1:
						var xx2 := x0 + rng.randi() % 5
						while xx2 + 7 < x1:
							if rng.randi() % 3 != 0:
								for a in 3:
									for b in 6:
										if land.call(c.tiles[(yy2 + a) * ZS + xx2 + b]):
											c.tiles[(yy2 + a) * ZS + xx2 + b] = cont
							xx2 += 8 + rng.randi() % 4
						yy2 += 5
				1:                                          # tank and silo pads: paved discs, a solid drum in each
					var tries := 0
					while tries < 7:
						tries += 1
						var r: int = rng.randi_range(6, 13)
						var cx: int = rng.randi_range(x0 + r + 2, maxi(x0 + r + 3, x1 - r - 2))
						var cy: int = rng.randi_range(y0 + r + 2, maxi(y0 + r + 3, y1 - r - 2))
						for yy in range(cy - r - 2, cy + r + 3):
							for xx in range(cx - r - 2, cx + r + 3):
								if yy < 0 or yy >= ZS or xx < 0 or xx >= ZS or not land.call(c.tiles[yy * ZS + xx]):
									continue
								var d2: int = (xx - cx) * (xx - cx) + (yy - cy) * (yy - cy)
								if d2 <= (r + 2) * (r + 2):
									c.tiles[yy * ZS + xx] = CG.PLATFORM
								if d2 <= (r - 1) * (r - 1):
									c.tiles[yy * ZS + xx] = CG.WALL
				2, 6:                                       # shed rows
					var bx := x0 + 2
					while bx + 18 < x1:
						var by: int = y0 + 2 + rng.randi() % 8
						var h: int = rng.randi_range(12, 24)
						if by + h < y1:
							c._building(bx, by, bx + rng.randi_range(14, 22), by + h, "house")
							homes_made += 1
						bx += 26 + rng.randi() % 10
				3:                                          # pipe racks: long low runs with a gap now and then
					for k in rng.randi_range(2, 4):
						var py: int = rng.randi_range(y0 + 2, y1 - 2)
						for xx in range(x0, x1):
							if (xx % 17) < 13 and land.call(c.tiles[py * ZS + xx]):
								c.tiles[py * ZS + xx] = CG.RAILING
				4:                                          # scrap and slag: crates and rubble, scattered
					for k in 90:
						var sx: int = rng.randi_range(x0, x1)
						var sy: int = rng.randi_range(y0, y1)
						if land.call(c.tiles[sy * ZS + sx]):
							c.tiles[sy * ZS + sx] = CG.CRATE if rng.randi() % 3 == 0 else CG.ROCKS
				5:                                          # drainage pools and cinder: sludge ponds
					for k in 3:
						var px: int = rng.randi_range(x0 + 6, maxi(x0 + 7, x1 - 6))
						var py2: int = rng.randi_range(y0 + 6, maxi(y0 + 7, y1 - 6))
						var pr: int = rng.randi_range(3, 8)
						for yy in range(py2 - pr, py2 + pr + 1):
							for xx in range(px - pr, px + pr + 1):
								if (xx - px) * (xx - px) + (yy - py2) * (yy - py2) <= pr * pr and land.call(c.tiles[yy * ZS + xx]):
									c.tiles[yy * ZS + xx] = CG.WATER
	for k in 80:                                            # work spots on the service roads' verges
		var wx: int = rng.randi_range(8, ZS - 8)
		var wy: int = rng.randi_range(8, ZS - 8)
		var cell: int = wy * ZS + wx
		if int(c.tiles[cell]) == CG.GROUND or int(c.tiles[cell]) == CG.PLATFORM:
			c.works.append(cell)
	c.xs = xs
	c.ys = ys
	c.ys_w = {}
