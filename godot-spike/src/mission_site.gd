extends RefCounted
## The generated site a mission takes place in: its own map, built from the offer and its seed and nothing else.  It has no place in the island, so it
## can never collide with the physical world, and it is thrown away when the player leaves it.
## Every site is a freshly generated building (a binary space partition cut into as many rooms as the contract's LENGTH asks for, 30 for Long, 10 for Standard,
## 5 for Short), joined up with doors by the contract's LAYOUT:
##   open    big rooms (about 10 x 11), three or more doors each where the plan allows, several doors to the outside; you start outside the building.
##   closed  small rooms (4 x 4 to 6 x 6), one or two doors each; you start inside, in a room whose only way out is a door and the exit portal on its floor.
##   mixed   large and small rooms, one to four doors each; you start outside or inside, either.
## The objective sits in a random room, half the time one of the rooms furthest from where you start.  The hostiles (their number comes from the length and
## the risk, never the layout) stand in random rooms, away from the start.  The exit portal is on the open ground outside (open) or on the floor of the start room.
## build() returns a CG whose meta "site" holds {entry, exit, objective, rooms, doors, agents:[{role, cell, fac, name, lv}], case, start_room, inside}.
const CG = preload("res://src/citygen.gd")
const TJ = preload("res://src/temp_jobs.gd")
const MS = preload("res://src/missions.gd")

## cell area per room (walls included), the smallest room (walls included)
const LAYOUT := {
	"open": {"area": 110, "mind": 8},
	"closed": {"area": 40, "mind": 6},
	"mix": {"area": 70, "mind": 6},
}

