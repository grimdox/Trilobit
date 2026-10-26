extends RefCounted
## The insides of the towers.  Every tower is one of two kinds above its lobby: an office block (open-plan floors and closed rooms of every
## size) or an apartment block (the same flat repeated along a corridor, one floor given over to a gym).  A tall tower can be both: offices
## low down, flats above.  The ground floor of every tower is a lobby, and a tower with room for it has a shop, cafe or restaurant on the
## street side (mixed use).
##
## Everything is laid out in a frame that is turned to face the street: f runs along the front, n runs inward from the street wall (n = 0 is
## the wall on the street, n = D - 1 the back wall).  A corridor runs along f at a fixed depth; the lift and the stairs stand in it, one cell
## apart, on every floor, and nothing is ever put in the corridors, so they are always reachable.  Units, offices and shops sit on the two sides.
const CG = preload("res://src/citygen.gd")
const BZ = preload("res://src/business.gd")

static func T(name: String) -> int:
	return CG.TID[name]

## a rectangle (the outer walls of a tower) seen from its street
class Fr:
	var x0: int
	var y0: int
	var x1: int
	var y1: int
	var side: int
	var size: int
	var F: int
	var D: int
	func _init(ax0: int, ay0: int, ax1: int, ay1: int, aside: int, asize: int) -> void:
		x0 = ax0; y0 = ay0; x1 = ax1; y1 = ay1; side = aside; size = asize
		if side < 2:
			F = x1 - x0 + 1
			D = y1 - y0 + 1
		else:
			F = y1 - y0 + 1
			D = x1 - x0 + 1
	func xy(f: int, n: int) -> Vector2i:
		match side:
			0: return Vector2i(x0 + f, y0 + n)
			1: return Vector2i(x0 + f, y1 - n)
			2: return Vector2i(x0 + n, y0 + f)
			_: return Vector2i(x1 - n, y0 + f)
	func idx(f: int, n: int) -> int:
		var p := xy(f, n)
		return p.y * size + p.x
	func inb(f: int, n: int) -> bool:
		return f >= 0 and n >= 0 and f < F and n < D
	## world rectangle of a frame rectangle (f0..f1, n0..n1 inclusive)
	func rect(f0: int, n0: int, f1: int, n1: int) -> Rect2i:
		var a := xy(f0, n0)
		var b := xy(f1, n1)
		return Rect2i(mini(a.x, b.x), mini(a.y, b.y), absi(a.x - b.x) + 1, absi(a.y - b.y) + 1)

## a flat or a suite: a rectangle of floor against its entry wall.  a runs along the front (from fa), b runs from the entry wall inward.
class U:
	var all: PackedByteArray
	var under: PackedByteArray
	var base: int
	var fr: Fr
	var fa: int
	var w: int
	var d: int
	var wallrow: int
	var front: bool
	var flr: int
	## (f, n) of cell (a, b); b = -1 is the entry wall row and a = w the party wall beside the unit
	func fn(a: int, b: int) -> Vector2i:
		return Vector2i(fa + a, (wallrow - 1 - b) if front else (wallrow + 1 + b))
	func idx(a: int, b: int) -> int:
		var p := fn(a, b)
		return base + fr.idx(p.x, p.y)
	func inside(a: int, b: int) -> bool:
		return a >= 0 and b >= 0 and a < w and b < d
	func is_free(a: int, b: int) -> bool:
		return inside(a, b) and all[idx(a, b)] == flr
	func put(a: int, b: int, name: String) -> bool:
		if not is_free(a, b) or not CG.TID.has(name):
			return false
		var i := idx(a, b)
		all[i] = CG.TID[name]
		under[i] = flr
		return true
	func wall(a: int, b: int) -> void:
		all[idx(a, b)] = CG.WALL
	func door(a: int, b: int) -> void:
		var i := idx(a, b)
		all[i] = CG.DOOR
		under[i] = flr
	func copy(a0: int, w0: int) -> U:
		var o := U.new()
		o.all = all; o.under = under; o.base = base; o.fr = fr; o.fa = fa + a0; o.w = w0; o.d = d
		o.wallrow = wallrow; o.front = front; o.flr = flr
		return o

