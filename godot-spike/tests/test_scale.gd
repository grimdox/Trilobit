extends RefCounted
## Spike test 1: NPC scale with level-of-detail.  Returns [passed, total, log]
const CG = preload("res://src/citygen.gd")
const SIM = preload("res://src/npc_sim.gd")

func _run(city, count: int, radius: int, ticks: int, churn: int = 0) -> Dictionary:
	var sim = SIM.new()
	sim.near_radius = radius
	sim.churn_per_tick = churn
	sim.setup(city, count, 99)
	sim.tick = 7 * 60 - 5          # start just before the morning commute so agents actually walk
	# the player walks a long road row back and forth, one tile per tick
	var row := 0
	for y in city.size:
		var ok := 0
		for x in range(20, city.size - 40):
			if city.tiles[y * city.size + x] == CG.ROAD:
				ok += 1
		if ok > city.size - 80:
			row = y
			break
	var px := 30
	var dirx := 1
	var times := []
	var near_sum := 0
	var seen_sum := 0
	for t in ticks:
		px += dirx
		if px > city.size - 50 or px < 30:
			dirx = -dirx
		var t0 := Time.get_ticks_usec()
		sim.step(row * city.size + px)
		times.append((Time.get_ticks_usec() - t0) / 1000.0)
		near_sum += sim.near_list.size()
		seen_sum += sim.seen_player
	times.sort()
	var sum := 0.0
	for v in times:
		sum += v
	return {"avg": sum / times.size(), "p50": times[times.size() / 2], "p95": times[int(times.size() * 0.95)], "max": times[times.size() - 1],
			"near_avg": near_sum / ticks, "promo": sim.promotions, "demo": sim.demotions, "seen_avg": seen_sum / ticks}

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	var city = CG.new()
	city.generate(11, Vector2(1, 0))
	var t0 := Time.get_ticks_msec()
	var probe = SIM.new()
	probe.setup(city, 10, 1)
	log.append("  (setup incl. 3 flow fields over a 256x256 city: %d ms)" % (Time.get_ticks_msec() - t0))
	var r2k := _run(city, 2000, 45, 1200, 40)
	log.append("  2,000 NPCs, LOD radius 45, constant re-targeting: avg %.2f ms, p50 %.2f, p95 %.2f, max %.2f; %d full agents on average (%d see the player); %d promotions" % [r2k["avg"], r2k["p50"], r2k["p95"], r2k["max"], r2k["near_avg"], r2k["seen_avg"], r2k["promo"]])
	var r5k := _run(city, 5000, 45, 1200, 100)
	log.append("  5,000 NPCs, LOD radius 45, constant re-targeting: avg %.2f ms, p50 %.2f, p95 %.2f, max %.2f; %d full agents on average; %d promotions" % [r5k["avg"], r5k["p50"], r5k["p95"], r5k["max"], r5k["near_avg"], r5k["promo"]])
	var rall := _run(city, 2000, 1000, 500, 40)
	log.append("  2,000 NPCs ALL full agents (no LOD), constant re-targeting: avg %.2f ms, p95 %.2f, max %.2f" % [rall["avg"], rall["p95"], rall["max"]])
	check.call("2,000 NPCs with LOD: average tick under 4 ms (%.2f)" % r2k["avg"], r2k["avg"] < 4.0)
	check.call("2,000 NPCs with LOD: 95th percentile tick under 8 ms (%.2f)" % r2k["p95"], r2k["p95"] < 8.0)
	check.call("2,000 NPCs with LOD: worst tick under 50 ms (%.2f)" % r2k["max"], r2k["max"] < 50.0)
	check.call("5,000 NPCs with LOD: average tick under 8 ms (%.2f)" % r5k["avg"], r5k["avg"] < 8.0)
	check.call("LOD matters: the all-agents run is at least 2x slower than the LOD run", rall["avg"] > 2.0 * r2k["avg"])
	check.call("agents are promoted and demoted as the player moves (%d)" % r2k["promo"], r2k["promo"] > 500)
	return [st[0], st[1], log]
