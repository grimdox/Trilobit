extends RefCounted
## The subway: a loop of track under the road grid (level -1) and a four-carriage train that runs it on a fixed schedule.
## It moves `speed` cells per turn, stops with its middle at each station for `dwell_turns` turns, and anything standing on the track
## when it comes through is hit.  The player boards by stepping onto a carriage while the doors are open and gets off onto a platform.
## The route is data (a ring of cells and a list of stops), so an airship or air-shuttle line is the same object with a different
## ring on a roof level and a different vehicle; nothing here knows about trains except the names and the track hazard.
const CG = preload("res://src/citygen.gd")
var g
var ring: PackedInt32Array
var stops: Array = []
var base: int = 0            # first cell of level -1
var head: int = 0            # ring index of the front carriage
var cars: int = 4
var speed: int = 6
var dwell_turns: int = 7
var dwell: int = 0
var nxt: int = 0             # index into stops of the next stop
var riding: int = -1         # the carriage the player is in, -1 if none
var laps: int = 0
var station_names := ["Harbor Gate", "Kuroda Plaza", "Ninth Street", "Old Market"]

func setup(game) -> void:
	g = game
	var sw: Dictionary = g.city.subway
	ring = sw["ring"]
	stops = sw["stops"]
	base = g.city.lvl_of_z(-1) * g.s2
	if ring.is_empty():
		return
	# start somewhere on the loop, a little before a stop
	head = (int(stops[1]) - 40 + ring.size()) % ring.size()
	nxt = 1

func active() -> bool:
	return not ring.is_empty()

## absolute cell of carriage k (0 is the front)
func car_cell(k: int) -> int:
	return base + ring[(head - k + ring.size() * 4) % ring.size()]

func car_cells() -> Array:
	var out: Array = []
	for k in cars:
		out.append(car_cell(k))
	return out

func car_at(cell: int) -> int:
	for k in cars:
		if car_cell(k) == cell:
			return k
	return -1

func stop_name(si: int) -> String:
	return station_names[si % station_names.size()]

## turns until the doors next open, and where
func next_arrival() -> Dictionary:
	var target: int = (int(stops[nxt]) + 2) % ring.size()
	var dist: int = (target - head + ring.size()) % ring.size()
	var t: int = dwell if dwell > 0 else int(ceil(float(dist) / speed))
	return {"turns": t, "stop": nxt, "dwelling": dwell > 0, "name": stop_name(nxt)}

func step() -> void:
	if not active():
		return
	if dwell > 0:
		dwell -= 1
		if dwell == 0 and riding >= 0:
			g.say("The doors chime and close.")
		return
	for _s in speed:
		head = (head + 1) % ring.size()
		_sweep(car_cell(0))
		if head == (int(stops[nxt]) + 2) % ring.size():
			dwell = dwell_turns
			if riding >= 0:
				g.say("%s.  Doors open." % stop_name(nxt))
			elif g.z_of(g.pc) == -1 and g.cheb(g.pc, car_cell(1)) < 14:
				g.say("A train pulls in with a long hiss.")
			nxt = (nxt + 1) % stops.size()
			if nxt == 0:
				laps += 1
			break
	if riding >= 0:
		g.pc = car_cell(riding)

## whatever is on a cell the train front runs through
func _sweep(cell: int) -> void:
	var who: int = g.sim.at[cell]
	if who >= 0 and g.sim.alive[who] == 1:
		g.say_if_seen(cell, "The train hits %s." % g.name_of(who))
		g.hurt(who, 200, false)
	if g.pc == cell and riding < 0:
		g.player_hurt(45, "The train hits you!")

## the player's move while riding.  Returns true if the move was consumed.
func ride_move(dx: int, dy: int) -> bool:
	if dwell == 0:
		g.say("The train is moving.")
		return true
	var to: int = g.pc + dy * g.size + dx
	var k := car_at(to)
	if k >= 0:
		riding = k
		g.pc = to
		g.end_turn()
		return true
	if g.city.tiles[to] == CG.PLATFORM or g.city.tiles[to] == CG.STAIRS:
		riding = -1
		g.pc = to
		g.say("You step off at %s." % stop_name((nxt + stops.size() - 1) % stops.size()))
		g.end_turn()
		return true
	g.say("You can't leave the train that way.")
	return true

## stepping onto a carriage from the platform: board if the doors are open
func try_board(to: int) -> bool:
	var k := car_at(to)
	if k < 0:
		return false
	if dwell == 0:
		g.say("The train rushes past.  Stay clear of the track.")
		return false
	riding = k
	g.pc = to
	g.say("You board the train.  It will leave in %d turns." % dwell)
	return true

func save() -> Dictionary:
	return {"head": head, "dwell": dwell, "nxt": nxt, "riding": riding, "laps": laps}

func load_from(d: Dictionary) -> void:
	head = int(d["head"])
	dwell = int(d["dwell"])
	nxt = int(d["nxt"])
	riding = int(d["riding"])
	laps = int(d["laps"])