## ------------------------------------------------------------------ the skeleton shared by every floor of a tower
## the corridor's depth for a tower D deep: in the middle of a deep tower (a row of units on each side), against the back wall of a
## middling one, and a narrower one in the smallest
static func layout(F: int, D: int) -> Dictionary:
	var mode := "mid"
	var cw := 3
	var n0: int
	if D >= 15:
		n0 = D / 2 - 1
	elif D >= 10:
		mode = "back"
		n0 = D - 4
	else:
		mode = "tiny"
		cw = 2
		n0 = D - 3
	var n1: int = n0 + cw - 1
	var fd: int = n0 - 2                                   # front rows: n = 1 .. n0 - 2, their door wall at n0 - 1
	var bd: int = (D - 2) - (n1 + 2) + 1                   # back rows: n = n1 + 2 .. D - 2, their door wall at n1 + 1
	return {"mode": mode, "cw": cw, "n0": n0, "n1": n1, "sn": n0 + (1 if cw == 3 else 0), "fs": F / 2 - 1, "fe": F / 2 + 1,
		"front_wall": (n0 - 1) if fd >= 4 else -1, "front_depth": fd if fd >= 4 else 0,
		"back_wall": (n1 + 1) if bd >= 4 else -1, "back_depth": bd if bd >= 4 else 0}

## which use a floor has: "office", "apartment" or "gym".  `t` carries "use" (office / apartment / hybrid), "split" and "gym_z"
static func floor_use(t: Dictionary, z: int) -> String:
	var use: String = t.get("use", "office")
	if use == "office":
		return "office"
	if use == "hybrid" and z < int(t["split"]):
		return "office"
	if z == int(t.get("gym_z", -1)):
		return "gym"
	return "apartment"

## the outer walls of a floor (glass with a pier every third cell, like every tower) and its floor
static func _shell(all: PackedByteArray, under: PackedByteArray, base: int, fr: Fr, flr: int) -> void:
	var size: int = fr.size
	for y in range(fr.y0, fr.y1 + 1):
		for x in range(fr.x0, fr.x1 + 1):
			var i: int = base + y * size + x
			var edge: bool = x == fr.x0 or x == fr.x1 or y == fr.y0 or y == fr.y1
			if not edge:
				all[i] = flr
				under[i] = flr
				continue
			var corner: bool = (x == fr.x0 or x == fr.x1) and (y == fr.y0 or y == fr.y1)
			var along: int = x if (y == fr.y0 or y == fr.y1) else y
			all[i] = CG.WALL if (corner or along % 3 == 0) else CG.GLASS

static func _set_f(all: PackedByteArray, under: PackedByteArray, base: int, fr: Fr, f: int, n: int, tid: int, flr: int = -1) -> void:
	var i: int = base + fr.idx(f, n)
	all[i] = tid
	if flr >= 0:
		under[i] = flr

## the corridor of a floor: carpet from end to end
static func _corridor(all: PackedByteArray, under: PackedByteArray, base: int, fr: Fr, lay: Dictionary, flr: int) -> void:
	for n in range(int(lay["n0"]), int(lay["n1"]) + 1):
		for f in range(1, fr.F - 1):
			_set_f(all, under, base, fr, f, n, flr, flr)

## a wall row between a row of units and the corridor
static func _wall_row(all: PackedByteArray, base: int, fr: Fr, n: int) -> void:
	for f in range(1, fr.F - 1):
		all[base + fr.idx(f, n)] = CG.WALL

