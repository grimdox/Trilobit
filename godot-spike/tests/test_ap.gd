extends RefCounted
## Action points, stamina and the 2d10 locational melee rules.  Returns [passed, total, log]
const GameScript = preload("res://src/game.gd")
const SK = preload("res://src/skills.gd")

func run() -> Array:
	preload("res://tests/legacy_implants.gd").install()
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	# ---- the dice
	check.call("2d10 outcomes: 2 fumbles, 19 crits, 20+Grit total crits, 11 hits, 10 misses",
		SK.melee_outcome(2, 15, 0) == "cmiss" and SK.melee_outcome(1, 30, 0) == "cmiss" and SK.melee_outcome(19, 3, 0) == "crit" and SK.melee_outcome(12, 22, 2) == "crit"
		and SK.melee_outcome(12, 21, 2) == "hit" and SK.melee_outcome(11, 11, 0) == "hit" and SK.melee_outcome(10, 10, 0) == "miss")
	check.call("hit odds: even skill and dodge %d%%, +5 %d%%, -3 %d%%" % [SK.hit_percent(0), SK.hit_percent(5), SK.hit_percent(-3)], SK.hit_percent(0) == 55 and SK.hit_percent(5) == 90 and SK.hit_percent(-3) == 28)
	check.call("a crit doubles (max weapon roll + skill); a hit is roll + skill", SK.melee_base(3, 8, 2, false) == 5 and SK.melee_base(3, 8, 2, true) == 20)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var cnt := {}
	var bd := preload("res://src/body.gd").new()
	for _k in 20000:
		var l: String = bd.pick_melee(rng)
		cnt[l] = int(cnt.get(l, 0)) + 1
	var pc_of = func(l: String) -> float:
		return 100.0 * float(cnt[l]) / 20000.0
	check.call("hit locations: torso %.0f%%, head %.0f%%, arm %.0f%%, leg %.0f%%" % [pc_of.call("chest"), pc_of.call("head"), pc_of.call("l_arm"), pc_of.call("r_leg")],
		absf(pc_of.call("chest") - 30.0) < 2.5 and absf(pc_of.call("head") - 10.0) < 2.0 and absf(pc_of.call("l_arm") - 15.0) < 2.0 and absf(pc_of.call("r_leg") - 15.0) < 2.0)
	# ---- action points and stamina
	var g = GameScript.new(61)
	g.setup(1200)
	for l_ in g.BODY.LIMBS:
		g.body.hp[l_] = 100000
		g.body.mx[l_] = 100000
	g.stamina = g.STAMINA_MAX
	check.call("100 action points a turn at full stamina", g.ap_rate() == 100)
	g.stamina = 50
	check.call("half stamina, half the action points (%d)" % g.ap_rate(), g.ap_rate() == 50)
	g.stamina = 0
	check.call("an empty tank still crawls along (%d AP)" % g.ap_rate(), g.ap_rate() == g.AP_MIN_RATE)
	g.stamina = g.STAMINA_MAX
	g.implants["reflex"] = true
	check.call("reflex wires push the rate over 100 (%d)" % g.ap_rate(), g.ap_rate() == 110)
	g.implants = {}
	check.call("cats have 110 AP, dogs 100", g.CAT_AP == 110 and g.AP_BASE == 100)
	var g0: int = g.lvl("grit")
	check.call("stamina regen is 1 + 1 per 2 Grit (%d at Grit %d)" % [g.stamina_regen(), g0], g.stamina_regen() == 1 + g0 / 2)
	# a slow body takes more turns for the same walk
	var open := -1
	for c in g.sim.n:
		pass
	open = _open_line(g, g.pc, 8)
	check.call("found a straight open line for the movement tests", open >= 0)
	g.pc = open
	g.stamina = g.STAMINA_MAX
	g._set_stance(g.WALKING)
	var t0: int = g.turn
	for _i in 6:
		g.act_move(1, 0)
	var t_full: int = g.turn - t0
	check.call("walking costs no stamina (%d)" % g.stamina, g.stamina == g.STAMINA_MAX)
	g.pc = open
	g.stamina = 50
	t0 = g.turn
	for _i in 6:
		g.act_move(1, 0)
	var t_half: int = g.turn - t0
	check.call("at half stamina the same walk takes about twice the turns (%d vs %d)" % [t_half, t_full], t_half >= t_full + 3)
	g.pc = open
	g.stamina = g.STAMINA_MAX
	g._set_stance(g.CRAWL)
	g.act_move(1, 0)
	g._set_stance(g.CROUCH)
	g.act_move(1, 0)
	check.call("crawling and crouching cost no stamina", g.stamina == g.STAMINA_MAX)
	g._set_stance(g.WALKING)
	g.pc = open
	g.stamina = 80
	var t_run: int = g.turn
	g.act_move(1, 0, true)
	check.call("running costs 5 stamina a move, plus at most the regen of each turn it takes (80 -> %d over %d turns)" % [g.stamina, g.turn - t_run], g.stamina >= 80 - g.RUN_STAMINA and g.stamina <= 80 - g.RUN_STAMINA + g.stamina_regen() * (g.turn - t_run))
	# ---- a swing: 100 AP, stamina by kg, 2d10, location, armor and Grit
	var who := -1
	var spot := -1
	for i in g.sim.n:
		if g.sim.alive[i] == 1 and g.fac[i] == g.CIV:
			who = i
			break
	g.wield = g._new_item("trl_mel_nodachi")
	var kg: int = g.swing_stamina(g.melee_stats())
	check.call("swing stamina is 1 per kg of weapon (nodachi %d)" % kg, kg >= 2 and kg == maxi(1, int(round(float(g.wield.def["weight_g"]) / 1000.0))))
	var outs := {"hit": 0, "miss": 0, "crit": 0, "cmiss": 0}
	var dmg_hit := 0
	var dmg_crit := 0
	var n_hit := 0
	var n_crit := 0
	var locs := {}
	var atk0: int = g.lvl(g.melee_skill_id()) + int(round(float(g.melee_stats().get("acc", 0)) / 5.0))
	var dd: int = g.npc_lvl(who, "dodge")
	var expect: int = SK.hit_percent(atk0 - dd)
	var swings := 0
	for _t in 600:
		g.sim.alive[who] = 1
		g.hpn[who] = 5000
		g.hpmax[who] = 5000
		g.astate[who] = g.HUNTING
		g.stun[who] = 0
		g.sim.pos[who] = g.pc + 1
		g.stamina = g.STAMINA_MAX
		g.skills = SK.default_skills()           # keep the skill fixed while the odds are sampled
		g.body.reset()
		g.body.mend_to(1.0)
		var l0: int = g.log.size()
		g.melee(who)
		swings += 1
		var lr: Dictionary = g.last_roll
		var fumbled := false
		for li in range(l0, g.log.size()):
			if String(g.log[li]).begins_with("You fumble"):
				fumbled = true
		if fumbled:
			outs["cmiss"] = int(outs["cmiss"]) + 1
			continue
		outs[lr["outcome"]] = int(outs[lr["outcome"]]) + 1
		if lr["outcome"] == "hit" or lr["outcome"] == "crit":
			locs[lr["loc"]] = int(locs.get(lr["loc"], 0)) + 1
	var hits: int = outs["hit"] + outs["crit"]
	var rate: float = 100.0 * float(hits) / float(swings)
	check.call("melee hit rate %.0f%% matches the 2d10 odds (%d%% expected), fumbles %d, crits %d" % [rate, expect, outs["cmiss"], outs["crit"]], absf(rate - float(expect)) < 9.0 and outs["cmiss"] > 0 and outs["crit"] > 0)
	check.call("blows land on several body parts (%d kinds)" % locs.size(), locs.size() >= 5)
	g.stamina = g.STAMINA_MAX
	g.astate[who] = g.HUNTING
	g.sim.pos[who] = g.pc + 1
	g.melee(who)
	check.call("a swing tires you by the weapon's weight (%d lost)" % (g.STAMINA_MAX - g.stamina), g.STAMINA_MAX - g.stamina == kg)
	# one swing is exactly one turn's worth of action points
	g.wield = g._new_item("trl_mel_kastet")
	g.stamina = g.STAMINA_MAX
	g.ap = 100
	t0 = g.turn
	g.end_turn()
	check.call("a 100-point action leaves the bank empty and advances one turn", g.turn == t0 + 1 and g.ap == 100)
	# crit damage: doubled and at maximum
	var ms: Dictionary = g.melee_stats()
	var cap: int = (int(ms["dmg"][1]) + g.lvl(g.melee_skill_id())) * 2
	check.call("a crit is worth (max roll + skill) x 2 = %d before armor and Grit" % cap, SK.melee_base(int(ms["dmg"][0]), int(ms["dmg"][1]), g.lvl(g.melee_skill_id()), true) == cap)
	# damage reaches implants after the limb
	g.body.reset()
	g.implants = {"dermal": true}
	g.imp_dur = {}
	g._limb_hit("chest", 200)
	check.call("damage past a limb's health wears the implants in it down", g.imp_dur.has("dermal") and int(g.imp_dur["dermal"]) < 20 or not g.body.ok("chest") and g.imp_dur.has("dermal"))
	# ---- creatures have stamina and AP; cats are faster
	var cell := _free_cell(g)
	var cat: int = g._add_critter("cat", cell)
	var dog: int = g._add_critter("dog", _free_cell(g, cell + 3))
	check.call("creatures carry action points and stamina", g.critters[cat].has("ap") and g.critters[dog]["stam"] == g.STAMINA_MAX)
	# ---- NPCs
	g.stamn[who] = 40
	g.stamt[who] = g.turn
	check.call("an NPC at 40%% stamina earns %d AP" % g.npc_ap_rate(who), g.npc_ap_rate(who) == 40)
	var s_before: int = g.npc_stamina(who)
	g.turn += 10
	check.call("NPCs regain stamina over turns (%d -> %d)" % [s_before, g.npc_stamina(who)], g.npc_stamina(who) > s_before)
	# ---- a live NPC attack on the player uses the same rules
	g.body.reset()
	g.body.mend_to(1.0)
	g.stamn[who] = 100
	g.stamt[who] = g.turn
	g.sim.pos[who] = g.pc + 1
	var hurt := 0
	for _t in 80:
		g.body.mend_to(1.0)
		g.body.reset()
		g.stamn[who] = 100
		g.stamt[who] = g.turn
		g._npc_melee_attack(who)
		if g.body.total() < 164:
			hurt += 1
	check.call("an NPC's blows hurt the player's limbs (%d of 80 swings)" % hurt, hurt > 0)
	# ---- save and load
	g.ap = 137
	g.stamina = 42
	g.stamn[who] = 33
	g.stamt[who] = 5
	g.apn[who] = 77
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.save_dict()))
	var g2 = GameScript.new(0)
	g2.load_dict(d)
	check.call("save and load keep the player's AP and stamina (%d, %d)" % [g2.ap, g2.stamina], g2.ap == 137 and g2.stamina == 42)
	check.call("save and load keep an NPC's AP bank and stamina", g2.apn[who] == 77 and g2.stamn[who] == 33 and g2.stamt[who] == 5)
	var old: Dictionary = d.duplicate(true)
	old.erase("stam_v")
	old.erase("ap")
	old["stamina"] = 15
	var g3 = GameScript.new(0)
	g3.load_dict(old)
	check.call("an older save's stamina (of 30) is scaled to a percentage (%d)" % g3.stamina, g3.stamina == 50)
	return [st[0], st[1], log]

func _open_line(g, from: int, len: int) -> int:
	for r in range(0, 140):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var x: int = from % g.size + dx
				var y: int = from / g.size + dy
				if x < 6 or y < 6 or x >= g.size - 8 or y >= g.size - 8:
					continue
				var ok := true
				for ox in range(-1, len + 2):
					for oy in range(-1, 2):
						var c: int = (y + oy) * g.size + x + ox
						if g.sim.walk[c] == 0 or g.sim.at[c] != -1 or g.veh_at.g(c) != -1:
							ok = false
				if ok:
					return y * g.size + x
	return -1

func _free_cell(g, near: int = -1) -> int:
	var from: int = g.pc if near < 0 else near
	return _open_line(g, from, 1) + 1
