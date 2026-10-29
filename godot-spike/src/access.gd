extends RefCounted
## Everything a person can walk into must also lead out to a road.  Run on the finished ground level (after the tower lobbies are built):
##  1. flood the open ground (street, pavement, parks, gravel, sand) from every road cell (parking-lot interiors do not count: they must reach a road themselves);
##  2. every outside door (a door with a floor on one side and something else on the other) must open onto ground that was reached; if it opens onto ground that was not (a walled-in
##     yard, a strip between two buildings), a pavement is cut from it to the nearest reached ground through anything that is only scenery (trees, fields, gravel, fixed street props);
##  3. a door that opens onto a wall or onto water is moved to another wall of the same building that does open onto ground;
##  4. a home, work or shop marker that cannot be walked to from a reached door is dropped (a marker nobody could ever reach is no use to the simulation).
## Returns {doors, carved, moved, dead, dropped}: the tests assert `dead` is 0.
const CG = preload("res://src/citygen.gd")

static func _tables() -> Dictionary:
	var out := PackedByteArray()                     # open ground a person walks on outdoors
	out.resize(256)
	for t in [CG.GROUND, CG.ROAD, CG.PARK, CG.BALLAST, CG.FIELD, CG.SAND, CG.ROCKS]:
		out[t] = 1
	var carve := PackedByteArray()                   # scenery a pavement may be cut through
	carve.resize(256)
	for t in [CG.GROUND, CG.ROAD, CG.PARK, CG.BALLAST, CG.FIELD, CG.SAND, CG.ROCKS, CG.TREE, CG.CRATE, CG.DUMPSTER, CG.PLANTER, CG.TID["street_tree"], CG.TID["street_bench"], CG.TID["bench_broken"]]:
		carve[t] = 1
	var door := PackedByteArray()
	door.resize(256)
	for t in [CG.DOOR, CG.LOCKED, CG.TID["door_closed"]]:
		door[t] = 1
	return {"out": out, "carve": carve, "door": door}

static func _indoor(t: int) -> bool:
	return t == CG.FLOOR or (t >= CG.EXTRA0 and not (CG.EXTRA[t - CG.EXTRA0][0] in ["street_tree", "street_bench", "bench_broken"]) and t != CG.TID["door_closed"] and t != CG.TID["window_broken"])

