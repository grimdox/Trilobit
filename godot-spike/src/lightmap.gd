extends RefCounted
## Where the light is.  Every tile is DARK, DIM or LIT, and the rules of sight follow from that:
##   - the open air is LIT in the day, DIM at sunrise and sunset, DARK at night (CLK.ambient_level);
##   - under a roof it is DARK except where a ceiling light reaches: LIT close to a fixture, DIM a little further, and walls and shut doors stop it;
##   - street lamps, neon and signs light the ground around them, in their own colour;
##   - a DARK tile can only be seen from two tiles or less; a DIM tile can be seen from outside it only two tiles deep (from its edge); a LIT tile can be seen from any distance.
## It is computed tile by tile when asked, from rules (no map is stored), and remembered until the hour's light changes or a door moves.
const CLK = preload("res://src/clock.gd")
const LT = preload("res://src/lighting.gd")
const SG = preload("res://src/signage.gd")

const BLOCK := 16
const WEALTH_THEME := ["slum", "mid", "rich"]
const FIXTURE_MOD := 7                  # a ceiling light on every seventh tile of a lattice: (x + 3y) mod 7 == 0, so no floor tile is more than about two from one
const FIXTURE_LIT := 2.5
const FIXTURE_DIM := 3.7
const STREET_LIT := 3.0
const STREET_DIM := 6.0
const NEON_LIT := 2.0                   # a neon sign lights the ground two tiles around it and dimly out to four
const NEON_DIM := 4.0
const WINDOW_LIT := 1.0                 # light spilling out of a lit window at night
const WINDOW_DIM := 2.5
const KERB_LAMP := {"rich": 9, "mid": 7, "slum": 13, "industry": 8, "rural": 19}      # the district's street lamps: one kerb tile in this many (see View's kerb furniture)
const LAMP_SPACING := 10                                                              # street lamps stand every ten tiles along a road's kerb (both directions) and go out at 8am
const KERB_BROKEN := {"slum": 9}                                                      # ... where every ninth is a broken lamp that gives nothing

var g                                   # the Game
var enabled := true
var _lvl := {}                          # cell -> level
var _col := {}                          # cell -> Color of the strongest light
var _blocks := {}                       # block key -> Array of [x, y, lit radius, dim radius, Color]
var _signs_by_block := {}
var _signs_built := false
var _stamp := -1
var forced := {}                        # tests: cell -> level, overriding the rules

func _init(game) -> void:
	g = game

## forget what was worked out (a door moved, or the hour changed)
func invalidate() -> void:
	_lvl.clear()
	_col.clear()

func _sync(tick: int) -> void:
	var s: int = CLK.ambient_level(tick) * 100 + (CLK.hour_of(tick) / 4)
	if s != _stamp:
		_stamp = s
		invalidate()
	if _lvl.size() > 60000:
		invalidate()

func ambient() -> int:
	return CLK.ambient_level(g.sim.tick)

# ---------------------------------------------------------------- the ground
func _x(c: int) -> int:
	return c % g.size

func _y(c: int) -> int:
	return (c / g.size) % g.size

func _z(c: int) -> int:
	return c / g.s2

func opaque(c: int) -> bool:
	return g.fov.opaque[c] == 1

# ---------------------------------------------------------------- mission sites
## A mission site has no street: each room is its own, with a ceiling light, a few wall bulbs, or no light at all.  Overhead lights are fixed;
## wall bulbs are small and can be shot out (Game.dead_lights).  The lights are worked out from the site's rooms, the same every time.
const BULB_LIT := 1.5
const BULB_DIM := 2.8
const DARK_ROOM_PCT := 30
var _site_city = null
var _site_in := {}                      # cell -> true: inside a room or its walls
var _site_lights: Array = []            # [cell, kind ("ceil" or "bulb"), lit radius, dim radius, Color]

func in_site() -> bool:
	return g.city != null and g.city.has_meta("site")

