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
	check.call("another seed gives a different one (%d of 400 samples differ)" % diff, diff > 6)
	# the sea all round
	check.call("open sea beyond every shore", a.terrain(5, 700) == CG.WATER and a.terrain(2000, 5) == CG.WATER and a.terrain(2000, ISL.H - 5) == CG.WATER and a.terrain(ISL.W - 5, 3000) == CG.WATER and a.terrain(ISL.W - 5, ISL.H - 5) == CG.WATER)
	var land := 0
	for k in 2000:
		if a.terrain((k * 389) % ISL.W, (k * 241) % ISL.H) != CG.WATER:
			land += 1
	check.call("the island is land in %d%% of a scatter (a long tapering island with a bay)" % (land / 20), land > 450 and land < 1100)
	# the shape of the guide: a point in the north, two capes in the south round a bay
	var north_tip := -1
	for y in range(100, 1200, 4):
		var hit := false
		for x in range(900, 2200, 6):
			if a.terrain(x, y) != CG.WATER:
				hit = true
				break
		if hit:
			north_tip = y
			break
	check.call("the island tapers to a point in the north (first land at row %d)" % north_tip, north_tip > 150 and north_tip < 700)
	var bay_ok: bool = a.terrain(2050, 6200) == CG.WATER and a.terrain(1000, 6200) != CG.WATER and a.terrain(3500, 6200) != CG.WATER
	check.call("the south bay lies between a west cape and an east cape", bay_ok)
	var sand := 0
	for y in range(900, 4000, 30):
		for x in range(300, 1800):
			if a.terrain(x, y) != CG.WATER:
				if a.terrain(x, y) == CG.SAND:
					sand += 1
				break
	check.call("the west shore is beach (%d of 104 rows)" % sand, sand >= 60)
	# the mountains: the caldera ring, the west range merged with it, and the range running on south to the cape
	var cvec := Vector2(float(ISL.CITY_CX), float(ISL.HWY_Y))
	var ring_hits := 0
	var ring_n := 0
	for k in 36:
		var ang: float = float(k) / 36.0 * TAU
		var px: int = int(cvec.x + cos(ang) * 570.0)
		var py: int = int(cvec.y + sin(ang) * 570.0)
		var from_south: float = absf(atan2(float(px) - cvec.x, float(py) - cvec.y))
		if from_south < 1.2:
			continue                                  # the ring is open to the south
		ring_n += 1
		if a._samp(a._g_mt, px, py) > 0.45:
			ring_hits += 1
	check.call("a ring of mountains closes the caldera except to the south (%d of %d points)" % [ring_hits, ring_n], ring_hits >= ring_n - 4)
	var south_open := 0
	for k in 8:
		var px2: int = int(cvec.x + (k - 3.5) * 40.0)
		if a._samp(a._g_mt, px2, int(cvec.y + 570.0)) < 0.2:
			south_open += 1
	check.call("... and the caldera opens south onto the bay (%d of 8)" % south_open, south_open >= 6)
	# flood the coarse mountain field: the north end of the west range reaches the south cape through the caldera
	var mt: PackedFloat32Array = a._g_mt
	var n0: Array = a._ridges[0][0]
	var n1: Array = a._ridges[1][a._ridges[1].size() - 1]
	var sx0: int = int(float(n0[0]) / ISL.GRID)
	var sy0: int = int(float(n0[1]) / ISL.GRID)
	var gx1: int = int(float(n1[0]) / ISL.GRID)
	var gy1: int = int(float(n1[1]) / ISL.GRID)
	var seen_m := {}
	var qm := [Vector2i(sx0, sy0)]
	seen_m[qm[0]] = true
	var hm := 0
	var joined := false
	while hm < qm.size():
		var cur: Vector2i = qm[hm]
		hm += 1
		if absi(cur.x - gx1) <= 2 and absi(cur.y - gy1) <= 2:
			joined = true
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			var nx: Vector2i = cur + d
			if nx.x < 0 or nx.y < 0 or nx.x >= ISL.GXN or nx.y >= ISL.GYN or seen_m.has(nx):
				continue
			if mt[nx.y * ISL.GXN + nx.x] > 0.3:
				seen_m[nx] = true
				qm.append(nx)
	check.call("the west range runs into the caldera's ring and on south to the cape: one unbroken massif (%d cells)" % seen_m.size(), joined)
	# the pass
	var xm: int = (a.PASS_X0 + ISL.PASS_X1) / 2
	var yc: int = a.pass_yc(xm)
	check.call("the pass is open ground with road and a two-track railway", a.terrain(xm, yc) == CG.ROAD and a.terrain(xm, yc + 9) == CG.TRACK and a.terrain(xm, yc + 10) == CG.TRACK and a.terrain(xm, yc + 13) == CG.TRACK and a.terrain(xm, yc + 14) == CG.TRACK)
	check.call("it is thin: walls of mountain close in beside it", a.terrain(xm, yc - 40) == CG.MOUNTAIN and a.terrain(xm, yc + 60) == CG.MOUNTAIN)
	var wind := 0
	for x in range(a.PASS_X0, ISL.PASS_X1):
		wind = maxi(wind, absi(a.pass_yc(x) - ISL.HWY_Y))
	check.call("and it winds (up to %d rows off line) over a long way (%d columns)" % [wind, ISL.PASS_X1 - a.PASS_X0], wind >= 20 and ISL.PASS_X1 - a.PASS_X0 > 900)
	var xo: int = a.PASS_X0 - 60
	check.call("the highway is six lanes wide (36 rows) outside the pass", a.pass_yc(xo) == ISL.HWY_Y and a.terrain(xo, ISL.HWY_Y - 18) == CG.ROAD and a.terrain(xo, ISL.HWY_Y + 17) == CG.ROAD and a.terrain(xo, ISL.HWY_Y - 19) != CG.ROAD)
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
		if cur.x >= ISL.PASS_X1 + 60:
			reached = true
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: Vector2i = cur + d
			if absi(nx.y - a.pass_yc(nx.x)) > 40 or seen.has(nx):
				continue
			if CG.WALK[a.terrain(nx.x, nx.y)] == 1:
				seen[nx] = true
				q.append(nx)
	check.call("you can walk from the port to the city through the pass", reached)
	# the long roads
	var rn: PackedInt32Array = a._roads_v[0]
	var smooth := true
	var rows_n := 0
	for y in range(1, ISL.H):
		if rn[y] >= 0 and rn[y - 1] >= 0:
			rows_n += 1
			if absi(rn[y] - rn[y - 1]) > 1:
				smooth = false
	var town_ok: bool = rn[ISL.TOWN.y] >= 0 and absi(rn[ISL.TOWN.y] + 6 - ISL.TOWN.x) <= 2
	var meets: bool = absi(rn[ISL.CITY_ORIGIN.y + 100] + 6 - ISL.NORTH_ROAD_X) <= 2
	check.call("the north road runs from the city through the town to the north point (%d rows, smooth: %s)" % [rows_n, str(smooth)], rows_n > 2800 and smooth and town_ok and meets)
	check.call("coast roads run south to both capes", (a._roads_v[1] as PackedInt32Array)[7000] >= 0 and (a._roads_v[2] as PackedInt32Array)[7100] >= 0)
	# zones
	check.call("zone ownership: the city owns its middle, the ferry port the west", ISL.zone_owner(ISL.CITY_CX, ISL.HWY_Y) == ISL.CITY_ZONE and ISL.zone_owner(a.PORT.x, a.PORT.y) == a.PORT_ZONE and ISL.zone_owner(ISL.TOWN.x, ISL.TOWN.y) == ISL.TOWN_ZONE and ISL.zone_owner(ISL.AIR_X0 + 100, ISL.AIR_Y) == ISL.AIR_ZONE)
	var co: Rect2i = ISL.CITY_OWN
	check.call("the city's territory is its big square (960 by 960), and its neighbours take over outside it", ISL.zone_owner(co.position.x, co.position.y + 480) == ISL.CITY_ZONE and ISL.zone_owner(co.end.x - 1, co.position.y + 480) == ISL.CITY_ZONE and ISL.zone_owner(co.position.x - 1, co.position.y + 480) != ISL.CITY_ZONE and ISL.zone_owner(co.end.x, co.position.y + 480) != ISL.CITY_ZONE and ISL.zone_owner(co.position.x + 480, co.position.y - 1) != ISL.CITY_ZONE and ISL.zone_owner(co.position.x + 480, co.end.y) != ISL.CITY_ZONE and co.size == Vector2i(960, 960))
	var kinds := {}
	for zx in ISL.NZX:
		for zy in ISL.NZY:
			var kd: String = a.zone_kind(Vector2i(zx, zy))
			kinds[kd] = kinds.get(kd, 0) + 1
	check.call("the zones: one city, one port, one town, one airstrip and a few industrial flats (%s)" % str(kinds), kinds.get("city", 0) == 1 and kinds.get("port", 0) == 1 and kinds.get("town", 0) == 1 and kinds.get("air", 0) == 1 and kinds.get("industry", 0) >= 3 and kinds.get("industry", 0) <= 8)
	var tiled := true
	for k in 600:
		var px: int = (k * 389) % ISL.W
		var py: int = (k * 241) % ISL.H
		var oz: Vector2i = ISL.zone_owner(px, py)
		var zo: Vector2i = ISL.zone_origin(oz.x, oz.y)
		var zs: int = ISL.zone_size(oz.x, oz.y)
		# every point belongs to a zone whose own map holds it (with at least 30 tiles to spare unless it is at the island's edge)
		if px < zo.x or py < zo.y or px >= zo.x + zs or py >= zo.y + zs:
			tiled = false
		if px >= zo.x + zs - 30 and zo.x + zs < ISL.W or px < zo.x + 30 and zo.x > 0:
			tiled = false
		if py >= zo.y + zs - 30 and zo.y + zs < ISL.H or py < zo.y + 30 and zo.y > 0:
			tiled = false
	check.call("every spot on the island belongs to a zone whose map holds it with room to spare", tiled)
	# the world
	var t0 := Time.get_ticks_msec()
	var w = World.new()
	w.start(7, 800)
	log.append("  (world start incl. the city zone: %d ms)" % (Time.get_ticks_msec() - t0))
	var g = w.game
	check.call("play starts in the city zone on a road", g.zone == ISL.CITY_ZONE and g.city.tiles[g.pc] == CG.ROAD)
	check.call("the city leaves its edges empty (no building within 60 of the border)", _clear_edges(g))
	var gp: Vector2i = g.global_pos()
	var CO: Vector2i = ISL.CITY_ORIGIN
	check.call("global position is the city origin plus local (%s)" % str(gp), gp.x >= CO.x and gp.x < CO.x + ISL.CZS and gp.y >= CO.y and gp.y < CO.y + ISL.CZS and g.size == ISL.CZS)
	# freight yard and rail in the city's west margin
	var rails := 0
	for x in range(0, 70):
		if g.city.tiles[(a.rail_ret(ISL.RAIL_X1) - CO.y) * g.size + x] == CG.TRACK:
			rails += 1
	check.call("the railway runs into the city's freight yard (%d track tiles)" % rails, rails >= 30)
	# walk west across the border
	var yrow: int = ISL.HWY_Y - CO.y + 2
	g.yen = 777
	g.pc = yrow * g.size + 40
	check.call("no change of zone mid-city", not w.poll())
	g.pc = yrow * g.size + 6
	var dest: Vector2i = ISL.zone_owner(CO.x + 6, CO.y + yrow)
	t0 = Time.get_ticks_msec()
	check.call("crossing the border hands over to the wild zone to the west %s" % str(dest), w.poll() and w.game.zone == dest and dest != ISL.CITY_ZONE)
	log.append("  (zone switch incl. generating it: %d ms)" % (Time.get_ticks_msec() - t0))
	var hg = w.game
	check.call("same spot on the island (%s -> %s)" % [str(gp), str(hg.global_pos())], hg.global_pos().x == CO.x + 6 and hg.global_pos().y == CO.y + yrow)
	check.call("the player's goods came along (¥%d, %d items)" % [hg.yen, hg.worn.size()], hg.yen == 777 and hg.worn.size() == 2 and hg.wield != null)
	check.call("you stand on walkable ground", hg.sim.walk[hg.pc] == 1)
	hg.yen = 123
	check.call("walking back hands the city back", not w.poll())
	hg.pc = (hg.global_pos().y - ISL.zone_origin(dest.x, dest.y).y) * hg.size + (CO.x + 60 - ISL.zone_origin(dest.x, dest.y).x)
	check.call("and over again returns to the city", w.poll() and w.game.zone == ISL.CITY_ZONE)
	check.call("the city is the one you left (cached), with your new yen", w.game.yen == 123 and w.game != g and w.game.sim.n == g.sim.n)
	# the ferry port, built on its own
	var pz: Vector2i = a.PORT_ZONE
	t0 = Time.get_ticks_msec()
	var pg = w._make(pz)
	log.append("  (building the port zone: %d ms)" % (Time.get_ticks_msec() - t0))
	check.call("the port has people, trucks, a mech and buildings", pg.sim.n == 220 and pg.vehicles.any(func(v): return v["kind"] == "truck") and pg.vehicles.any(func(v): return v["kind"] == "mech") and pg.city.buildings >= 4)
	var ai_trucks: int = pg.vehicles.filter(func(v): return v["ai"] and v["kind"] == "truck").size()
	check.call("trucks haul goods up and down the quay road all day (%d AI trucks)" % ai_trucks, ai_trucks >= 3)
	check.call("six gantry cranes stand over the quay road (%d)" % pg.city.cranes.size(), pg.city.cranes.size() == 6)
	var containers := 0
	for cc in pg.s2:
		if pg.city.tiles[cc] == pg.city.TID["container"]:
			containers += 1
	check.call("container stacks fill the yard (%d cells)" % containers, containers > 400)
	var north := 0
	var south := 0
	var civ := 0
	var oh: Vector2i = ISL.zone_origin(pz.x, pz.y)
	for i in pg.sim.n:
		var dy: int = pg.sim.pos[i] / pg.size + oh.y - a.PORT.y
		if pg.fac[i] == pg.GANG and dy < -54:
			north += 1
		elif pg.fac[i] == pg.BRATVA and dy > 54:
			south += 1
		elif pg.fac[i] == pg.CIV and absi(dy) <= 54:
			civ += 1
	check.call("criminals in the north (%d), Bratva in the south (%d), workers in the middle (%d)" % [north, south, civ], north >= 20 and south >= 15 and civ >= 30)
	# driving across with a car
	var cg = w.game
	for vi in cg.vehicles.size():
		cg.vs.lift(vi)
	cg.vehicles.clear()
	cg.veh_at.fill(-1)
	cg.in_vehicle = -1
	var e: int = int(cg.city.plan["trunk"])
	var cy2: int = VS.lane_k2(e, 1)
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
	while w.game == cg and guard < 60:
		guard += 1
		cg.act_move(-1, 0)
		w.poll()
	check.call("driving west carries the car over the border (%d moves)" % guard, w.game.zone != ISL.CITY_ZONE and w.game.in_vehicle >= 0 and w.game.vehicles[w.game.in_vehicle]["kind"] == "car")
	var wv = w.game.vehicles[w.game.in_vehicle]
	check.call("it is intact and its seat is the player's cell", w.game.pc == wv["cell"] and w.game.vs.probe(w.game.in_vehicle, wv["cell"], wv["dir"]).is_empty())
	check.call("it left the city: the city no longer has it", cg.vehicles.size() == 0 or not cg.vehicles.any(func(v): return v["color"] == Color.RED and v["kind"] == "car" and v["cell"] == wv["cell"]))
	var img: Image = a.overview_image(8)
	var lm: Array = a.landmarks()
	check.call("the map image covers the island and marks places (%dx%d, %d landmarks)" % [img.get_width(), img.get_height(), lm.size()], img.get_width() == ISL.W / 8 and img.get_height() == ISL.H / 8 and lm.size() >= 6 and img.get_pixel(ISL.CITY_CX / 8, ISL.HWY_Y / 8) != img.get_pixel(5, 5))
	# the railway through the mountain pass: a wild zone has no subway, and stepping onto the track used to crash (modulo by zero)
	var wz = pg
	var wo: Vector2i = ISL.zone_origin(wz.zone.x, wz.zone.y)
	var rx0: int = a.PORT.x + 50
	var rail_row: int = (a.rail_ret(rx0) - wo.y) * wz.size
	var rx: int = rx0 - wo.x
	wz.transit.adopt(cg.transit)
	check.call("the port shares the rail line with the city", wz.transit.active() and wz.transit.line.size() > 0 and wz.transit.path.size() == cg.transit.path.size())
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
	var m: int = ISL.MARGIN_ZONE - 8
	for y in range(0, g.size, 3):
		for x in range(0, g.size, 3):
			if x >= m and x < g.size - m and y >= m and y < g.size - m:
				continue
			var t: int = g.city.tiles[y * g.size + x]
			if t == CG.WALL or t == CG.FLOOR or t == CG.DOOR:
				return false
	return true
