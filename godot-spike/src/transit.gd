extends RefCounted
## The rail network: a single LINE that several trains run in a repeating loop on a fixed timetable.
## From the city's four subway stations (level -1) the line leaves through a tunnel on the west side, comes up into the daylight at a portal,
## runs along the island railway through the mountain pass to the Harbor Terminal on the port siding, turns round at the buffers and
## comes back on the second track, into the tunnel and round the city loop again.
##
## GEOMETRY.  A track is two tiles wide: the path holds the first tile and the second is the one to its right (east of a vertical run,
## south of a horizontal one).  A train is four tiles wide centred on the track pair -- lane 0 a wall/door tile, lanes 1 and 2 the floor
## (standing room for passengers), lane 3 a wall/door tile -- and each carriage is six tiles long, four carriages to a train.
## The doors are the middle two tiles of each side wall; they open while the train is stopped.  Two-track lines run the tracks four
## rows apart so two trains pass wall to wall.
##
## Trains are STATELESS: the timetable (one lap of the line, including the dwell at every stop) is tabulated once, and train j is wherever
## `table[(clock + offset_j) % period]` says.  `clock` is a turn counter that travels with the player from zone to zone, so each zone game
## draws only the part of the line that lies inside it and a train that leaves the city simply turns up in the harbor game.
## The line is a list of GLOBAL cells (gx, gy, z), so it does not care which zone a cell belongs to.
const CG = preload("res://src/citygen.gd")
const ISL = preload("res://src/island.gd")

const TRAINS := 3
const CARS := 4
const CAR_LEN := 6
const TRAIN_LEN := CARS * CAR_LEN
const SPEED := 6
const DWELL := 7
const PORTAL_X := 62            # city-local column where the tunnel meets the daylight
const DOOR_A := 2               # the doors are at these two positions along each carriage
const DOOR_B := 3