## cut a row into segments along the front: widths between lo and hi, the last one takes the rest
static func _segments(total: int, lo: int, hi: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var left: int = total
	while left > 0:
		var w: int = rng.randi_range(lo, hi)
		if left - w - 1 < lo:
			w = left
		out.append(w)
		left -= w + 1                                 # a wall column between two segments
	return out

# ------------------------------------------------------------------ apartments
## one floor of flats.  Returns {homes: [cells], units: [{cell, rect}]}; cells are indices within the level
static func apartment_floor(all: PackedByteArray, under: PackedByteArray, base: int, fr: Fr, lay: Dictionary, wealth: int) -> Dictionary:
	var floor_flat: int = T("floor_parquet") if wealth >= 2 else T("floor_lino")
	var floor_corr: int = T("floor_carpet")
	_shell(all, under, base, fr, floor_flat)
	_corridor(all, under, base, fr, lay, floor_corr)
	var homes: Array = []
	var units: Array = []
	for zone in 2:
		var front: bool = zone == 0
		var wr: int = int(lay["front_wall"] if front else lay["back_wall"])
		var depth: int = int(lay["front_depth"] if front else lay["back_depth"])
		if wr < 0:
			continue
		_wall_row(all, base, fr, wr)
		var avail: int = fr.F - 2
		var count: int = maxi(1, int(round(float(avail + 1) / 9.5)))
		var each: int = (avail + 1) / count - 1
		var f: int = 1
		for k in count:
			var w: int = each if k < count - 1 else fr.F - 2 - f + 1
			var u := U.new()
			u.all = all; u.under = under; u.base = base; u.fr = fr; u.fa = f; u.w = w; u.d = depth; u.wallrow = wr; u.front = front; u.flr = floor_flat
			if k < count - 1:
				for b in depth:
					u.wall(w, b)                                   # the party wall to the next flat
			furnish_unit(u, wealth)
			var ad: int = 1
			u.door(ad, -1)
			under[u.idx(ad, -1)] = floor_corr
			var home: int = u.idx(ad, 1)
			homes.append(home - base)
			var r: Rect2i = fr.rect(f, (wr - depth) if front else (wr + 1), f + w - 1, (wr - 1) if front else (wr + depth))
			units.append({"cell": home - base, "rect": r})
			f += w + 1
	return {"homes": homes, "units": units}

## the flat: a bathroom in the corner by the door wall, the kitchen along the door wall, a bed against the window, a living corner
static func furnish_unit(u: U, wealth: int) -> void:
	var w: int = u.w
	var d: int = u.d
	var bx: int = w - 2
	var have_bath: bool = w >= 6 and d >= 4
	if have_bath:
		for b in 2:
			u.wall(bx - 1, b)
		for a in range(bx - 1, w):
			u.wall(a, 2)
		u.door(bx - 1, 1)
		u.put(w - 1, 0, "toilet")
		u.put(w - 1, 1, "bathtub" if wealth >= 2 else "shower")
	u.put(0, 0, "shoe_rack")
	var kitchen: Array = ["kitchen_counter", "kitchen_sink", "range", "fridge"] if wealth >= 1 else ["kitchen_counter", "kitchen_sink", "hot_plate"]
	var last: int = (bx - 2) if have_bath else (w - 1)
	for k in kitchen.size():
		if 2 + k > last:
			break
		u.put(2 + k, 0, kitchen[k])
	var wb: int = d - 1
	match wealth:
		0:
			u.put(w - 1, wb, "bunk_bed")
			u.put(w - 2, wb, "futon")
		1:
			u.put(w - 1, wb, "bed_single")
			if wb - 1 >= 3:
				u.put(w - 1, wb - 1, "wardrobe")
		_:
			u.put(w - 1, wb, "bed_double")
			if wb - 1 >= 3:
				u.put(w - 1, wb - 1, "wardrobe")
			u.put(w - 3, wb, "dresser")
	if d >= 5:
		u.put(2, wb, "tv_stand")
		if wealth == 0:
			u.put(2, wb - 2, "futon")
			u.put(2, wb - 1, "kotatsu")
			u.put(0, wb, "dresser")
		else:
			u.put(2, wb - 2, "sofa")
			u.put(2, wb - 1, "coffee_table")
		if wealth >= 2:
			u.put(0, wb, "bonsai")
			u.put(4, wb - 2, "armchair")
	else:
		u.put(2, wb, "tv_stand")

# ------------------------------------------------------------------ offices
## one floor of offices: open-plan suites and closed rooms of different sizes along the corridor.  Returns {works: [cells], rooms: [Rect2i]}
static func office_floor(all: PackedByteArray, under: PackedByteArray, base: int, fr: Fr, lay: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var flr: int = T("floor_carpet_grey")
	_shell(all, under, base, fr, flr)
	_corridor(all, under, base, fr, lay, flr)
	var works: Array = []
	var rooms: Array = []
	for zone in 2:
		var front: bool = zone == 0
		var wr: int = int(lay["front_wall"] if front else lay["back_wall"])
		var depth: int = int(lay["front_depth"] if front else lay["back_depth"])
		if wr < 0:
			continue
		_wall_row(all, base, fr, wr)
		var segs: Array = _segments(fr.F - 2, 7, 15, rng)
		var f: int = 1
		for k in segs.size():
			var w: int = int(segs[k])
			var u := U.new()
			u.all = all; u.under = under; u.base = base; u.fr = fr; u.fa = f; u.w = w; u.d = depth; u.wallrow = wr; u.front = front; u.flr = flr
			if k < segs.size() - 1:
				for b in depth:
					u.wall(w, b)
			var roll: float = rng.randf()
			var kind: String
			if w >= 9 and depth >= 5 and roll < 0.55:
				kind = "open"
			elif w >= 11 and roll < 0.7:
				kind = "private"
			elif roll < 0.8:
				kind = "meeting"
			elif roll < 0.88:
				kind = "executive"
			elif roll < 0.94:
				kind = "server"
			else:
				kind = "break"
			if kind == "open":
				_open_suite(u, rng, works)
			else:
				_closed_suite(u, kind, works, rooms)
			f += w + 1
	return {"works": works, "rooms": rooms}

## an open-plan suite: a wide opening onto the corridor, rows of workstations with a divider between neighbours and aisles between the rows
static func _open_suite(u: U, rng: RandomNumberGenerator, works: Array) -> void:
	var mid: int = u.w / 2
	for a in range(mid - 2, mid + 2):
		u.all[u.idx(a, -1)] = u.flr                              # the wall row is open here
	var placed := 0
	var b: int = 1
	while b + 1 < u.d:
		var a: int = 1
		while a + 1 < u.w:
			if u.put(a, b, "desk_workstation"):
				u.put(a, b + 1, "office_chair")
				u.put(a + 1, b, "cubicle_divider")
				u.put(a + 1, b + 1, "cubicle_divider")
				if placed < 4 and rng.randf() < 0.6:
					works.append(u.idx(a, b + 1) - u.base)
					placed += 1
			a += 3
		b += 3
	if placed == 0:
		works.append(u.idx(mid, 0) - u.base)
	u.put(u.w - 1, u.d - 1, "whiteboard")

## closed rooms: walled in with one door onto the corridor (a "private" suite is cut into several small offices)
static func _closed_suite(u: U, kind: String, works: Array, rooms: Array) -> void:
	if kind == "private":
		var n: int = maxi(2, u.w / 6)
		var each: int = (u.w + 1) / n - 1
		var a: int = 0
		for k in n:
			var rw: int = each if k < n - 1 else u.w - a
			var sub: U = u.copy(a, rw)
			if k < n - 1:
				for b in u.d:
					sub.wall(rw, b)
			sub.door(rw / 2, -1)
			sub.put(rw / 2, u.d - 2, "desk_workstation")
			sub.put(rw / 2, u.d - 3, "office_chair")
			works.append(sub.idx(rw / 2, u.d - 3) - u.base)
			sub.put(0, u.d - 1, "filing_cabinet")
			sub.put(rw - 1, u.d - 1, "office_shelf")
			rooms.append(_rect_of(sub))
			a += rw + 1
		return
	var cx: int = u.w / 2
	u.door(cx, -1)
	match kind:
		"meeting":
			for b in range(2, u.d - 2):
				for a in range(2, u.w - 2):
					u.put(a, b, "meeting_table")
			for a in range(2, u.w - 2, 2):
				u.put(a, 1, "office_chair")
				u.put(a, u.d - 2, "office_chair")
			u.put(0, u.d - 1, "whiteboard")
		"executive":
			u.put(cx, u.d - 2, "desk_executive")
			u.put(cx, u.d - 3, "office_chair")
			works.append(u.idx(cx, u.d - 3) - u.base)
			u.put(0, u.d - 1, "bookshelf")
			u.put(u.w - 1, u.d - 1, "bookshelf")
			u.put(0, 1, "lobby_sofa")
			u.put(u.w - 1, 1, "fern")
		"server":
			for b in range(1, u.d - 1, 2):
				for a in range(1, u.w - 1):
					if a != cx:
						u.put(a, b, "server_rack")
		_:
			u.put(0, 1, "kitchen_counter")
			u.put(1, 1, "kitchen_sink")
			u.put(2, 1, "fridge")
			u.put(u.w - 1, 1, "water_cooler")
			var a2: int = 2
			while a2 < u.w - 2:
				if u.put(a2, u.d - 2, "cafe_table"):
					u.put(a2 - 1, u.d - 2, "cafe_chair")
					u.put(a2 + 1, u.d - 2, "cafe_chair")
				a2 += 4
			works.append(u.idx(cx, 0) - u.base)
	rooms.append(_rect_of(u))

static func _rect_of(u: U) -> Rect2i:
	return _world_rect(u)

## the world rectangle of a unit's floor
static func _world_rect(u: U) -> Rect2i:
	var p0: Vector2i = u.fn(0, 0)
	var p1: Vector2i = u.fn(u.w - 1, u.d - 1)
	var a: Vector2i = u.fr.xy(p0.x, p0.y)
	var b: Vector2i = u.fr.xy(p1.x, p1.y)
	return Rect2i(mini(a.x, b.x), mini(a.y, b.y), absi(a.x - b.x) + 1, absi(a.y - b.y) + 1)

# ------------------------------------------------------------------ the gym floor
## the whole floor an open gym: treadmills along the windows, benches and racks on a loose lattice, lockers at one end, a mat corner
static func gym_floor(all: PackedByteArray, under: PackedByteArray, base: int, fr: Fr, lay: Dictionary) -> Dictionary:
	var rubber: int = T("floor_rubber")
	_shell(all, under, base, fr, rubber)
	var works: Array = []
	var fs: int = int(lay["fs"])
	var fe: int = int(lay["fe"])
	var sn: int = int(lay["sn"])
	var cf: int = (fs + fe) / 2
	var keep := func(f: int, n: int) -> bool:
		return absi(f - cf) <= 3 and absi(n - sn) <= 3        # the lifts stay clear
	var mat: int = T("floor_mat")
	var mw: int = mini(7, fr.F - 4)
	var md: int = mini(6, fr.D - 4)
	for n in range(fr.D - 1 - md, fr.D - 1):
		for f in range(fr.F - 1 - mw, fr.F - 1):
			if not keep.call(f, n):
				_set_f(all, under, base, fr, f, n, mat, mat)
	for k in 3:
		var f2: int = fr.F - 3 - k * 2
		var n2: int = fr.D - 2
		if not keep.call(f2, n2):
			_set_f(all, under, base, fr, f2, n2, T("punching_bag" if k % 2 == 0 else "training_dummy"), mat)
	for n in range(2, fr.D - 2, 2):
		if not keep.call(1, n):
			_set_f(all, under, base, fr, 1, n, T("locker"), rubber)
	for f in range(3, fr.F - 3, 2):
		for n in [1, fr.D - 2]:
			if not keep.call(f, n) and all[base + fr.idx(f, n)] == rubber:
				_set_f(all, under, base, fr, f, n, T("treadmill"), rubber)
	var kinds: Array = ["weight_bench", "squat_rack", "dumbbell_rack", "weight_bench"]
	var j := 0
	for n in range(4, fr.D - 4, 3):
		for f in range(4, fr.F - 4, 3):
			if keep.call(f, n):
				continue
			if all[base + fr.idx(f, n)] == rubber:
				_set_f(all, under, base, fr, f, n, T(String(kinds[j % kinds.size()])), rubber)
				j += 1
	for p in [Vector2i(fs - 2, sn + 2), Vector2i(fe + 2, sn - 2)]:
		if fr.inb(p.x, p.y) and all[base + fr.idx(p.x, p.y)] == rubber:
			works.append(fr.idx(p.x, p.y))
	return {"works": works, "rooms": []}

# ------------------------------------------------------------------ the ground floor
## the lobby of a tower, with a shop on the street side where there is room.  Writes the whole footprint of the ground floor and returns
## {door: Vector2i, biz: [records]}, or {} when no door can be put on the street (the tower is then left as it was)
static func ground(c, all: PackedByteArray, fr: Fr, lay: Dictionary, use: String, rng: RandomNumberGenerator) -> Dictionary:
	var size: int = fr.size
	var s2: int = size * size
	var F: int = fr.F
	var D: int = fr.D
	var n0: int = int(lay["n0"])
	var n1: int = int(lay["n1"])
	var mode: String = lay["mode"]
	var marble: int = T("floor_marble")
	if c.under.size() != s2:
		c.under = PackedByteArray()
		c.under.resize(s2)
	# where the shop goes: on the street side, beside an entry hall four cells wide
	var hall_hi: bool = rng.randf() < 0.5
	var can_front: bool = F >= 14 and ((mode == "mid" and D >= 20) or (mode == "back" and D >= 12))
	var can_back: bool = mode == "mid" and D >= 20 and F >= 10
	var hall_f0: int = (F - 5) if hall_hi else 1
	var hall_f1: int = hall_f0 + 3
	# the door: a hall cell (or the middle of the front when there is no shop) with walkable ground outside it
	var door_f: int = -1
	var order: Array = []
	if can_front:
		var mid_h: int = (hall_f0 + hall_f1) / 2
		order = [mid_h, mid_h + 1, mid_h - 1, hall_f0, hall_f1]
	else:
		for k in range(0, F / 2 - 1):
			order.append(F / 2 + k)
			order.append(F / 2 - k - 1)
	for f in order:
		if f < 1 or f > F - 2:
			continue
		var o: Vector2i = fr.xy(f, -1)
		if o.x < 0 or o.y < 0 or o.x >= size or o.y >= size:
			continue
		if CG.WALK[all[o.y * size + o.x]] == 1:
			door_f = f
			break
	if door_f < 0:
		return {}
	# clear the footprint, forget the old markers, lay the lobby floor and the walls
	_strip_markers(c, fr)
	for y in range(fr.y0, fr.y1 + 1):
		for x in range(fr.x0, fr.x1 + 1):
			var i: int = y * size + x
			var edge: bool = x == fr.x0 or x == fr.x1 or y == fr.y0 or y == fr.y1
			all[i] = CG.WALL if edge else marble
			if not edge:
				c.under[i] = marble
	for f in range(1, F - 1):
		if (not can_front) or (f >= hall_f0 and f <= hall_f1):
			if f % 3 != 0:
				all[fr.idx(f, 0)] = CG.GLASS                  # the lobby shows through to the street
	all[fr.idx(door_f, 0)] = CG.DOOR
	var res: Dictionary = {"door": fr.xy(door_f, 0), "biz": []}
	c.cur_zone = "core"
	if can_front:
		var rec = _place_shop(c, all, fr, 0, n0, F - 5, hall_hi, true, rng)
		if rec != null:
			res["biz"].append(rec)
	if can_back:
		var rec2 = _place_shop(c, all, fr, n1 + 1, D - n1 - 1, F, false, false, rng)
		if rec2 != null:
			res["biz"].append(rec2)
	_lobby_fittings(all, c, fr, lay, door_f, use, can_front, hall_hi, hall_f0, hall_f1)
	return res

## the shop's rectangle is `depth` rows from n_start and `span` wide along the front; the shop sits flush on the street (front) or against the
## corridor band (back) and faces the street's way.  `hall_hi` says which side of the front the hall is on.
static func _place_shop(c, all: PackedByteArray, fr: Fr, n_start: int, depth: int, span: int, hall_hi: bool, on_street: bool, rng: RandomNumberGenerator):
	var size: int = fr.size
	var sd: int = fr.side
	var ww: int = span if sd < 2 else depth
	var hh: int = depth if sd < 2 else span
	var id: String = ""
	if rng.randf() < 0.6:
		var okf: Array = []
		for k in ["restaurant", "cafe", "noodle_stall", "bar", "bakery", "convenience"]:
			if not BZ.fitting_side(k, ww, hh, sd).is_empty():
				okf.append(k)
		if not okf.is_empty():
			id = String(okf[rng.randi() % okf.size()])
	if id == "":
		id = c._pick_business(ww, hh, sd)
	if id == "":
		return null
	var fits: Array = BZ.fitting_side(id, ww, hh, sd)
	if fits.is_empty():
		return null
	var ver: int = fits[rng.randi() % fits.size()]
	if fits.size() > 1 and rng.randf() < 0.5:
		ver = fits[fits.size() - 1]
	var sz: Vector2i = BZ.size_of(id, ver, sd)
	var bf: int = sz.x if sd < 2 else sz.y
	var bn: int = sz.y if sd < 2 else sz.x
	var f0: int
	if on_street:
		f0 = 0 if hall_hi else fr.F - bf
	else:
		f0 = (fr.F - bf) / 2
	var rect: Rect2i = fr.rect(f0, n_start, f0 + bf - 1, n_start + bn - 1)
	# the shop's door is in the middle of its front wall: what is outside it must be walkable
	var dcell: Vector2i = fr.xy(f0 + 1 + (bf - 2) / 2, n_start - 1)
	if dcell.x < 0 or dcell.y < 0 or dcell.x >= size or dcell.y >= size or CG.WALK[all[dcell.y * size + dcell.x]] != 1:
		return null
	var w0: int = c.works.size()
	var s0: int = c.shops.size()
	var rec: Dictionary = BZ.stamp(c, id, ver, rect.position.x, rect.position.y, sd)
	for k in range(w0, c.works.size()):
		c.works_g.append(c.works[k])
	for k in range(s0, c.shops.size()):
		c.shops_g.append(c.shops[k])
	c.biz_count[id] = int(c.biz_count.get(id, 0)) + 1
	return rec

## drop the ground-floor markers the old plan left inside a tower
static func _strip_markers(c, fr: Fr) -> void:
	var s2: int = fr.size * fr.size
	for name in ["homes_g", "works_g", "shops_g"]:
		var src: PackedInt32Array = c.get(name)
		var keep := PackedInt32Array()
		for i in src:
			if i < s2:
				var x: int = i % fr.size
				var y: int = i / fr.size
				if x >= fr.x0 and x <= fr.x1 and y >= fr.y0 and y <= fr.y1:
					continue
			keep.append(i)
		c.set(name, keep)

## the directory and the mailboxes by the door, a reception desk by the lifts, sofas and plants at the ends of the band
static func _lobby_fittings(all: PackedByteArray, c, fr: Fr, lay: Dictionary, door_f: int, use: String, shops: bool, hall_hi: bool, hall_f0: int, hall_f1: int) -> void:
	var n0: int = int(lay["n0"])
	var n1: int = int(lay["n1"])
	var sn: int = int(lay["sn"])
	var fe: int = int(lay["fe"])
	var marble: int = T("floor_marble")
	var wall_f: int = (hall_f0 if hall_hi else hall_f1) if shops else 1
	var rows: Array = [[2, "directory_board"]]
	if use != "office":
		rows.append([3, "mailboxes"])
		rows.append([4, "mailboxes"])
	for r in rows:
		if fr.inb(wall_f, int(r[0])) and all[fr.idx(wall_f, int(r[0]))] == marble and absi(wall_f - door_f) > 0:
			all[fr.idx(wall_f, int(r[0]))] = T(String(r[1]))
	var rf: int = fe + 3
	if (use == "office" or c.rng.randf() < 0.5) and fr.inb(rf, n0) and all[fr.idx(rf, n0)] == marble and fr.inb(rf, sn):
		all[fr.idx(rf, n0)] = T("reception")
		c.works_g.append(fr.idx(rf, sn))
	for f in [2, fr.F - 3]:
		if absi(f - door_f) > 1:
			if all[fr.idx(f, n0)] == marble:
				all[fr.idx(f, n0)] = T("lobby_sofa")
			if all[fr.idx(f, n1)] == marble:
				all[fr.idx(f, n1)] = T("fern")
	if not shops:
		for f in range(2, fr.F - 2, 4):
			if absi(f - door_f) > 1 and all[fr.idx(f, 1)] == marble:
				all[fr.idx(f, 1)] = T("lobby_sofa")
				if all[fr.idx(f + 1, 1)] == marble:
					all[fr.idx(f + 1, 1)] = T("fern")
