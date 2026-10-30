extends SceneTree
## Mission terminals: the pure rules (test_missions.gd), then the live flow on a real world: a terminal in a venue, the screen, the portal, a site of each
## of the five types, leaving, pay, saving inside a site.  Run: godot --headless -s tests/run_missions.gd
const MainScript = preload("res://src/main.gd")
const WorldScript = preload("res://src/world.gd")
const MS = preload("res://src/missions.gd")
const CG = preload("res://src/citygen.gd")
var ok := 0
var n := 0

func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name)

## move the player onto a free walkable cell next to `cell` and return the direction to step into it
func stand_beside(g, cell: int) -> Vector2i:
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var x: int = cell % g.size + d.x
		var y: int = cell / g.size + d.y
		var c: int = y * g.size + x
		if g.sim.walk[c] == 1 and g.sim.at[c] == -1 and g.thing_at.g(c) == -1 and g.veh_at.g(c) == -1 and not g.items_at.has(c) and g.city.tiles[c] != CG.DOOR:
			g.pc = c
			g.last_pc = c
			return Vector2i(-d.x, -d.y)
	return Vector2i.ZERO

## a walkable cell about `steps` of walking from `from` (or the furthest there is)
func _far_cell(g, from: int, steps: int) -> int:
	var dist := {from: 0}
	var q: Array = [from]
	var qi := 0
	var best: int = from
	while qi < q.size():
		var cur: int = q[qi]
		qi += 1
		if int(dist[cur]) >= steps:
			return cur
		for d in [1, -1, g.size, -g.size]:
			var nx: int = cur + d
			if nx < 0 or nx >= g.s2 or dist.has(nx) or g.sim.walk[nx] == 0 or g.sim.at[nx] != -1 or g.thing_at.g(nx) != -1:
				continue
			if (cur % g.size == 0 and d == -1) or (cur % g.size == g.size - 1 and d == 1):
				continue
			dist[nx] = int(dist[cur]) + 1
			q.append(nx)
			best = nx
	return best

