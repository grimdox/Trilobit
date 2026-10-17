extends RefCounted
## The rail network: a single LINE that several trains run in a repeating loop on a fixed timetable.
## From the city's four subway stations (level -1) the line leaves through a tunnel on the west side, comes up into the daylight at a portal,
## runs along the island railway through the mountain pass to the Harbor Terminal on the port siding, turns round at the buffers and
## comes back on the second track, into the tunnel and round the city loop again.
##
## Trains are STATELESS: the timetable (one lap of the line, including the dwell at every stop) is tabulated once, and train j is wherever
## `table[(clock + offset_j) % period]` says.  `clock` is a turn counter that travels with the player from zone to zone, so each zone game
## draws only the part of the line that lies inside it and a train that leaves the city simply turns up in the harbor game.
## The line is a list of GLOBAL cells (gx, gy, z), so it does not care which zone a cell belongs to.
const CG = preload("res://src/citygen.gd")
const ISL = preload("res://src/island.gd")

const TRAINS := 3
const CARS := 4
const SPEED := 6
const DWELL := 7
const PORTAL_X := 62            # city-local column where the tunnel meets the daylight

var g
var line: Dictionary = {}       # {"path": PackedInt32Array, "stops": Array of [head_index, name]}
var clock: int = 0
var riding: int = -1            # the carriage the player is in, -1 if none
var rtrain: int = 0             # ... of this train
var laps: int = 0
var cars: int = CARS
var speed: int = SPEED
var dwell_turns: int = DWELL

# derived (not saved)
var path: PackedInt32Array
var stop_heads: PackedInt32Array
var stop_names: Array = []
var period: int = 1
var tab_head: PackedInt32Array
var tab_dwell: PackedInt32Array
var tab_stop: PackedInt32Array        # the stop being approached or stood at
var arrivals: Array = []              # per stop: the table indices at which the doors open
var offsets: PackedInt32Array
var cell_of: PackedInt32Array         # path index -> absolute cell in THIS game, or -1
var any_here: bool = false
var base: int = 0                     # first cell of level -1 (kept for the old tests)
var station_names := ["Harbor Gate", "Kuroda Plaza", "Ninth Street", "Old Market"]

# ------------------------------------------------------------------------------------------------ the line itself
static func pack(gx: int, gy: int, z: int) -> int:
	return ((z + 2) << 24) | (gy << 12) | gx

static func unpack(v: int) -> Vector3i:
	return Vector3i(v & 4095, (v >> 12) & 4095, ((v >> 24) & 7) - 2)

## build the line from a finished city game.  With no island it is just the subway loop.
static func build_line(city, island, zone: Vector2i) -> Dictionary:
	var sw: Dictionary = city.subway
	var ring: PackedInt32Array = sw["ring"]
	if ring.is_empty():
		return {}
	var size: int = city.size
	var o: Vector2i = island.zone_origin(zone.x, zone.y) if island != null else Vector2i.ZERO
	var names := ["Harbor Gate", "Kuroda Plaza", "Ninth Street", "Old Market"]
	var out := PackedInt32Array()
	var stops: Array = []
	var stop_ring: Array = sw["stops"]
	# the junction on the west side of the ring
	var iO := -1
	var iR := -1
	if island != null:
		var y_out: int = island.HWY_Y + 10 - o.y
		var y_ret: int = y_out - 1
		for i in ring.size():
			var rx: int = ring[i] % size
			var ry: int = ring[i] / size
			if ry == y_out and rx > 4 and iO < 0 and i > ring.size() / 2:
				iO = i
			if ry == y_ret and rx > 4 and iR < 0 and i > ring.size() / 2:
				iR = i
		if iO < 0 or iR != iO + 1 or ring[iO] % size != ring[iR] % size:
			iO = -1
	if iO < 0:
		for i in ring.size():
			out.append(pack(o.x + ring[i] % size, o.y + ring[i] / size, -1))
		for k in stop_ring.size():
			stops.append([int(stop_ring[k]) + 2, names[k % names.size()]])
		return {"path": out, "stops": stops}
	var xl: int = ring[iO] % size
	var y_out2: int = ring[iO] / size
	var y_ret2: int = ring[iR] / size
	# city loop from just after the return junction round to the outbound junction
	var order: Array = []
	for i in range(iR + 1, ring.size()):
		order.append(i)
	for i in range(0, iO + 1):
		order.append(i)
	for i in order:
		out.append(pack(o.x + ring[i] % size, o.y + ring[i] / size, -1))
	for k in stop_ring.size():
		var si: int = int(stop_ring[k])
		var pi: int = order.find(si)
		if pi >= 0:
			stops.append([(pi + 2) % out.size(), names[k % names.size()]])
	# the tunnel west to the portal
	for x in range(xl - 1, PORTAL_X - 1, -1):
		out.append(pack(o.x + x, o.y + y_out2, -1))
	# the daylight run: rows follow the winding pass
	var xt: int = int(island.west_x(island.PORT.y)) + 6 + 16
	var gx: int = o.x + PORTAL_X
	var prev_y := -1
	var ys_out: Array = []
	while gx >= xt:
		var gy: int = island.pass_yc(gx) + 10
		if prev_y >= 0:
			var stepv: int = signi(gy - prev_y)
			var yy: int = prev_y + stepv
			while stepv != 0 and yy != gy:
				out.append(pack(gx + 1, yy, 0))
				yy += stepv
		out.append(pack(gx, gy, 0))
		prev_y = gy
		gx -= 1
	var term_idx: int = out.size() - 1
	stops.append([term_idx, "Harbor Terminal"])
	# round the buffers and back on the return track
	var gx2: int = xt
	var prev2 := -1
	while gx2 <= o.x + PORTAL_X:
		var gy2: int = island.pass_yc(gx2) + 9
		if prev2 >= 0:
			var sv: int = signi(gy2 - prev2)
			var y3: int = prev2 + sv
			while sv != 0 and y3 != gy2:
				out.append(pack(gx2 - 1, y3, 0))
				y3 += sv
		out.append(pack(gx2, gy2, 0))
		prev2 = gy2
		gx2 += 1
	for x in range(PORTAL_X, xl):
		out.append(pack(o.x + x, o.y + y_ret2, -1))
	out.append(pack(o.x + xl, o.y + y_ret2, -1))
	stops.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	var order_names := ["Old Market", "Ninth Street", "Kuroda Plaza", "Harbor Gate"]
	var ci := 0
	for s in stops:
		if s[1] != "Harbor Terminal":
			s[1] = order_names[ci % order_names.size()]
			ci += 1
	return {"path": out, "stops": stops}

