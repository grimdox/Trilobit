extends RefCounted
## Spike test 3: the anchored overworld and the city.
const WG = preload("res://src/worldgen.gd")
const CG = preload("res://src/citygen.gd")

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	var cfg = JSON.parse_string(FileAccess.open("res://data/anchors.json", FileAccess.READ).get_as_text())
	# anchors in every one of 100 seeds
	var missing := 0
	var coast_sides := {}
	var harbor_on_coast := 0
	var airport_ok := 0
	var city_x := []
	var sigs := {}
	for s in range(1, 101):
		var wg = WG.new()
		wg.generate(s, cfg)
		sigs[wg.signature()] = true
		for need in [WG.SEA, WG.MOUNTAIN, WG.CITY_CORE, WG.HARBOR, WG.AIRPORT, WG.INDUSTRIAL]:
			if wg.count(need) == 0:
				missing += 1
		coast_sides[wg.anchors["coast"]["side"]] = true
		city_x.append(wg.anchors["big_city"]["pos"].x)
		# harbor touches the sea
		var hp: Vector2i = wg.anchors["harbor"]["pos"]
		var near_sea := false
		for dy in range(-6, 7):
			for dx in range(-6, 7):
				var x := hp.x + dx
				var y := hp.y + dy
				if x >= 0 and y >= 0 and x < wg.w and y < wg.h and wg.cells[y * wg.w + x] == WG.SEA:
					near_sea = true
		if near_sea:
			harbor_on_coast += 1
		var ap: Vector2i = wg.anchors["airport"]["pos"]
		var cp: Vector2i = wg.anchors["big_city"]["pos"]
		if (ap - cp).length() > wg.anchors["big_city"]["radius"]:
			airport_ok += 1
	check.call("sea, mountains, city, harbor, airport and industrial belt exist in all 100 seeds", missing == 0)
	check.call("the harbor sits on the sea in all 100 seeds (relational anchor)", harbor_on_coast == 100)
	check.call("the airport sits outside the city in all 100 seeds", airport_ok == 100)
	check.call("the coast appears on more than one side across seeds", coast_sides.size() >= 2)
	check.call("the city moves between seeds (more than 8 distinct x positions)", _distinct(city_x) > 8)
	check.call("100 seeds give at least 99 different worlds", sigs.size() >= 99)
	# determinism
	var a = WG.new()
	a.generate(42, cfg)
	var b = WG.new()
	b.generate(42, cfg)
	check.call("the same seed gives the identical world", a.signature() == b.signature())
	a.save_png("/tmp/claude-0/spike_world_42.png")
	var c = WG.new()
	c.generate(7, cfg)
	c.save_png("/tmp/claude-0/spike_world_7.png")
	# the city
	var worst_reach := 1.0
	var min_markers := 1 << 30
	var t0 := Time.get_ticks_msec()
	for s in [1, 2, 3, 4, 5]:
		var g = CG.new()
		g.generate(s, Vector2(1, 0.3))
		worst_reach = minf(worst_reach, g.reachable_fraction())
		min_markers = mini(min_markers, g.homes.size() + g.works.size() + g.shops.size())
	var ms := (Time.get_ticks_msec() - t0) / 5.0
	check.call("every home, work and shop is reachable on foot in 5 seeds (worst %.1f%%)" % (worst_reach * 100.0), worst_reach >= 0.99)
	check.call("a city has at least 300 markers (min %d)" % min_markers, min_markers >= 300)
	check.call("a 256x256 city generates in under 1 second (%.0f ms)" % ms, ms < 1000.0)
	var g1 = CG.new()
	g1.generate(11, Vector2(1, 0))
	var g2 = CG.new()
	g2.generate(11, Vector2(1, 0))
	check.call("the same seed gives the identical city", hash(g1.tiles) == hash(g2.tiles))
	var g3 = CG.new()
	g3.generate(12, Vector2(1, 0))
	check.call("a different seed gives a different city", hash(g1.tiles) != hash(g3.tiles))
	g1.save_png("/tmp/claude-0/spike_city_11.png")
	log.append("  (city 11: %d buildings, %d homes, %d works, %d shops)" % [g1.buildings, g1.homes.size(), g1.works.size(), g1.shops.size()])
	return [st[0], st[1], log]

func _distinct(a: Array) -> int:
	var d := {}
	for v in a:
		d[v] = true
	return d.size()