static func ensure(c, all: PackedByteArray) -> Dictionary:
	var size: int = c.size
	var s2: int = size * size
	var T: Dictionary = _tables()
	var out: PackedByteArray = T["out"]
	var carve: PackedByteArray = T["carve"]
	var door_t: PackedByteArray = T["door"]
	var stat := {"doors": 0, "carved": 0, "moved": 0, "dead": 0, "dropped": 0}
	var in_lot := PackedByteArray()
	in_lot.resize(s2)
	for lot in c.lots:
		for y in range(int(lot["y0"]), int(lot["y1"]) + 1):
			for x in range(int(lot["x0"]), int(lot["x1"]) + 1):
				in_lot[y * size + x] = 1
	var reach := PackedByteArray()
	reach.resize(s2)
	var q := PackedInt32Array()
	for i in s2:
		if all[i] == CG.ROAD and in_lot[i] == 0:
			reach[i] = 1
			q.append(i)
	_flood(all, out, reach, q, size, s2)
	var remap := {}                                                    # a door that was moved: old cell -> new cell (the records and the signs follow it)
	for ti in c.tower_info:                                           # (the lobby builder moved the tower doors: the building records still hold the first guess)
		for b in c.bldgs:
			if int(b["x0"]) == int(ti["x0"]) and int(b["y0"]) == int(ti["y0"]):
				b["door"] = ti["door"]
	var pending: Array = []                                           # doors nothing above could fix: [door, outward cell]
	# the doors on the outside of buildings
	for i in s2:
		if door_t[all[i]] == 0 or i < size * 2 or i >= s2 - size * 2:
			continue
		var x: int = i % size
		if x < 2 or x >= size - 2:
			continue
		var inward := -1
		var outward := -1
		for pr in [[i - 1, i + 1], [i - size, i + size]]:
			var a: int = pr[0]
			var b: int = pr[1]
			if _indoor(all[a]) and not _indoor(all[b]) and door_t[all[b]] == 0:
				inward = a
				outward = b
				break
			if _indoor(all[b]) and not _indoor(all[a]) and door_t[all[a]] == 0:
				inward = b
				outward = a
				break
		if inward < 0:
			continue                                              # an inside door
		stat["doors"] += 1
		if reach[outward] == 1 and out[all[outward]] == 1:
			continue
		if carve[all[outward]] == 1 and _cut(all, carve, out, reach, outward, size, s2):
			stat["carved"] += 1
			continue
		var nd: int = _relocate(c, all, out, carve, reach, i, size, s2)
		if nd >= 0:
			stat["moved"] += 1
			remap[i] = nd
			continue
		pending.append([i, outward])
	# what can be walked to from a street, through doors and rooms
	var walk := PackedByteArray()
	walk.resize(s2)
	var q2 := PackedInt32Array()
	for i in s2:
		if reach[i] == 1:
			walk[i] = 1
			q2.append(i)
	_flood_walk(all, walk, q2, size, s2)
	# the doors left over: open the wall between their yard (or their wall) and a room that can be walked to from a street, so the way out is through that room
	for pd in pending:
		var door: int = pd[0]
		var outc: int = pd[1]
		var region: Array = [outc] if carve[all[outc]] == 1 else []
		var seen := {outc: 1}
		var ri := 0
		while ri < region.size() and region.size() < 600:
			var cur: int = region[ri]
			ri += 1
			for nb in [cur - 1, cur + 1, cur - size, cur + size]:
				if nb >= 0 and nb < s2 and not seen.has(nb) and carve[all[nb]] == 1:
					seen[nb] = 1
					region.append(nb)
		var cells: Array = region if not region.is_empty() else [door]
		var done := false
		for cell in cells:
			if done:
				break
			for d in [1, -1, size, -size]:
				var w1: int = cell + d
				if w1 < 0 or w1 >= s2 or all[w1] != CG.WALL:
					continue
				var b1: int = w1 + d
				if b1 >= 0 and b1 < s2 and walk[b1] == 1 and _indoor(all[b1]) and CG.WALK[all[b1]] == 1:
					all[w1] = CG.DOOR
					done = true
					break
				var b2: int = b1 + d
				if b1 >= 0 and b2 >= 0 and b2 < s2 and all[b1] == CG.WALL and walk[b2] == 1 and _indoor(all[b2]) and CG.WALK[all[b2]] == 1:
					all[w1] = CG.DOOR
					all[b1] = CG.DOOR
					done = true
					break
		if done:
			stat["punched"] = int(stat.get("punched", 0)) + 1
			# the yard (and whatever else opens into it) is now part of the walkable area
			var qq := PackedInt32Array()
			for cell in cells:
				if walk[cell] == 0:
					walk[cell] = 1
					qq.append(cell)
			if door >= 0 and walk[door] == 0:
				walk[door] = 1
				qq.append(door)
			_flood_walk(all, walk, qq, size, s2)
		else:
			stat["dead"] += 1
			_seal(c, door, size)
	for lst in [c.businesses, c.bldgs, c.towers, c.tower_info, c.venues]:
		for b in lst:
			for key in ["door", "door2"]:
				if b.has(key) and b[key] is Vector2i and (b[key] as Vector2i).x >= 0:
					var oi: int = (b[key] as Vector2i).y * size + (b[key] as Vector2i).x
					if remap.has(oi):
						b[key] = Vector2i(int(remap[oi]) % size, int(remap[oi]) / size)
	# staff posts nobody could walk to (behind a counter that was cut off when a door moved, say)
	for b in c.businesses:
		var st: Array = b.get("staff", [])
		var keep_st: Array = []
		for cell in st:
			if int(cell) >= s2 or walk[int(cell)] == 1:
				keep_st.append(cell)
			else:
				stat["dropped"] += 1
		b["staff"] = keep_st
	# markers that nobody could walk to
	for name in ["homes_g", "works_g", "shops_g"]:
		var src: PackedInt32Array = c.get(name)
		var keep := PackedInt32Array()
		for m in src:
			if m >= s2 or walk[m] == 1:
				keep.append(m)
			else:
				stat["dropped"] += 1
		c.set(name, keep)
	return stat

static func _flood_walk(all: PackedByteArray, walk: PackedByteArray, q: PackedInt32Array, size: int, s2: int) -> void:
	var qi := 0
	while qi < q.size():
		var cur: int = q[qi]
		qi += 1
		for nb in [cur - 1, cur + 1, cur - size, cur + size]:
			if nb >= 0 and nb < s2 and walk[nb] == 0 and CG.WALK[all[nb]] == 1:
				walk[nb] = 1
				q.append(nb)

static func _flood(all: PackedByteArray, out: PackedByteArray, reach: PackedByteArray, q: PackedInt32Array, size: int, s2: int) -> void:
	var qi := 0
	while qi < q.size():
		var cur: int = q[qi]
		qi += 1
		var x: int = cur % size
		if x > 0 and reach[cur - 1] == 0 and out[all[cur - 1]] == 1:
			reach[cur - 1] = 1
			q.append(cur - 1)
		if x < size - 1 and reach[cur + 1] == 0 and out[all[cur + 1]] == 1:
			reach[cur + 1] = 1
			q.append(cur + 1)
		if cur >= size and reach[cur - size] == 0 and out[all[cur - size]] == 1:
			reach[cur - size] = 1
			q.append(cur - size)
		if cur < s2 - size and reach[cur + size] == 0 and out[all[cur + size]] == 1:
			reach[cur + size] = 1
			q.append(cur + size)