# ------------------------------------------------------------------------------------------------ per-game set-up
func setup(game) -> void:
	g = game
	if g.world != null and not g.world.line.is_empty():
		line = g.world.line
	elif g.zone == ISL.CITY_ZONE or g.island == null:
		line = build_line(g.city, g.island, g.zone if g.island != null else Vector2i.ZERO)
		if g.world != null:
			g.world.line = line
	_derive()

func _derive() -> void:
	if line.is_empty():
		path = PackedInt32Array()
		any_here = false
		cell_of = PackedInt32Array()
		return
	path = line["path"]
	stop_heads = PackedInt32Array()
	stop_names = []
	for s in line["stops"]:
		stop_heads.append(int(s[0]))
		stop_names.append(String(s[1]))
	_tabulate()
	var n: int = path.size()
	cell_of = PackedInt32Array()
	cell_of.resize(n)
	var o: Vector2i = g.island.zone_origin(g.zone.x, g.zone.y) if g.island != null else Vector2i.ZERO
	any_here = false
	for i in n:
		var v: Vector3i = unpack(path[i])
		var lx: int = v.x - o.x
		var ly: int = v.y - o.y
		var cell := -1
		if lx >= 0 and ly >= 0 and lx < g.size and ly < g.size and v.z >= -2 and v.z <= g.city.zmax:
			cell = g.city.lvl_of_z(v.z) * g.s2 + ly * g.size + lx
			any_here = true
		cell_of[i] = cell
	base = g.city.lvl_of_z(-1) * g.s2

## one lap of the timetable
func _tabulate() -> void:
	var n: int = path.size()
	tab_head = PackedInt32Array()
	tab_dwell = PackedInt32Array()
	tab_stop = PackedInt32Array()
	arrivals = []
	for _s in stop_heads.size():
		arrivals.append([])
	var h := 0
	var nx := 0
	# the first stop at or after head 0
	var best := 1 << 30
	for k in stop_heads.size():
		if int(stop_heads[k]) > 0 and int(stop_heads[k]) < best:
			best = int(stop_heads[k])
			nx = k
	var done := false
	var guard := 0
	while not done and guard < 20000:
		guard += 1
		var moved := 0
		var stopped := false
		while moved < speed:
			h += 1
			moved += 1
			if h >= n:
				h = n
				done = true
				break
			if stop_heads.size() > 0 and h == int(stop_heads[nx]):
				stopped = true
				break
		tab_head.append(h % n)
		tab_dwell.append(dwell_turns if stopped else 0)
		tab_stop.append(nx)
		if stopped:
			arrivals[nx].append(tab_head.size() - 1)
			for d in range(dwell_turns - 1, -1, -1):
				tab_head.append(h % n)
				tab_dwell.append(d)
				tab_stop.append(nx)
			nx = (nx + 1) % stop_heads.size()
			# the dwell already ran inside this block: re-label (first entry holds the full dwell)
		if done:
			break
	period = tab_head.size()
	offsets = PackedInt32Array()
	for j in TRAINS:
		offsets.append((period * j) / TRAINS)