func _site_build() -> void:
	if _site_city == g.city:
		return
	_site_city = g.city
	g.dead_lights.clear()
	_site_in.clear()
	_site_lights.clear()
	var st: Dictionary = g.city.get_meta("site")
	var size: int = g.size
	var ri := 0
	for r in st["rooms"]:
		var rx: int = int(r[0])
		var ry: int = int(r[1])
		var rw: int = int(r[2])
		var rh: int = int(r[3])
		for y in range(ry - 1, ry + rh + 1):
			for x in range(rx - 1, rx + rw + 1):
				if x >= 0 and y >= 0 and x < size and y < size:
					_site_in[y * size + x] = true
		var h: int = absi(hash([rx, ry, rw, rh, "room"]))
		var start: bool = ri == int(st.get("start_room", -1))
		ri += 1
		if not start and h % 100 < DARK_ROOM_PCT:
			continue                                   # an unlit room: sneak through it
		var col: Color = _fixture_colour(ry * size + rx)
		var any := false
		if rw >= 4 and rh >= 4 and (start or (h / 100) % 100 < 55):
			_site_lights.append([(ry + rh / 2) * size + rx + rw / 2, "ceil", FIXTURE_LIT, FIXTURE_DIM, col])
			any = true
		var nb: int = 1 + (h / 10000) % 3
		var spots: Array = [[rx + rw / 3, ry - 1], [rx + (2 * rw) / 3, ry + rh], [rx - 1, ry + rh / 2], [rx + rw, ry + rh / 3]]
		for k in nb:
			var sp: Array = spots[((h / 1000000) + k) % 4]
			var bc: int = int(sp[1]) * size + int(sp[0])
			if int(sp[0]) < 0 or int(sp[1]) < 0 or int(sp[0]) >= size or int(sp[1]) >= size:
				continue
			if g.city.tiles[bc] == g.CG.WALL:
				_site_lights.append([bc, "bulb", BULB_LIT, BULB_DIM, col])
				any = true
		if not any:                                    # a lit room always has some light
			_site_lights.append([(ry + rh / 2) * size + rx + rw / 2, "ceil", FIXTURE_LIT, FIXTURE_DIM, col])

## the lights of the site: [cell, kind] for the ones still burning
func site_lights() -> Array:
	var out: Array = []
	if not in_site():
		return out
	_site_build()
	for L in _site_lights:
		if not g.dead_lights.has(int(L[0])):
			out.append([int(L[0]), String(L[1])])
	return out

## true if a wall bulb burns on this cell
func bulb_at(c: int) -> bool:
	if not in_site():
		return false
	_site_build()
	if g.dead_lights.has(c):
		return false
	for L in _site_lights:
		if int(L[0]) == c and String(L[1]) == "bulb":
			return true
	return false

## shoot a bulb out
func break_bulb(c: int) -> void:
	g.dead_lights[c] = true
	invalidate()

## true if the tile is under a roof as far as the light goes
func indoor(c: int) -> bool:
	if c < g.s2 and in_site():
		_site_build()
		return _site_in.has(c)
	var t: int = g.city.tiles[c]
	if c >= g.s2:
		return not (t == 11 or t == 7 or t == 0 or t == 6 or t == 20)
	if t == 3 or t == 4 or t == 8 or t == 9 or t == 18 or t == 22:
		return true
	if t >= g.CG.EXTRA0:
		var u: int = g.city.under[c] if c < g.city.under.size() else 3
		return u == 3 or u >= g.CG.EXTRA0
	return false

func _wall(c: int) -> bool:
	return opaque(c) or g.city.tiles[c] == 2

## true if the tile is open air: not under a roof and not a wall (a shut door counts as a wall): the only tiles rain falls on
func open_air(c: int) -> bool:
	return not indoor(c) and not _wall(c)

func theme(c: int) -> String:
	if g.island != null and g.zone != g.island.CITY_ZONE:
		return "industry" if g.zone == g.island.PORT_ZONE else "rural"
	if c / g.s2 > g.city.zmax:
		return "industry"
	return WEALTH_THEME[clampi(g.city.wealth_at(c % g.s2), 0, 2)]

## true if a kerb tile carries a street lamp: one in every LAMP_SPACING along the road
static func kerb_lamp(x: int, y: int, roadh: bool, roadv: bool) -> bool:
	return (roadh and x % LAMP_SPACING == 0) or (roadv and y % LAMP_SPACING == 0)