## cut a pavement from `start` to the nearest reached ground through scenery; true when one was cut (or none was needed)
static func _cut(all: PackedByteArray, carve: PackedByteArray, out: PackedByteArray, reach: PackedByteArray, start: int, size: int, s2: int) -> bool:
	var prev := {start: -1}
	var q: Array = [start]
	var qi := 0
	var found := -1
	while qi < q.size() and q.size() < 90000:
		var cur: int = q[qi]
		qi += 1
		if reach[cur] == 1 and out[all[cur]] == 1:
			found = cur
			break
		var x: int = cur % size
		for nb in [cur - 1 if x > 1 else -1, cur + 1 if x < size - 2 else -1, cur - size if cur >= size * 2 else -1, cur + size if cur < s2 - size * 2 else -1]:
			if nb < 0 or prev.has(nb) or carve[all[nb]] == 0:
				continue
			prev[nb] = cur
			q.append(nb)
	if found < 0:
		return false
	var path: Array = []
	var k: int = found
	while k != -1:
		path.append(k)
		k = prev[k]
	var seeds := PackedInt32Array()
	for p in path:
		if out[all[p]] == 0:
			all[p] = CG.GROUND
		reach[p] = 1
		seeds.append(p)
	_flood(all, out, reach, seeds, size, s2)                       # whatever was shut in behind the door is now reached too
	return true

## a building that no street can reach (a packed block with no alley): it is closed down.  Its business is struck off, its rooms give no homes or jobs (the marker pass below), and its sign reads For Rent.
static func _seal(c, door: int, size: int) -> void:
	var dx: int = door % size
	var dy: int = door / size
	for b in c.businesses.duplicate():
		if dx >= int(b["x0"]) and dx <= int(b["x1"]) and dy >= int(b["y0"]) and dy <= int(b["y1"]):
			c.businesses.erase(b)
	for b in c.bldgs:
		if dx >= int(b["x0"]) and dx <= int(b["x1"]) and dy >= int(b["y0"]) and dy <= int(b["y1"]):
			b["sealed"] = true
			b["filled"] = false

## a door that opens onto nothing: put one in another wall of the same building
static func _relocate(c, all: PackedByteArray, out: PackedByteArray, carve: PackedByteArray, reach: PackedByteArray, door: int, size: int, s2: int) -> int:
	var dx: int = door % size
	var dy: int = door / size
	var rect := Rect2i()
	var found := false
	for lst in [c.businesses, c.bldgs]:
		for b in lst:
			if dx >= int(b["x0"]) and dx <= int(b["x1"]) and dy >= int(b["y0"]) and dy <= int(b["y1"]):
				var r := Rect2i(int(b["x0"]), int(b["y0"]), int(b["x1"]) - int(b["x0"]) + 1, int(b["y1"]) - int(b["y0"]) + 1)
				if not found or r.get_area() < rect.get_area():
					rect = r
					found = true
	if not found:
		for t in c.towers:
			if dx >= int(t["x0"]) and dx <= int(t["x1"]) and dy >= int(t["y0"]) and dy <= int(t["y1"]):
				rect = Rect2i(int(t["x0"]), int(t["y0"]), int(t["x1"]) - int(t["x0"]) + 1, int(t["y1"]) - int(t["y0"]) + 1)
				found = true
	if not found:
		return -1
	var cands: Array = []
	for x in range(rect.position.x + 1, rect.end.x - 1):
		cands.append([Vector2i(x, rect.position.y), Vector2i(0, -1)])
		cands.append([Vector2i(x, rect.end.y - 1), Vector2i(0, 1)])
	for y in range(rect.position.y + 1, rect.end.y - 1):
		cands.append([Vector2i(rect.position.x, y), Vector2i(-1, 0)])
		cands.append([Vector2i(rect.end.x - 1, y), Vector2i(1, 0)])
	cands.sort_custom(func(a, b): return (a[0] - Vector2i(dx, dy)).length_squared() < (b[0] - Vector2i(dx, dy)).length_squared())
	for cd in cands:
		var p: Vector2i = cd[0]
		var d: Vector2i = cd[1]
		var ci: int = p.y * size + p.x
		if all[ci] != CG.WALL:
			continue
		var inn: int = ci - d.y * size - d.x
		var outc: int = ci + d.y * size + d.x
		if CG.WALK[all[inn]] != 1 or not _indoor(all[inn]):
			continue
		if all[inn] >= CG.EXTRA0 and CG.WALK[all[inn]] != 1:
			continue                                              # furniture behind the wall
		if carve[all[outc]] == 0:
			continue
		if reach[outc] == 1 and out[all[outc]] == 1:
			pass
		elif not _cut(all, carve, out, reach, outc, size, s2):
			continue
		all[ci] = CG.DOOR
		all[door] = CG.WALL
		return ci
	return -1
