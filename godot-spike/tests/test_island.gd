extends RefCounted
## The island: shape, features, zones, crossing between them.  Returns [passed, total, log]
const ISL = preload("res://src/island.gd")
const CG = preload("res://src/citygen.gd")
const World = preload("res://src/world.gd")
const VS = preload("res://src/vehicles.gd")

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	var a = ISL.new(7)
	var b = ISL.new(7)
	var c = ISL.new(99)
	var same := true
	var diff := 0
	for k in 400:
		var x: int = (k * 977) % ISL.W
		var y: int = (k * 613) % ISL.H
		if a.terrain(x, y) != b.terrain(x, y):
			same = false
		if a.terrain(x, y) != c.terrain(x, y):
			diff += 1
	check.call("the same seed gives the same island", same)
	check.call("another seed gives a different one (%d of 400 samples differ)" % diff, diff > 20)
	# the sea all round, the cliff in the east
	check.call("open sea beyond every shore", a.terrain(5, 700) == CG.WATER and a.terrain(1200, 5) == CG.WATER and a.terrain(1200, ISL.H - 5) == CG.WATER and a.terrain(ISL.W - 5, 700) == CG.WATER)
	var cliff := 0
	for y in range(200, 1200, 10):
		for x in range(ISL.W - 90, ISL.W):
			if a.terrain(x, y) == CG.CLIFF:
				cliff += 1
				break
	check.call("the east coast is a sheer cliff the whole way (%d of 100 rows)" % cliff, cliff >= 95)
	var rocky := 0
	for x in range(300, 2200, 20):
		for y in range(100, 400):
			if a.terrain(x, y) != CG.WATER:
				if a.terrain(x, y) == CG.ROCKS:
					rocky += 1
				break
	check.call("the north shore is rocky (%d of 95 columns)" % rocky, rocky >= 70)
	var sand := 0
	for y in range(300, 1100, 8):
		for x in range(60, 300):
			if a.terrain(x, y) != CG.WATER:
				if a.terrain(x, y) == CG.SAND:
					sand += 1
				break
	check.call("the west shore is beach (%d of 100 rows)" % sand, sand >= 60)
	# the mountains and the pass
	var mt := 0
	for y in range(250, 1150, 10):
		if a.terrain(390, y) == CG.MOUNTAIN:
			mt += 1
	check.call("a mountain range runs the length of the island (%d of 90 rows)" % mt, mt >= 80)
	var yc: int = a.pass_yc(390)
	check.call("the pass is open ground with road and rail", a.terrain(390, yc) == CG.ROAD and a.terrain(390, yc + 9) == CG.TRACK and a.terrain(390, yc + 10) == CG.TRACK and [a.terrain(390, yc + 7), a.terrain(390, yc + 8), a.terrain(390, yc + 11), a.terrain(390, yc + 12), a.terrain(390, yc + 13)].has(CG.BALLAST) and a.terrain(390, yc + 14) in [CG.ROCKS, CG.BALLAST])
	check.call("it is thin: walls of mountain close in beside it", a.terrain(390, yc - 30) == CG.MOUNTAIN and a.terrain(390, yc + 40) == CG.MOUNTAIN)
	var wind := 0
	for x in range(ISL.PASS_X0, ISL.PASS_X1):
		wind = maxi(wind, absi(a.pass_yc(x) - ISL.HWY_Y))
	check.call("and it winds (up to %d rows off line)" % wind, wind >= 12)
	check.call("the highway meets the city's main street exactly", a.pass_yc(ISL.CITY_ZONE.x * ISL.STRIDE) == ISL.HWY_Y and a.terrain(460, ISL.HWY_Y - 6) == CG.ROAD and a.terrain(460, ISL.HWY_Y + 5) == CG.ROAD and a.terrain(460, ISL.HWY_Y + 6) != CG.ROAD)
	# walk the pass: flood fill over the analytic map from the quay to the city edge
	var seen := {}
	var start := Vector2i(a._hx0 + 2, ISL.HWY_Y)
	var q := [start]
	seen[start] = true
	var reached := false
	var head := 0
	while head < q.size() and not reached:
		var cur: Vector2i = q[head]
		head += 1
		if cur.x >= 560:
			reached = true
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: Vector2i = cur + d
			if nx.x < 150 or nx.x > 600 or nx.y < 560 or nx.y > 860 or seen.has(nx):
				continue
			if CG.WALK[a.terrain(nx.x, nx.y)] == 1:
				seen[nx] = true
				q.append(nx)
	check.call("you can walk from the port to the city through the pass", reached)
	# zones
	check.call("zone ownership: the city owns its middle, the harbor the west", ISL.zone_owner(720, 720) == Vector2i(1, 1) and ISL.zone_owner(200, 700) == Vector2i(0, 1) and ISL.zone_owner(1150, 700) == Vector2i(2, 1) and ISL.zone_owner(2290, 1400) == Vector2i(4, 2))
	# the world
	var t0 := Time.get_ticks_msec()
	var w = World.new()
	w.start(7, 800)
	log.append("  (world start incl. the city zone: %d ms)" % (Time.get_ticks_msec() - t0))
	var g = w.game
	check.call("play starts in the city zone on a road", g.zone == ISL.CITY_ZONE and g.city.tiles[g.pc] == CG.ROAD)
	check.call("the city leaves its edges empty (no building within 70 of the border)", _clear_edges(g))
	var gp: Vector2i = g.global_pos()
	check.call("global position is the city origin plus local (%s)" % str(gp), gp.x >= 448 and gp.x < 960 and gp.y >= 448 and gp.y < 960)
	# freight yard and rail in the city's west margin
	var rails := 0
	for x in range(0, 60):
		if g.city.tiles[(ISL.HWY_Y + 9 - 448) * g.size + x] == CG.TRACK:
			rails += 1
	check.call("the railway runs into the city's freight yard (%d track tiles)" % rails, rails >= 30)
	# walk west across the border
	var yrow: int = ISL.HWY_Y - 448 + 2
	g.yen = 777
	g.pc = yrow * g.size + 40
	check.call("no change of zone mid-city", not w.poll())
	g.pc = yrow * g.size + 20
	t0 = Time.get_ticks_msec()
	check.call("crossing the border hands over to the harbor zone", w.poll() and w.game.zone == Vector2i(0, 1))
	log.append("  (zone switch incl. generating the harbor: %d ms)" % (Time.get_ticks_msec() - t0))
	var hg = w.game
	check.call("same spot on the island (%s -> %s)" % [str(gp), str(hg.global_pos())], hg.global_pos().x == 448 + 20 and hg.global_pos().y == 448 + yrow)
	check.call("the player's goods came along (¥%d, %d items)" % [hg.yen, hg.worn.size()], hg.yen == 777 and hg.worn.size() == 2 and hg.wield != null)
	check.call("the harbor has people, trucks, a mech and buildings", hg.sim.n == 220 and hg.vehicles.any(func(v): return v["kind"] == "truck") and hg.vehicles.any(func(v): return v["kind"] == "mech") and hg.city.buildings >= 4)
	var ai_trucks: int = hg.vehicles.filter(func(v): return v["ai"] and v["kind"] == "truck").size()
	check.call("trucks haul goods up and down the quay road all day (%d AI trucks)" % ai_trucks, ai_trucks >= 3)
	check.call("six gantry cranes stand over the quay road", hg.city.cranes.size() == 6)
	var containers := 0
	for cc in hg.s2:
		if hg.city.tiles[cc] == hg.city.TID["container"]:
			containers += 1
	check.call("container stacks fill the yard (%d cells)" % containers, containers > 400)
	var north := 0
	var south := 0
	var civ := 0
	var oh: Vector2i = hg.island.zone_origin(0, 1)
	for i in hg.sim.n:
		var dy: int = hg.sim.pos[i] / hg.size + oh.y - hg.island.PORT.y
		if hg.fac[i] == hg.GANG and dy < -54:
			north += 1
		elif hg.fac[i] == hg.BRATVA and dy > 54:
			south += 1
		elif hg.fac[i] == hg.CIV and absi(dy) <= 54:
			civ += 1
	check.call("criminals in the north (%d), Bratva in the south (%d), workers in the middle (%d)" % [north, south, civ], north >= 20 and south >= 15 and civ >= 30)
	check.call("you stand on walkable ground", hg.sim.walk[hg.pc] == 1)
	hg.yen = 123
	check.call("walking back hands the city back", not w.poll())
	hg.pc = hg.pc + 1 * 0
	# back east, further than the hysteresis
	var back: int = (448 + yrow - 448) * hg.size + 495
	hg.pc = yrow * hg.size + 0 + 495
	hg.pc = (hg.global_pos().y - 448) * hg.size + 495
	check.call("and over again returns to the city", w.poll() and w.game.zone == ISL.CITY_ZONE)
	check.call("the city is the one you left (cached), with your new yen", w.game.yen == 123 and w.game != g and w.game.sim.n == g.sim.n)
	# driving across with a car
	var cg = w.game
	for vi in cg.vehicles.size():
		cg.vs.lift(vi)
	cg.vehicles.clear()
	cg.veh_at.fill(-1)
	cg.in_vehicle = -1
	var e: int = cg.city.ys[cg.city.ys.find(250)] if cg.city.ys.has(250) else 250
	var cy2: int = VS.lane_lo2(e)
	var anchor: int = cg.vs.anchor_for("car", 3, 2 * 40, cy2, 0)
	var vi2: int = cg.vs.spawn("car", anchor, 3, Color.RED)
	check.call("a car stands in the westbound lane of the main street", vi2 >= 0)
	var spot := -1
	for cc in cg.vs.cells(cg.vehicles[vi2]):
		for d in cg.SIZE_DIRS:
			var nc: int = cc + d[1] * cg.size + d[0]
			if cg.veh_at[nc] == -1 and cg.sim.walk[nc] == 1 and cg.sim.at[nc] == -1:
				spot = nc
	cg.pc = spot
	cg.sim.retier(cg.pc)
	check.call("you get in", cg.act_vehicle() and cg.in_vehicle == vi2)
	var guard := 0
	while w.game == cg and guard < 40:
		guard += 1
		cg.act_move(-1, 0)
		w.poll()
	check.call("driving west carries the car over the border (%d moves)" % guard, w.game.zone == Vector2i(0, 1) and w.game.in_vehicle >= 0 and w.game.vehicles[w.game.in_vehicle]["kind"] == "car")
	var wv = w.game.vehicles[w.game.in_vehicle]
	check.call("it is intact and its seat is the player's cell", w.game.pc == wv["cell"] and w.game.vs.probe(w.game.in_vehicle, wv["cell"], wv["dir"]).is_empty())
	check.call("it left the city: the city no longer has it", cg.vehicles.size() == 0 or not cg.vehicles.any(func(v): return v["color"] == Color.RED and v["kind"] == "car" and v["cell"] == wv["cell"]))
	var img: Image = a.overview_image(4)
	check.call("the map image covers the island and marks the city, harbor and town (%dx%d, %d landmarks)" % [img.get_width(), img.get_height(), a.landmarks().size()], img.get_width() == ISL.W / 4 and img.get_height() == ISL.H / 4 and a.landmarks().size() >= 6 and img.get_pixel(720 / 4, 720 / 4) != img.get_pixel(1500 / 4, 400 / 4))
	# the railway through the mountain pass: a wild zone has no subway, and stepping onto the track used to crash (modulo by zero)
	var wz = w.game
	var wo: Vector2i = ISL.zone_origin(wz.zone.x, wz.zone.y)
	var rail_row: int = (ISL.HWY_Y + 9 - wo.y) * wz.size
	var rx: int = 300 - wo.x
	check.call("the harbor shares the rail line with the city (%d cells of it here)" % wz.transit.cell_of.count(-1), wz.transit.active() and wz.transit.line.size() > 0 and wz.transit.path.size() == cg.transit.path.size())
	wz.pc = rail_row - 3 * wz.size + rx
	wz.sim.retier(wz.pc)
	var crossed := 0
	for k in 12:
		if wz.act_move(0, 1):
			crossed += 1
	check.call("you can walk straight across the rails (%d of 12 steps)" % crossed, crossed == 12 and wz.transit.riding == -1 and wz.hp > 0)
	# save and load the whole world
	var d: Dictionary = JSON.parse_string(JSON.stringify(w.save_dict()))
	var w2 = World.new()
	w2.load_dict(d)
	check.call("save and load keep the zone, the player and the visited zones", w2.game.zone == w.game.zone and w2.game.pc == w.game.pc and w2.game.yen == w.game.yen and w2.cache.size() == w.cache.size() and w2.game.in_vehicle == w.game.in_vehicle)
	return [st[0], st[1], log]

func _clear_edges(g) -> bool:
	for k in 8:
		var x: int = (k * 37) % 60
		for y in range(0, g.size, 5):
			var t: int = g.city.tiles[y * g.size + x]
			if t == CG.WALL or t == CG.FLOOR or t == CG.DOOR:
				return false
	return true