var g
var line: Dictionary = {}       # {"path": PackedInt32Array, "stops": Array of [head_index, name]}
var clock: int = 0
var riding: int = -1            # the carriage the player is in, -1 if none
var ri: int = 0                 # ... how far back along that carriage (0..5) and which lane (0..3) they stand in
var rl: int = 1
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
var cell_of: PackedInt32Array         # path index -> absolute cell of the first track tile in THIS game, or -1
var lane_cell: Array = []             # 4 arrays: lane -> path index -> absolute cell here, or -1
var axis: PackedByteArray             # 0 = running east-west, 1 = north-south
var fdx: PackedInt32Array             # direction of travel at each path index
var fdy: PackedInt32Array
var any_here: bool = false
var base: int = 0                     # first cell of level -1 (kept for the old tests)
var _occ: Dictionary = {}
var _occ_clock: int = -1
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
	var iO := -1
	var iR := -1
	var xw := 0
	var xe := 0
	if island != null and not city.plan.is_empty():
		var rb: Dictionary = city.plan["rail"]
		var y_out: int = rb["y_out"]
		var y_ret: int = rb["y_ret"]
		xw = rb["xw"]
		xe = rb["xe"]
		var xl := size
		for cell in ring:
			xl = mini(xl, cell % size)
		for i in ring.size():
			var rx: int = ring[i] % size
			var ry: int = ring[i] / size
			if rx == xl and ry == y_out:
				iO = i
			if rx == xl and ry == y_ret:
				iR = i
		if iO < 0 or iR != iO + 4:
			iO = -1
	if iO < 0:
		for i in ring.size():
			out.append(pack(o.x + ring[i] % size, o.y + ring[i] / size, -1))
		for k in stop_ring.size():
			stops.append([(int(stop_ring[k]) + TRAIN_LEN / 2) % out.size(), names[k % names.size()]])
		return {"path": out, "stops": stops}
	var xl2: int = ring[iO] % size
	var y_o: int = ring[iO] / size
	var y_r: int = ring[iR] / size
	# the city loop from just after the return junction round to the outbound junction
	var order: Array = []
	for i in range(iR + 1, ring.size()):
		order.append(i)
	for i in range(0, iO + 1):
		order.append(i)
	for i in order:
		out.append(pack(o.x + ring[i] % size, o.y + ring[i] / size, -1))
	for k in stop_ring.size():
		var pi: int = order.find(int(stop_ring[k]))
		if pi >= 0:
			stops.append([(pi + TRAIN_LEN / 2) % out.size(), names[k % names.size()]])
	# the tunnel west under the downtown to the bridge portal, the rail bridge over the river in the daylight, and the tunnel on to the island portal
	for x in range(xl2 - 1, xe - 1, -1):
		out.append(pack(o.x + x, o.y + y_o, -1))
	for x in range(xe, xw - 1, -1):
		out.append(pack(o.x + x, o.y + y_o, 0))
	for x in range(xw, PORTAL_X - 1, -1):
		out.append(pack(o.x + x, o.y + y_o, -1))
	# the daylight run on the outbound (south) track: rows follow the winding pass
	var xt: int = int(island.west_x(island.PORT.y)) + 6 + 16
	var gx: int = o.x + PORTAL_X
	var prev_y := -1
	while gx >= xt:
		var gy: int = island.rail_out(gx)
		if prev_y >= 0:
			var stepv: int = signi(gy - prev_y)
			var yy: int = prev_y + stepv
			while stepv != 0 and yy != gy:
				out.append(pack(gx + 1, yy, 0))
				yy += stepv
		out.append(pack(gx, gy, 0))
		prev_y = gy
		gx -= 1
	stops.append([out.size() - 1, "Harbor Terminal"])
	# round the buffers (up the connecting tracks) and back on the return track
	var ys: int = island.rail_out(xt)
	var yn: int = island.rail_ret(xt)
	for yy in range(ys - 1, yn - 1, -1):
		out.append(pack(xt, yy, 0))
	var gx2: int = xt + 1
	var prev2: int = yn
	while gx2 <= o.x + PORTAL_X:
		var gy2: int = island.rail_ret(gx2)
		var sv: int = signi(gy2 - prev2)
		var y3: int = prev2 + sv
		while sv != 0 and y3 != gy2:
			out.append(pack(gx2 - 1, y3, 0))
			y3 += sv
		out.append(pack(gx2, gy2, 0))
		prev2 = gy2
		gx2 += 1
	for x in range(PORTAL_X, xw + 1):
		out.append(pack(o.x + x, o.y + y_r, -1))
	for x in range(xw, xe + 1):
		out.append(pack(o.x + x, o.y + y_r, 0))
	for x in range(xe, xl2 + 1):
		out.append(pack(o.x + x, o.y + y_r, -1))
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
	_occ_clock = -1
	if line.is_empty():
		path = PackedInt32Array()
		any_here = false
		cell_of = PackedInt32Array()
		lane_cell = []
		return
	path = line["path"]
	stop_heads = PackedInt32Array()
	stop_names = []
	for s in line["stops"]:
		stop_heads.append(int(s[0]))
		stop_names.append(String(s[1]))
	_tabulate()
	var n: int = path.size()
	axis = PackedByteArray()
	axis.resize(n)
	fdx = PackedInt32Array()
	fdx.resize(n)
	fdy = PackedInt32Array()
	fdy.resize(n)
	for i in n:
		var v: Vector3i = unpack(path[i])
		var pv: Vector3i = unpack(path[(i + n - 1) % n])
		var nv: Vector3i = unpack(path[(i + 1) % n])
		if pv.z != v.z:
			pv = v
		if nv.z != v.z:
			nv = v
		var ddx: int = nv.x - pv.x
		var ddy: int = nv.y - pv.y
		axis[i] = 0 if absi(ddx) >= absi(ddy) else 1
		# the way the train is heading here (towards the next cell if there is one, else away from the previous)
		var fx: int = signi(nv.x - v.x)
		var fy: int = signi(nv.y - v.y)
		if fx == 0 and fy == 0:
			fx = signi(v.x - pv.x)
			fy = signi(v.y - pv.y)
		fdx[i] = fx
		fdy[i] = fy
	var o: Vector2i = g.island.zone_origin(g.zone.x, g.zone.y) if g.island != null else Vector2i.ZERO
	cell_of = PackedInt32Array()
	cell_of.resize(n)
	lane_cell = []
	for l in 4:
		var arr := PackedInt32Array()
		arr.resize(n)
		lane_cell.append(arr)
	any_here = false
	for i in n:
		var v2: Vector3i = unpack(path[i])
		for l in 4:
			var lx: int = v2.x - o.x + (0 if axis[i] == 0 else l - 1)
			var ly: int = v2.y - o.y + (l - 1 if axis[i] == 0 else 0)
			var cell := -1
			if lx >= 0 and ly >= 0 and lx < g.size and ly < g.size and v2.z >= -2 and v2.z <= g.city.zmax:
				cell = g.city.lvl_of_z(v2.z) * g.s2 + ly * g.size + lx
				any_here = true
			lane_cell[l][i] = cell
		cell_of[i] = _track_cell(v2, o)
	base = g.city.lvl_of_z(-1) * g.s2