## the street lamps (and the other lights outdoors) of one 16 x 16 block of the ground level
func _block(bx: int, by: int) -> Array:
	var key: int = by * 4096 + bx
	if _blocks.has(key):
		return _blocks[key]
	var out: Array = []
	var size: int = g.size
	for y in range(by * BLOCK, mini(size, (by + 1) * BLOCK)):
		for x in range(bx * BLOCK, mini(size, (bx + 1) * BLOCK)):
			var c: int = y * size + x
			if g.city.tiles[c] != 0:
				continue
			var roadh := false                               # a road to the north or south: this kerb runs east-west
			var roadv := false
			var wall := false
			for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= size or ny >= size:
					continue
				var nt: int = g.city.tiles[ny * size + nx]
				if nt == 1:
					if d.x == 0:
						roadh = true
					else:
						roadv = true
				wall = wall or nt == 2 or nt == 10
			if not (roadh or roadv) or wall:
				continue
			var th: String = theme(c)
			var h: int = ((c * 2654435761) >> 7) & 0xffffff
			if KERB_BROKEN.has(th) and h % int(KERB_BROKEN[th]) == 0:
				continue
			if kerb_lamp(x, y, roadh, roadv):
				out.append([x, y, STREET_LIT, STREET_DIM, LT.STREET, true])
	if not _signs_built:
		_signs_built = true
		for sg in g.city.signs:
			var sc: int = int(sg["cell"])
			if sc >= g.s2:
				continue
			var k2: int = (_y(sc) / BLOCK) * 4096 + (_x(sc) / BLOCK)
			if not _signs_by_block.has(k2):
				_signs_by_block[k2] = []
			_signs_by_block[k2].append(sg)
	for sg in _signs_by_block.get(key, []):
		var neon: bool = String(sg["shape"]) == "neon"
		var pal: Array = (SG.PALS[String(sg["cat"])] as Array)[int(sg["pal"])]
		out.append([_x(int(sg["cell"])), _y(int(sg["cell"])), NEON_LIT if neon else 0.0, NEON_DIM if neon else 2.6, pal[2], false])
	# lit windows throw a little light into the street after dark: one pane in three, most of them lit
	for y in range(by * BLOCK, mini(size, (by + 1) * BLOCK)):
		for x in range(bx * BLOCK, mini(size, (bx + 1) * BLOCK)):
			if (x + y) % 3 != 0 or g.city.tiles[y * size + x] != 10:
				continue
			if ((y * size + x) * 2654435761 >> 5) % 10 < 3:
				continue
			out.append([x, y, WINDOW_LIT, WINDOW_DIM, LT.WARM_WHITE, true])
	_blocks[key] = out
	return out

## a clear line between two tiles of one level (the ends do not count)
func _clear(a: int, b: int) -> bool:
	var x0: int = _x(a)
	var y0: int = _y(a)
	var x1: int = _x(b)
	var y1: int = _y(b)
	var base: int = (a / g.s2) * g.s2
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	while true:
		if x0 == x1 and y0 == y1:
			return true
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
		if x0 == x1 and y0 == y1:
			return true
		if opaque(base + y0 * g.size + x0):
			return false
	return true

func _fixture_colour(c: int) -> Color:
	var h: int = hash([_x(c) / 14, _y(c) / 14, _z(c), "lamp"]) % 100
	if h < 60:
		return LT.WARM_WHITE
	if h < 85:
		return LT.COOL_WHITE
	return LT.AMBER