func active() -> bool:
	return any_here

func _u(j: int) -> int:
	return (clock + int(offsets[j])) % period

## ring index of the front carriage (kept as `head` for callers that only care about the first train)
var head: int:
	get:
		return int(tab_head[_u(0)]) if period > 1 else 0
var dwell: int:
	get:
		return int(tab_dwell[_u(0)]) if period > 1 else 0
var nxt: int:
	get:
		return int(tab_stop[_u(0)]) if period > 1 else 0

func head_of(j: int) -> int:
	return int(tab_head[_u(j)])

func dwell_of(j: int) -> int:
	return int(tab_dwell[_u(j)])

func stop_of(j: int) -> int:
	return int(tab_stop[_u(j)])

## absolute cell of carriage k of train j (0 is the front), -1 when it is not in this zone
func cell_at(j: int, k: int) -> int:
	if path.is_empty():
		return -1
	var n: int = path.size()
	return int(cell_of[((head_of(j) - k) % n + n) % n])

func car_cell(k: int) -> int:
	return cell_at(0, k)

## unit direction (dx, dy) the carriage is travelling in (0,0 if it is on a level change)
func car_dir(j: int, k: int) -> Vector2i:
	var n: int = path.size()
	var i: int = ((head_of(j) - k) % n + n) % n
	var a: Vector3i = unpack(path[i])
	var b: Vector3i = unpack(path[(i + 1) % n])
	if a.z != b.z:
		b = unpack(path[(i + n - 1) % n])
		return Vector2i(signi(a.x - b.x), signi(a.y - b.y))
	return Vector2i(signi(b.x - a.x), signi(b.y - a.y))

func car_cells() -> Array:
	var out: Array = []
	for k in cars:
		out.append(cell_at(0, k))
	return out

## every carriage on the line: [[train, car, cell], ...] for those inside this zone
func all_cars() -> Array:
	var out: Array = []
	if not any_here:
		return out
	for j in TRAINS:
		for k in cars:
			var c: int = cell_at(j, k)
			if c >= 0:
				out.append([j, k, c])
	return out

## which carriage of which train is on a cell: [train, car] or []
func car_on(cell: int) -> Array:
	if not any_here:
		return []
	for j in TRAINS:
		for k in cars:
			if cell_at(j, k) == cell:
				return [j, k]
	return []

func car_at(cell: int) -> int:
	var r := car_on(cell)
	return -1 if r.is_empty() else int(r[1])

func stop_name(si: int) -> String:
	if si < stop_names.size():
		return stop_names[si]
	return station_names[si % station_names.size()]

## the cell the doors of stop si open onto (the middle of the train), or -1
func stop_cell(si: int) -> int:
	if si >= stop_heads.size():
		return -1
	var n: int = path.size()
	return int(cell_of[((int(stop_heads[si]) - 2) % n + n) % n])

## turns until the next train's doors open at stop si
func turns_to(si: int) -> int:
	var best := 1 << 30
	for j in TRAINS:
		var u: int = _u(j)
		if int(tab_dwell[u]) > 0 and int(tab_stop[u]) == si:
			return 0
		for a in arrivals[si]:
			best = mini(best, (int(a) - u + period) % period)
	return best

## for the HUD: the next arrival at the stop nearest the player (or the next stop of the train being ridden)
func next_arrival() -> Dictionary:
	if riding >= 0:
		var s: int = stop_of(rtrain)
		var d: int = dwell_of(rtrain)
		var t: int = d if d > 0 else _turns_for_train(rtrain, s)
		return {"turns": t, "stop": s, "dwelling": d > 0, "name": stop_name(s)}
	var bs := -1
	var bd := 1 << 30
	for si in stop_heads.size():
		var c: int = stop_cell(si)
		if c < 0:
			continue
		var dd: int = g.cheb(g.pc, c)
		if dd < bd:
			bd = dd
			bs = si
	if bs < 0:
		return {"turns": 0, "stop": 0, "dwelling": false, "name": "", "dist": 1 << 30}
	var t2: int = turns_to(bs)
	return {"turns": t2, "stop": bs, "dwelling": t2 == 0, "name": stop_name(bs), "dist": bd}

func _turns_for_train(j: int, si: int) -> int:
	var u: int = _u(j)
	var best := 1 << 30
	for a in arrivals[si]:
		best = mini(best, (int(a) - u + period) % period)
	return best