## the absolute cell (in this game) of the first track tile at a path position
func _track_cell(v: Vector3i, o: Vector2i) -> int:
	var lx: int = v.x - o.x
	var ly: int = v.y - o.y
	if lx >= 0 and ly >= 0 and lx < g.size and ly < g.size and v.z >= -2 and v.z <= g.city.zmax:
		return g.city.lvl_of_z(v.z) * g.s2 + ly * g.size + lx
	return -1

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

## path index of the front of train 0 (kept for callers that only care about the first train)
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

## path index of position i (0 = the front) of carriage k of train j
func pidx(j: int, k: int, i: int) -> int:
	var n: int = path.size()
	return ((head_of(j) - k * CAR_LEN - i) % n + n) % n

## absolute cell (here) of lane l at position i of carriage k of train j, or -1
func cell_at(j: int, k: int, i: int = 0, l: int = 1) -> int:
	if path.is_empty():
		return -1
	return int(lane_cell[l][pidx(j, k, i)])

func car_cell(k: int) -> int:
	return cell_at(0, k, CAR_LEN / 2, 1)

func car_cells() -> Array:
	var out: Array = []
	for k in cars:
		out.append(car_cell(k))
	return out

# ---- who is where: cell -> packed (train, car, position, lane)
static func occ_pack(j: int, k: int, i: int, l: int) -> int:
	return ((j * 8 + k) * 8 + i) * 4 + l

static func occ_unpack(v: int) -> Array:
	return [v / 256, (v / 32) % 8, (v / 4) % 8, v % 4]

## every cell of every train inside this zone
func occupancy() -> Dictionary:
	if _occ_clock == clock and not _occ.is_empty():
		return _occ
	_occ = {}
	_occ_clock = clock
	if not any_here:
		return _occ
	for j in TRAINS:
		for k in cars:
			for i in CAR_LEN:
				var pi: int = pidx(j, k, i)
				for l in 4:
					var c: int = lane_cell[l][pi]
					if c >= 0:
						_occ[c] = occ_pack(j, k, i, l)
	return _occ

func occupied(cell: int) -> bool:
	return any_here and occupancy().has(cell)

## which carriage of which train is on a cell: [train, car, position, lane] or []
func car_on(cell: int) -> Array:
	if not any_here:
		return []
	var v: int = int(occupancy().get(cell, -1))
	return [] if v < 0 else occ_unpack(v)

func car_at(cell: int) -> int:
	var r := car_on(cell)
	return -1 if r.is_empty() else int(r[1])

## unit direction (dx, dy) the carriage is travelling in
func dir_at(j: int, k: int, i: int) -> Vector2i:
	var pi: int = pidx(j, k, i)
	return Vector2i(int(fdx[pi]), int(fdy[pi]))

func axis_at(j: int, k: int, i: int) -> int:
	return int(axis[pidx(j, k, i)])

func stop_name(si: int) -> String:
	if si < stop_names.size():
		return stop_names[si]
	return station_names[si % station_names.size()]

## the cell the middle of a stopped train sits on at stop si (a floor tile), or -1
func stop_cell(si: int) -> int:
	if si >= stop_heads.size():
		return -1
	var n: int = path.size()
	return int(lane_cell[1][((int(stop_heads[si]) - TRAIN_LEN / 2) % n + n) % n])

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
			if any_here:
				for l in 4:
					var c: int = lane_cell[l][p]
					if c >= 0:
						_sweep(c)
		if dwell_of(j) == 0 and was_dwell > 0 and riding >= 0 and j == rtrain:
			g.say("The doors chime and close.")
			if rl == 0 or rl == 3:
				rl = 1 if rl == 0 else 2
	for j in TRAINS:
		if int(tab_dwell[_u(j)]) == dwell_turns and _just_arrived(j):
			var si: int = stop_of(j)
			if riding >= 0 and rtrain == j:
				g.say("%s.  Doors open." % stop_name(si))
			elif any_here:
				var mc: int = cell_at(j, 1, 3, 1)
				if mc >= 0 and g.cheb(g.pc, mc) < 20 and g.z_of(g.pc) == g.z_of(mc):
					g.say("A train pulls in with a long hiss.")
	if riding >= 0:
		var c2: int = seat_cell()
		if c2 >= 0:
			g.pc = c2
		else:
			_cross_zone()