static func build(offer: Dictionary):
	var o: Dictionary = MS.normalize(offer)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(o["seed"]) ^ 0x51e7
	var layout: String = String(o["layout"])
	var prof: Dictionary = LAYOUT[layout]
	var nrooms: int = int(o["rooms"])
	var mind: int = int(prof["mind"])
	var asp: float = 0.8 + 0.45 * rng.randf()
	var scale: float = 1.0
	var bw := 0
	var bh := 0
	var leaves: Array = []
	for attempt in 10:                    # too many rooms for the footprint (the cuts ran out of room): a bigger building
		var area: float = float(nrooms * int(prof["area"])) * scale
		bw = maxi(12, int(round(sqrt(area * asp))))
		bh = maxi(12, int(round(area / float(bw))))
		leaves = [Rect2i(0, 0, bw, bh)]
		var r_state: int = rng.randi()
		var rr := RandomNumberGenerator.new()
		rr.seed = r_state
		leaves = _cut(rr, bw, bh, nrooms, mind, layout)
		if leaves.size() >= nrooms:
			break
		scale *= 1.15
	var S: int = maxi(64, maxi(bw, bh) + 18)
	var bx0: int = (S - bw) / 2
	var by0: int = maxi(6, (S - bh - 9) / 2)
	var bx1: int = bx0 + bw - 1
	var by1: int = by0 + bh - 1
	for i in leaves.size():
		leaves[i] = Rect2i((leaves[i] as Rect2i).position + Vector2i(bx0, by0), (leaves[i] as Rect2i).size)
	var inside: bool = layout == "closed" or (layout == "mix" and rng.randi() % 2 == 0)
	var c = CG.new()
	c.size = S
	var s2: int = S * S
	c.tiles = PackedByteArray(); c.tiles.resize(s2)
	c.tiles.fill(CG.PARK)
	c.marks = PackedByteArray(); c.marks.resize(s2)
	c.under = PackedByteArray(); c.under.resize(s2)
	for y in range(4, S - 4):
		for x in range(4, S - 4):
			c.tiles[y * S + x] = CG.GROUND
	var steel: int = CG.TID["floor_steel"]
	var clean: int = CG.TID["floor_clean"]
	var n: int = leaves.size()
	for y in range(by0, by1 + 1):
		for x in range(bx0, bx1 + 1):
			c.tiles[y * S + x] = CG.WALL
	var inner: Array = []
	for i in n:
		var r: Rect2i = leaves[i]
		var ir := Rect2i(r.position.x + 1, r.position.y + 1, r.size.x - 2, r.size.y - 2)
		inner.append(ir)
		var fl: int = steel if rng.randi() % 3 != 0 else clean
		for y in range(ir.position.y, ir.end.y):
			for x in range(ir.position.x, ir.end.x):
				c.tiles[y * S + x] = fl
	# ---- who touches whom: every shared wall run is a place for a door
	var edges: Array = []
	for i in n:
		for j in range(i + 1, n):
			var A: Rect2i = leaves[i]
			var B: Rect2i = leaves[j]
			var ax1: int = A.end.x - 1
			var ay1: int = A.end.y - 1
			var bxe: int = B.end.x - 1
			var bye: int = B.end.y - 1
			if ax1 == B.position.x or bxe == A.position.x:
				var wx: int = ax1 if ax1 == B.position.x else bxe
				var lo: int = maxi(A.position.y, B.position.y) + 1
				var hi: int = mini(ay1, bye) - 1
				if hi >= lo:
					edges.append({"a": i, "b": j, "vert": true, "c": wx, "lo": lo, "hi": hi})
			elif ay1 == B.position.y or bye == A.position.y:
				var wy: int = ay1 if ay1 == B.position.y else bye
				var lo3: int = maxi(A.position.x, B.position.x) + 1
				var hi3: int = mini(ax1, bxe) - 1
				if hi3 >= lo3:
					edges.append({"a": i, "b": j, "vert": false, "c": wy, "lo": lo3, "hi": hi3})
	# ---- the start room, and how many doors each room may have
	var start_room: int = rng.randi() % n
	var cap: Array = []
	for i in n:
		match layout:
			"closed": cap.append(2)
			"mix": cap.append(1 + rng.randi() % 4)
			_: cap.append(99)
	if inside:
		cap[start_room] = 1
	var best_tree: Dictionary = {}
	for attempt in 80:                    # grow random spanning trees under the door caps; keep the first that breaks none (else the least bad)
		var tr: Dictionary = _grow_tree(rng, n, edges, cap, start_room)
		if best_tree.is_empty() or int(tr["over"]) < int(best_tree["over"]):
			best_tree = tr
		if int(best_tree["over"]) == 0:
			break
	var deg: Array = best_tree["deg"]
	var used_e: Dictionary = best_tree["used"]
	var order: Array = range(edges.size())
	for k in range(order.size() - 1, 0, -1):
		var j: int = rng.randi() % (k + 1)
		var tmp = order[k]
		order[k] = order[j]
		order[j] = tmp
	var doors: Array = []                # {"cell", "a", "b"}
	var door_set := {}
	for ek in used_e:
		_door(rng, edges[ek], S, doors, door_set, -1)
	for ek in order:
		if used_e.has(ek):
			continue
		var e: Dictionary = edges[ek]
		var a: int = e["a"]
		var b: int = e["b"]
		var add := false
		match layout:
			"open": add = (deg[a] < 3 or deg[b] < 3) and rng.randf() < 0.9
			"closed": add = deg[a] < 2 and deg[b] < 2 and a != start_room and b != start_room and rng.randf() < 0.3
			_: add = deg[a] < cap[a] and deg[b] < cap[b] and a != start_room and b != start_room and rng.randf() < 0.6
		if add:
			used_e[ek] = 1
			deg[a] += 1
			deg[b] += 1
			_door(rng, e, S, doors, door_set, -1)
	if layout == "open":                 # long shared walls get a second doorway
		for ek in used_e.keys():
			var e: Dictionary = edges[ek]
			if int(e["hi"]) - int(e["lo"]) >= 6 and rng.randf() < 0.6:
				var first: int = -1
				for d in doors:
					if d["a"] == e["a"] and d["b"] == e["b"]:
						first = int(d["cell"])
						break
				if _door(rng, e, S, doors, door_set, first):
					deg[e["a"]] += 1
					deg[e["b"]] += 1
	# ---- doors to the outside (open and some mixed buildings) and the exit portal
	var exit_cell: int = -1
	var entry: int = -1
	var ext: Array = []
	if not inside:
		var want: int = clampi(nrooms / 4, 2, 5) if layout == "open" else 1 + rng.randi() % 2
		var sides: Array = []
		for i in n:
			var r: Rect2i = leaves[i]
			var ir: Rect2i = inner[i]
			if r.end.y - 1 == by1:
				sides.append({"room": i, "cell": (by1) * S + rng.randi_range(ir.position.x, ir.end.x - 1), "side": 2})
			if r.position.y == by0:
				sides.append({"room": i, "cell": by0 * S + rng.randi_range(ir.position.x, ir.end.x - 1), "side": 0})
			if r.position.x == bx0:
				sides.append({"room": i, "cell": rng.randi_range(ir.position.y, ir.end.y - 1) * S + bx0, "side": 3})
			if r.end.x - 1 == bx1:
				sides.append({"room": i, "cell": rng.randi_range(ir.position.y, ir.end.y - 1) * S + bx1, "side": 1})
		var south: Array = sides.filter(func(s): return s["side"] == 2)
		var first_ext: Dictionary = south[rng.randi() % south.size()]
		ext.append(first_ext)
		var rest: Array = sides.filter(func(s): return s["room"] != first_ext["room"])
		for k in range(rest.size() - 1, 0, -1):
			var j: int = rng.randi() % (k + 1)
			var tmp = rest[k]
			rest[k] = rest[j]
			rest[j] = tmp
		var seen_rooms := {first_ext["room"]: true}
		for s in rest:
			if ext.size() >= want:
				break
			if seen_rooms.has(s["room"]):
				continue
			seen_rooms[s["room"]] = true
			ext.append(s)
		for s in ext:
			doors.append({"cell": int(s["cell"]), "a": int(s["room"]), "b": -1})
			door_set[int(s["cell"])] = true
			deg[int(s["room"])] += 1
		var ex: int = int(first_ext["cell"]) % S
		entry = (by1 + 3) * S + ex
		exit_cell = (by1 + 5) * S + ex
		c.tiles[exit_cell] = CG.TID["portal"]
		c.under[exit_cell] = CG.GROUND
		start_room = int(first_ext["room"])
	for d in doors:
		c.tiles[int(d["cell"])] = CG.DOOR
	# ---- keep every door's neighbourhood clear
	var used := {}
	for d in doors:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				used[int(d["cell"]) + dy * S + dx] = true
	if inside:
		var sr: Rect2i = inner[start_room]
		var dcell: int = -1
		for d in doors:
			if int(d["a"]) == start_room or int(d["b"]) == start_room:
				dcell = int(d["cell"])
				break
		var best: int = -1
		var bd: int = -1
		for y in range(sr.position.y, sr.end.y):
			for x in range(sr.position.x, sr.end.x):
				var cell: int = y * S + x
				if used.has(cell):
					continue
				var dd: int = _dist(cell, dcell, S)
				if dd > bd:
					bd = dd
					best = cell
		if best < 0:
			best = sr.position.y * S + sr.position.x
		exit_cell = best
		c.tiles[exit_cell] = CG.TID["portal"]
		c.under[exit_cell] = steel
		# the player starts on the free cell beside the portal that is nearest the door's side of the room
		var ebest: int = -1
		var ebd: int = 1 << 30
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var q: int = exit_cell + dy * S + dx
				var qt: int = c.tiles[q]
				if qt != steel and qt != clean:
					continue
				var qd: int = _dist(q, dcell, S)
				if qd < ebd:
					ebd = qd
					ebest = q
		entry = ebest
	used[entry] = true
	used[exit_cell] = true
	# ---- furniture: a prop never touches a wall, a door's neighbourhood or another prop, so none can seal a way through
	var mov: Array = []
	var prop_at := {}
	for i in n:
		var ir: Rect2i = inner[i]
		if i == start_room and inside:
			continue
		var want_p: int = ir.get_area() / 24 + (rng.randi() % 2)
		for _k in want_p * 8:
			if want_p <= 0:
				break
			var cell: int = rng.randi_range(ir.position.y + 1, maxi(ir.position.y + 1, ir.end.y - 2)) * S + rng.randi_range(ir.position.x + 1, maxi(ir.position.x + 1, ir.end.x - 2))
			if not _clear8(c, cell, S, used) or _near_used(prop_at, cell, 1, S):
				continue
			prop_at[cell] = true
			mov.append([cell, ["crate", "crate", "table", "chair"][rng.randi() % 4]])
			want_p -= 1
	c.movables = mov
	for cell in prop_at:
		used[cell] = true
	# ---- where the objective goes: any room but the start room (inside), half the time one of the furthest third from the player
	var far_rooms: Array = []
	for i in n:
		if not (inside and i == start_room):
			far_rooms.append(i)
	far_rooms.sort_custom(func(p, q): return _dist(_centre(inner[p], S), entry, S) > _dist(_centre(inner[q], S), entry, S))
	var third: Array = far_rooms.slice(0, maxi(1, far_rooms.size() / 3))
	var site := {"entry": entry, "exit": exit_cell, "doors": doors.map(func(d): return int(d["cell"])), "agents": [], "start_room": start_room, "inside": inside,
		"rooms": inner.map(func(r): return [r.position.x, r.position.y, r.size.x, r.size.y]), "ext_doors": ext.map(func(s): return int(s["cell"])), "size": S}
	var obj_room: int = -1
	var obj: int = -1
	for tries in 12:
		var cand_room: int = third[rng.randi() % third.size()] if rng.randi() % 2 == 0 else far_rooms[rng.randi() % far_rooms.size()]
		var oc: int = _pick_clear(rng, inner[cand_room], used, c, S)
		if oc >= 0:
			obj_room = cand_room
			obj = oc
			break
	if obj < 0:                           # nothing free in a dozen tries: take the biggest room
		for i in far_rooms:
			var oc2: int = _pick_clear(rng, inner[i], used, c, S)
			if oc2 >= 0:
				obj_room = i
				obj = oc2
				break
	used[obj] = true
	site["objective"] = obj
	site["obj_room"] = (inner[obj_room] as Rect2i).position.x
	site["obj_room_idx"] = obj_room
	if TJ.is_temp(o):
		_dress_temp(c, o, rng, inner, used, S, site, far_rooms, start_room, inside)
	var t: String = o["type"]
	var risk: int = int(o["risk"])
	var hostiles: int = int(o["hostiles"])
	var agents: Array = site["agents"]
	# faction for every hostile: the contract's organisation, hired gang muscle, or a mix
	var aff: int = int(o["aff"])
	var facs: Array = []
	var n_aff: int = hostiles if String(o["faction"]) == "affiliated" else (0 if String(o["faction"]) == "unaffiliated" else clampi(int(round(float(o["share"]) * hostiles)), 1, hostiles))
	for k in hostiles:
		facs.append(aff if k < n_aff and aff != 0 else 4)
	for k in range(facs.size() - 1, 0, -1):
		var j: int = rng.randi() % (k + 1)
		var tmp = facs[k]
		facs[k] = facs[j]
		facs[j] = tmp
	var lv: Array = o["lv"]
	var placed := 0
	match t:
		"repair", "sabotage":
			c.tiles[obj] = CG.TID["mission_device"]
			c.under[obj] = steel
		"recover":
			site["case"] = obj
			if rng.randi() % 3 == 0:          # the case may lie in another room
				var r2: int = far_rooms[rng.randi() % far_rooms.size()]
				var o2: int = _pick_free(rng, inner[r2], used, S)
				if o2 >= 0:
					used[o2] = true
					site["case"] = o2
		"assassination":
			var tf: int = aff if (aff != 0 and String(o["faction"]) != "unaffiliated") else 4
			agents.append({"role": "target", "cell": obj, "fac": tf, "name": o["target"], "lv": rng.randi_range(int(lv[0]), int(lv[1]))})
			placed += 1
			var nb: int = mini(hostiles - 1, 1 + (1 if risk >= 2 else 0) + (1 if risk >= 3 else 0))
			for k in nb:
				var gc: int = _near(rng, obj, used, 2, S, c)
				if gc >= 0:
					used[gc] = true
					agents.append({"role": "bodyguard", "cell": gc, "fac": int(facs[placed % facs.size()]), "name": "", "lv": rng.randi_range(int(lv[0]), int(lv[1]))})
					placed += 1
		"rescue":
			agents.append({"role": "hostage", "cell": obj, "fac": 0, "name": o["target"], "lv": 0})
	# the rest of the hostiles: random rooms, weighted by size, never in the start room (inside) nor within 8 of the player (outside)
	var weights: Array = []
	var wsum := 0
	for i in n:
		var wgt: int = 0 if (inside and i == start_room) else (inner[i] as Rect2i).get_area() + (12 if i == obj_room else 0)
		weights.append(wgt)
		wsum += wgt
	var guard_n: int = hostiles - placed
	var guard_idx := placed
	for k in guard_n:
		var gc2: int = -1
		for tries in 30:
			var rv: int = rng.randi() % maxi(1, wsum)
			var ri: int = 0
			for i in n:
				rv -= int(weights[i])
				if rv < 0:
					ri = i
					break
			var cand_c: int = _pick_free(rng, inner[ri], used, S)
			if cand_c >= 0 and _dist(cand_c, entry, S) >= 8:
				gc2 = cand_c
				break
		if gc2 < 0:
			continue
		used[gc2] = true
		agents.append({"role": "guard", "cell": gc2, "fac": int(facs[guard_idx % facs.size()]), "name": "", "lv": rng.randi_range(int(lv[0]), int(lv[1]))})
		guard_idx += 1
	# ---- markers the NPC simulation needs (it builds its flow fields from them): the first cell of three rooms
	var mk := PackedInt32Array()
	for i in mini(3, n):
		var ir: Rect2i = inner[(i * (n / 3 if n >= 3 else 1)) % n]
		mk.append(ir.position.y * S + ir.position.x)
	c.homes = mk
	c.works = mk
	c.shops = mk
	c.homes_g = mk
	c.works_g = mk
	c.shops_g = mk
	c.homes_t = PackedInt32Array()
	c.works_t = PackedInt32Array()
	c.shops_t = PackedInt32Array()
	c.lairs = PackedInt32Array()
	c.subway = {"ring": PackedInt32Array(), "stops": []}
	c.tower_info = []
	c.vaults = []
	c.venues = []
	c.towers = []
	c.zmax = 0
	c.nlev = 3
	var rock := PackedByteArray()
	rock.resize(s2)
	rock.fill(CG.EARTH)
	var all: PackedByteArray = c.tiles.duplicate()
	all.append_array(rock)
	all.append_array(rock)
	c.tiles = all
	c.links = {}
	c.haslink = PackedByteArray()
	c.haslink.resize(all.size())
	c.set_meta("site", site)
	return c

