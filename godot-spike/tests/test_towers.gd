extends RefCounted
## Tower interiors: every tower is offices or flats (or both), has a street door, a lobby, lifts that are always reachable, furnished floors,
## one gym floor per residential tower, and shops on the street where there is room.  Returns [passed, total, log]
const ISL = preload("res://src/island.gd")
const CG = preload("res://src/citygen.gd")
const LV = preload("res://src/levels.gd")

## cells reachable from `start` on one level by walking (doors open, locked doors and furniture closed)
func _flood(c, start: int, s2: int, box: Rect2i) -> Dictionary:
	var lvl: int = start / s2
	var seen := {start: true}
	var q: Array = [start]
	var head := 0
	while head < q.size():
		var cur: int = q[head]
		head += 1
		for nb in [cur - 1, cur + 1, cur - c.size, cur + c.size]:
			if nb / s2 != lvl or nb < 0 or nb >= c.tiles.size() or seen.has(nb):
				continue
			var cc: int = nb % s2
			if not box.has_point(Vector2i(cc % c.size, cc / c.size)):
				continue
			var tt: int = c.tiles[nb]
			if CG.WALK[tt] == 1 and tt != CG.LOCKED:
				seen[nb] = true
				q.append(nb)
	return seen

func _box(t: Dictionary) -> Rect2i:
	return Rect2i(t["x0"], t["y0"], t["x1"] - t["x0"] + 1, t["y1"] - t["y0"] + 1)

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	var isl = ISL.new(7)
	var c = isl.build_zone(ISL.CITY_ZONE.x, ISL.CITY_ZONE.y)
	LV.build(c, 7)
	var s2: int = c.size * c.size
	var infos: Array = c.tower_info
	check.call("the city has towers (%d)" % infos.size(), infos.size() >= 20)
	var uses := {"office": 0, "apartment": 0, "hybrid": 0}
	var bad_lift := []
	var bad_door := []
	var bad_gym := []
	var shops := 0
	var no_lift := 0
	var floors_checked := 0
	var bad_marker := []
	var tall_no_elev := 0
	for t in infos:
		uses[t["use"]] = int(uses[t["use"]]) + 1
		shops += int(t["shops"])
		var h: int = t["h"]
		# the street door leads to the lobby, and from there to the stairs and the lift
		var d: Vector2i = t["door"]
		var door_cell: int = d.y * c.size + d.x
		if c.tiles[door_cell] != CG.DOOR:
			bad_door.append("door tile %s" % [str(d)])
			continue
		var outside := -1
		for dd in [-1, 1, -c.size, c.size]:
			var o: int = door_cell + dd
			if CG.WALK[c.tiles[o]] == 1 and (o % c.size < t["x0"] or o % c.size > t["x1"] or o / c.size < t["y0"] or o / c.size > t["y1"]):
				outside = o
		if outside < 0:
			bad_door.append("no street outside %s" % [str(d)])
			continue
		var seen0: Dictionary = _flood(c, door_cell, s2, _box(t))
		if not seen0.has(int(t["stairs"])) or not seen0.has(int(t["elev"])):
			bad_door.append("lobby does not reach the lifts %s" % [str(d)])
		# every upper floor: the lift and the stairs are reachable from each other, and so is everything a person is sent to
		for z in range(1, h):
			var base: int = c.lvl_of_z(z) * s2
			var seen: Dictionary = _flood(c, base + int(t["stairs"]), s2, _box(t))
			floors_checked += 1
			if not seen.has(base + int(t["elev"])):
				bad_lift.append("z%d" % z)
			elif h > 3 and c.tiles[base + int(t["elev"])] != CG.ELEVATOR:
				bad_lift.append("z%d tile" % z)
		if h > 3 and c.tiles[int(t["elev"])] != CG.ELEVATOR:
			tall_no_elev += 1
		# gym floor
		if t["use"] != "office":
			var gz: int = t["gym_z"]
			if gz < 1 or gz >= h:
				if h > 2:
					bad_gym.append("no gym z=%d h=%d" % [gz, h])
			else:
				var gb: int = c.lvl_of_z(gz) * s2
				var rubber := 0
				for y in range(t["y0"], t["y1"] + 1):
					for x in range(t["x0"], t["x1"] + 1):
						var tt: int = c.tiles[gb + y * c.size + x]
						var un: int = c.under[gb + y * c.size + x]
						if tt == CG.TID["floor_rubber"] or un == CG.TID["floor_rubber"]:
							rubber += 1
				if rubber < 20:
					bad_gym.append("gym floor is not rubber (%d)" % rubber)
	log.append("  (towers: %d offices, %d apartment, %d hybrid; %d with a shop on the street; %d floors checked)" % [uses["office"], uses["apartment"], uses["hybrid"], shops, floors_checked])
	check.call("every tower has a street door that leads to its lobby and the lifts (%d bad: %s)" % [bad_door.size(), str(bad_door.slice(0, 3))], bad_door.is_empty())
	check.call("the lift and the stairs are reachable from each other on every floor (%d bad: %s)" % [bad_lift.size(), str(bad_lift.slice(0, 3))], bad_lift.is_empty())
	check.call("every tower over three storeys has a lift (%d without)" % tall_no_elev, tall_no_elev == 0)
	check.call("both uses exist: offices and flats", uses["office"] >= 5 and uses["apartment"] + uses["hybrid"] >= 5)
	check.call("some towers are mixed use, with a shop on the street (%d)" % shops, shops >= 4)
	check.call("every residential tower has a gym floor (%d problems: %s)" % [bad_gym.size(), str(bad_gym.slice(0, 3))], bad_gym.is_empty())
	# furniture: the floors are furnished with the new pieces
	var counts := {}
	for t in infos:
		for z in range(1, int(t["h"])):
			var base: int = c.lvl_of_z(z) * s2
			for y in range(t["y0"], t["y1"] + 1):
				for x in range(t["x0"], t["x1"] + 1):
					var tt: int = c.tiles[base + y * c.size + x]
					if tt >= CG.EXTRA0:
						counts[tt] = int(counts.get(tt, 0)) + 1
	var names := {}
	for k in CG.TID:
		names[CG.TID[k]] = k
	var seen_names := []
	for k in counts:
		seen_names.append(String(names.get(k, "?")))
	for must in ["bed_single", "desk_workstation", "kitchen_counter", "toilet", "treadmill", "meeting_table", "office_chair"]:
		check.call("%s is in the towers" % must, seen_names.has(must))
	# markers: every flat has a home, every home and workplace can be walked to from its floor's stairs
	check.call("flats are recorded for later (%d)" % c.apartments.size(), c.apartments.size() >= 100)
	var by_no := {}
	for t in infos:
		by_no[int(t["no"])] = t
	var unreach := 0
	var tested := 0
	for ap in c.apartments:
		if tested >= 120:
			break
		tested += 1
		var cell: int = ap["cell"]
		var lvl: int = cell / s2
		var tower: Dictionary = by_no.get(int(ap["tower"]), {})
		if tower.is_empty():
			continue
		var base: int = lvl * s2
		var seen: Dictionary = _flood(c, base + int(tower["stairs"]), s2, _box(tower))
		if not seen.has(cell):
			unreach += 1
	check.call("every flat (sampled) can be walked into from the stairs (%d unreachable of %d)" % [unreach, tested], unreach == 0)
	return [st[0], st[1], log]
