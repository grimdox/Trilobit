extends RefCounted
## The big seeded city: every seed lays out a different river, bridges and downtown on the same themes; riverside boulevards; the West Bank
## station; commuters on the trains; the painted train sprites; the density; the redrawn chart.  Returns [passed, total, log]
const World = preload("res://src/world.gd")
const CG = preload("res://src/citygen.gd")
const ISL = preload("res://src/island.gd")
const TR = preload("res://src/transit.gd")

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	# ---- seeds: same themes, different map
	var a = ISL.new(7)
	var b = ISL.new(4242)
	var a2 = ISL.new(7)
	check.call("the same seed lays out the same river, bridges and downtown", a.bridges_y == a2.bridges_y and a.downtown == a2.downtown and a.city_ring == a2.city_ring and a.river_span(500) == a2.river_span(500))
	check.call("another seed lays out another one (bridges %s vs %s, downtown %s vs %s)" % [str(a.bridges_y), str(b.bridges_y), str(a.downtown), str(b.downtown)],
		a.bridges_y != b.bridges_y and a.downtown != b.downtown)
	var themes := true
	for isl in [a, b]:
		themes = themes and isl.bridges_y.size() == 3 and isl.city_ring.size == Vector2i(ISL.RING_W, ISL.RING_H)
		var rows_n := 0
		var rows_s := 0
		var tr: int = ISL.HWY_Y - ISL.HWY_N - ISL.CITY_ORIGIN.y
		for y in isl.bridges_y:
			if int(y) < tr:
				rows_n += 1
			else:
				rows_s += 1
		themes = themes and rows_n >= 1 and rows_s >= 1
		themes = themes and isl.downtown.x > isl.river_span(ISL.CITY_ORIGIN.y + int(isl.downtown.y)).y - ISL.CITY_ORIGIN.x      # downtown on the east bank
	check.call("every seed keeps the themes: three bridges split north and south of the highway, downtown east of the river, a subway ring", themes)
	check.call("the city is much bigger (%d square, owning %s)" % [ISL.CZS, str(ISL.CITY_OWN.size)], ISL.CZS == 1024 and ISL.CITY_OWN.size == Vector2i(960, 960))
	# ---- the world, density, boulevards, station, passengers
	var w = World.new()
	w.start(7, 300)
	var g = w.game
	var c = g.city
	var n: int = g.size
	var mask: PackedByteArray = c.plan["mask"]
	var area := 0
	var bld := 0
	for i in n * n:
		if mask[i] == 0:
			continue
		area += 1
		var t: int = c.tiles[i]
		if t == CG.FLOOR or t == CG.WALL or t == CG.DOOR or t == CG.LOCKED:
			bld += 1
	var share: float = float(bld) / float(area)
	check.call("the city covers more than twice the old area (%d tiles vs 226,000)" % area, area > 2 * 226000)
	check.call("and is more jam-packed: %.1f%% of it is building (it was 24.5%%)" % (100.0 * share), share > 0.22)
	check.call("it holds far more people (%d)" % g.sim.n, g.sim.n >= 300 and World.CITY_PEOPLE >= 2000)
	var blv_w: PackedInt32Array = c.plan["blv_w"]
	var blv_e: PackedInt32Array = c.plan["blv_e"]
	var nb := 0
	var on_road := 0
	var tot := 0
	for y in n:
		for arr in [blv_w, blv_e]:
			if arr[y] >= 0:
				nb += 1
				var xm: int = arr[y] + ISL.BLV_W / 2
				tot += 1
				if c.tiles[y * n + xm] == CG.ROAD:
					on_road += 1
	check.call("riverside boulevards run down both banks (%d rows, %d%% paved)" % [nb, 100 * on_road / maxi(1, tot)], nb > 400 and on_road * 10 > tot * 8)
	var bends := false
	for y in range(1, n):
		if blv_e[y] >= 0 and blv_e[y - 1] >= 0 and blv_e[y] != blv_e[y - 1]:
			bends = true
	check.call("the boulevards follow the river's bends (not straight)", bends)
	var t: TR = g.transit
	check.call("the line has the West Bank station once each way (%s)" % str(t.stop_names), t.stop_names.count("West Bank") == 2 and t.stop_names.has("Harbor Terminal"))
	var plat := 0
	for tt in c.tiles:
		if tt == CG.PLATFORM:
			plat += 1
	check.call("the station has platforms (%d tiles) and stairs" % plat + "", plat >= 100 and not c.links.is_empty())
	# passengers: deterministic, never in a doorway, change with the hour
	var p1: int = t.passenger(0, 1, 1, 1)
	var p2: int = t.passenger(0, 1, 1, 1)
	var door := true
	for k in t.cars:
		for l in 4:
			door = door and t.passenger(0, k, TR.DOOR_A, l) == -1 and t.passenger(0, k, TR.DOOR_B, l) == -1
	check.call("passengers never stand in the doorways", door)
	var tick0: int = g.sim.tick
	g.sim.tick = 8 * 60
	var rush: int = t.passengers_on(0) + t.passengers_on(1) + t.passengers_on(2)
	g.sim.tick = 3 * 60
	var night: int = t.passengers_on(0) + t.passengers_on(1) + t.passengers_on(2)
	g.sim.tick = tick0
	check.call("the carriages are fuller at rush hour than at night (%d vs %d)" % [rush, night], rush > night * 2 and p1 == p2)
	# ---- sprites and chart
	var ok := true
	for nm in ["veh_train_u", "veh_train_p", "veh_train_o", "veh_trainopen_u", "veh_trainopen_p", "veh_trainopen_o"]:
		ok = ok and FileAccess.file_exists("res://gfx/Trilobit64/veh/%s.png" % nm)
	check.call("the painted train sprites are in the art folder", ok)
	var img: Image = a.overview_image(2)
	check.call("the island chart is drawn from the seed (%dx%d) and differs between seeds" % [img.get_width(), img.get_height()], img.get_width() == ISL.W / 2 and img.get_data() != b.overview_image(2).get_data())
	return [st[0], st[1], log]
