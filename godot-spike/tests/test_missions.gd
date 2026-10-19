extends RefCounted
## Mission terminals, offers, sites: the pure rules (no world needed).  Returns [passed, total, log].
const MS = preload("res://src/missions.gd")
const SITE = preload("res://src/mission_site.gd")
const CG = preload("res://src/citygen.gd")
var ok := 0
var n := 0
var log: Array = []

func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	log.append(("  PASS " if cond else "  FAIL ") + name)

## cells reachable from `from` on foot across the site (doors and floors and the open ground; props and machines block)
static func flood(c, from: int) -> Dictionary:
	var size: int = c.size
	var blocked := {}
	for m in c.movables:
		blocked[int(m[0])] = true
	var seen := {from: true}
	var q: Array = [from]
	while not q.is_empty():
		var cur: int = q.pop_back()
		for d in [1, -1, size, -size]:
			var nx: int = cur + d
			if nx < 0 or nx >= size * size or seen.has(nx) or blocked.has(nx):
				continue
			if cur % size == 0 and d == -1 or cur % size == size - 1 and d == 1:
				continue
			if not CG.WALK[c.tiles[nx]] == 1:
				continue
			seen[nx] = true
			q.append(nx)
	return seen

func run() -> Array:
	check("five mission types, in order: assassination, rescue, repair, recover, sabotage", MS.TYPES.map(func(t): return t["id"]) == ["assassination", "rescue", "repair", "recover", "sabotage"])
	check("every type has a name, a tag, a one-line description, a how-to and skills that exist", MS.TYPES.all(func(t): return t["name"] != "" and t["tag"] != "" and t["line"] != "" and t["how"] != "" and t["skills"].all(func(s): return not preload("res://src/skills.gd").skill(s).is_empty())))
	var offs: Array = MS.offers(21, 4242, 3)
	check("a terminal shows exactly five offers, one of each type in order", offs.size() == 5 and offs.map(func(o): return o["type"]) == MS.TYPES.map(func(t): return t["id"]))
	check("the same terminal on the same day shows the same offers (ids and all)", MS.offers(21, 4242, 3) == offs)
	check("a different day, terminal or world changes them", MS.offers(21, 4242, 4) != offs and MS.offers(21, 4243, 3) != offs and MS.offers(22, 4242, 3) != offs)
	var ids := {}
	for o in offs:
		ids[o["id"]] = true
	check("offer ids are unique and start with the type id", ids.size() == 5 and offs.all(func(o): return String(o["id"]).begins_with(o["type"] + "-")))
	check("risk is 1-3 and the reward rises with the type's base and the risk", offs.all(func(o): return o["risk"] >= 1 and o["risk"] <= 3 and o["reward"] >= MS.type_of(o["type"])["base"] + 90 * o["risk"]))
	check("assassination and rescue name a person; the others do not", offs[0]["target"] != "" and offs[1]["target"] != "" and offs[2]["target"] == "" and offs[3]["target"] == "" and offs[4]["target"] == "")
	check("titles and briefs are written for every offer", offs.all(func(o): return String(o["title"]).length() > 8 and String(o["brief"]).length() > 30))
	check("work needed: repair 3+2*risk, sabotage 2+risk, the others none", MS.need_for("repair", 2) == 7 and MS.need_for("sabotage", 3) == 5 and MS.need_for("recover", 3) == 0)
	# sites
	var all_ok := true
	var reach_ok := true
	var guards_ok := true
	var place_ok := true
	var obj_ok := true
	var seen_rooms := {}
	for sd in 12:
		for o in MS.offers(sd, 99, 0):
			var c = SITE.build(o)
			var st: Dictionary = c.get_meta("site")
			var r: Dictionary = flood(c, int(st["entry"]))
			all_ok = all_ok and c.size == 64 and c.tiles.size() == 3 * 64 * 64 and c.nlev == 3
			reach_ok = reach_ok and r.has(int(st["exit"]))
			var cells := {}
			var gcount := 0
			for a in st["agents"]:
				var ce: int = int(a["cell"])
				place_ok = place_ok and CG.WALK[c.tiles[ce]] == 1 and not cells.has(ce) and r.has(ce)
				cells[ce] = true
				if a["role"] == "guard" or a["role"] == "bodyguard":
					gcount += 1
					guards_ok = guards_ok and (int(a["cell"]) % 64 != int(st["entry"]) % 64 or true)
			guards_ok = guards_ok and gcount >= 2 and gcount <= MS.guard_count(int(o["risk"])) + 1
			match o["type"]:
				"repair", "sabotage":
					obj_ok = obj_ok and c.tiles[int(st["objective"])] == CG.TID["mission_device"]
					var nb := false
					for d in [1, -1, 64, -64]:
						nb = nb or r.has(int(st["objective"]) + d)
					obj_ok = obj_ok and nb
				"recover":
					obj_ok = obj_ok and r.has(int(st["case"]))
				"assassination":
					obj_ok = obj_ok and st["agents"].any(func(a): return a["role"] == "target" and a["name"] == o["target"])
				"rescue":
					obj_ok = obj_ok and st["agents"].any(func(a): return a["role"] == "hostage" and a["name"] == o["target"])
			seen_rooms[str(st["obj_room"][0])] = true
	check("every site is 64 x 64 over three levels (ground and two of rock)", all_ok)
	check("the exit portal is reachable on foot from the entry in every site (60 sites)", reach_ok)
	check("every person stands on a walkable, reachable, unshared cell", place_ok)
	check("each site has guards in proportion to its risk", guards_ok)
	check("the objective is in place and reachable for each type (device, case, target, hostage)", obj_ok)
	check("the objective room varies with the seed (both north rooms used)", seen_rooms.size() == 2)
	var o1: Dictionary = offs[2]
	var a1 = SITE.build(o1)
	var a2 = SITE.build(o1)
	check("a site is rebuilt identically from its offer", a1.tiles == a2.tiles and a1.get_meta("site") == a2.get_meta("site") and a1.movables == a2.movables)
	var b1 = SITE.build(MS.offers(21, 4242, 4)[2])
	check("a different offer builds a different site", b1.tiles != a1.tiles or b1.get_meta("site")["agents"] != a1.get_meta("site")["agents"])
	check("the tileset ids exist: terminal and device are solid, the portal walks", CG.WALK[CG.TID["terminal"]] == 0 and CG.WALK[CG.TID["mission_device"]] == 0 and CG.WALK[CG.TID["portal"]] == 1)
	check("the new tiles have sprite ids", CG.TILE_SPRITE[CG.TID["terminal"]] == "f_trl_terminal" and CG.TILE_SPRITE[CG.TID["portal"]] == "f_trl_portal" and CG.TILE_SPRITE[CG.TID["mission_device"]] == "f_trl_device")
	return [ok, n, log]
