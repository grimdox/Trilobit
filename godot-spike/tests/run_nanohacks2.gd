extends SceneTree
## Nanohacks, second round: wide chips, the plating tiers, Mend and Heal, cooldowns and Networking, Skill chips, and Impair, Underclock, Acid Feedback and Chaotic Resonance.
## Run: godot --headless -s tests/run_nanohacks2.gd
const MainScript = preload("res://src/main.gd")
const WorldScript = preload("res://src/world.gd")
const NANO = preload("res://src/nanohacks.gd")
const BODY = preload("res://src/body.gd")
const NW = preload("res://src/network.gd")
var ok := 0
var n := 0

func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name)

func inst(g, id: String, slot: int = -1) -> bool:
	var c = g._new_item(NANO.chip_item(id))
	g.inv.stow(c)
	return g.act_nano_install(c, slot)

func fresh(g, imp: String = "x303") -> void:
	g.implants = {imp: true}
	g.nanos = []
	g.nano_fx = {}
	g.nano_cd = {}
	g.npc_fx = {}
	g._sync_pools()
	g.power = g.power_cap()

func _initialize() -> void:
	var m = MainScript.new()
	m.save_prefix = "user://test_nano2_save_"
	m.settings_path = "user://test_nano2_settings.json"
	root.add_child(m)
	await process_frame
	var w = WorldScript.new()
	w.start(21, 300)
	m.world = w
	m.start_play(w.game)
	await process_frame
	var g = w.game
	# ---- the table
	var ratios := {"minor_plating": [1, 1], "plating": [2, 3], "major_plating": [4, 12], "mend": [1, 1], "heal": [2, 3], "impair": [2, 3], "acid": [2, 3], "underclock": [1, 1], "chaotic": [4, 12]}
	var tab_ok := true
	for id in ratios:
		var it = g._new_item(NANO.chip_item(id))
		if NANO.width(NANO.get_def(id)) != int(ratios[id][0]) or int(it.def["price"]) != 400 * int(ratios[id][1]):
			tab_ok = false
	check("slots and prices: Minor 1/400, Plating 2/1200, Major 4/4800, Mend 1/400, Heal 2/1200, Impair 2/1200, Acid 2/1200, Underclock 1/400, Chaotic 4/4800", tab_ok)
	check("Plating's old chip and Mend (test) are gone: 12 named hacks and 16 Skill chips", NANO.ALL.size() == 28 and NANO.get_def("mend")["name"] == "Mend")
	check("each of the 16 skills has a Skill chip of +1", ["unarmed", "melee", "ranged", "dodge", "grit", "networking", "analysis", "implementation", "manual", "engineering", "artisan", "research", "streetwise", "etiquette", "diplomacy", "negotiation"].all(func(s): var d: Dictionary = NANO.get_def(s); return not d.is_empty() and d["kind"] == "passive" and int(d["skills"][s]) == 1 and d["name"].begins_with("Skill: ")))
	# ---- wide chips
	fresh(g)
	check("a top-tier Trilobit holds 6 slots", g.nano_slots() == 6)
	check("Plating takes two slots", inst(g, "plating") and g.nano_used() == 2 and g.nano_at(0) == "plating" and g.nano_at(1) == "" and g.nano_cover(1) == "plating" and g.nano_installed() == ["plating"])
	check("Major Plating takes the next four: six used", inst(g, "major_plating") and g.nano_used() == 6 and g.nano_at(2) == "major_plating")
	check("nothing more fits", not inst(g, "shock"))
	check("ejecting from the middle of a wide chip returns it and frees every slot it held", g.act_nano_remove(4) and g.nano_used() == 2 and g.nano_cover(5) == "")
	check("a wide chip needs a run of free slots: Shock at slot 3 splits the gap, so Chaotic (4) cannot fit, Heal (2) can", inst(g, "shock", 3) and not inst(g, "chaotic") and inst(g, "heal") and g.nano_at(4) == "heal")
	# ---- Plating tiers
	fresh(g)
	inst(g, "plating")
	while g.nanos.size() < 6:
		g.nanos.append("")
	var arm0: int = g.armor_value("chest")
	var hd0: int = g.armor_value("head")
	check("Plating costs 10 kJ x 6 parts", absf(g.nano_cost("plating") - 60.0) < 0.01)
	g.act_nano_use("plating")
	check("Plating: +1 armor on every part, +3 more on the implanted head (chest %d, head %d)" % [g.armor_value("chest") - arm0, g.armor_value("head") - hd0], g.armor_value("chest") == arm0 + 1 and g.armor_value("head") == hd0 + 4 and absf(g.power_left() - (g.power_cap() - 60.0)) < 1.0)
	check("its upkeep is 2 kJ/h x 6 parts", absf(g.nano_draw() - 12.0) < 0.01)
	fresh(g)
	inst(g, "major_plating")
	arm0 = g.armor_value("l_arm")
	hd0 = g.armor_value("head")
	g.act_nano_use("major_plating")
	check("Major Plating: +2 on every part, +5 more on the head, 90 kJ, 3 kJ/h x 6, runs 15 minutes", g.armor_value("l_arm") == arm0 + 2 and g.armor_value("head") == hd0 + 7 and absf(g.power_left() - (g.power_cap() - 90.0)) < 1.0 and absf(g.nano_draw() - 18.0) < 0.01 and int(g.nano_fx["major_plating"]) >= 149 and int(g.nano_fx["major_plating"]) <= 150)
	fresh(g)
	inst(g, "minor_plating")
	check("Minor Plating: 5 kJ x 6, 1 kJ/h x 6, 10 minutes", absf(g.nano_cost("minor_plating") - 30.0) < 0.01 and g.act_nano_use("minor_plating") and absf(g.nano_draw() - 6.0) < 0.01 and int(g.nano_fx["minor_plating"]) >= 99 and int(g.nano_fx["minor_plating"]) <= 100)
	# ---- Mend and Heal
	fresh(g)
	inst(g, "mend")
	inst(g, "heal")
	g.body.hp["head"] = 1
	g.body.hp["l_arm"] = 1
	g.body.hp["chest"] = 1
	var hmax: int = g.body.mx["head"]
	var amax: int = g.body.mx["l_arm"]
	check("one implanted part (the head): Mend costs 5 kJ x 1", g.implanted_limb_count() == 1 and absf(g.nano_cost("mend") - 5.0) < 0.01 and absf(g.nano_cost("heal") - 7.0) < 0.01)
	check("Mend closes 10 on the implanted head and 2 on the others", g.act_nano_use("mend") and g.body.hp["head"] == mini(hmax, 11) and g.body.hp["l_arm"] == mini(amax, 3) and g.body.hp["chest"] == mini(g.body.mx["chest"], 3))
	check("it then cools down for 1 minute (less 10% per Networking level)", absi(int(g.nano_cd.get("mend", 0)) - g.nano_cd_turns(NANO.get_def("mend"))) <= 1 and not g.act_nano_use("mend"))
	g.body.hp["head"] = 1
	g.body.hp["l_arm"] = 1
	check("Heal closes 15 on the implanted head and 10 on the others", g.act_nano_use("heal") and g.body.hp["head"] == mini(hmax, 16) and g.body.hp["l_arm"] == mini(amax, 11))
	# ---- cooldown and Networking
	var md: Dictionary = NANO.get_def("impair")
	var net: int = g.lvl("networking")
	var exp_t: int = maxi(0, int(round(50.0 * maxf(0.0, 1.0 - 0.1 * net))))
	check("cooldown turns = minutes x 10 turns x (1 - 10%% per Networking level) (Impair, level %d: %d turns)" % [net, exp_t], g.nano_cd_turns(md) == exp_t)
	g.skills["networking"] = 5
	var l5: int = g.lvl("networking")
	check("Networking at level %d takes %d%% off" % [l5, l5 * 10], g.nano_cd_turns(md) == maxi(0, int(round(50.0 * maxf(0.0, 1.0 - 0.1 * l5)))))
	g.skills["networking"] = 10
	check("at level 10 or more there is no cooldown at all", g.lvl("networking") >= 10 and g.nano_cd_turns(md) == 0 and g.nano_cd_turns(NANO.get_def("mend")) == 0)
	g.skills["networking"] = 0
	fresh(g)
	inst(g, "mend")
	g.act_nano_use("mend")
	var cdl: int = int(g.nano_cd["mend"])
	for _i in cdl:
		g._tick()
	check("and the cooldown runs down a turn at a time, then Mend is ready again", not g.nano_cd.has("mend") and g.act_nano_use("mend"))
	# ---- Skill chips
	var sk_ok := true
	for s in ["unarmed", "melee", "ranged", "dodge", "grit", "networking", "analysis", "implementation", "manual", "engineering", "artisan", "research", "streetwise", "etiquette", "diplomacy", "negotiation"]:
		fresh(g)
		var b: int = g.lvl(s)
		inst(g, s)
		if g.lvl(s) != b + 1:
			sk_ok = false
	check("every Skill chip gives +1 to its own skill while installed", sk_ok)
	# ---- the offensive hacks on a person
	var target := -1
	for i in g.sim.n:
		if g.sim.alive[i] == 1 and g.fac[i] != g.CIV:
			var rg: Array = g.npc_implants(i).filter(func(id): return BODY.PART_GROUP[g.IMP.get_def(id)["part"]] in ["arms", "legs"])
			if not rg.is_empty() and g.npc_implants(i).size() >= 2:
				target = i
				break
	check("someone wired in an arm or leg exists to test on", target >= 0)
	g.sim.player = g.pc
	var spot := -1
	for d in [1, -1, g.size, -g.size, g.size + 1, -g.size - 1]:
		if g.sim.walk[g.pc + d] == 1 and g.sim.at[g.pc + d] == -1:
			spot = g.pc + d
			break
	g.sim.place(target, spot)
	g.hpn[target] = 1000
	g.hpmax[target] = 1000
	g._npc_limbs_init(target)
	g.skills["networking"] = 10
	g.skills["implementation"] = 0
	fresh(g)
	for h in ["impair", "acid", "underclock"]:
		inst(g, h)
	var rig0: Array = g.npc_implants(target)
	var hp0: int = g.hpn[target]
	check("none of these runs without a network link", not g.act_nano_use("impair", target, true) and not g.act_nano_use("acid") and g.power_left() == g.power_cap())
	g.net_links["h" + str(target)] = {}
	# Impair
	var p0: float = g.power_left()
	var legs0: int = g.npc_legs_ok(target)
	var arms0: int = g.npc_arms_ok(target)
	check("Impair costs 20 kJ", g.act_nano_use("impair", target, true) and absf(p0 - g.power_left() - 20.0) < 0.5)
	var f: Dictionary = g.npc_fx[target]["impair"]
	var grp: String = f["grp"]
	var lost: int = (arms0 - g.npc_arms_ok(target)) + (legs0 - g.npc_legs_ok(target))
	check("it disables one arm or leg implant's group (%s): that pair of limbs is out, health untouched" % grp, lost == 2 and g.hpn[target] == hp0 and BODY.LIMBS.all(func(l): return g.npc_limb_hp(target, l) == g.npc_limb_max(target, l)))
	check("it cannot be stacked on the same target, and it has a cooldown", not g.act_nano_use("impair", target, true) and int(g.nano_cd.get("impair", 0)) == 0)
	var rem: int = int(g.npc_fx[target]["impair"]["until"]) - g.turn
	for _i in rem - 1:
		g._tick()
	check("it holds for 5 minutes (%d turns left on it at the start)" % rem, rem >= 49 and rem <= 50 and g.npc_group_out(target, grp))
	for _i in 2:
		g._tick()
	check("after 50 turns the limbs work again", not g.npc_group_out(target, grp) and g.npc_arms_ok(target) == arms0 and g.npc_legs_ok(target) == legs0)
	# Underclock
	check("a person acts for 100 action points", g.npc_act_cost(target) == 100)
	p0 = g.power_left()
	check("Underclock costs 10 kJ", g.act_nano_use("underclock", target, true) and absf(p0 - g.power_left() - 10.0) < 0.5)
	check("then every action of theirs costs 110 action points", g.npc_act_cost(target) == 110 and not g.act_nano_use("underclock", target, true))
	var rem2: int = int(g.npc_fx[target]["under"]) - g.turn
	for _i in rem2 + 1:
		g._tick()
	check("and after 5 minutes back to 100", g.npc_act_cost(target) == 100)
	# Acid Feedback
	g.hpn[target] = 1000
	hp0 = 1000
	p0 = g.power_left()
	var d1: int = NW.power_damage(g, 2, g.npc_lvl(target, "analysis"))
	var d2: int = NW.power_damage(g, 1, g.npc_lvl(target, "analysis"))
	g.nano_cd.erase("acid")
	check("Acid Feedback costs 20 kJ", g.act_nano_use("acid", target, true) and absf(p0 - g.power_left() - 20.0) < 0.5)
	for _i in 10:
		g._tick()
	check("it hurts them every turn for 5 turns: %d + %d each, %d in all (took %d)" % [d1, d2, 5 * (d1 + d2), hp0 - g.hpn[target]], hp0 - g.hpn[target] == 5 * (d1 + d2) and not g.npc_has_fx(target, "acid"))
	# Chaotic Resonance
	fresh(g)
	inst(g, "chaotic")
	g.skills["networking"] = 10
	g.net_links["h" + str(target)] = {}
	var n0: int = g.npc_implants(target).size()
	p0 = g.power_left()
	check("Chaotic Resonance costs 40 kJ", g.act_nano_use("chaotic", target, true) and absf(p0 - g.power_left() - 40.0) < 0.5 and g.npc_implants(target).size() == n0)
	check("it cannot be stacked while the resonance builds", not g.act_nano_use("chaotic", target, true))
	for _i in 6:
		g._tick()
	check("30 seconds on, one implant is gone for good (%d -> %d)" % [n0, g.npc_implants(target).size()], g.npc_implants(target).size() == n0 - 1)
	# ---- saving
	g.npc_fx[target]["impair"] = {"grp": "legs", "until": g.turn + 50}
	var round_tripped: Dictionary = JSON.parse_string(JSON.stringify(g.npc_fx))
	var back: Dictionary = g._fx_load(round_tripped)
	check("what the hacks left on people survives saving (keys come back as numbers)", back.has(target) and back[target].has("gone"))
	# ---- the N menu
	fresh(g)
	inst(g, "shock")
	inst(g, "impair")
	g.net_links = {}
	g.net_snap = {}
	m.open_nano()
	m.nano_key(KEY_B)
	check("N then an offensive hack with nobody networked says 'No Networked Targets Available.'", g.log.size() > 0 and String(g.log.back()) == "No Networked Targets Available.")
	m.mode = "play"
	m.panel.visible = false
	# ---- the scenario's kit
	var g2 = load("res://src/game.gd").new(7)
	g2.setup(300)
	g2.nano_test_kit()
	check("the test kit: a top-tier Trilobit, Networking/Analysis/Implementation at 5, Shock, Impair, Acid, Underclock installed and Chaotic Resonance in the pack", g2.nano_slots() == 6 and g2.nano_installed() == ["shock", "impair", "acid", "underclock"] and g2.inv.grid_items().any(func(it): return it.def.get("nano", "") == "chaotic") and g2.base_lvl("networking") >= 5 and g2.base_lvl("analysis") >= 5 and g2.base_lvl("implementation") >= 5)
	# ---- the scenario's mission: level 4 hostiles, none in the starting room
	var MSN = preload("res://src/missions.gd")
	var all_ok := true
	var lv_ok := true
	var sites := 0
	for sd in [3, 8, 21, 55, 90]:
		for o0 in MSN.offers(sd, 7, 1):
			var o: Dictionary = o0.duplicate(true)
			o["lv"] = [4, 4]
			var g3 = load("res://src/game.gd").new(int(o["seed"]))
			g3.setup(0, null, Vector2i(-1, -1), MSN.new_state(o))
			var site: Dictionary = g3.city.get_meta("site")
			sites += 1
			if bool(site["inside"]):
				var r: Array = site["rooms"][int(site["start_room"])]
				for a in site["agents"]:
					var ax: int = int(a["cell"]) % g3.size
					var ay: int = (int(a["cell"]) / g3.size) % g3.size
					if int(a["fac"]) != 0 and ax >= r[0] and ax < r[0] + r[2] and ay >= r[1] and ay < r[1] + r[3]:
						all_ok = false
			for a in site["agents"]:
				if int(a["fac"]) != 0 and String(a["role"]) != "hostage" and int(a["lv"]) != 4:
					lv_ok = false
	check("the scenario's missions (%d sites): hostiles are level 4 and none stands in the starting room" % sites, all_ok and lv_ok)
	print("NANOHACKS2 %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
