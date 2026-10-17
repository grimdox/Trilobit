extends RefCounted
## The rail line: several trains looping the city stations, out to the harbor terminal and back.  Returns [passed, total, log]
const World = preload("res://src/world.gd")
const TR = preload("res://src/transit.gd")
const CG = preload("res://src/citygen.gd")
const ISL = preload("res://src/island.gd")

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	var w = World.new()
	w.start(5, 300)
	var g = w.game
	var t = g.transit
	check.call("the city has the line (%d cells, %d stops)" % [t.path.size(), t.stop_heads.size()], t.active() and t.stop_heads.size() == 5)
	check.call("the last stop is the Harbor Terminal", t.stop_names.has("Harbor Terminal") and t.stop_names.has("Harbor Gate"))
	var gaps := 0
	var n: int = t.path.size()
	for i in n:
		var a: Vector3i = TR.unpack(t.path[i])
		var b: Vector3i = TR.unpack(t.path[(i + 1) % n])
		if a.z == b.z and maxi(absi(a.x - b.x), absi(a.y - b.y)) > 1:
			gaps += 1
		if a.z != b.z and (a.x != b.x or a.y != b.y):
			gaps += 1
	check.call("the line is one unbroken loop (%d gaps)" % gaps, gaps == 0)
	var heads := {}
	for j in TR.TRAINS:
		heads[t.head_of(j)] = true
	check.call("%d trains run it, spaced round the loop" % TR.TRAINS, TR.TRAINS >= 3 and heads.size() == TR.TRAINS)
	var bad := 0
	for i in n:
		var c: int = t.cell_of[i]
		if c >= 0:
			var tt: int = g.city.tiles[c]
			if tt != CG.TRACK and tt != CG.PLATFORM:
				bad += 1
	check.call("the whole line is laid on track in the city zone (%d cells off)" % bad, bad == 0)
	# the harbor game sees the same line and its terminal platform
	var hz = w._make(Vector2i(0, 1))
	var term: int = hz.transit.stop_cell(hz.transit.stop_names.find("Harbor Terminal"))
	var plat := false
	if term >= 0:
		for nb in [term - hz.size, term + hz.size, term - 1, term + 1]:
			if hz.city.tiles[nb] == CG.PLATFORM:
				plat = true
	check.call("the terminal is in the harbor zone, with a platform beside the track", term >= 0 and plat and hz.city.tiles[term] == CG.TRACK)
	var onrail := 0
	for i in n:
		var c2: int = hz.transit.cell_of[i]
		if c2 >= 0 and hz.city.tiles[c2] != CG.TRACK and TR.unpack(t.path[i]).z == 0:
			onrail += 1
	check.call("every harbor-zone cell of the line is track (%d off)" % onrail, onrail == 0 and hz.transit.any_here)
	# every stop is served: its doors open every lap
	var served := true
	for si in t.stop_heads.size():
		if t.arrivals[si].is_empty():
			served = false
	check.call("every stop sees a train each lap (period %d turns)" % t.period, served and t.period > 150)
	# ride: board at a city stop and stay on until we reach the harbor and come back
	var stop_i: int = t.stop_names.find("Harbor Gate")
	var guard := 0
	while t.turns_to(stop_i) > 0 and guard < 2000:
		t.clock += 1
		guard += 1
	check.call("a train stands at Harbor Gate (%d turns wait)" % guard, t.turns_to(stop_i) == 0)
	var mid: int = t.stop_cell(stop_i)
	var car: Array = t.car_on(mid)
	check.call("a carriage is at the platform", not car.is_empty())
	var plat2 := -1
	for nb in [mid - 1, mid + 1, mid - g.size, mid + g.size]:
		if g.city.tiles[nb] == CG.PLATFORM:
			plat2 = nb
	g.pc = plat2
	g.sim.retier(g.pc)
	g.act_move((mid % g.size) - (plat2 % g.size), ((mid / g.size) % g.size) - ((plat2 / g.size) % g.size))
	check.call("the player boards", t.riding >= 0)
	var visited_harbor := false
	var back_in_city := false
	var seat_ok := true
	var turns := 0
	var rode_clock0: int = t.clock
	while turns < t.period * 2 and w.game.hp > 0:
		w.game.act_wait()
		turns += 1
		var cg2 = w.game
		if cg2.transit.riding >= 0 and cg2.pc != cg2.transit.seat_cell():
			seat_ok = false
		if cg2.zone == Vector2i(0, 1):
			visited_harbor = true
		elif visited_harbor and cg2.zone == ISL.CITY_ZONE:
			back_in_city = true
		if back_in_city:
			break
	check.call("riding the line carries you into the harbor zone (%d turns)" % turns, visited_harbor)
	check.call("... and back into the city on the return run", back_in_city)
	check.call("the player's cell tracks the carriage the whole way", seat_ok)
	check.call("the clock carried over between zones", w.game.transit.clock >= rode_clock0 + turns - 2)
	# a train on a plain stand-alone city still works (no island)
	var GameScript = preload("res://src/game.gd")
	var g2 = GameScript.new(5)
	g2.setup(200)
	check.call("a stand-alone city loops the subway only", g2.transit.active() and g2.transit.stop_heads.size() == 4)
	return [st[0], st[1], log]
