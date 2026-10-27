extends SceneTree
## Implant power, charging posts, the loss of the overall health pool: the pure rules (test_power.gd), then the live game on a real world: posts in the city, the drain,
## the dark, the bill at a post, siphoning a downed man, saving, head/chest death.  Run: godot --headless -s tests/run_power.gd
const MainScript = preload("res://src/main.gd")
const WorldScript = preload("res://src/world.gd")
const PW = preload("res://src/power.gd")
const CG = preload("res://src/citygen.gd")
var ok := 0
var n := 0

func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name)

func stand_beside(g, cell: int) -> Vector2i:
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var c: int = (cell / g.size + d.y) * g.size + cell % g.size + d.x
		if g.sim.walk[c] == 1 and g.sim.at[c] == -1 and g.thing_at[c] == -1 and g.veh_at[c] == -1 and not g.items_at.has(c):
			g.pc = c
			g.last_pc = c
			return Vector2i(-d.x, -d.y)
	return Vector2i.ZERO

func _initialize() -> void:
	var r = preload("res://tests/test_power.gd").new().run()
	for l in r[2]:
		print(l)
	ok = r[0]
	n = r[1]
	var m = MainScript.new()
	m.save_prefix = "user://test_pw_save_"
	m.settings_path = "user://test_pw_settings.json"
	root.add_child(m)
	await process_frame
	var w = WorldScript.new()
	w.start(21, 300)
	m.world = w
	m.start_play(w.game)
	await process_frame
	var g = w.game
	# ---- posts in the city
	var posts: Array = []
	for i in g.s2:
		if g.city.tiles[i] == CG.TID["charger"]:
			posts.append(i)
	check("the city has implant charging posts (%d), all at parking lots and charging stations" % posts.size(), posts.size() >= 4 and posts.size() == g.city.chargers.size())
	var in_lot := 0
	for p in posts:
		for lot in g.city.lots:
			if p % g.size >= lot["x0"] and p % g.size <= lot["x1"] and p / g.size >= lot["y0"] and p / g.size <= lot["y1"]:
				in_lot += 1
				break
	check("no post stands loose on a street: every one is inside a lot", in_lot == posts.size())
	check("a post is a solid, static tile", g.sim.walk[posts[0]] == 0 and g.thing_at[posts[0]] == -1)
	var reach := 0
	for p in posts:
		var free := 0
		for dd in [1, -1, g.size, -g.size]:
			if g.sim.walk[p + dd] == 1:
				free += 1
		if free >= 2:
			reach += 1
	check("every post can be reached from at least two sides", reach == posts.size())
	# ---- no overall health pool
	check("there is no overall health pool: the Game has no hp or hp_max", g.get("hp") == null and g.get("hp_max") == null)
	# ---- a human has no power use at all
	g.implants = {}
	g.power = -1.0
	var t0: float = g.power_left()
	for _i in 100:
		g.end_turn()
	check("fully human: no power, no draw, nothing to charge", g.power_cap() == 0.0 and g.power_left() == 0.0 and t0 == 0.0)
	var hm: Dictionary = g.eco.charger_menu(posts[0])
	check("the post tells a human to move along and bills nothing", hm["options"].size() == 1 and hm["options"][0]["op"] == "close" and g.yen >= 0)
	# ---- fit a tier 1 rig: it arrives charged
	for id in ["smartlink", "optics", "legs", "dermal"]:
		g.implants[id] = true
	g.power_install("smartlink")
	check("a fitted rig starts a full charge (576 kJ, 72 h)", g.power_cap() == 576.0 and g.power_left() == 576.0 and absf(g.power_hours() - 72.0) < 1e-6)
	var acc0: float = g.imp_sum("acc")
	var arm0: int = g.armor_value("chest")
	check("charged implants work: accuracy %.0f, chest armor %d" % [acc0, arm0], acc0 > 0.0 and arm0 > 0 and g.has_implant("smartlink"))
	var p0: float = g.power_left()
	for _i in 600:
		g.end_turn()
	check("an hour of play (600 turns) costs the rig's 8 kJ", absf(p0 - g.power_left() - 8.0) < 0.01)
	# ---- the warnings, then dark
	g.power = 150.0
	g.power_state = 0
	g.log.clear()
	var saw_low := false
	var saw_crit := false
	var saw_dark := false
	for stage in [[150.0, "power low"], [58.0, "power critical"], [0.5, "go dark"]]:
		g.power = float(stage[0])
		for _i in 3000:
			g.end_turn()
			var hit := false
			for ln in g.log:
				if String(ln).contains(String(stage[1])):
					hit = true
			if hit:
				break
		for ln in g.log:
			if String(ln).contains("power low"):
				saw_low = true
			if String(ln).contains("power critical"):
				saw_crit = true
			if String(ln).contains("go dark"):
				saw_dark = true
	check("the store warns when low, when critical, then goes dark", saw_low and saw_crit and saw_dark)
	var low_lines := 0
	for ln in g.log:
		if String(ln).contains("power low"):
			low_lines += 1
	check("a warning is not repeated every turn (%d)" % low_lines, low_lines <= 1)
	check("at 0 the implants stop: no accuracy, no armor, no jump, none 'fitted' to the game", g.power_left() == 0.0 and g.imp_sum("acc") == 0.0 and g.armor_value("chest") < arm0 and not g.has_implant("legs") and not g.has_implant("smartlink"))
	check("the rig is still in the body, only off (the implants dictionary is untouched)", g.implants.get("optics", false) and g.implants.size() == 4)
	check("the HUD bar reads dark: 0 kJ, 0 hours", g.power_hours() == 0.0)
	# ---- the post: bill and recharge
	var post: int = posts[0]
	var dir: Vector2i = stand_beside(g, post)
	g.yen = 2000
	var q: Dictionary = g.charge_quote(post, 576.0)
	var dist: int = g.district_of(post)
	var turn0: int = g.turn
	check("bumping a post does nothing but say what it is, and spends no time", dir != Vector2i.ZERO and not g.act_move(dir.x, dir.y) and g.charger_hit == -1 and g.turn == turn0)
	var near_list: Array = g.interactables()
	check("the interact key finds the post beside you", near_list.size() >= 1 and near_list.any(func(it): return it["kind"] == "charger" and it["cell"] == post))
	g.act_interact_with(near_list.filter(func(it): return it["kind"] == "charger")[0])
	check("using it asks for its menu", g.charger_hit == post)
	g.charger_hit = -1
	var menu: Dictionary = g.eco.charger_menu(post)
	var full_idx := -1
	for k in menu["options"].size():
		if menu["options"][k]["op"] == "charge" and String(menu["options"][k]["label"]).begins_with("Top up"):
			full_idx = k
	check("the menu offers a top-up with the real price (¥%d)" % int(q["total"]), full_idx >= 0 and String(menu["options"][full_idx]["label"]).contains("¥%d" % int(q["total"])))
	var yen0: int = g.yen
	g.eco.choose(menu, full_idx)
	check("paying takes exactly the quoted yen and refills the store (¥%d, now %d kJ)" % [yen0 - g.yen, int(g.power_left())], yen0 - g.yen == int(q["total"]) and g.power_left() == 576.0)
	check("the implants wake again", g.imp_sum("acc") > 0.0 and g.armor_value("chest") > 0 and g.has_implant("legs"))
	check("the post answers with a log line and a breakdown", String(g.log[-1]).contains("fee") and String(g.log[-1]).contains("power tax"))
	# the same bill again: nothing to deliver
	var yen1: int = g.yen
	var m2: Dictionary = g.eco.charger_menu(post)
	check("a full rig is offered no charge", m2["options"].size() == 1 and m2["text"][-1].contains("full"))
	check("recharging a full rig takes no money", not g.recharge(post, 100.0) and g.yen == yen1)
	# too poor
	g.power = 100.0
	g.yen = 200
	check("a purse under the fee and tax buys nothing and changes nothing", not g.recharge(post, 300.0) and g.yen == 200 and g.power_left() == 100.0)
	var m3: Dictionary = g.eco.charger_menu(post)
	var has_aff := false
	for o in m3["options"]:
		if String(o["label"]).begins_with("Charge what I can afford"):
			has_aff = true
	check("and the menu does not offer an affordable charge it cannot sell", not has_aff)
	g.yen = 1000
	var m4: Dictionary = g.eco.charger_menu(post)
	var aff_idx := -1
	for k in m4["options"].size():
		if String(m4["options"][k]["label"]).begins_with("Charge what I can afford"):
			aff_idx = k
	var pw1: float = g.power_left()
	g.eco.choose(m4, aff_idx)
	check("'what I can afford' charges as much as the purse pays for and not more (¥%d left, +%d kJ)" % [g.yen, int(g.power_left() - pw1)], aff_idx >= 0 and g.yen >= 0 and g.yen < 40 and g.power_left() > pw1)
	# place changes the bill
	var lo := -1
	var hi := -1
	for p in posts:
		if g.district_of(p) == 0 and lo < 0:
			lo = p
		if g.district_of(p) == 2 and hi < 0:
			hi = p
	check("the city has a cheap post and a dear post, and the dear one costs more (%d, %d)" % [lo, hi], lo >= 0 and hi >= 0 and int(g.charge_quote(hi, 300.0)["energy"]) > int(g.charge_quote(lo, 300.0)["energy"]))
	# ---- the ripperdoc fits a charged implant
	g.implants = {"optics": true}
	g.power = 20.0
	g.implants["smartlink"] = true
	g.power_install("smartlink")
	check("a newly fitted implant brings its own 72 hours of charge to the store (%d kJ)" % int(g.power_left()), absf(g.power_left() - (20.0 + 2.0 * 72.0)) < 0.01 or g.power_left() == g.power_cap())
	# ---- NPC energy
	var bratva := -1
	var nasim := -1
	var nap := -1
	var civ := -1
	for i in g.sim.n:
		if g.fac[i] == g.BRATVA and bratva < 0:
			bratva = i
		elif g.fac[i] == g.NASIM and nasim < 0:
			nasim = i
		elif g.fac[i] == g.NAP and nap < 0:
			nap = i
		elif g.fac[i] == g.CIV and civ < 0:
			civ = i
	check("wired people hold a charge by faction: Bratva up to 576 kJ, NAP up to 1152; Nasim, gangs and civilians none", g.npc_energy(bratva) > 0 and g.npc_energy(bratva) <= 576 and g.npc_energy(nap) > 0 and g.npc_energy(nap) <= 1152 and g.npc_energy(nasim) == 0 and g.npc_energy(civ) == 0)
	# ---- siphon
	g.implants = {"smartlink": true, "optics": true}
	g.power = 50.0
	g.sim.place(bratva, g.pc + 1)
	if g.sim.walk[g.pc + 1] == 0:
		g.sim.place(bratva, g.pc - 1)
	var alive_e: int = g.npc_energy(bratva)
	g.kill(bratva)
	check("what was left in a person is recorded when they die (%d kJ)" % alive_e, g.energy[bratva] == alive_e and g.npc_energy(bratva) == alive_e)
	g.sim.tick += 20000
	check("and stays fixed on the body however long it lies there", g.npc_energy(bratva) == alive_e)
	g.log.clear()
	var e0: int = g.npc_energy(bratva)
	var ok_s: bool = g.act_siphon()
	check("siphoning a downed man moves energy: his charge drops, the rig's store rises (%d kJ, he has %d)" % [int(g.power_left()), g.npc_energy(bratva)], ok_s and g.npc_energy(bratva) < e0 and g.power_left() > 50.0)
	check("and says so", g.log.any(func(l): return String(l).contains("draw")))
	var took: int = e0 - g.npc_energy(bratva)
	check("one draw is a tenth of what the body holds (%d of %d)" % [took, e0], took == PW.siphon_take(e0) and absf(float(took) - 0.1 * e0) <= 1.0)
	var e1: int = g.npc_energy(bratva)
	g.act_siphon()
	check("a second draw takes a tenth of what is left, so less than the first", e1 - g.npc_energy(bratva) == PW.siphon_take(e1) and e1 - g.npc_energy(bratva) <= took)
	g.implants = {}
	check("with no implants of your own there is nothing to draw into", not g.act_siphon())
	g.implants = {"smartlink": true}
	g.energy[bratva] = 0
	g.power = 10.0
	check("a drained body gives nothing more", not g.act_siphon())
	g.energy[nap] = -1
	var nap_before: int = g.npc_energy(nap)
	g.sim.place(nap, g.pc + 1)
	if g.sim.walk[g.pc + 1] == 0:
		g.sim.place(nap, g.pc - 1)
	check("a standing, healthy man cannot be drained", not g.act_siphon() and g.npc_energy(nap) == nap_before)
	# ---- save and load
	g.implants = {"smartlink": true, "optics": true, "legs": true}
	g.done_contracts = {"repair-0000abcd": true}
	g.power = 123.5
	g.power_state = 1
	g.energy[nap] = 77
	g.energy[bratva] = 33
	var sd: Dictionary = JSON.parse_string(JSON.stringify(g.save_dict()))
	var g2 = preload("res://src/game.gd").new(7)
	g2.load_dict(sd)
	check("power survives a save and load (%.1f kJ, state %d)" % [g2.power, g2.power_state], absf(g2.power - 123.5) < 0.01 and g2.power_state == 1)
	check("a person's energy, and what a dead one held, survives a save and load", g2.npc_energy(nap) == 77 and g2.npc_energy(bratva) == 33)
	var pd: Dictionary = JSON.parse_string(JSON.stringify(g.player_dict()))
	w.game.dispose()                                     # (one 1536 city at a time: this one is finished with)
	var w2 = WorldScript.new()
	w2.start(21, 300)
	var posts2: Array = []
	for i in w2.game.s2:
		if w2.game.city.tiles[i] == CG.TID["charger"]:
			posts2.append(i)
	check("the same seed gives the same posts", posts2 == posts)
	w2.game.dispose()
	var g3 = preload("res://src/game.gd").new(7)
	g3.setup(300)
	g3.apply_player(pd)
	check("power travels with the player between zones", absf(g3.power - 123.5) < 0.01)
	check("a paid contract is remembered through a save and a zone change, and cannot be taken again (money must come from new work)", g2.done_contracts.has("repair-0000abcd") and g3.done_contracts.has("repair-0000abcd") and not g2.portal_open({"id": "repair-0000abcd"}, 0))
	g2.dispose()
	g3.dispose()
	var old: Dictionary = sd.duplicate(true)
	old.erase("power")
	old.erase("power_state")
	old["npc"].erase("energy")
	var g4 = preload("res://src/game.gd").new(7)
	g4.load_dict(old)
	check("an old save (no power, no energy) loads: the rig is full and people hold their clock-based charge", g4.power_left() == g4.power_cap() and g4.npc_energy(nap) >= 0 and g4.npc_energy(nap) <= 1152)
	g4.dispose()
	# ---- the same seed plays the same
	var ga = preload("res://src/game.gd").new(7)
	ga.setup(300)
	ga.implants = {"smartlink": true, "optics": true}
	var gb = preload("res://src/game.gd").new(7)
	gb.setup(300)
	gb.implants = {"smartlink": true, "optics": true}
	for _i in 900:
		ga.end_turn()
		gb.end_turn()
	check("two games from one seed drain identically (%.4f)" % ga.power_left(), ga.power_left() == gb.power_left() and ga.power_left() < ga.power_cap())
	ga.dispose()
	gb.dispose()
	# ---- health is per limb; the head or chest at 0 ends the run
	var gh = preload("res://src/game.gd").new(7)
	gh.setup(300)
	gh.player_hurt(500, "Test", "phys", "r_leg")
	check("a leg at 0 disables the leg and the run goes on", not gh.body.ok("r_leg") and not gh.game_over)
	gh.player_hurt(500, "Test", "phys", "head")
	gh.end_turn()
	check("the head at 0 kills and ends the run", gh.game_over and gh.log.any(func(l): return String(l).contains("You are dead")))
	gh.dispose()
	var gc = preload("res://src/game.gd").new(7)
	gc.setup(300)
	gc.player_hurt(500, "Test", "phys", "chest")
	gc.end_turn()
	check("the chest at 0 kills and ends the run", gc.game_over)
	gc.dispose()
	var gf = preload("res://src/game.gd").new(7)
	gf.setup(300)
	gf.player_hurt(30, "Test", "phys", "chest")
	gf.player_hurt(30, "Test", "phys", "r_arm")
	var tot0: int = gf.body.total()
	var healed: int = gf.heal_body(10)
	check("healing closes wounds on the most hurt limb, never past full (%d points)" % healed, healed == 10 and gf.body.total() == tot0 + 10 and gf.body.hp["r_arm"] <= gf.body.mx["r_arm"])
	check("a limb at 0 stays at 0 while healing points go elsewhere", gf.body.hp["r_arm"] == 0)
	gf.dispose()
	var gd = preload("res://src/game.gd").new(7)
	gd.setup(300)
	gd.player_hurt(500, "Test", "phys", "l_arm")
	var before: int = gd.body.total()
	gd.heal_body(50)
	check("a disabled arm stays disabled when healing points are spread", not gd.body.ok("l_arm") and gd.body.total() == before)
	gd.dispose()
	print("POWER %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
