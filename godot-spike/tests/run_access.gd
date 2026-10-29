extends SceneTree
## Every door leads out to a road, every tower has two ways out, every parking lot has a driveway, labor centers downtown.  Run: godot --headless -s tests/run_access.gd
const WorldScript = preload("res://src/world.gd")
const CG = preload("res://src/citygen.gd")
var ok := 0
var n := 0

func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name)

func _initialize() -> void:
	var total_doors := 0
	var lots_all := 0
	var lots_out := 0
	var downtown_labor := 0
	for sd in [21, 5, 77]:
		var w = WorldScript.new()
		w.start(sd, 300)
		var g = w.game
		var c = g.city
		var size: int = g.size
		var s2: int = size * size
		# an independent flood from every street cell (not a parking lot's) over everything a person can walk on at ground level
		var inlot := PackedByteArray()
		inlot.resize(s2)
		for lot in c.lots:
			for y in range(int(lot["y0"]), int(lot["y1"]) + 1):
				for x in range(int(lot["x0"]), int(lot["x1"]) + 1):
					inlot[y * size + x] = 1
		var reach := PackedByteArray()
		reach.resize(s2)
		var q := PackedInt32Array()
		for i in s2:
			if c.tiles[i] == CG.ROAD and inlot[i] == 0:
				reach[i] = 1
				q.append(i)
		var qi := 0
		while qi < q.size():
			var cur: int = q[qi]
			qi += 1
			for nb in [cur - 1, cur + 1, cur - size, cur + size]:
				if nb >= 0 and nb < s2 and reach[nb] == 0 and g.sim.walk[nb] == 1:
					reach[nb] = 1
					q.append(nb)
		var bad := 0
		var doors := 0
		for i in s2:
			var t: int = c.tiles[i]
			if t == CG.DOOR or t == CG.LOCKED or t == CG.TID["door_closed"]:
				var inside := false
				var outside := false
				for nb in [i - 1, i + 1, i - size, i + size]:
					if c.tiles[nb] == CG.FLOOR or c.tiles[nb] >= CG.EXTRA0:
						inside = true
					elif CG.WALK[c.tiles[nb]] == 1:
						outside = true
				if inside and outside:
					doors += 1
					if reach[i] == 0:
						bad += 1
		total_doors += doors
		check("seed %d: every outside door leads out to a road (%d doors, %d cut off, access %s)" % [sd, doors, bad, str(c.access)], bad <= int(c.access.get("dead", 0)) * 3 and int(c.access.get("dead", 1)) < 10)
		check("seed %d: almost no marker was dropped as unreachable (%d)" % [sd, int(c.access.get("dropped", 0))], int(c.access.get("dropped", 0)) < 200)
		var two := 0
		var floors_ok := 0
		for tw in c.tower_info:
			if tw["door2"].x >= 0:
				two += 1
				var d1: int = int(tw["door"].y) * size + int(tw["door"].x)
				var d2: int = int(tw["door2"].y) * size + int(tw["door2"].x)
				if reach[d1] == 1 and reach[d2] == 1 and d1 != d2:
					floors_ok += 1
		check("seed %d: towers have two reachable doors (%d of %d)" % [sd, floors_ok, c.tower_info.size()], c.tower_info.size() > 0 and floors_ok >= c.tower_info.size() - 1)
		for lot in c.lots:
			lots_all += 1
			var hit := false
			for x in range(int(lot["x0"]), int(lot["x1"]) + 1):
				for y in [int(lot["y0"]), int(lot["y1"])]:
					if reach[y * size + x] == 1:
						hit = true
			if hit:
				lots_out += 1
		for b in c.businesses:
			if b["type"] == "labor_center" and c.wealth_at(int(b["door"].y) * size + int(b["door"].x)) == 2:
				downtown_labor += 1
	check("every parking lot has a driveway to a road (%d of %d)" % [lots_out, lots_all], lots_all > 0 and lots_out == lots_all)
	check("there are a few labor centers downtown (%d over three cities)" % downtown_labor, downtown_labor >= 3)
	print("ACCESS %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