## one random spanning tree of the room graph, grown outwards from the start room, never giving a room more doors than its cap while another choice exists
static func _grow_tree(rng: RandomNumberGenerator, n: int, edges: Array, cap: Array, start: int) -> Dictionary:
	var deg: Array = []
	deg.resize(n)
	deg.fill(0)
	var used_e := {}
	var in_tree := {start: true}
	var over := 0
	while in_tree.size() < n:
		var ok_e: Array = []
		var any_e: Array = []
		for k in edges.size():
			var e: Dictionary = edges[k]
			var ia: bool = in_tree.has(e["a"])
			var ib: bool = in_tree.has(e["b"])
			if ia == ib:
				continue
			var t: int = int(e["a"]) if ia else int(e["b"])
			any_e.append(k)
			if deg[t] < cap[t]:
				ok_e.append(k)
		var pool: Array = ok_e
		if pool.is_empty():
			if any_e.is_empty():
				break
			pool = any_e
		var ek: int = pool[rng.randi() % pool.size()]
		var ee: Dictionary = edges[ek]
		var ta: int = int(ee["a"]) if in_tree.has(ee["a"]) else int(ee["b"])
		if deg[ta] >= cap[ta]:
			over += 1
		used_e[ek] = 1
		deg[ee["a"]] += 1
		deg[ee["b"]] += 1
		in_tree[ee["a"]] = true
		in_tree[ee["b"]] = true
	return {"deg": deg, "used": used_e, "over": over}