func step() -> void:
	if line.is_empty():
		return
	var prev: PackedInt32Array = PackedInt32Array()
	for j in TRAINS:
		prev.append(head_of(j))
	var was_dwell: int = dwell_of(rtrain) if riding >= 0 else 0
	clock += 1
	if clock % period == 0:
		laps += 1
	var n: int = path.size()
	for j in TRAINS:
		var h: int = head_of(j)
		var p: int = int(prev[j])
		var guard := 0
		while p != h and guard <= speed + 1:
			p = (p + 1) % n
			guard += 1
			if cell_of[p] >= 0:
				_sweep(int(cell_of[p]), j)
		if dwell_of(j) == 0 and was_dwell > 0 and riding >= 0 and j == rtrain:
			g.say("The doors chime and close.")
	for j in TRAINS:
		if int(tab_dwell[_u(j)]) == dwell_turns and _just_arrived(j):
			var si: int = stop_of(j)
			if riding >= 0 and rtrain == j:
				g.say("%s.  Doors open." % stop_name(si))
			elif any_here and g.cheb(g.pc, cell_at(j, 1)) < 14 and cell_at(j, 1) >= 0 and g.z_of(g.pc) == g.z_of(cell_at(j, 1)):
				g.say("A train pulls in with a long hiss.")
	if riding >= 0:
		var c: int = cell_at(rtrain, riding)
		if c >= 0:
			g.pc = c
		else:
			_cross_zone()

func _just_arrived(j: int) -> bool:
	return arrivals[stop_of(j)].has(_u(j))

## the carriage the player is in has left this zone: hand over to the zone it is now in
func _cross_zone() -> void:
	if g.world == null or g.island == null:
		return
	var n: int = path.size()
	var i: int = ((head_of(rtrain) - riding) % n + n) % n
	var v: Vector3i = unpack(path[i])
	var owner: Vector2i = ISL.zone_owner(v.x, v.y)
	if owner != g.zone:
		g.world.enter(owner)

## a freshly made zone game takes over the clock and the passenger
func adopt(from) -> void:
	clock = from.clock
	riding = from.riding
	rtrain = from.rtrain
	laps = from.laps

func seat_cell() -> int:
	if riding < 0:
		return -1
	return cell_at(rtrain, riding)

## whatever is on a cell a train front runs through
func _sweep(cell: int, _j: int) -> void:
	var who: int = g.sim.at[cell]
	if who >= 0 and g.sim.alive[who] == 1:
		g.say_if_seen(cell, "The train hits %s." % g.name_of(who))
		g.hurt(who, 200, false)
	if g.pc == cell and riding < 0:
		g.player_hurt(45, "The train hits you!")

## the player's move while riding.  Returns true if the move was consumed.
func ride_move(dx: int, dy: int) -> bool:
	if dwell_of(rtrain) == 0:
		g.say("The train is moving.")
		return true
	var to: int = g.pc + dy * g.size + dx
	var r := car_on(to)
	if not r.is_empty() and int(r[0]) == rtrain:
		riding = int(r[1])
		g.pc = to
		g.end_turn()
		return true
	if g.city.tiles[to] == CG.PLATFORM or g.city.tiles[to] == CG.STAIRS:
		var si: int = stop_of(rtrain)
		riding = -1
		g.pc = to
		g.say("You step off at %s." % stop_name(si))
		g.end_turn()
		return true
	g.say("You can't leave the train that way.")
	return true

## stepping onto a carriage from the platform: board if the doors are open
func try_board(to: int) -> bool:
	var r := car_on(to)
	if r.is_empty():
		return false
	var j: int = int(r[0])
	if dwell_of(j) == 0:
		g.say("The train rushes past.  Stay clear of the track.")
		return false
	riding = int(r[1])
	rtrain = j
	g.pc = to
	g.say("You board the train.  It will leave in %d turns." % dwell_of(j))
	return true

func save() -> Dictionary:
	var pl: Array = []
	if not line.is_empty():
		for v in line["path"]:
			pl.append(int(v))
	return {"clock": clock, "riding": riding, "rtrain": rtrain, "laps": laps,
		"line": {"path": pl, "stops": line.get("stops", [])}}

func load_from(d: Dictionary) -> void:
	clock = int(d.get("clock", 0))
	riding = int(d.get("riding", -1))
	rtrain = int(d.get("rtrain", 0))
	laps = int(d.get("laps", 0))
	if line.is_empty() and d.has("line") and not d["line"]["path"].is_empty():
		var pa := PackedInt32Array()
		for v in d["line"]["path"]:
			pa.append(int(v))
		var st: Array = []
		for s in d["line"]["stops"]:
			st.append([int(s[0]), String(s[1])])
		line = {"path": pa, "stops": st}
		if g.world != null and g.world.line.is_empty():
			g.world.line = line
		_derive()
