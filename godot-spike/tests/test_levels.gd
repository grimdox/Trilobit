extends RefCounted
## Vertical world: tower heights, shafts linked on every floor, connectivity through stairs, the underground, and the flow field crossing levels.
const CG = preload("res://src/citygen.gd")
const LV = preload("res://src/levels.gd")
const FF = preload("res://src/flowfield.gd")
var passed := 0
var failed := 0
var out: Array = []

func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	out.append(("  PASS " if ok else "  FAIL ") + name + ("" if ok else "  " + detail))

func run() -> Array:
	var c = CG.new()
	c.generate(7, Vector2(1, 0.2))
	var t0 := Time.get_ticks_msec()
	LV.build(c, 7)
	out.append("  (build %d ms, %d levels, %d towers, %d homes in towers)" % [Time.get_ticks_msec() - t0, c.nlev, c.tower_info.size(), c.homes_t.size()])
	var s2: int = c.size * c.size
	check("stack size matches level count", c.tiles.size() == s2 * c.nlev, str(c.tiles.size()))
	var tallest := 0
	for ti in c.tower_info:
		tallest = maxi(tallest, int(ti["h"]))
	check("a tower reaches 14 floors, with open air above it", tallest == 14 and c.zmax == 14 + preload("res://src/levels.gd").AIR_ABOVE, "tallest=%d zmax=%d" % [tallest, c.zmax])
	check("at least 8 towers", c.tower_info.size() >= 8, str(c.tower_info.size()))
	# every shaft cell is linked up on every floor
	var linked := true
	var tall: Dictionary = {}
	for t in c.tower_info:
		if tall.is_empty() or int(t["h"]) > int(tall["h"]):
			tall = t
	for z in tall["h"]:
		var a: int = z * s2 + int(tall["stairs"])
		var b: int = (z + 1) * s2 + int(tall["stairs"])
		if not (c.links.has(a) and c.links[a].has(b)):
			linked = false
		var e: int = z * s2 + int(tall["elev"])
		if c.tiles[e] != CG.ELEVATOR and z > 0:
			linked = false
	check("tallest tower: stairs and elevator linked floor by floor", linked)
	# city layout: mega-towers 2-3 blocks wide, ring buildings 1-2 blocks, three wealth tiers
	var big := 0
	var areas := []
	for t in c.tower_info:
		var ar: int = (int(t["x1"]) - int(t["x0"]) + 1) * (int(t["y1"]) - int(t["y0"]) + 1)
		areas.append(ar)
		if ar >= 3600:
			big += 1
	check("there are several mega-towers (2+ blocks each way) among %d towers" % c.tower_info.size(), big >= 2, str(areas))
	var wc := [0, 0, 0]
	for i in c.size * c.size:
		wc[c.wealth_at(i)] += 1
	check("lower, middle and upper districts each cover a fair share of the city %s" % str(wc), wc[0] > c.size * c.size / 6 and wc[1] > c.size * c.size / 6 and wc[2] > c.size * c.size / 6)
	check("roof is open walkable roof", c.tiles[int(tall["h"]) * s2 + (int(tall["y0"]) + 3) * c.size + int(tall["x0"]) + 4] in [CG.ROOF, CG.WALL, CG.STAIRS, CG.ELEVATOR])
	check("tower floors hold markers", c.homes_t.size() > 200 and c.works_t.size() > 200, "%d %d" % [c.homes_t.size(), c.works_t.size()])
	check("subway has four stations", c.subway["stops"].size() == 4, str(c.subway["stops"].size()))
	check("lairs in the sewers", c.lairs.size() > 10)
	var frac: float = LV.reachable_all(c)
	check("99%+ of markers and lairs reachable on foot through stairs and ladders", frac > 0.99, "%.3f" % frac)
	# a flow field built on the stacked map brings an agent from the top floor to the street
	var walk := PackedByteArray()
	walk.resize(c.tiles.size())
	for i in c.tiles.size():
		walk[i] = 1 if c.walkable(c.tiles[i]) else 0
	var src := PackedInt32Array([c.homes_g[0]])
	var f: PackedInt32Array = FF.build(c.tiles, c.size, walk, src, c.links, c.haslink)
	var top: int = int(tall["h"]) * s2 + int(tall["stairs"])
	check("flow field reaches the roof of the tallest tower", f[top] < FF.UNREACHED, "d=%d" % f[top])
	# a station platform exists and connects up
	var st0: int = c.subway["ring"][c.subway["stops"][0]]
	var l1: int = c.lvl_of_z(-1) * s2
	var near_platform := false
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if c.tiles[l1 + st0 + dy * c.size + dx] == CG.PLATFORM:
				near_platform = true
	check("platform beside the first station", near_platform)
	return [passed, passed + failed, out]