## cut a w x h footprint into rooms: repeatedly split a leaf (the largest, or any at random for mixed buildings) along its longer side; rooms share their walls
static func _cut(rng: RandomNumberGenerator, w: int, h: int, nrooms: int, mind: int, layout: String) -> Array:
	var leaves: Array = [Rect2i(0, 0, w, h)]
	while leaves.size() < nrooms:
		var cand: Array = []
		for i in leaves.size():
			var r: Rect2i = leaves[i]
			if r.size.x >= 2 * mind - 1 or r.size.y >= 2 * mind - 1:
				cand.append(i)
		if cand.is_empty():
			break
		var pick: int = cand[rng.randi() % cand.size()]
		if layout != "mix" and rng.randf() > 0.25:
			pick = cand[0]
			for i in cand:
				if (leaves[i] as Rect2i).get_area() > (leaves[pick] as Rect2i).get_area():
					pick = i
		var r: Rect2i = leaves[pick]
		var can_v: bool = r.size.x >= 2 * mind - 1
		var can_h: bool = r.size.y >= 2 * mind - 1
		var vertical: bool = can_v and (not can_h or float(r.size.x) > float(r.size.y) * (0.9 + 0.3 * rng.randf()))
		var a: Rect2i
		var b: Rect2i
		if vertical:
			var lo: int = r.position.x + mind - 1
			var hi: int = r.end.x - 1 - (mind - 1)
			var p: int = lo + int(float(hi - lo) * (0.3 + 0.4 * rng.randf()))
			a = Rect2i(r.position.x, r.position.y, p - r.position.x + 1, r.size.y)
			b = Rect2i(p, r.position.y, r.end.x - p, r.size.y)
		else:
			var lo2: int = r.position.y + mind - 1
			var hi2: int = r.end.y - 1 - (mind - 1)
			var p2: int = lo2 + int(float(hi2 - lo2) * (0.3 + 0.4 * rng.randf()))
			a = Rect2i(r.position.x, r.position.y, r.size.x, p2 - r.position.y + 1)
			b = Rect2i(r.position.x, p2, r.size.x, r.end.y - p2)
		leaves[pick] = a
		leaves.append(b)
	return leaves