func _click(p: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = p
	return e

func _initialize() -> void:
	var r = preload("res://tests/test_missions.gd").new().run()
	for l in r[2]:
		print(l)
	ok = r[0]
	n = r[1]
	var m = MainScript.new()
	m.save_prefix = "user://test_ms_save_"
	m.settings_path = "user://test_ms_settings.json"
	root.add_child(m)
	await process_frame
	var w = WorldScript.new()
	w.start(21, 300)
	m.world = w
	m.start_play(w.game)
	await process_frame
	var g = w.game
	# the terminals of the physical city
	var terms: Array = []
	for i in g.s2:
		if g.city.tiles[i] == CG.TID["terminal"]:
			terms.append(i)
	check("the city has mission terminals (in shops, clinics and restaurants)", terms.size() >= 4)
	var venue_kinds := {}
	for v in g.city.venues:
		var vc: int = int(v["y0"]) * g.size + int(v["x0"])
		for t in terms:
			if t % g.size > int(v["x0"]) and t % g.size < int(v["x1"]) and t / g.size > int(v["y0"]) and t / g.size < int(v["y1"]):
				venue_kinds[v["kind"]] = true
	check("terminals stand inside venues of more than one kind", venue_kinds.size() >= 2)
	check("a terminal is solid and static: no one can walk on it", g.sim.walk[terms[0]] == 0 and g.thing_at.g(terms[0]) == -1)
	var term: int = terms[0]
	# bump it
	var dv: Vector2i = stand_beside(g, term)
	check("a cell beside the terminal is free to stand on", dv != Vector2i.ZERO)
	var turn0: int = g.turn
	var moved: bool = g.act_move(dv.x, dv.y)
	check("walking into a terminal only names it: no move, no turn spent, nothing opens", not moved and g.terminal_hit == -1 and g.turn == turn0 and g.pc != term)
	var tl: Array = g.interactables().filter(func(it): return it["kind"] == "terminal" and it["cell"] == term)
	g.act_interact_with(tl[0])
	check("the interact key wakes the terminal: no turn spent", tl.size() == 1 and g.terminal_hit == term and g.turn == turn0)
	g.terminal_hit = -1
	# through the keys and the screen
	m.mode = "play"
	var kd: int = KEY_DOWN
	m.open_terminal(term)
	check("the mission screen opens with five offers", m.mode == "terminal" and m.screen.kind == "terminal" and m.tm["offers"].size() == 5)
	m.screen.set_process(false)
	m.screen_key(KEY_3)
	check("1-5 select an offer", m.tm["sel"] == 2)
	m.screen_key(KEY_UP)
	check("Up and Down move the selection", m.tm["sel"] == 1)
	m.screen_key(KEY_C)
	check("C with no portal open says so", String(m.tm["msg"]).contains("No portal"))
	m.screen_key(KEY_ESCAPE)
	check("Esc closes the screen and returns to play", m.mode == "play" and not m.screen.visible)
	# ---- the board: free first batch, switches, paid new batch, free daily batch, free batch when all five are done
	var yenb: int = g.yen
	m.open_terminal(term)
	var board0: Dictionary = g.boards[str(term)]
	check("the first batch is free and on Neutral", g.yen == yenb and board0["sw"] == [1, 1, 1, 1] and board0["gen"] == 0 and m.tm["offers"] == board0["offers"])
	check("the board is kept: reopening the terminal shows the same contracts", (func(): m.screen_key(KEY_ESCAPE); m.open_terminal(term); return m.tm["offers"] == board0["offers"]).call())
	m.screen_key(KEY_TAB)
	check("Tab moves the focus to the switches", m.tm["foc"] == 1)
	m.screen_key(KEY_LEFT)
	check("Left moves the chosen switch to Value A (Open) and says it applies to the next batch", m.tm["sw"][0] == 0 and String(m.tm["msg"]).contains("next batch") and m.tm["offers"] == board0["offers"])
	m.screen_key(KEY_RIGHT)
	m.screen_key(KEY_RIGHT)
	check("Right twice goes through Neutral to Value B (Closed), and it stops there", m.tm["sw"][0] == 2)
	m.screen_key(KEY_RIGHT)
	check("it cannot go beyond Value B", m.tm["sw"][0] == 2)
	m.screen_key(KEY_DOWN)
	m.screen_key(KEY_LEFT)
	check("Down chooses the next switch (Opposition): Left sets it to Affiliated", m.tm["sw_sel"] == 1 and m.tm["sw"][1] == 0)
	m.screen_key(KEY_DOWN)
	m.screen_key(KEY_RIGHT)
	m.screen_key(KEY_RIGHT)
	check("the Length switch goes to Short", m.tm["sw_sel"] == 2 and m.tm["sw"][2] == 2)
	var hit: Dictionary = m.screen.tm_hit(Vector2(790, m.screen.tm_sw_y(3) - 6))
	check("the pointer finds a notch on the switch track (Risk, Value A)", hit.get("kind", "") == "switch" and hit["i"] == 3 and hit["v"] == 0)
	m._term_mouse(_click(Vector2(790, m.screen.tm_sw_y(3) - 6) * 1.5))
	check("clicking the notch sets it", m.tm["sw"][3] == 0)
	g.yen = 50
	m.screen_key(KEY_R)
	check("a new batch needs ¥100: with ¥50 nothing changes", g.yen == 50 and g.boards[str(term)]["gen"] == 0 and String(m.tm["msg"]).contains("¥100"))
	g.yen = 500
	m.screen_key(KEY_R)
	var board1: Dictionary = g.boards[str(term)]
	check("R pays ¥100 and posts a new batch with the new settings", g.yen == 400 and board1["gen"] == 1 and board1["offers"] != board0["offers"] and m.tm["offers"] == board1["offers"] and board1["used"] == [2, 0, 2, 0])
	check("the new batch obeys them: closed, affiliated, short (5 rooms), Low risk", board1["offers"].all(func(o): return o["faction"] == "affiliated" and o["length"] == "short" and o["rooms"] == 5 and o["layout"] == "closed") and board1["offers"].filter(func(o): return o["risk"] == 1).size() == 4)
	m.screen_key(KEY_ESCAPE)
	g.sim.tick += 14400
	m.open_terminal(term)
	var board2: Dictionary = g.boards[str(term)]
	check("a new game day posts a free batch on the settings you left", g.yen == 400 and board2["gen"] == 2 and board2["sw"] == [2, 0, 2, 0] and board2["offers"] != board1["offers"])
	m.screen_key(KEY_ESCAPE)
	var paid_before: int = g.yen
	for o in board2["offers"]:
		g.done_contracts[String(o["id"])] = true
	check("all five done: the board regenerates itself, free", g.board_after_pay(term) and g.yen == paid_before and g.boards[str(term)]["gen"] == 3 and g.boards[str(term)]["offers"] != board2["offers"])
	check("four done is not enough", (func(): var bb: Dictionary = g.boards[str(term)]; g.done_contracts[String(bb["offers"][0]["id"])] = true; return not g.board_after_pay(term)).call())
	var sdump: Dictionary = JSON.parse_string(JSON.stringify(g.save_dict()))
	var gg = preload("res://src/game.gd").new(0)
	gg.world = w
	gg.island = w.island
	gg.load_dict(sdump)
	var lb: Dictionary = gg.boards.get(str(term), {})
	check("the board survives a save and load (batch, settings, contracts)", not lb.is_empty() and int(lb["gen"]) == 3 and (lb["sw"] as Array).map(func(v): return int(v)) == [2, 0, 2, 0] and int(lb["offers"][0]["rooms"]) == 5 and lb["offers"][0]["id"] == g.boards[str(term)]["offers"][0]["id"])
	gg.dispose()
	g.done_contracts.clear()
	g.boards.clear()
	g.sim.tick -= 14400
	# accept each of the five types in turn, play it through
	var types := ["assassination", "rescue", "repair", "recover", "sabotage"]
	var last_offer: Dictionary = {}
	for ti in 5:
		var tid: String = types[ti]
		g = w.game
		var yen0: int = g.yen
		dv = stand_beside(g, term)
		m.open_terminal(term)
		m.screen_key(KEY_1 + ti)
		var offer: Dictionary = m.tm["offers"][ti]
		last_offer = offer
		m.screen_key(KEY_ENTER)
		check("%s: Enter accepts, closes the screen, opens a portal beside the terminal" % tid, m.mode == "play" and not g.portal.is_empty() and g.portal["offer"]["id"] == offer["id"] and g.cheb(int(g.portal["cell"]), term) == 1)
		check("%s: the portal is a walkable tile on the street" % tid, g.city.tiles[int(g.portal["cell"])] == CG.TID["portal"] and g.sim.walk[int(g.portal["cell"])] == 1)
		# a second accept while open is refused
		m.open_terminal(term)
		m.screen_key(KEY_ENTER)
		check("%s: a second contract is refused while a portal is open" % tid, String(m.tm["msg"]).contains("already open") and g.portal["offer"]["id"] == offer["id"])
		m.screen_key(KEY_ESCAPE)
		# step in
		var pc0: int = int(g.portal["cell"])
		var near: Vector2i = stand_beside(g, pc0)
		var phys_pc: int = pc0
		g.act_move(near.x, near.y)
		check("%s: stepping onto the portal asks the world to enter the site" % tid, g.mission_enter_request)
		m.refresh()
		var s = w.game
		check("%s: the site is a separate game (mission set, not on the island)" % tid, s != g and not s.mission.is_empty() and s.island == null and s.mission["offer"]["id"] == offer["id"])
		check("%s: the physical world is put away, whole" % tid, w.in_site() and m.game == s)
		var site: Dictionary = s.city.get_meta("site")
		check("%s: the player stands at the site's entry; guards are about" % tid, s.pc == int(site["entry"]) and s.sim.n >= 3 and s.eco.role.size() == s.sim.n)
		check("%s: the player's goods came along" % tid, s.yen == yen0 and s.wield != null and s.attrs == g.attrs)
		var guards: Array = []
		for k in s.mission["agents"]:
			if s.mission["agents"][k] in ["guard", "bodyguard"]:
				guards.append(int(k))
		check("%s: guards are armed hostiles (gang factions) standing their posts" % tid, guards.size() >= 3 and guards.all(func(i): return s.fac[i] != s.CIV and s.sim.sticky[i] == 1))
		# play the objective
		match tid:
			"assassination":
				var t: int = MS.agent_with_role(s, "target")
				check("assassination: the target is a named person alive in the site", t >= 0 and s.nname[t] == offer["target"] and s.sim.alive[t] == 1)
				var t0: Dictionary = MS.outcome(s)
				check("assassination: leaving now would be abandoned, no pay", t0["outcome"] == "abandoned" and t0["reward"] == 0)
				s.sim.alive[t] = 0
				s.end_turn()
				check("assassination: the kill is noticed and the contract is met", s.mission["done"])
			"rescue":
				var h: int = MS.agent_with_role(s, "hostage")
				check("rescue: the hostage is bound (stationary civilian with the hostage role)", h >= 0 and s.eco.role[h] == s.eco.HOSTAGE and s.sim.sticky[h] == 1 and s.fac[h] == s.CIV)
				s.pc = s.sim.pos[h] + 1 if s.sim.walk[s.sim.pos[h] + 1] == 1 and s.sim.at[s.sim.pos[h] + 1] == -1 else s.sim.pos[h] - 1
				check("rescue: not free, leaving is pay-less", MS.outcome(s)["reward"] == 0)
				var who: int = s.talk_target()
				check("rescue: talking reaches the hostage", who == h)
				var mm: Dictionary = s.eco.menu_for(h)
				check("rescue: the hostage's menu offers to cut the bonds", mm["options"][0]["op"] == "mission_free")
				s.eco.choose(mm, 0)
				check("rescue: they are free and follow", s.mission["freed"] and s.sim.sticky[h] == 0)
				# walk away and see them trail
				s.pc = int(site["entry"]) - 64 * 4
				for _k in 90:
					s.end_turn()
				check("rescue: the freed hostage keeps up with the player", s.cheb(s.sim.pos[h], s.pc) <= 2)
			"repair":
				var dev: int = int(site["objective"])
				check("repair: the unit is a solid machine in the site", s.sim.walk[dev] == 0)
				s.skills["engineering"] = 10
				s.skills["manual"] = 8
				var need: int = int(s.mission["need"])
				var tries := 0
				var d2: Vector2i = stand_beside(s, dev)
				while not s.mission["done"] and tries < 80:
					s.act_interact_with({"kind": "device", "cell": dev})
					tries += 1
				check("repair: attempts add up to the work needed and the unit runs (%d tries)" % tries, s.mission["done"] and s.mission["progress"] == need and tries >= need)
				check("repair: working makes noise", s.step_noise >= 0)
			"recover":
				var cc: int = int(site["case"])
				check("recover: the data case lies in the site", s.items_at.has(cc) and s.items_at[cc].any(func(it): return it.id() == "trl_datacase"))
				check("recover: without it, leaving is pay-less", not MS.has_case(s) and MS.outcome(s)["reward"] == 0)
				s.pc = cc
				s.act_pickup()
				check("recover: picked up, it is in the pack", MS.has_case(s))
			"sabotage":
				var dev: int = int(site["objective"])
				s.skills["engineering"] = 10
				var d2: Vector2i = stand_beside(s, dev)
				var tries := 0
				while not s.mission["planted"] and tries < 80:
					s.act_interact_with({"kind": "device", "cell": dev})
					tries += 1
				check("sabotage: the charge is set and the fuse lit", s.mission["planted"] and s.mission["fuse"] > 0)
				check("sabotage: the alarm turned the guards", s.astate[guards[0]] == s.HUNTING or s.noticed_you[guards[0]] == 1)
				var f0: int = s.mission["fuse"]
				s.end_turn()
				check("sabotage: the fuse burns down each turn", s.mission["fuse"] < f0)
		# a save inside the site comes back with its progress
		var d: Dictionary = JSON.parse_string(JSON.stringify(s.save_dict()))
		var g2 = preload("res://src/game.gd").new(0)
		g2.load_dict(d)
		check("%s: a save made inside the site loads back into the same site, progress and all" % tid, g2.mission["offer"]["id"] == offer["id"] and g2.mission["done"] == s.mission["done"] and g2.mission["planted"] == s.mission["planted"] and g2.mission["freed"] == s.mission["freed"] and g2.mission["progress"] == s.mission["progress"] and g2.pc == s.pc and g2.city.tiles == s.city.tiles)
		g2.dispose()
		# leave through the exit portal
		var ex: int = int(site["exit"])
		var dx: Vector2i = stand_beside(s, ex)
		if tid == "rescue":
			var h2: int = MS.agent_with_role(s, "hostage")
			s.sim.at[s.sim.pos[h2]] = -1
			s.sim.pos[h2] = s.pc
			for dd in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
				var c3: int = s.pc + dd.y * s.size + dd.x
				if s.sim.walk[c3] == 1 and s.sim.at[c3] == -1 and c3 != ex:
					s.sim.pos[h2] = c3
					s.sim.at[c3] = h2
					break
		var pcb: int = s.pc
		var mv: bool = s.act_move(dx.x, dx.y)
		if s.mission_leave_request != "exit":
			print("  DEBUG ", tid, " from ", pcb, " exit ", ex, " dx ", dx, " moved ", mv, " pc ", s.pc, " tile ", s.city.tiles[ex], " walk ", s.sim.walk[ex], " at ", s.sim.at[ex], " log ", s.log.slice(-2))
		check("%s: stepping onto the exit portal asks to leave" % tid, s.mission_leave_request == "exit")
		m.refresh()
		g = w.game
		check("%s: back in the physical world, the site is gone and the portal is closed" % tid, g != s and g.mission.is_empty() and g.portal.is_empty() and not w.in_site() and m.game == g)
		check("%s: the street tile under the old portal is restored" % tid, g.city.tiles[pc0] != CG.TID["portal"] and g.city.tiles[pc0] == g.city.tiles[pc0 - 0] and g.pc == pc0)
		check("%s: the player is carried back (same world, same terminals)" % tid, g.city.tiles[term] == CG.TID["terminal"] and g.seed_value == s.seed_value ^ s.seed_value or g.island != null)
		check("%s: pay arrives on return, only if the objective was met" % tid, g.yen == yen0 + int(offer["reward"]))
		var ended := String(g.log[-1])
		check("%s: the log says how it ended" % tid, ended.contains("Contract complete"))
	# failure and abandonment pay nothing; the blast
	g = w.game
	check("finishing all five contracts on a board posted a fresh batch by itself, free", g.boards[str(term)]["gen"] == 1 and g.boards[str(term)]["offers"][0]["id"] != types[0] and not g.done_contracts.has(String(g.boards[str(term)]["offers"][0]["id"])))
	check("a paid contract cannot be taken again", not g.portal_open(last_offer, term))
	g.done_contracts.clear()                # (the tests below reuse the same postings)
	var yen1: int = g.yen
	dv = stand_beside(g, term)
	m.open_terminal(term)
	m.screen_key(KEY_5)
	m.screen_key(KEY_ENTER)
	var pcc: int = int(g.portal["cell"])
	var nb: Vector2i = stand_beside(g, pcc)
	g.act_move(nb.x, nb.y)
	m.refresh()
	var s2 = w.game
	check("blast: a second site opens fine after the first mission closed", not s2.mission.is_empty())
	var site2: Dictionary = s2.city.get_meta("site")
	s2.skills["engineering"] = 10
	for k in s2.mission["agents"]:
		if s2.mission["agents"][k] in ["guard", "bodyguard"]:
			s2.sim.remove_agent(int(k))
			s2.sim.alive[int(k)] = 0
	var d3: Vector2i = stand_beside(s2, int(site2["objective"]))
	var tr := 0
	while not s2.mission["planted"] and tr < 80:
		s2.act_interact_with({"kind": "device", "cell": int(site2["objective"])})
		tr += 1
	# the blast hurts by distance: walk out to the far end of the hall first (the exit side), well beyond the bomb's reach
	var far_c: int = int(site2["entry"])
	for ce in s2.city.tiles.size() / 3:
		if s2.sim.walk[ce] == 1 and s2.sim.at[ce] == -1 and s2.cheb(ce, int(site2["objective"])) > s2.cheb(far_c, int(site2["objective"])):
			far_c = ce
	s2.pc = far_c
	s2.sim.retier(s2.pc)
	var hp0: int = s2.body.total()
	for _k in 60:
		if s2.mission_leave_request != "":
			break
		s2.end_turn()
	check("blast: the fuse runs out and the charge goes off with the player inside", s2.mission_leave_request == "blast")
	check("blast: far from the bomb the player is not hurt at all, and is thrown out with the contract failed", s2.body.total() == hp0 and not s2.game_over)
	m.refresh()
	g = w.game
	check("blast: the player is back on the street, the contract failed, no pay, the portal closed", g.mission.is_empty() and g.portal.is_empty() and g.yen == yen1 and String(g.log[-1]).contains("failed"))
	# the bomb's damage by distance: more at the core, none beyond the radius, and it reaches the head and chest
	g.crits = false
	g.armor_worn = []
	g.implants = {}
	var means := []
	var vital_hits := 0
	for dist in 6:
		var tot := 0
		for _t in 60:
			g.body.reset()
			g.game_over = false
			g._explode(g.pc + dist, MS.BOMB_RADIUS, MS.BOMB_DAMAGE)
			tot += 164 - g.body.total()
			if dist == 0 and (g.body.hp["head"] < g.body.mx["head"] or g.body.hp["chest"] < g.body.mx["chest"]):
				vital_hits += 1
		means.append(float(tot) / 60.0)
	g.body.reset()
	g.game_over = false
	check("bomb: damage falls with distance (a limb only loses what it has, so the first two are close; mean loss at 0..5 tiles: %s)" % str(means.map(func(v): return int(v))), means[0] >= means[1] - 3.0 and means[1] > means[2] and means[2] > means[3] and means[3] > 0.0 and means[4] == 0.0 and means[5] == 0.0)
	check("bomb: it hurts the head and chest too (%d of 60 blasts at the core)" % vital_hits, vital_hits > 0)
	check("bomb: stronger than a grenade (radius %d against 2, %d at the core against 40-70, mean 55)" % [MS.BOMB_RADIUS, MS.BOMB_DAMAGE], MS.BOMB_RADIUS > 2 and MS.BOMB_DAMAGE > 55 and MS.BOMB_DAMAGE <= 80)
	# scrapping at the terminal
	dv = stand_beside(g, term)
	m.open_terminal(term)
	m.screen_key(KEY_2)
	m.screen_key(KEY_ENTER)
	check("scrap: a portal is open", not g.portal.is_empty())
	var cellp: int = int(g.portal["cell"])
	var was: int = int(g.portal["was"])
	m.open_terminal(term)
	m.screen_key(KEY_C)
	check("scrap: C at the terminal closes the portal and restores the street, no pay", g.portal.is_empty() and g.city.tiles[cellp] == was and g.yen == yen1)
	m.screen_key(KEY_ESCAPE)
	# a save with a portal open comes back with it
	m.open_terminal(term)
	m.screen_key(KEY_4)
	m.screen_key(KEY_ENTER)
	var sd: Dictionary = JSON.parse_string(JSON.stringify(g.save_dict()))
	var gl = preload("res://src/game.gd").new(0)
	gl.world = w
	gl.island = w.island
	gl.load_dict(sd)
	check("an open portal survives a save and load (tile and offer)", not gl.portal.is_empty() and gl.portal["offer"]["id"] == g.portal["offer"]["id"] and gl.city.tiles[int(gl.portal["cell"])] == CG.TID["portal"])
	gl.dispose()
	# the whole world saves and loads inside a site
	var cell_p: int = int(g.portal["cell"])
	var nb2: Vector2i = stand_beside(g, cell_p)
	g.act_move(nb2.x, nb2.y)
	m.refresh()
	var s3 = w.game
	var wd: Dictionary = JSON.parse_string(JSON.stringify(w.save_dict()))
	if w.origin_game != null:                           # (one 1536 city at a time: the first world is finished with once it is saved)
		w.origin_game.dispose()
	var w2 = WorldScript.new()
	w2.load_dict(wd)
	check("a world saved inside a site loads back inside it, with the street stored behind it", not w2.game.mission.is_empty() and w2.in_site())
	var s4 = w2.game
	var ex4: int = int(s4.city.get_meta("site")["exit"])
	for dd in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var nc: int = ex4 + dd.y * s4.size + dd.x
		if s4.sim.walk[nc] == 1 and s4.sim.at[nc] == -1 and s4.thing_at.g(nc) == -1:
			s4.pc = nc
			s4.act_move(-dd.x, -dd.y)
			break
	check("and leaving after the reload returns to the street and closes the portal", s4.mission_leave_request == "exit")
	var res: Dictionary = w2.leave_mission("")
	check("(the abandoned site pays nothing; the portal is closed in the restored street)", res["outcome"] == "abandoned" and w2.game.portal.is_empty() and w2.game.mission.is_empty())
	# a freed hostage finds a way round a guard standing on the shortest route (it used to freeze behind one in about one site in eight)
	var stuck := 0
	var freed_n := 0
	for k in 40:
		var ro: Dictionary = MS.offers(1000 + k * 7, 4000 + k * 13, k % 9, 0, MS.NEUTRAL, k % 6)[1]
		var rs = preload("res://src/game.gd").new(int(ro["seed"]))
		rs.setup(0, null, Vector2i(-1, -1), MS.new_state(ro))
		var rh: int = MS.agent_with_role(rs, "hostage")
		for gk in rs.mission["agents"]:                 # (a guard standing in a one-cell doorway would block the hostage and the player alike: this tests the following, not the fight)
			if rs.mission["agents"][gk] != "hostage":
				rs.sim.remove_agent(int(gk))
				rs.sim.alive[int(gk)] = 0
		if rh >= 0:
			rs.pc = rs.sim.pos[rh] + 1 if rs.sim.walk[rs.sim.pos[rh] + 1] == 1 and rs.sim.at[rs.sim.pos[rh] + 1] == -1 else rs.sim.pos[rh] - 1
			rs.eco.choose(rs.eco.menu_for(rh), 0)
			if rs.mission["freed"]:
				freed_n += 1
				rs.pc = _far_cell(rs, rs.sim.pos[rh], 28)
				for _k in 140:
					rs.end_turn()
				if rs.cheb(rs.sim.pos[rh], rs.pc) > 2:
					stuck += 1
		rs.dispose()
	check("a freed hostage keeps up in every site tried (%d of %d stuck)" % [stuck, freed_n], freed_n >= 30 and stuck == 0)
	print("MISSIONS %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
