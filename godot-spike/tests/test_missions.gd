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
	check("a different day, terminal, world or batch changes them", MS.offers(21, 4242, 4) != offs and MS.offers(21, 4243, 3) != offs and MS.offers(22, 4242, 3) != offs and MS.offers(21, 4242, 3, 1) != offs)
	var ids := {}
	for o in offs:
		ids[o["id"]] = true
	check("offer ids are unique and start with the type id", ids.size() == 5 and offs.all(func(o): return String(o["id"]).begins_with(o["type"] + "-")))
	check("risk is 1-3 and the pay follows the hostile count and the risk", offs.all(func(o): return o["risk"] >= 1 and o["risk"] <= 3 and o["reward"] == MS.reward_for(o["type"], o["hostiles"], o["risk"])))
	check("assassination and rescue name a person; the others do not", offs[0]["target"] != "" and offs[1]["target"] != "" and offs[2]["target"] == "" and offs[3]["target"] == "" and offs[4]["target"] == "")
	check("titles and briefs are written for every offer, and a brief names the opposition", offs.all(func(o): return String(o["title"]).length() > 8 and String(o["brief"]).length() > 30 and String(o["brief"]).contains("Opposition:")))
	check("work needed: repair 3+2*risk, sabotage 2+risk, the others none", MS.need_for("repair", 2) == 7 and MS.need_for("sabotage", 3) == 5 and MS.need_for("recover", 3) == 0)
	# ---- the switches
	var low_ok := true
	var mod_ok := true
	var sweep := {}
	for sd in 40:
		for swi in [[1, 1, 1, 1], [0, 0, 0, 0], [2, 2, 2, 2], [0, 2, 0, 2], [1, 1, 1, 0], [1, 1, 1, 2]]:
			var bo: Array = MS.offers(sd, 900 + sd, sd % 9, sd % 3, swi, 3)
			low_ok = low_ok and bo.any(func(o): return o["risk"] == 1)
			mod_ok = mod_ok and bo.any(func(o): return o["risk"] == 2)
	check("every board, whatever the settings, has one Low and one Moderate contract", low_ok and mod_ok)
	var all_a: Array = MS.offers(3, 50, 0, 0, [0, 0, 0, 0], 4)
	check("Value A on every switch: open, affiliated, long (20 rooms); Risk Low makes four Low and a Moderate", all_a.all(func(o): return o["layout"] == "open" and o["faction"] == "affiliated" and o["rooms"] == 20 and o["length"] == "long") and all_a.filter(func(o): return o["risk"] == 1).size() == 4)
	var all_b: Array = MS.offers(3, 50, 0, 0, [2, 2, 2, 2], 4)
	check("Value B on every switch: closed, unaffiliated, short (5 rooms); Risk High makes three High, a Low and a Moderate", all_b.all(func(o): return o["layout"] == "closed" and o["faction"] == "unaffiliated" and o["rooms"] == 5 and o["length"] == "short" and o["aff"] == 0) and all_b.filter(func(o): return o["risk"] == 3).size() == 3)
	var seen_l := {}
	var seen_f := {}
	var seen_n := {}
	var share_ok := true
	var nap_neutral := false
	var nap_affil := false
	var rooms_ok := true
	for sd in 120:
		for o in MS.offers(sd, 77, sd, 0, MS.NEUTRAL, 2):
			seen_l[o["layout"]] = true
			seen_f[o["faction"]] = true
			seen_n[o["length"]] = true
			rooms_ok = rooms_ok and o["rooms"] in [20, 10, 5]
			if o["faction"] == "mix":
				share_ok = share_ok and o["share"] >= 0.25 and o["share"] <= 0.5 and o["aff"] in [1, 3, 5]
			nap_neutral = nap_neutral or (o["faction"] == "mix" and o["aff"] == 2)
		for o in MS.offers(sd, 78, sd, 0, [0, 1, 1, 1], 2):
			nap_affil = nap_affil or o["aff"] == 2
	check("Neutral picks A, B or the mix at random for layout, opposition and length", seen_l.size() == 3 and seen_f.size() == 3 and seen_n.size() == 3 and rooms_ok)
	check("the neutral opposition is one organisation for 25-50%, never the NAP, the rest gang members", share_ok and not nap_neutral)
	check("an Affiliated board can name the NAP", nap_affil)
	var hc_ok := true
	var lay_same := true
	for o in MS.offers(9, 3, 3, 0, [1, 1, 1, 1], 5):
		hc_ok = hc_ok and o["hostiles"] == MS.hostile_count(o["rooms"], o["risk"])
	for rm in [5, 10, 30]:
		for rk in [1, 2, 3]:
			lay_same = lay_same and MS.hostile_count(rm, rk) >= 3
	check("hostiles follow rooms and risk (and nothing else)", hc_ok and lay_same and MS.hostile_count(30, 2) > MS.hostile_count(10, 2) and MS.hostile_count(10, 2) > MS.hostile_count(5, 2) and MS.hostile_count(10, 3) > MS.hostile_count(10, 2) and MS.hostile_count(10, 2) > MS.hostile_count(10, 1))
	check("the neutral site holds 10 rooms and about 7 hostiles at moderate risk", MS.ROOMS["mid"] == 10 and MS.hostile_count(10, 2) == 7 and MS.ROOMS["long"] == 20 and MS.ROOMS["short"] == 5)
	check("levels: Low is 1-2 below the player, Moderate at or one below, High at or one above (clamped 0-10)", MS.level_range(5, 1) == [3, 4] and MS.level_range(5, 2) == [4, 5] and MS.level_range(5, 3) == [5, 6] and MS.level_range(0, 1) == [0, 0] and MS.level_range(10, 3) == [10, 10])
	check("pay rises with the hostile count and with the risk, for every type", MS.TYPES.all(func(t): return MS.reward_for(t["id"], 20, 2) > MS.reward_for(t["id"], 10, 2) and MS.reward_for(t["id"], 10, 2) > MS.reward_for(t["id"], 5, 2) and MS.reward_for(t["id"], 10, 3) > MS.reward_for(t["id"], 10, 2)))
	var lg: Array = MS.offers(4, 5, 5, 0, [0, 1, 0, 1], 3)
	var sh: Array = MS.offers(4, 5, 5, 0, [0, 1, 2, 1], 3)
	var lsum := 0
	var ssum := 0
	for k in 5:
		lsum += int(lg[k]["reward"])
		ssum += int(sh[k]["reward"])
	check("a Long board pays more than a Short one", lsum > ssum * 1.5)
	check("a board's offers carry the terminal and batch they came from", offs.all(func(o): return o["term"] == 4242 and o["gen"] == 0))
	# ---- sites: every layout at every length, every type
	var all_ok := true
	var reach_ok := true
	var count_ok := true
	var place_ok := true
	var obj_ok := true
	var room_ok := true
	var spread_ok := true
	var fac_ok := true
	var closed_deg := 0
	var closed_rooms := 0
	var closed_in := true
	var open_ext := true
	var open_out := true
	var open_deg := 0.0
	var open_dn := 0
	var area_open := 0.0
	var area_closed := 0.0
	var n_open := 0
	var n_closed := 0
	var mix_vary := true
	var k_all := 0
	for lay in ["open", "closed", "mix"]:
		for ln in ["short", "mid", "long"]:
			for sd in 4:
				var o: Dictionary = MS.offers(sd * 5 + 1, 300 + sd, sd, 0, MS.NEUTRAL, 3)[(k_all + sd) % 5].duplicate()
				k_all += 1
				var fct: String = ["affiliated", "mix", "unaffiliated"][(sd + k_all) % 3]
				o["layout"] = lay
				o["length"] = ln
				o["rooms"] = MS.ROOMS[ln]
				o["faction"] = fct
				o["aff"] = [1, 3, 5, 2][sd] if fct != "unaffiliated" else 0
				o["share"] = 0.35 if fct == "mix" else (1.0 if fct == "affiliated" else 0.0)
				o["hostiles"] = MS.hostile_count(o["rooms"], int(o["risk"]))
				o["seed"] = 1000 + sd * 31 + k_all
				if fct == "mix" and o["aff"] == 2:
					o["aff"] = 5
				var c = SITE.build(o)
				var st: Dictionary = c.get_meta("site")
				var S: int = c.size
				var r: Dictionary = flood(c, int(st["entry"]))
				all_ok = all_ok and S >= 64 and c.tiles.size() == 3 * S * S and c.nlev == 3 and st["size"] == S
				reach_ok = reach_ok and r.has(int(st["exit"]))
				room_ok = room_ok and st["rooms"].size() == o["rooms"]
				var cells := {}
				var hostile_n := 0
				var aff_n := 0
				var gang_n := 0
				for a in st["agents"]:
					var ce: int = int(a["cell"])
					place_ok = place_ok and CG.WALK[c.tiles[ce]] == 1 and not cells.has(ce) and r.has(ce)
					cells[ce] = true
					if a["role"] != "hostage":
						hostile_n += 1
						if int(a["fac"]) == 4:
							gang_n += 1
						elif int(a["fac"]) == int(o["aff"]):
							aff_n += 1
						spread_ok = spread_ok and a["lv"] >= o["lv"][0] and a["lv"] <= o["lv"][1]
						if st["inside"]:
							spread_ok = spread_ok and not _in_room(st["rooms"][st["start_room"]], ce, S)
						else:
							spread_ok = spread_ok and maxi(absi(ce % S - int(st["entry"]) % S), absi(ce / S - int(st["entry"]) / S)) >= 8
				count_ok = count_ok and hostile_n == o["hostiles"]
				match fct:
					"affiliated": fac_ok = fac_ok and aff_n == hostile_n
					"unaffiliated": fac_ok = fac_ok and gang_n == hostile_n
					"mix": fac_ok = fac_ok and aff_n >= 1 and gang_n >= 1 and not st["agents"].any(func(a): return int(a["fac"]) == 2)
				match o["type"]:
					"repair", "sabotage":
						obj_ok = obj_ok and c.tiles[int(st["objective"])] == CG.TID["mission_device"]
						var nb := 0
						for d in [1, -1, S, -S, S + 1, S - 1, -S + 1, -S - 1]:
							nb += 1 if r.has(int(st["objective"]) + d) else 0
						obj_ok = obj_ok and nb == 8
					"recover":
						obj_ok = obj_ok and r.has(int(st["case"]))
					"assassination":
						obj_ok = obj_ok and st["agents"].any(func(a): return a["role"] == "target" and a["name"] == o["target"] and r.has(int(a["cell"])))
					"rescue":
						obj_ok = obj_ok and st["agents"].any(func(a): return a["role"] == "hostage" and a["name"] == o["target"])
				# door counts per room
				var degs: Array = []
				for ri in st["rooms"].size():
					degs.append(0)
				var rects: Array = st["rooms"]
				for dc in st["doors"]:
					for ri in rects.size():
						if _touches(rects[ri], int(dc), S):
							degs[ri] += 1
				var area_sum := 0.0
				for rc in rects:
					area_sum += float(rc[2] * rc[3])
				match lay:
					"closed":
						closed_in = closed_in and st["inside"] and st["ext_doors"].is_empty() and _in_room(rects[st["start_room"]], int(st["entry"]), S) and _in_room(rects[st["start_room"]], int(st["exit"]), S)
						for dg in degs:
							closed_rooms += 1
							closed_deg += 1 if (dg >= 1 and dg <= 2) else 0
						closed_in = closed_in and degs[st["start_room"]] == 1
						area_closed += area_sum / rects.size()
						n_closed += 1
					"open":
						open_ext = open_ext and st["ext_doors"].size() >= 2 and not st["inside"]
						var inb := false
						for ri in rects.size():
							inb = inb or _in_room(rects[ri], int(st["entry"]), S)
						open_out = open_out and not inb and c.tiles[int(st["exit"])] == CG.TID["portal"] and int(st["exit"]) / S > int(st["entry"]) / S
						for dg in degs:
							open_deg += dg
							open_dn += 1
						area_open += area_sum / rects.size()
						n_open += 1
					"mix":
						if ln != "short":
							var amin := 9999.0
							var amax := 0.0
							for rc in rects:
								amin = minf(amin, float(rc[2] * rc[3]))
								amax = maxf(amax, float(rc[2] * rc[3]))
							mix_vary = mix_vary and amax > 2.0 * amin
	check("every site is a square of at least 64 over three levels (ground and two of rock)", all_ok)
	check("every site has exactly the rooms its contract asks for (5, 10 or 30)", room_ok)
	check("the exit portal is reachable on foot from the entry in every site (%d sites)" % k_all, reach_ok)
	check("every person stands on a walkable, reachable, unshared cell", place_ok)
	check("the hostile count is exactly the contract's, at the contract's levels, away from the start", count_ok and spread_ok)
	check("opposition: affiliated sites are all the organisation, unaffiliated all gang, mixed are both and never the NAP", fac_ok)
	check("the objective is in place and reachable for each type (device with floor all round, case, target, hostage)", obj_ok)
	check("closed: you start inside, in a room with one door, the portal on its floor, no doors to the outside", closed_in)
	check("closed: nearly every room has one or two doors (%d of %d)" % [closed_deg, closed_rooms], float(closed_deg) >= 0.9 * float(closed_rooms))
	check("open: several doors to the outside, you start outside, the portal on the ground beyond", open_ext and open_out)
	check("open: three doors to a room on average", open_deg / float(maxi(1, open_dn)) >= 2.4)
	check("open rooms are much larger than closed ones (%.0f vs %.0f cells)" % [area_open / maxf(1.0, n_open), area_closed / maxf(1.0, n_closed)], area_open / maxf(1.0, n_open) > 1.9 * area_closed / maxf(1.0, n_closed))
	check("mixed buildings have both large and small rooms", mix_vary)
	# the objective's room: half the time one of the furthest third from the player
	var far := 0
	var total := 0
	var layouts_seen := {}
	for k in 240:
		var o2: Dictionary = MS.offers(k, 200 + k, k % 7, 0, MS.NEUTRAL, 2)[2].duplicate()
		o2["layout"] = ["open", "mix", "closed"][k % 3]
		o2["rooms"] = 10
		o2["length"] = "mid"
		o2["hostiles"] = 7
		var c2 = SITE.build(o2)
		var st2: Dictionary = c2.get_meta("site")
		var S2: int = c2.size
		var rooms2: Array = st2["rooms"]
		var order: Array = range(rooms2.size())
		if st2["inside"]:
			order.erase(st2["start_room"])
		var ent: int = int(st2["entry"])
		order.sort_custom(func(p, q): return _rd(rooms2[p], ent, S2) > _rd(rooms2[q], ent, S2))
		var rank: int = order.find(int(st2["obj_room_idx"]))
		total += 1
		far += 1 if rank >= 0 and rank < maxi(1, order.size() / 3) else 0
		layouts_seen[o2["layout"]] = true
	var frac: float = float(far) / float(total)
	check("the objective lands in the furthest third of rooms about two times in three (%.0f%%): half biased far, half anywhere" % (frac * 100.0), frac > 0.55 and frac < 0.80)
	var o1: Dictionary = offs[2]
	var a1 = SITE.build(o1)
	var a2 = SITE.build(o1)
	check("a site is rebuilt identically from its offer", a1.tiles == a2.tiles and a1.get_meta("site") == a2.get_meta("site") and a1.movables == a2.movables)
	var b1 = SITE.build(MS.offers(21, 4242, 3, 1)[2])
	check("a new batch builds different sites", b1.tiles != a1.tiles or b1.get_meta("site")["agents"] != a1.get_meta("site")["agents"])
	check("the tileset ids exist: terminal and device are solid, the portal walks", CG.WALK[CG.TID["terminal"]] == 0 and CG.WALK[CG.TID["mission_device"]] == 0 and CG.WALK[CG.TID["portal"]] == 1)
	check("the new tiles have sprite ids", CG.TILE_SPRITE[CG.TID["terminal"]] == "f_trl_terminal" and CG.TILE_SPRITE[CG.TID["portal"]] == "f_trl_portal" and CG.TILE_SPRITE[CG.TID["mission_device"]] == "f_trl_device")
	return [ok, n, log]

func _in_room(rc: Array, cell: int, S: int) -> bool:
	var x: int = cell % S
	var y: int = cell / S
	return x >= rc[0] and x < rc[0] + rc[2] and y >= rc[1] and y < rc[1] + rc[3]

## is the cell one of the wall cells round this room (so a door of it)?
func _touches(rc: Array, cell: int, S: int) -> bool:
	var x: int = cell % S
	var y: int = cell / S
	var inx: bool = x >= rc[0] and x < rc[0] + rc[2]
	var iny: bool = y >= rc[1] and y < rc[1] + rc[3]
	return (inx and (y == rc[1] - 1 or y == rc[1] + rc[3])) or (iny and (x == rc[0] - 1 or x == rc[0] + rc[2]))

func _rd(rc: Array, cell: int, S: int) -> int:
	var cx: int = rc[0] + rc[2] / 2
	var cy: int = rc[1] + rc[3] / 2
	return maxi(absi(cx - cell % S), absi(cy - cell / S)) * 100 + mini(absi(cx - cell % S), absi(cy - cell / S))