func _just_arrived(j: int) -> bool:
	return arrivals[stop_of(j)].has(_u(j))

## the carriage the player is in has left this zone: hand over to the zone it is now in
func _cross_zone() -> void:
	if g.world == null or g.island == null:
		return
	var v: Vector3i = unpack(path[pidx(rtrain, riding, ri)])
	var owner: Vector2i = ISL.zone_owner(v.x, v.y)
	if owner != g.zone:
		g.world.enter(owner)

## a freshly made zone game takes over the clock and the passenger
func adopt(from) -> void:
	clock = from.clock
	riding = from.riding
	rtrain = from.rtrain
	ri = from.ri
	rl = from.rl
	laps = from.laps
	_occ_clock = -1

func seat_cell() -> int:
	if riding < 0:
		return -1
	return cell_at(rtrain, riding, ri, rl)

## whatever is on a cell a train front runs through
func _sweep(cell: int) -> void:
	var who: int = g.sim.at[cell]
	if who >= 0 and g.sim.alive[who] == 1:
		g.say_if_seen(cell, "The train hits %s." % g.name_of(who))
		g.hurt(who, 200, false)
	if g.pc == cell and riding < 0:
		g.player_hurt(45, "The train hits you!")

## the player's move while riding.  Returns true if the move was consumed.
func ride_move(dx: int, dy: int) -> bool:
	var to: int = g.pc + dy * g.size + dx
	var r := car_on(to)
	if not r.is_empty():
		if int(r[0]) != rtrain:
			g.say("That is another train.")
			return true
		var l: int = int(r[3])
		var i: int = int(r[2])
		var open: bool = dwell_of(rtrain) > 0
		if l == 1 or l == 2 or (open and (i == DOOR_A or i == DOOR_B)):
			riding = int(r[1])
			ri = i
			rl = l
			g.pc = to
			g.end_turn()
			return true
		g.say("A solid carriage wall.  The doors are further along." if open else "A solid carriage wall.")
		return true
	if dwell_of(rtrain) > 0 and (rl == 0 or rl == 3) and (ri == DOOR_A or ri == DOOR_B) and (g.city.tiles[to] == CG.PLATFORM or g.city.tiles[to] == CG.STAIRS):
		var si: int = stop_of(rtrain)
		riding = -1
		g.pc = to
		g.say("You step off at %s." % stop_name(si))
		g.end_turn()
		return true
	g.say("You can't leave the train that way.")
	return true

## stepping onto a train from outside: board through an open door.  False if you cannot (the move is then refused).
func try_board(to: int) -> bool:
	var r := car_on(to)
	if r.is_empty():
		return false
	var j: int = int(r[0])
	var l: int = int(r[3])
	var i: int = int(r[2])
	if dwell_of(j) == 0:
		g.say("The train rushes past.  Stay clear of the track.")
		return false
	if (l == 0 or l == 3) and (i == DOOR_A or i == DOOR_B):
		riding = int(r[1])
		rtrain = j
		ri = i
		rl = l
		g.pc = to
		g.say("You board the train.  It will leave in %d turns." % dwell_of(j))
		return true
	g.say("The doors are further along the carriage.")
	return false

func save() -> Dictionary:
	var pl: Array = []
	if not line.is_empty():
		for v in line["path"]:
			pl.append(int(v))
	return {"clock": clock, "riding": riding, "rtrain": rtrain, "ri": ri, "rl": rl, "laps": laps,
		"line": {"path": pl, "stops": line.get("stops", [])}}

func load_from(d: Dictionary) -> void:
	clock = int(d.get("clock", 0))
	riding = int(d.get("riding", -1))
	rtrain = int(d.get("rtrain", 0))
	ri = int(d.get("ri", 2))
	rl = int(d.get("rl", 1))
	laps = int(d.get("laps", 0))
	_occ_clock = -1
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
