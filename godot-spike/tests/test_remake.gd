extends RefCounted
## The guide-image remake: scale constants, seeds on the same themes, the south harbor merged into the city, the messy east industry, the chart.
const World = preload("res://src/world.gd")
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
	var a = ISL.new(7)
	var b = ISL.new(31)
	check.call("scale: the island is 4400 x 7750 tiles (1 guide px = 4.4 tiles), about 4.5x the old 2304 x 1408 land" , ISL.W == 4400 and ISL.H == 7750 and ISL.W * ISL.H > 4 * 2304 * 1408)
	var gp: Vector2 = a.g2t(1000.0, 1000.0)
	check.call("g2t converts guide pixels at 4.4 tiles each", absf(gp.x - (1000.0 * 4.4 - 722.7)) < 0.01 and absf(gp.y - (4400.0 - 664.5)) < 0.01)
	check.call("the coast template ships with the game (data/island_sdf.bin, %d bytes)" % FileAccess.get_file_as_bytes("res://data/island_sdf.bin").size(), FileAccess.get_file_as_bytes("res://data/island_sdf.bin").size() == ISL.TW * ISL.TH)
	var diff := 0
	for k in 300:
		var x: int = (k * 977) % ISL.W
		var y: int = (k * 613) % ISL.H
		if a.terrain(x, y) != b.terrain(x, y):
			diff += 1
	check.call("another seed moves the ridges and lagoons (%d of 300 samples differ) but the coast stays the guide's" % diff, diff > 3 and diff < 120 and a.terrain(5, 5) == CG.WATER)
	# the city sits in a caldera, the harbor is its south edge
	check.call("the harbor is the city's south: the quay row lies in the city map at row %d" % a.harb_y, a.harb_y > 700 and a.harb_y < ISL.CZS - 60 and a.zone_kind(ISL.CITY_ZONE) == "city")
	var w = World.new()
	w.start(7, 300)
	var g = w.game
	var c = g.city
	var plat := 0
	var cont := 0
	var water_below := false
	var n: int = g.size
	for y in range(a.harb_y - 120, a.harb_y + 5):
		for x in range(60, n - 60):
			var t: int = c.tiles[y * n + x]
			if t == CG.PLATFORM:
				plat += 1
			elif t == CG.TID["container"]:
				cont += 1
	for x in range(300, 700, 20):
		for y in range(a.harb_y, mini(n - 1, a.harb_y + 90)):
			if c.tiles[y * n + x] == CG.WATER:
				water_below = true
	check.call("the south harbor: apron (%d platform tiles), container stacks (%d), cranes (%d), water beyond the quay" % [plat, cont, c.cranes.size()], plat > 3000 and cont > 300 and c.cranes.size() >= 4 and water_below)
	var trucks: int = g.vehicles.filter(func(v): return v["kind"] == "truck").size()
	check.call("trucks are parked on the harbor apron (%d)" % trucks, trucks >= 2)
	# the messy east industry
	var kinds := {}
	var ind: Array = []
	for zx in ISL.NZX:
		for zy in ISL.NZY:
			var z := Vector2i(zx, zy)
			var kd: String = a.zone_kind(z)
			kinds[kd] = kinds.get(kd, 0) + 1
			if kd == "industry":
				ind.append(z)
	var road := 0
	var wall := 0
	var rail := 0
	var water := 0
	var ig_n := 0
	for zi in mini(3, ind.size()):                                # (the kinds of works are drawn per block, so the mix is judged over a few industrial zones)
		var ig = w._make(ind[zi])
		if zi == 0:
			ig_n = ig.sim.n
		for i in ig.size * ig.size:
			var t: int = ig.city.tiles[i]
			if t == CG.ROAD:
				road += 1
			elif t == CG.WALL:
				wall += 1
			elif t == CG.RAILING:
				rail += 1
			elif t == CG.WATER:
				water += 1
		ig.dispose()
	check.call("an industrial zone %s is a mixed mess: service roads %d, walls %d, pipe racks %d, people %d" % [str(ind[0]), road, wall, rail, ig_n], road > 4000 and wall > 600 and rail > 100 and ig_n == 70)
	var lag := 0
	for z in ind:
		var o: Vector2i = ISL.zone_origin(z.x, z.y)
		for k in 200:
			if a.terrain(o.x + (k * 37) % ISL.ZS, o.y + (k * 91) % ISL.ZS) == CG.WATER:
				lag += 1
	check.call("lagoon water lies among the industrial flats (%d of %d samples)" % [lag, ind.size() * 200], lag > 20)
	check.call("the industry is not one thing: zone kinds %s, none called a refinery" % str(kinds), not a.zone_name(ind[0]).to_lower().contains("refin") and not a.zone_name(ind[0]).to_lower().contains("oil"))
	# roads
	var rn: PackedInt32Array = a._roads_v[0]
	check.call("the north road passes the town and joins the city's road grid", absi(rn[ISL.TOWN.y] + 6 - ISL.TOWN.x) <= 2 and rn[ISL.CITY_ORIGIN.y + 100] >= 0)
	# chart and landmarks
	var img: Image = a.overview_image(8)
	var names := []
	for l in a.landmarks():
		names.append(str(l[0]) if l is Array else str(l.get("name", "")))
	check.call("the chart is %dx%d and names %d places" % [img.get_width(), img.get_height(), names.size()], img.get_width() == 550 and img.get_height() == 968 and names.size() >= 8)
	# save / load
	var d: Dictionary = JSON.parse_string(JSON.stringify(w.save_dict()))
	var pc0: int = g.pc                                        # (one 1536 city at a time: the first world is let go of once it is saved)
	var harb0: int = a.harb_y
	w.game.dispose()
	var w2 = World.new()
	w2.load_dict(d)
	check.call("save and load round trip the new layout (v%d)" % ISL.LAYOUT_VER, w2.game.zone == ISL.CITY_ZONE and w2.game.pc == pc0 and w2.island.harb_y == harb0)
	d["layout"] = 3
	var w3 = World.new()
	w3.load_dict(d)
	w2.game.dispose()
	check.call("an old-layout save restarts on the same island instead of loading nonsense", w3.seed_value == 7 and w3.game.zone == ISL.CITY_ZONE)
	return [st[0], st[1], log]
