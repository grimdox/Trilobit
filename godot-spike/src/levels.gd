extends RefCounted
## The vertical world, built on top of a generated city (citygen.gd).
## Every level is a size x size layer; all levels are stacked in ONE array: ground first (so every ground-level cell index is unchanged),
## then the floors above it (1..zmax), then the two underground levels (-1 tunnels and subway, -2 sewers).  A cell index therefore says
## which level it is on (cell / (size*size)); cells on different levels are far apart in row terms, which gives the NPC simulation its
## level of detail for free: only people on the player's own level are ever "near".  Stairs, elevators and ladders are `links` between
## cells; flow fields and pathing treat a link as one more step.
##   above ground: the tall core buildings become towers of up to 30 floors (offices, shops, flats), a roof, and a few skybridges
##   -1: a subway loop under the road grid (four stations, a scheduled train) with maintenance catwalks, hatches up to the street
##   -2: sewers under every road line, ladders up to the tunnels, manholes up to the street, and lairs for squatters
const CG = preload("res://src/citygen.gd")
const TP = preload("res://src/tower_plan.gd")

static func build(c, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed ^ 0x7a11
	var size: int = c.size
	var s2 := size * size
	var centre: Vector2 = c.centre_pt if c.rad > 0.0 else Vector2(size * 0.5, size * 0.5)
	var dscale: float = c.rad if c.rad > 0.0 else size * 0.5
	c.homes_g = c.homes.duplicate()
	c.works_g = c.works.duplicate()
	c.shops_g = c.shops.duplicate()

	# ---- heights: the closer to the centre, the taller; the tallest is always a full 30
	var cands: Array = []
	for t in c.towers:
		var w: int = int(t["x1"]) - int(t["x0"]) + 1
		var hgt: int = int(t["y1"]) - int(t["y0"]) + 1
		if w < 9 or hgt < 9:
			continue
		var d: float = Vector2((int(t["x0"]) + int(t["x1"])) * 0.5, (int(t["y0"]) + int(t["y1"])) * 0.5).distance_to(centre) / dscale
		var hh: int = int(lerpf(float(c.max_floors), 5.0, clampf(d / 0.45, 0.0, 1.0))) + rng.randi_range(-4, 3)
		if w * hgt >= 3600:               # a mega-tower (2-3 blocks wide) is always among the tallest
			hh = c.max_floors - rng.randi_range(0, 4)
		elif rng.randf() < 0.12:
			hh = rng.randi_range(2, 5)
		t["h"] = clampi(hh, 2, c.max_floors)
		t["d"] = d
		cands.append(t)
	if not cands.is_empty():
		var best: Dictionary = cands[0]
		for t in cands:
			if float(t["d"]) < float(best["d"]):
				best = t
		best["h"] = c.max_floors
	var zmax := 0
	for t in cands:
		zmax = maxi(zmax, int(t["h"]))
	c.zmax = zmax
	c.nlev = zmax + 3

	# ---- the stacked array
	var air := PackedByteArray()
	air.resize(s2)
	air.fill(CG.AIR)
	var rock := PackedByteArray()
	rock.resize(s2)
	rock.fill(CG.EARTH)
	var all: PackedByteArray = c.tiles.duplicate()
	for _z in zmax:
		all.append_array(air)
	for _z in 2:
		all.append_array(rock)
	c.tiles = all                                         # the businesses built into the lobbies write straight into the stack
	var links := {}
	c.apartments = []
	c.tower_info = []
	c.under_up = PackedByteArray()
	c.under_up.resize(all.size())
	c.under_up.fill(3)
	c.vaults = []
	c.homes_t = PackedInt32Array()
	c.works_t = PackedInt32Array()
	c.shops_t = PackedInt32Array()
	var idx := 0
	for t in cands:
		idx += 1
		_tower(c, all, links, t, rng, idx)
	# the floor under every cell of every level (the lobbies' and shops' floors are the ground part), for the furniture standing on it
	var under_all: PackedByteArray = c.under_up
	for i in mini(c.under.size(), s2):
		under_all[i] = c.under[i]
	c.under = under_all
	c.under_up = PackedByteArray()
	_bridges(c, all, rng)
	_underground(c, all, links, rng)

	c.movables = []
	_props(c, all, links, rng)
	c.tiles = all
	c.links = links
	c.haslink = PackedByteArray()
	c.haslink.resize(all.size())
	for k in links:
		c.haslink[k] = 1
	c.homes = _concat(c.homes_g, c.homes_t)
	c.works = _concat(c.works_g, c.works_t)
	c.shops = _concat(c.shops_g, c.shops_t)

## a wild zone: ground only (plus solid rock below so the level maths still holds), no towers, no subway
static func flat(c, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed ^ 0x7a11
	var s2: int = c.size * c.size
	c.homes_g = c.homes.duplicate()
	c.works_g = c.works.duplicate()
	c.shops_g = c.shops.duplicate()
	c.zmax = 0
	c.nlev = 3
	var rock := PackedByteArray()
	rock.resize(s2)
	rock.fill(CG.EARTH)
	var all: PackedByteArray = c.tiles.duplicate()
	for _z in 2:
		all.append_array(rock)
	var links := {}
	c.tower_info = []
	c.vaults = []
	c.homes_t = PackedInt32Array()
	c.works_t = PackedInt32Array()
	c.shops_t = PackedInt32Array()
	c.lairs = PackedInt32Array()
	c.subway = {"ring": PackedInt32Array(), "stops": []}
	c.movables = []
	_props(c, all, links, rng)
	c.tiles = all
	c.links = links
	c.haslink = PackedByteArray()
	c.haslink.resize(all.size())
	c.homes = c.homes_g
	c.works = c.works_g
	c.shops = c.shops_g

static func _concat(a: PackedInt32Array, b: PackedInt32Array) -> PackedInt32Array:
	var out := a.duplicate()
	out.append_array(b)
	return out

## low cover: crates in rooms, dumpsters and planters outdoors.  A prop only goes where all eight neighbours are walkable (so it can never wall anything in)
## and never on a marker, a link or a vault cell.
static func _props(c, all: PackedByteArray, links: Dictionary, rng: RandomNumberGenerator) -> void:
	var size: int = c.size
	var s2: int = size * size
	var skip := {}
	for arr in [c.homes_g, c.works_g, c.shops_g, c.homes_t, c.works_t, c.shops_t, c.lairs]:
		for i in arr:
			skip[i] = 1
	for v in c.vaults:
		for i in v:
			skip[i] = 1
	for k in links:
		skip[k] = 1
	# ground
	for _n in size * size / 13:
		var x: int = rng.randi_range(2, size - 3)
		var y: int = rng.randi_range(2, size - 3)
		_prop_try(c, all, skip, y * size + x, size, rng)
	# (the floors of the towers are furnished by tower_plan.gd; only the roofs get the odd crate)
	for t in c.tower_info:
		var rbase: int = c.lvl_of_z(int(t["h"])) * s2
		for _n in 3:
			var x: int = rng.randi_range(int(t["x0"]) + 2, int(t["x1"]) - 2)
			var y: int = rng.randi_range(int(t["y0"]) + 2, int(t["y1"]) - 2)
			_prop_try(c, all, skip, rbase + y * size + x, size, rng)

static func _prop_try(c, all: PackedByteArray, skip: Dictionary, cell: int, size: int, rng: RandomNumberGenerator) -> void:
	if skip.has(cell):
		return
	var t: int = all[cell]
	var kind := -1
	var mov := ""
	match t:
		CG.GROUND:
			kind = CG.DUMPSTER if rng.randf() < 0.35 else (CG.PLANTER if rng.randf() < 0.5 else CG.CRATE)
		CG.PARK: kind = CG.PLANTER
		CG.FLOOR:
			var r := rng.randf()
			mov = "table" if r < 0.45 else ("chair" if r < 0.75 else "crate")
		CG.ROOF: kind = CG.CRATE
	if kind < 0 and mov == "":
		return
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nb: int = cell + dy * size + dx
			if skip.has(nb) or CG.WALK[all[nb]] != 1:
				return
	if kind == CG.CRATE and rng.randf() < 0.6:
		c.movables.append([cell, "crate"])           # a loose crate: the tile stays plain floor
		return
	if mov != "":
		c.movables.append([cell, mov])
		if mov == "table" and rng.randf() < 0.6:
			var ds: Array = [[1, 1], [-1, 1], [1, -1], [-1, -1]]
			var d: Array = ds[rng.randi() % 4]
			c.movables.append([cell + d[1] * size + d[0], "chair"])
		return
	all[cell] = kind

static func _link(links: Dictionary, a: int, b: int) -> void:
	if not links.has(a):
		links[a] = []
	if not links.has(b):
		links[b] = []
	links[a].append(b)
	links[b].append(a)

# ------------------------------------------------------------------ towers
static func _tower(c, all: PackedByteArray, links: Dictionary, t: Dictionary, rng: RandomNumberGenerator, tower_no: int) -> void:
	var size: int = c.size
	var s2 := size * size
	var x0: int = t["x0"]
	var y0: int = t["y0"]
	var x1: int = t["x1"]
	var y1: int = t["y1"]
	var h: int = t["h"]
	var side: int = int(t.get("side", 1))
	var fr := TP.Fr.new(x0, y0, x1, y1, side, size)
	var lay: Dictionary = TP.layout(fr.F, fr.D)
	var wealth: int = clampi(c.wealth_at(((y0 + y1) / 2) * size + (x0 + x1) / 2), 0, 2)
	# what the tower is: offices, flats, or offices low down and flats above (tall towers only)
	var d: float = float(t.get("d", 0.5))
	var use := "office" if rng.randf() < (0.62 if d < 0.2 else 0.42) else "apartment"
	if h >= 12 and rng.randf() < 0.3:
		use = "hybrid"
	t["use"] = use
	t["split"] = rng.randi_range(3, maxi(3, h / 2)) if use == "hybrid" else 0
	var first_flat: int = 1 if use == "apartment" else (int(t["split"]) if use == "hybrid" else 99)
	t["gym_z"] = first_flat if first_flat < h else -1               # the lowest residential floor is the gym
	# the lobby (with a shop on the street where there is room); the lifts and the stairs are in the corridor above it
	var rng_state: int = c.rng.state                                 # the shops use the city's own random stream: leave it as it was for what comes after
	var g: Dictionary = TP.ground(c, all, fr, lay, "office" if use == "office" else "apartment", rng)
	c.rng.state = rng_state
	if g.is_empty():
		return                                                     # nowhere to put a street door: leave it a plain building
	t["door"] = g["door"]
	var s_cell: int = fr.idx(int(lay["fs"]), int(lay["sn"]))
	var e_cell: int = fr.idx(int(lay["fe"]), int(lay["sn"]))
	var units := 0
	for z in range(1, h + 1):
		var base := z * s2
		if z < h:
			var kind: String = TP.floor_use(t, z)
			var res: Dictionary
			match kind:
				"apartment": res = TP.apartment_floor(all, c.under_up, base, fr, lay, wealth)
				"gym": res = TP.gym_floor(all, c.under_up, base, fr, lay)
				_: res = TP.office_floor(all, c.under_up, base, fr, lay, rng)
			_floor_markers(c, res, base, z, kind, tower_no)
			units += int(res.get("units", []).size())
			if kind == "office" and z >= 4 and z % 3 == 1 and rng.randf() < 0.55:
				_vault(c, all, res["rooms"], base, rng, [s_cell, e_cell], size)
		else:
			for y in range(y0, y1 + 1):
				for x in range(x0, x1 + 1):
					var edge := x == x0 or x == x1 or y == y0 or y == y1
					all[base + y * size + x] = CG.RAILING if edge else CG.ROOF
			for _k in 3:                                   # rooftop plant
				var rx := rng.randi_range(x0 + 2, x1 - 3)
				var ry := rng.randi_range(y0 + 2, y1 - 3)
				if maxi(absi(rx - s_cell % size), absi(ry - s_cell / size)) > 3 and maxi(absi(rx - e_cell % size), absi(ry - e_cell / size)) > 3:
					for oy in 2:
						for ox in 2:
							all[base + (ry + oy) * size + rx + ox] = CG.WALL
		all[base + s_cell] = CG.STAIRS
		all[base + e_cell] = CG.ELEVATOR
		_link(links, base - s2 + s_cell, base + s_cell)
		_link(links, base - s2 + e_cell, base + e_cell)
	all[s_cell] = CG.STAIRS
	all[e_cell] = CG.ELEVATOR
	c.tower_info.append({"x0": x0, "y0": y0, "x1": x1, "y1": y1, "h": h, "stairs": s_cell, "elev": e_cell, "use": use, "side": side,
		"no": tower_no, "door": t["door"], "gym_z": int(t["gym_z"]), "split": int(t["split"]), "units": units, "shops": g["biz"].size()})

## the markers a floor leaves: homes in flats (and a record of each flat for later), places to work in offices and the gym
static func _floor_markers(c, res: Dictionary, base: int, z: int, kind: String, tower_no: int) -> void:
	for i in res.get("homes", []):
		c.homes_t.append(base + int(i))
	for u in res.get("units", []):
		c.apartments.append({"cell": base + int(u["cell"]), "tower": tower_no, "z": z, "rect": u["rect"]})
	for i in res.get("works", []):
		c.works_t.append(base + int(i))

static func _nearest(cells: Array, size: int, tx: int, ty: int, skip: int) -> int:
	var best: int = -1
	var bd := 1 << 30
	for i in cells:
		if i == skip:
			continue
		if skip >= 0 and maxi(absi(i % size - skip % size), absi(i / size - skip / size)) < 2:
			continue
		var d: int = absi(i % size - tx) + absi(i / size - ty)
		if d < bd:
			bd = d
			best = i
	return best

## homes, offices and shops on one floor: flats and offices alternate in bands of three floors, the lowest two are retail
static func _markers(c, rooms: Array, pt: PackedByteArray, base: int, z: int, rng: RandomNumberGenerator, skip: Array, size: int) -> void:
	for r in rooms:
		var rr: Rect2i = r
		var n := clampi(rr.get_area() / 8, 1, 4)
		for _k in n:
			var cell := Vector2i(rng.randi_range(rr.position.x, rr.end.x - 1), rng.randi_range(rr.position.y, rr.end.y - 1))
			var i := cell.y * size + cell.x
			if pt[i] != CG.FLOOR or skip.has(i):
				continue
			if z <= 2:
				if rng.randf() < 0.5:
					c.shops_t.append(base + i)
				else:
					c.works_t.append(base + i)
			elif (z / 3) % 2 == 0:
				c.works_t.append(base + i)
			else:
				c.homes_t.append(base + i)

## lock every door of the smallest closed room on a floor and remember its cells
static func _vault(c, all: PackedByteArray, rooms: Array, base: int, rng: RandomNumberGenerator, skip: Array, size: int) -> void:
	var best: Rect2i = Rect2i()
	var ba := 1 << 30
	for r in rooms:
		var rr: Rect2i = r
		var has_shaft := false
		for sc in skip:
			if rr.has_point(Vector2i(sc % size, sc / size)):
				has_shaft = true
		if has_shaft:
			continue
		if rr.get_area() < ba and rr.get_area() >= 12:
			ba = rr.get_area()
			best = rr
	if best.get_area() == 0:
		return
	var doors := 0
	for y in range(best.position.y - 1, best.end.y + 1):
		for x in range(best.position.x - 1, best.end.x + 1):
			var i: int = base + y * size + x
			if all[i] == CG.DOOR:
				all[i] = CG.LOCKED
				doors += 1
	if doors == 0:
		return
	var cells := PackedInt32Array()
	for y in range(best.position.y, best.end.y):
		for x in range(best.position.x, best.end.x):
			if CG.WALK[all[base + y * size + x]] == 1:
				cells.append(base + y * size + x)
	c.vaults.append(cells)

## glass corridors between towers that stand close together
static func _bridges(c, all: PackedByteArray, rng: RandomNumberGenerator) -> void:
	var size: int = c.size
	var s2 := size * size
	var info: Array = c.tower_info
	var made := 0
	for i in info.size():
		for j in range(i + 1, info.size()):
			if made >= 10:
				return
			var a: Dictionary = info[i]
			var b: Dictionary = info[j]
			var lo: int = mini(int(a["h"]), int(b["h"]))
			if lo < 8:
				continue
			var zs: Array = []
			for zc in [8, 14, 20, 26]:
				if zc <= lo - 2:
					zs.append(zc)
			if zs.is_empty():
				continue
			var z: int = zs[rng.randi() % zs.size()]
			var base := z * s2
			# a to the west of b
			for horizontal in [true, false]:
				var w_t: Dictionary = a
				var e_t: Dictionary = b
				var ax1: int
				var bx0: int
				var lo_r: int
				var hi_r: int
				if horizontal:
					if int(a["x0"]) > int(b["x0"]):
						w_t = b
						e_t = a
					ax1 = int(w_t["x1"])
					bx0 = int(e_t["x0"])
					lo_r = maxi(int(w_t["y0"]), int(e_t["y0"])) + 2
					hi_r = mini(int(w_t["y1"]), int(e_t["y1"])) - 2
				else:
					if int(a["y0"]) > int(b["y0"]):
						w_t = b
						e_t = a
					ax1 = int(w_t["y1"])
					bx0 = int(e_t["y0"])
					lo_r = maxi(int(w_t["x0"]), int(e_t["x0"])) + 2
					hi_r = mini(int(w_t["x1"]), int(e_t["x1"])) - 2
				var gap := bx0 - ax1 - 1
				if gap < 2 or gap > 18 or hi_r - lo_r < 3:
					continue
				for _try in 12:
					var m: int = rng.randi_range(lo_r + 1, hi_r - 1)
					if _bridge_ok(all, base, size, horizontal, ax1, bx0, m):
						_bridge_make(all, base, size, horizontal, ax1, bx0, m)
						made += 1
						break

static func _cell(horizontal: bool, along: int, across: int, size: int) -> int:
	return across * size + along if horizontal else along * size + across

static func _bridge_ok(all: PackedByteArray, base: int, size: int, horizontal: bool, a_edge: int, b_edge: int, m: int) -> bool:
	if all[base + _cell(horizontal, a_edge - 1, m, size)] != CG.FLOOR or all[base + _cell(horizontal, b_edge + 1, m, size)] != CG.FLOOR:
		return false
	for k in range(a_edge + 1, b_edge):
		for off in [-1, 0, 1]:
			if all[base + _cell(horizontal, k, m + off, size)] != CG.AIR:
				return false
	return true

static func _bridge_make(all: PackedByteArray, base: int, size: int, horizontal: bool, a_edge: int, b_edge: int, m: int) -> void:
	all[base + _cell(horizontal, a_edge, m, size)] = CG.DOOR
	all[base + _cell(horizontal, b_edge, m, size)] = CG.DOOR
	for k in range(a_edge + 1, b_edge):
		all[base + _cell(horizontal, k, m, size)] = CG.FLOOR
		all[base + _cell(horizontal, k, m - 1, size)] = CG.GLASS
		all[base + _cell(horizontal, k, m + 1, size)] = CG.GLASS

# ------------------------------------------------------------------ underground
static func _near_line(lines: Array, target: float, rw: int, size: int) -> int:
	var best: int = int(lines[0])
	for l in lines:
		if absf(float(l) - target) < absf(float(best) - target):
			best = int(l)
	return clampi(best + rw / 2, 6, size - 7)

static func _underground(c, all: PackedByteArray, links: Dictionary, rng: RandomNumberGenerator) -> void:
	var size: int = c.size
	var s2 := size * size
	var l1: int = c.lvl_of_z(-1) * s2
	var l2: int = c.lvl_of_z(-2) * s2
	var rw: int = c.rw
	var xl := _near_line(c.xs, size * 0.27, rw, size)
	var xr := _near_line(c.xs, size * 0.73, rw, size)
	var yt := _near_line(c.ys, size * 0.27, rw, size)
	var yb := _near_line(c.ys, size * 0.73, rw, size)
	if xr - xl < 30:
		xl = int(size * 0.27)
		xr = int(size * 0.73)
	if yb - yt < 30:
		yt = int(size * 0.27)
		yb = int(size * 0.73)
	if not c.plan.is_empty():
		var rr: Rect2i = c.plan["ring"]                 # the island city: the loop runs round the downtown, east of the river
		xl = rr.position.x
		xr = rr.end.x
		yt = rr.position.y
		yb = rr.end.y
	# the subway ring, clockwise from the top-left corner
	var ring := PackedInt32Array()
	for x in range(xl, xr):
		ring.append(yt * size + x)
	for y in range(yt, yb):
		ring.append(y * size + xr)
	for x in range(xr, xl, -1):
		ring.append(yb * size + x)
	for y in range(yb, yt, -1):
		ring.append(y * size + xl)
	# the line is two tiles of track wide (the ring cell and its right/lower neighbour); a train is four wide, so the tunnel
	# is carved six wide: a catwalk, the body (wall, two floor tiles, wall) over the tracks, and a catwalk
	var catwalk: Array = []
	for i in ring.size():
		var cell: int = ring[i]
		var horiz_cell: bool = _ring_horiz(ring, i, size)
		for off in range(-2, 4):
			var q: int = cell + (off * size if horiz_cell else off)
			if off == 0 or off == 1:
				all[l1 + q] = CG.TRACK
			elif all[l1 + q] == CG.EARTH or all[l1 + q] == CG.TUNNEL:
				all[l1 + q] = CG.TUNNEL
				catwalk.append(q)
	# four stations, one on each side of the ring, each with an entrance on a street tile
	var w := xr - xl
	var hh := yb - yt
	var sides := [[0, w, true], [w, hh, false], [w + hh, w, true], [2 * w + hh, hh, false]]
	var stops: Array = []
	c.station_doors = PackedInt32Array()
	var ring_len := ring.size()
	var si := 0
	for sd in sides:
		var mid: int = int(sd[0]) + int(sd[1]) / 2
		var horiz: bool = sd[2]
		var placed := false
		for off in [0, 5, -5, 10, -10, 15, -15, 20, -20, 25, -25, 30, -30, 40, -40]:
			if placed:
				break
			var sc: int = mid + off
			var tc: int = ring[sc % ring_len]
			if si == 3 and c.rail_row >= 0 and absi(tc / size - c.rail_row) < 26:
				continue                      # keep the station clear of the tunnel to the railway
			for sgn in [1, -1]:
				if placed:
					break
				for dist in range(5, 26):
					var p: int = tc + (sgn * dist * size if horiz else sgn * dist)
					var g: int = all[p]
					if (g == CG.GROUND or g == CG.PARK):
						placed = true
						stops.append(sc % ring_len)
						_station(c, all, ring, sc, horiz, size, l1)
						# a passage from the platform edge out to the stairs
						for d in range(2, dist + 1):
							var q: int = tc + (sgn * d * size if horiz else sgn * d)
							if all[l1 + q] == CG.EARTH:
								all[l1 + q] = CG.TUNNEL
						all[p] = CG.STAIRS
						all[l1 + p] = CG.STAIRS
						_link(links, p, l1 + p)
						c.station_doors.append(p)
						break
		si += 1
	c.subway = {"ring": ring, "stops": stops}
	# hatches from the street into the maintenance tunnels
	var hatch: Array = []
	for cell in catwalk:
		if all[cell] == CG.ROAD and all[l1 + cell] == CG.TUNNEL:
			hatch.append(cell)
	for cell in _pick_spaced(hatch, 5, 28, size, rng):
		all[cell] = CG.MANHOLE
		all[l1 + cell] = CG.LADDER
		_link(links, cell, l1 + cell)
	# the sewers: three wide under every road line (a wet channel in the middle, dry catwalks either side)
	for lx in c.xs:
		for y in range(4, size - 4):
			for k in range(rw / 2 - 2, rw / 2 + 3):
				_sewer_cell(all, l2, size, int(lx) + k, y, k == rw / 2, c)
	for ly in c.ys:
		var lw: int = c.line_w(int(ly), true)
		for x in range(4, size - 4):
			for k in range(lw / 2 - 2, lw / 2 + 3):
				_sewer_cell(all, l2, size, x, int(ly) + k, k == lw / 2, c)
	# ladders tunnel <-> sewer, manholes street -> sewer
	var shared: Array = []
	var down: Array = []
	for y in range(5, size - 5):
		for x in range(5, size - 5):
			var i := y * size + x
			if all[l2 + i] == CG.SEWER:
				if all[l1 + i] == CG.TUNNEL:
					shared.append(i)
				elif all[i] == CG.ROAD and all[l1 + i] == CG.EARTH:
					down.append(i)
	for cell in _pick_spaced(shared, 4, 30, size, rng):
		all[l1 + cell] = CG.LADDER
		all[l2 + cell] = CG.LADDER
		_link(links, l1 + cell, l2 + cell)
	for cell in _pick_spaced(down, 6, 24, size, rng):
		all[cell] = CG.MANHOLE
		all[l2 + cell] = CG.LADDER
		_link(links, cell, l2 + cell)
	# lairs: sewer cells where squatters live
	c.lairs = PackedInt32Array()
	var sewer_cells: Array = []
	for y in range(5, size - 5):
		for x in range(5, size - 5):
			if all[l2 + y * size + x] == CG.SEWER:
				sewer_cells.append(l2 + y * size + x)
	for _k in 24:
		if sewer_cells.is_empty():
			break
		c.lairs.append(sewer_cells[rng.randi() % sewer_cells.size()])

static func _sewer_cell(all: PackedByteArray, l2: int, size: int, x: int, y: int, channel: bool, c) -> void:
	if x < 4 or y < 4 or x >= size - 4 or y >= size - 4:
		return
	if all[y * size + x] == CG.WATER:
		return
	if not c.plan.is_empty():
		var wt: PackedByteArray = c.plan["water"]
		if all[y * size + x] != CG.ROAD or wt[y * size + x] != 0:        # sewers lie under the streets only, never under the river
			return
	all[l2 + y * size + x] = CG.SLUDGE if channel else CG.SEWER

## platform tiles on both sides of the track around ring index sc
static func _station(c, all: PackedByteArray, ring: PackedInt32Array, sc: int, horiz: bool, size: int, l1: int) -> void:
	var n := ring.size()
	# a platform along both sides of the train (30 tiles: a 24-tile train and room to walk), two tiles deep, flush with the car walls
	for k in range(-15, 15):
		var tc: int = ring[(sc + k + n) % n]
		for off in [-3, -2, 3, 4]:
			var p: int = tc + (off * size if horiz else off)
			if all[l1 + p] == CG.TUNNEL or all[l1 + p] == CG.EARTH:
				all[l1 + p] = CG.PLATFORM

## is the ring running east-west at index i (a cell's neighbours decide; corners count as horizontal)
static func _ring_horiz(ring: PackedInt32Array, i: int, size: int) -> bool:
	var n := ring.size()
	var a: int = ring[(i - 1 + n) % n]
	var b: int = ring[(i + 1) % n]
	return absi(b % size - a % size) >= absi(b / size - a / size)

## up to `count` cells at least `gap` apart (chebyshev), chosen at random
static func _pick_spaced(cells: Array, count: int, gap: int, size: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var pool := cells.duplicate()
	var tries := 0
	while out.size() < count and not pool.is_empty() and tries < 400:
		tries += 1
		var cell: int = pool[rng.randi() % pool.size()]
		var far := true
		for o in out:
			if maxi(absi(int(o) % size - cell % size), absi(int(o) / size - cell / size)) < gap:
				far = false
				break
		if far:
			out.append(cell)
	return out

## fraction of every marker (and lair) that can be walked to from the first road tile, through stairs, elevators and ladders
static func reachable_all(c) -> float:
	var size: int = c.size
	var tiles: PackedByteArray = c.tiles
	var seen := PackedByteArray()
	seen.resize(tiles.size())
	var start := -1
	for i in size * size:
		if tiles[i] == CG.ROAD:
			start = i
			break
	var q := PackedInt32Array([start])
	seen[start] = 1
	var head := 0
	var total: int = tiles.size()
	while head < q.size():
		var cur := q[head]
		head += 1
		var nbs: Array = []
		if cur % size > 0:
			nbs.append(cur - 1)
		if cur % size < size - 1:
			nbs.append(cur + 1)
		if cur >= size:
			nbs.append(cur - size)
		if cur + size < total:
			nbs.append(cur + size)
		if c.haslink[cur] == 1:
			nbs.append_array(c.links[cur])
		for nb in nbs:
			if seen[nb] == 0 and c.walkable(tiles[nb]):
				seen[nb] = 1
				q.append(nb)
	var tot := 0
	var ok := 0
	for arr in [c.homes, c.works, c.shops, c.lairs]:
		for i in arr:
			tot += 1
			if seen[i] == 1:
				ok += 1
	return float(ok) / maxf(1.0, float(tot))
