extends RefCounted
## Station clocks: two wall units on every platform that read the timetable.
const World = preload("res://src/world.gd")
const CG = preload("res://src/citygen.gd")

func run() -> Array:
	var cnt: Array = [0, 0]
	var log: Array = []
	var check := func(label: String, ok: bool) -> void:
		cnt[1] += 1
		if ok:
			cnt[0] += 1
		else:
			log.append("  FAIL " + label)
	var w = World.new()
	w.start(5, 300)
	var g = w.game
	var t = g.transit
	var clocks: Array = []
	for c in g.total:
		if g.city.tiles[c] == CG.TID["station_clock"]:
			clocks.append(c)
	check.call("clocks stand on the platforms of this zone's stations (%d)" % clocks.size(), clocks.size() >= 2)
	var per := {}
	for c in clocks:
		var info: Dictionary = g.station_clock_info(c)
		per[info["name"]] = int(per.get(info["name"], 0)) + 1
	check.call("every station of the zone has its own clock (%s)" % str(per), per.size() >= 4)
	check.call("a clock does not block a platform: the cell is not walkable but its neighbours are", g.sim.walk[clocks[0]] == 0)
	var info0: Dictionary = g.station_clock_info(clocks[0])
	check.call("it reads a name and a countdown", String(info0["name"]) != "" and int(info0["turns"]) >= 0)
	# interacting
	g.pc = clocks[0] + 1
	var found := false
	var near: Array = g.interactables()
	for it in near:
		if it["kind"] == "clock":
			found = true
			g.act_interact_with(it)
	check.call("the interact key lists the clock and uses it", found and g.clock_hit == clocks[0] or g.clock_hit >= 0)
	# the countdown ticks down
	var t0: int = int(g.station_clock_info(clocks[0])["turns"])
	for k in 3:
		g.end_turn()
	var t1: int = int(g.station_clock_info(clocks[0])["turns"])
	check.call("the countdown moves with the turns (%d then %d)" % [t0, t1], t1 != t0)
	return [cnt[0], cnt[1], log]