## the light of one open (non-wall) tile: [level, colour]
func _open(c: int) -> Array:
	var ind: bool = indoor(c)
	var lvl: int = LT.DARK if ind else ambient()
	var col: Color = LT.DAYLIGHT
	if not ind and lvl == LT.DIM:
		col = LT.DUSK_TINT.lerp(Color.WHITE, 0.5)
	var best := 0.0                                  # how strong the strongest light is here (2 lit, 1 dim, scaled by closeness)
	var x: int = _x(c)
	var y: int = _y(c)
	var size: int = g.size
	var base: int = (c / g.s2) * g.s2
	if ind and in_site():
		for L in _site_lights:
			if g.dead_lights.has(int(L[0])):
				continue
			var lc: int = int(L[0])
			if lc / g.s2 != c / g.s2:
				continue
			var ldx: float = float(_x(lc) - x)
			var ldy: float = float(_y(lc) - y)
			var ld: float = sqrt(ldx * ldx + ldy * ldy)
			if ld > float(L[3]):
				continue
			if ld > 1.0 and not _clear(c, lc):
				continue
			var lgot: int = LT.LIT if ld <= float(L[2]) else LT.DIM
			var lscore: float = float(lgot) * 10.0 - ld
			if lscore > best:
				best = lscore
				lvl = maxi(lvl, lgot)
				col = L[4]
	elif ind:
		var r: int = ((x + 3 * y) % FIXTURE_MOD + FIXTURE_MOD) % FIXTURE_MOD
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				if ((dx + 3 * dy) + r) % FIXTURE_MOD != 0:
					continue
				var nx: int = x + dx
				var ny: int = y + dy
				if nx < 1 or ny < 1 or nx >= size - 1 or ny >= size - 1:
					continue
				var fc: int = base + ny * size + nx
				if not indoor(fc):
					continue
				var d: float = sqrt(float(dx * dx + dy * dy))
				if d > FIXTURE_DIM:
					continue
				if d > 1.0 and not _clear(c, fc):
					continue
				var got: int = LT.LIT if d <= FIXTURE_LIT else LT.DIM
				var score: float = float(got) * 10.0 - d
				if score > best:
					best = score
					lvl = maxi(lvl, got)
					col = _fixture_colour(fc)
	if base == 0:
		var daylight: bool = ambient() == LT.LIT       # street lamps and window light are off from 8am
		var bx: int = x / BLOCK
		var by: int = y / BLOCK
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				if bx + ox < 0 or by + oy < 0:
					continue
				for L in _block(bx + ox, by + oy):
					if bool(L[5]) and daylight:
						continue
					var dx2: float = float(int(L[0]) - x)
					var dy2: float = float(int(L[1]) - y)
					var d2: float = sqrt(dx2 * dx2 + dy2 * dy2)
					if d2 > float(L[3]):
						continue
					if d2 > 1.0 and not _clear(c, int(L[1]) * size + int(L[0])):
						continue
					var got2: int = LT.LIT if d2 <= float(L[2]) else LT.DIM
					var score2: float = float(got2) * 10.0 - d2
					if got2 > lvl or (got2 == lvl and score2 > best):
						lvl = maxi(lvl, got2)
						if score2 > best:
							best = score2
							col = L[4]
	return [lvl, col]

func _info(c: int) -> Array:
	if _lvl.has(c):
		return [_lvl[c], _col[c]]
	var v: Array
	if _wall(c):
		# a wall takes the brightest light of the open tiles that touch it
		v = [LT.DARK, LT.DAYLIGHT]
		var bestl := -1
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var nx: int = _x(c) + d.x
			var ny: int = _y(c) + d.y
			if nx < 0 or ny < 0 or nx >= g.size or ny >= g.size:
				continue
			var nc: int = (c / g.s2) * g.s2 + ny * g.size + nx
			if _wall(nc):
				continue
			var o: Array = _open(nc)
			if int(o[0]) > bestl:
				bestl = int(o[0])
				v = o
	else:
		v = _open(c)
	_lvl[c] = v[0]
	_col[c] = v[1]
	return v

## the light level of a tile (LIT, DIM or DARK)
func level(c: int) -> int:
	if forced.has(c):
		return int(forced[c])
	if not enabled:
		return LT.LIT
	_sync(g.sim.tick)
	return int(_info(c)[0])

## the colour of the light on a tile
func colour(c: int) -> Color:
	_sync(g.sim.tick)
	return _info(c)[1]

func _cheb(a: int, b: int) -> int:
	return maxi(absi(_x(a) - _x(b)), absi(_y(a) - _y(b)))

## true if a dim tile has an unlit-or-lit (non-dim) tile within two tiles: it is on the rim of its dim region, which is as deep as one can see into it from outside
func _rim(c: int) -> bool:
	var base: int = (c / g.s2) * g.s2
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if dx == 0 and dy == 0:
				continue
			var nx: int = _x(c) + dx
			var ny: int = _y(c) + dy
			if nx < 0 or ny < 0 or nx >= g.size or ny >= g.size:
				continue
			if level(base + ny * g.size + nx) != LT.DIM:
				return true
	return false

## can someone standing on tile `a` make out what is on tile `b`, as far as the light goes (line of sight is checked elsewhere)?
func sees(a: int, b: int) -> bool:
	if not enabled and forced.is_empty():
		return true
	var lb: int = level(b)
	if lb == LT.LIT:
		return true
	var d: int = _cheb(a, b)
	if d <= 1:
		return true
	if lb == LT.DARK:
		return d <= 2
	# DIM: from inside the dim light everything in it shows; from outside only its first two tiles
	return level(a) == LT.DIM or _rim(b)