## put a door on a shared wall run (away from `avoid`, a door already on it, when given); false if there was no room
static func _door(rng: RandomNumberGenerator, e: Dictionary, S: int, doors: Array, door_set: Dictionary, avoid: int) -> bool:
	for _k in 12:
		var v: int = rng.randi_range(int(e["lo"]), int(e["hi"]))
		var cell: int = (v * S + int(e["c"])) if e["vert"] else (int(e["c"]) * S + v)
		if door_set.has(cell):
			continue
		if avoid >= 0 and _dist(cell, avoid, S) < 3:
			continue
		doors.append({"cell": cell, "a": int(e["a"]), "b": int(e["b"])})
		door_set[cell] = true
		return true
	return false

static func _dist(a: int, b: int, S: int) -> int:
	return maxi(absi(a % S - b % S), absi(a / S - b / S))

static func _centre(r: Rect2i, S: int) -> int:
	return (r.position.y + r.size.y / 2) * S + r.position.x + r.size.x / 2

static func _near_used(used: Dictionary, cell: int, r: int, S: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if used.has(cell + dy * S + dx):
				return true
	return false

## a cell whose eight neighbours are all floor (no wall, door or portal beside it)
static func _clear8(c, cell: int, S: int, used: Dictionary) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var q: int = cell + dy * S + dx
			var tt: int = c.tiles[q]
			if not CG.is_floor(tt):
				return false
			if used.has(q):
				return false
	return true

## a cell for a device or a case: floor all round it, nothing used near, so it is reachable from every side
static func _pick_clear(rng: RandomNumberGenerator, rect: Rect2i, used: Dictionary, c, S: int) -> int:
	if rect.size.x < 3 or rect.size.y < 3:
		return -1
	for _k in 80:
		var x: int = rng.randi_range(rect.position.x + 1, rect.end.x - 2)
		var y: int = rng.randi_range(rect.position.y + 1, rect.end.y - 2)
		var cell: int = y * S + x
		if _clear8(c, cell, S, used):
			return cell
	return -1

## a free cell in a room (not on a prop, door neighbourhood or another person)
static func _pick_free(rng: RandomNumberGenerator, rect: Rect2i, used: Dictionary, S: int) -> int:
	for _k in 40:
		var x: int = rng.randi_range(rect.position.x, rect.end.x - 1)
		var y: int = rng.randi_range(rect.position.y, rect.end.y - 1)
		var cell: int = y * S + x
		if not used.has(cell):
			return cell
	return -1

## a free floor cell within r of another
static func _near(rng: RandomNumberGenerator, cell: int, used: Dictionary, r: int, S: int, c) -> int:
	for _k in 40:
		var x: int = cell % S + rng.randi_range(-r, r)
		var y: int = cell / S + rng.randi_range(-r, r)
		var c2: int = y * S + x
		var tt: int = c.tiles[c2]
		if c2 != cell and not used.has(c2) and (tt == CG.TID["floor_steel"] or tt == CG.TID["floor_clean"]):
			return c2
	return -1


## A Temp Agency job's floor: white collar (carpet, desks, cubicles, copiers) or blue collar (concrete, racks, pallets, conveyors); no hostiles, a few coworkers,
## and one work station (a mission_device tile) in each of the job's rooms, one per task.
static func _dress_temp(c, o: Dictionary, rng: RandomNumberGenerator, inner: Array, used: Dictionary, S: int, site: Dictionary, far_rooms: Array, start_room: int, inside: bool) -> void:
	var j: Dictionary = TJ.job_of(o)
	var style: Dictionary = TJ.floor_style(String(o["collar"]))
	var kinds: Array = (style["rooms"] as Dictionary).keys()
	var floors: Array = style["floors"]
	var room_kind: Array = []
	var prop_at := {}
	c.movables = []
	# the stations: one in each of the job's rooms (the furthest rooms first), never in the start room
	var rooms_for: Array = far_rooms.duplicate()
	var stations: Array = []
	var nst: int = (j["stations"] as Array).size()
	for k in nst:
		var placed := false
		for tries in rooms_for.size():
			var ri: int = rooms_for[(k + tries * 1) % rooms_for.size()] if tries == 0 else rooms_for[rng.randi() % rooms_for.size()]
			var oc: int = _pick_clear(rng, inner[ri], used, c, S)
			if oc >= 0:
				used[oc] = true
				c.tiles[oc] = CG.TID["mission_device"]
				c.under[oc] = CG.TID[floors[0]]
				stations.append([oc, k])
				placed = true
				break
		if not placed:
			push_error("temp site: no room for station %d" % k)
	site["stations"] = stations
	site["objective"] = int(stations[0][0]) if not stations.is_empty() else int(site["objective"])
	site["collar"] = o["collar"]
	site["room_kind"] = room_kind
	for i in inner.size():
		var ir: Rect2i = inner[i]
		var fl: int = CG.TID[floors[rng.randi() % floors.size()]]
		for y in range(ir.position.y, ir.end.y):
			for x in range(ir.position.x, ir.end.x):
				if c.tiles[y * S + x] != CG.TID["portal"] and c.tiles[y * S + x] != CG.TID["mission_device"]:
					c.tiles[y * S + x] = fl
		var kind: String = kinds[i % kinds.size()]
		room_kind.append(kind)
		var list: Array = (style["rooms"] as Dictionary)[kind]
		var want_p: int = ir.get_area() / 20
		for _k in want_p * 10:
			if want_p <= 0:
				break
			var cell: int = rng.randi_range(ir.position.y + 1, maxi(ir.position.y + 1, ir.end.y - 2)) * S + rng.randi_range(ir.position.x + 1, maxi(ir.position.x + 1, ir.end.x - 2))
			if used.has(cell) or not _clear8(c, cell, S, used) or _near_used(prop_at, cell, 1, S):
				continue
			prop_at[cell] = true
			c.tiles[cell] = CG.TID[list[rng.randi() % list.size()]]
			want_p -= 1
	for cell in prop_at:
		used[cell] = true
	# coworkers: harmless civilians standing about on free floor
	var agents: Array = site["agents"]
	var ncw: int = clampi(inner.size() / 2, 2, 6)
	for k in ncw:
		var ri2: int = rng.randi() % inner.size()
		if inside and ri2 == start_room:
			continue
		var cc: int = _pick_free(rng, inner[ri2], used, S)
		if cc >= 0:
			used[cc] = true
			agents.append({"role": "coworker", "cell": cc, "fac": 0, "name": "", "lv": 0})
