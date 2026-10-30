extends RefCounted
## Ranged combat: action points and stamina, the 2d10 hit model with natural range and aim, locational damage, crits, the gunman's tell, saves.
## Returns [passed, total, log]
const GameScript = preload("res://src/game.gd")
const GP = preload("res://src/gunplay.gd")
const SK = preload("res://src/skills.gd")

func _open_line(g, from: int, len: int) -> int:
	for r in range(0, 140):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var x: int = from % g.size + dx
				var y: int = from / g.size + dy
				if x < 6 or y < 6 or x >= g.size - 12 or y >= g.size - 8:
					continue
				var ok := true
				for ox in range(-1, len + 2):
					for oy in range(-1, 2):
						var c: int = (y + oy) * g.size + x + ox
						if g.sim.walk[c] == 0 or g.sim.at[c] != -1 or g.veh_at.g(c) != -1 or g.city.tiles[c] != g.city.tiles[y * g.size + x]:
							ok = false
				if ok:
					return y * g.size + x
	return -1

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	var g = GameScript.new(71)
	g.setup(1200)
	for l_ in g.BODY.LIMBS:
		g.body.hp[l_] = 100000
		g.body.mx[l_] = 100000
	# ---- data: every gun shows its numbers, and the classes match the design
	var by_cls := {}
	var shown := true
	for k in g.db.defs:
		var d: Dictionary = g.db.defs[k]
		if "gun" in d["tags"]:
			var s: Dictionary = GP.stats(g._new_item(k))
			var cls: String = s["cls"]
			if not by_cls.has(cls):
				by_cls[cls] = []
			by_cls[cls].append([s["max_aim"], s["range_lo"], s["range_hi"]])
			var line: String = GP.stat_line(s, 1.0)
			for need in ["natural range", "max aim", "clip", "mod slots"]:
				if not line.contains(need):
					shown = false
	check.call("every gun's stat block shows natural range, max aim, clip and mod slots", shown)
	var spec_ok := true
	for cls in ["pistol", "shotgun", "revolver"]:
		for r in by_cls[cls]:
			spec_ok = spec_ok and r == [2, 3, 7]
	for r in by_cls["rifle"]:
		spec_ok = spec_ok and r == [3, 10, 15]
	for r in by_cls["sniper"]:
		spec_ok = spec_ok and r == [5, 20, 30]
	check.call("unmodded pistols and shotguns: max aim 2, range 3-7; rifles 3, 10-15; snipers 5, 20-30 (%d classes)" % by_cls.size(), spec_ok)
	# ---- damage lives on the bullet
	var no_gun_dmg := true
	for k in g.db.defs:
		if "gun" in g.db.defs[k]["tags"] and g.db.defs[k]["gun"].has("dmg"):
			no_gun_dmg = false
	var bullets_ok := GP.AMMO.size() >= 19
	for kk in GP.AMMO:
		var bl: Dictionary = GP.AMMO[kk]
		bullets_ok = bullets_ok and bl["dmg"][1] >= bl["dmg"][0] and int(bl["eff_range"]) >= 1
	check.call("no gun carries damage; all %d bullet types carry a damage range and an effective range" % GP.AMMO.size(), no_gun_dmg and bullets_ok)
	var acc_ok := true
	var acc_seen := {}
	for k in g.db.defs:
		if "gun" in g.db.defs[k]["tags"]:
			var av: int = int(g.db.defs[k]["gun"]["acc"])
			acc_seen[av] = true
			acc_ok = acc_ok and av >= -2 and av <= 2
	check.call("every gun's accuracy is a flat -2..+2 (values in use: %s)" % str(acc_seen.keys()), acc_ok and acc_seen.size() >= 4)
	var ps = g._new_item(g.gun_ids["pistol"][0])
	check.call("a gun's damage is its loaded bullet's (pistol with %s: %s)" % [ps.kind, str(GP.stats(ps)["dmg"])], int(GP.stats(ps)["dmg"][0]) == int(GP.bullet("9mm", "fmj")["dmg"][0]) and int(GP.stats(ps)["dmg"][1]) == int(GP.bullet("9mm", "fmj")["dmg"][1]))
	ps.kind = "hp"
	ps.loaded = 3
	check.call("hollow-points swap in their own numbers (%s)" % str(GP.stats(ps)["dmg"]), int(GP.stats(ps)["dmg"][1]) == int(GP.bullet("9mm", "hp")["dmg"][1]) and GP.stats(ps)["eff_range"] == 12)
	check.call("damage is full inside the effective range and loses 1/range a tile past it (12: %.2f, 18: %.2f, 24: %.2f, 40: %.2f)" % [GP.falloff(12, 12), GP.falloff(12, 18), GP.falloff(12, 24), GP.falloff(12, 40)],
		GP.falloff(12, 12) == 1.0 and absf(GP.falloff(12, 18) - 0.5) < 0.001 and GP.falloff(12, 24) == 0.0 and GP.falloff(12, 40) == 0.0 and absf(GP.falloff(30, 31) - (1.0 - 1.0 / 30.0)) < 0.001)
	# ---- the hit model against hand-computed cases
	var flat := {"acc": 0, "sights": 0, "hip": 0, "range_lo": 5, "range_hi": 5, "rangepen": 1.0, "pellets": 1, "spread": 1.0, "close_pen": 0, "max_aim": 2, "aim_loss": 1.0}
	check.call("on the natural range with no bonus: 55%% (%d), +2 aim 72%% (%d)" % [GP.hit_chance(flat, 5, 0, false, false, 0, 0), GP.hit_chance(flat, 5, 2, false, false, 0, 0)], GP.hit_chance(flat, 5, 0, false, false, 0, 0) == 55 and GP.hit_chance(flat, 5, 2, false, false, 0, 0) == 72)
	check.call("3 tiles off the natural range costs 3 points (%d%%)" % GP.hit_chance(flat, 8, 0, false, false, 0, 0), GP.hit_chance(flat, 8, 0, false, false, 0, 0) == 28)
	check.call("20%% cover multiplies the total by 0.8: +10 skill needs a natural 4 (%d%%)" % GP.hit_chance(flat, 5, 0, false, false, 10, 0, 0, false, 0, 20), GP.hit_chance(flat, 5, 0, false, false, 10, 0, 0, false, 0, 20) == 97)
	check.call("a natural 19-20 always hits and a natural 2 never does (far away %d%%, point blank bonus %d%%)" % [GP.hit_chance(flat, 60, 0, false, false, 0, 0), GP.hit_chance(flat, 5, 0, false, false, 30, 0)], GP.hit_chance(flat, 60, 0, false, false, 0, 0) == 3 and GP.hit_chance(flat, 5, 0, false, false, 30, 0) == 99)
	var rb := [GP.aim_at_shot(flat, 2, 0), GP.aim_at_shot(flat, 2, 1), GP.aim_at_shot(flat, 2, 9)]
	check.call("aim drops 1 a bullet and bottoms out at max aim - 5 (%s)" % str(rb), rb == [2, 1, -3])
	# ---- a live duel on open ground
	var spot: int = _open_line(g, g.pc, 12)
	check.call("found open ground", spot >= 0)
	g.pc = spot
	g.last_pc = spot
	g.sim.retier(g.pc)
	var who := -1
	for k in g.sim.near_list.size():
		var j: int = g.sim.near_list[k]
		if g.sim.alive[j] == 1 and g.z_of(g.sim.pos[j]) == 0 and who < 0:
			who = j
	if who < 0:                                               # (most people are up in the flats at this hour: bring one down to the street)
		for j in g.sim.n:
			if g.sim.alive[j] == 1 and g.sim.sticky[j] == 0:
				g.sim.place(j, spot + 1)
				who = j
				break
	var put = func(cell: int) -> void:
		g.sim.at[g.sim.pos[who]] = -1
		g.sim.pos[who] = cell
		g.sim.at[cell] = who
		g.sim.idle[who] = 1
		g.sim.sticky[who] = 1
		g.sim.near[who] = 1
		g.fac[who] = g.BRATVA
		g.hpn[who] = 50000
		g.hpmax[who] = 50000
		g.astate[who] = g.HUNTING
		g.sim.ctl[who] = 1
		g.stun[who] = 0
		g.body.reset()
		g.body.mend_to(1.0)
		g.game_over = false
		g.pc = spot
		g.last_pc = spot
		g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
	put.call(spot + 5)
	var pis = g._new_item(g.gun_ids["pistol"][0])
	g.wield = pis
	g.pool_add("9mm", "fmj", 5000)
	pis.loaded = int(GP.stats(pis)["mag"])
	g.skills = SK.default_skills()
	# costs: a shot is 50 AP and 2 stamina, aiming 100 AP and 1 stamina
	g.stamina = g.STAMINA_MAX
	g.ap = 199
	var t0: int = g.turn
	g.act_fire(true)
	check.call("a shot costs 50 AP (bank 199 -> %d, same turn) and 2 stamina (%d)" % [g.ap, g.STAMINA_MAX - g.stamina], g.ap == 149 and g.turn == t0 and g.STAMINA_MAX - g.stamina == 2)
	g.ap = 100
	g.stamina = g.STAMINA_MAX
	put.call(spot + 5)
	t0 = g.turn
	pis.loaded = 14
	for _i in 10:
		g.act_fire(true)
	check.call("ten shots take about five turns (%d), not ten: a shot is half a turn" % (g.turn - t0), g.turn - t0 >= 5 and g.turn - t0 <= 7)
	g.ap = 199
	put.call(spot + 5)
	g.stamina = 80
	g.aim_turns = 0
	t0 = g.turn
	g.act_aim(true)
	check.call("aiming costs a whole turn (+%d) and 1 stamina (80 -> %d, with the turn's regen)" % [g.turn - t0, g.stamina], g.turn == t0 + 1 and g.stamina == 80 - 1 + g.stamina_regen() and g.aim_turns >= 1)
	# aim bank: a long burst eats it, a lucky fumble resets it
	g.aim_turns = 2
	g.aim_dbt = 0.0
	for _b in 8:
		g._spend_aim_on_bullet(GP.stats(pis))
	check.call("eight bullets take aim from 2 down to the floor (%d = max aim - 5)" % g.aim_turns, g.aim_turns == int(GP.stats(pis)["max_aim"]) - 5)
	# the roll: sample many single shots at a fixed range and compare with the model
	var hits := 0
	var crits := 0
	var fumbles := 0
	var shots := 0
	var crit_ok := true
	var locs := {}
	var dmg_ok := true
	var sp: Dictionary = GP.stats(pis)
	for _t in 700:
		put.call(spot + 5)
		g.skills = SK.default_skills()
		g.aim_turns = 1
		g.aim_dbt = 0.0
		g.stamina = g.STAMINA_MAX
		g.ap = 199
		pis.loaded = 10
		pis.jammed = false
		var sk0: int = g.lvl("ranged")          # the shot is taken at this level; hitting teaches a little afterwards
		g.act_fire(true)
		shots += 1
		var lr: Dictionary = g.last_roll
		match lr["outcome"]:
			"crit":
				crits += 1
				hits += 1
			"hit":
				hits += 1
			"cmiss":
				fumbles += 1
				crit_ok = crit_ok and g.aim_turns == 0
		if lr["outcome"] == "crit" or lr["outcome"] == "hit":
			locs[lr["loc"]] = int(locs.get(lr["loc"], 0)) + 1
			var arm: int = maxi(0, g.npc_armor(who) - int(sp.get("pen", 0)))
			var gr: int = SK.grit_cut(g.npc_lvl(who, "grit"))
			var lo_d: int = int(sp["dmg"][0])
			var hi_d: int = int(sp["dmg"][1])
			var sk: int = sk0
			var d_got: int = int(lr["dmg"])
			if lr["outcome"] == "crit":
				crit_ok = crit_ok and (d_got == maxi(0, (hi_d + sk) * 2 - arm - gr) or d_got == 0)
			else:
				dmg_ok = dmg_ok and d_got >= maxi(0, lo_d + sk - arm - gr) and d_got <= maxi(0, hi_d + sk - arm - gr)
	g.skills = SK.default_skills()               # the shots were all taken at the starting level; hitting taught a little afterwards
	var expect: int = GP.hit_chance(sp, 5, 1, false, false, g.lvl("ranged"), 0, 0, false, g._ranged_extra(5), 0)
	var rate: float = 100.0 * float(hits) / float(shots)
	check.call("live hit rate %.0f%% matches the model's %d%% (fumbles %d, crits %d of %d)" % [rate, expect, fumbles, crits, shots], absf(rate - float(expect)) < 8.0 and fumbles > 0 and crits > 0)
	check.call("a fumble resets aim to 0 and a crit does double (max roll + skill), armor and Grit still subtract", crit_ok)
	check.call("a hit does roll + skill - armor - Grit", dmg_ok)
	check.call("bullets land on several body parts (%d kinds)" % locs.size(), locs.size() >= 5)
	# the shooter still gets the log line and the tracer
	put.call(spot + 5)
	g.aim_turns = 0
	pis.loaded = 10
	var l0: int = g.log.size()
	g.tracers.clear()
	g.act_fire(true)
	var said := false
	for li in range(l0, g.log.size()):
		if String(g.log[li]).begins_with("You fire the"):
			said = true
	check.call("every shot gives a log line and a tracer", said and g.tracers.size() == 1)
	check.call("the gun line shows range and aim (%s)" % g.gun_line(), g.gun_line().contains("range 3-7") and g.gun_line().contains("aim "))
	# ---- the gunman's tell and his shot
	put.call(spot + 5)
	g.gunc[who] = 1
	g.aimn[who] = 0
	g.stamn[who] = 100
	g.stamt[who] = g.turn
	g.apn[who] = 100
	l0 = g.log.size()
	g._hunt_act(who, 5, true)
	var tell := false
	for li in range(l0, g.log.size()):
		if String(g.log[li]).contains("raises a pistol and takes aim"):
			tell = true
	check.call("a gunman first spends an action raising his gun: the tell (aim %d)" % g.aimn[who], tell and g.aimn[who] == 1)
	var ap0: int = g.apn[who]
	var s0: int = g.npc_stamina(who)
	l0 = g.log.size()
	g._hunt_act(who, 5, true)
	var fired := false
	for li in range(l0, g.log.size()):
		var m: String = String(g.log[li])
		if m.contains("shoots you") or m.contains("shoots at you") or m.contains("goes wild") or m.contains("twist aside"):
			fired = true
	check.call("then he fires: 50 AP back to his bank (%d -> %d), 2 stamina (%d -> %d), aim spent" % [ap0, g.apn[who], s0, g.npc_stamina(who)], fired and g.apn[who] == ap0 + 50 and g.npc_stamina(who) == s0 - 2 and g.aimn[who] == 0)
	var nhit := 0
	for _t in 200:
		g.body.mend_to(1.0)
		g.body.reset()
		g.aimn[who] = 1
		g.stamn[who] = 100
		g.stamt[who] = g.turn
		g._hunt_act(who, 5, true)
		if g.body.total() < 164:
			nhit += 1
	check.call("a gunman's bullets hurt the player's limbs (%d of 200)" % nhit, nhit > 20 and nhit < 190)
	# ---- a long shot loses damage past the effective range (pistol rounds: full to 12 tiles)
	var far_spot: int = _open_line(g, spot, 18)
	if far_spot >= 0:
		g.pc = far_spot
		g.last_pc = far_spot
		var fall_ok := true
		var seen_hit := false
		var sp2: Dictionary = GP.stats(pis)
		var alive0: PackedByteArray = g.sim.alive.duplicate()      # with sight 30 bystanders are in view and nearer: only the gunman is a target here
		for oi in g.sim.n:
			if oi != who and g.sim.alive[oi] == 1:
				g.sim.alive[oi] = 0
		for _t in 300:
			g.sim.place(who, far_spot + 15)
			g.sim.near[who] = 1
			g.hpn[who] = 50000
			g.hpmax[who] = 50000
			g.fac[who] = g.BRATVA
			g.astate[who] = g.HUNTING
			g.skills = SK.default_skills()
			g.body.reset()
			g.body.mend_to(1.0)
			g.game_over = false
			g.aim_turns = 2
			g.stamina = g.STAMINA_MAX
			g.ap = 199
			pis.loaded = 10
			pis.jammed = false
			pis.kind = "fmj"
			g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
			g.sim.retier(g.pc)
			g.sim.near[who] = 1
			g.last_roll = {}
			g.act_fire(true)
			g.last_roll["outcome"] = g.last_roll.get("outcome", "none")
			if g.last_roll["outcome"] == "hit":
				seen_hit = true
				var cap: int = int(round(float(int(sp2["dmg"][1])) * GP.falloff(int(sp2["eff_range"]), 15)))
				fall_ok = fall_ok and int(g.last_roll["dmg"]) <= cap
		g.sim.alive = alive0
		check.call("at 15 tiles a 9mm round has a third less punch (damage never above %d, max %d close up)" % [int(round(float(int(sp2["dmg"][1])) * GP.falloff(int(sp2["eff_range"]), 15))), sp2["dmg"][1]], seen_hit and fall_ok)
	# ---- save and load
	g.aimn[who] = 2
	var dd: Dictionary = JSON.parse_string(JSON.stringify(g.save_dict()))
	var g2 = GameScript.new(0)
	g2.load_dict(dd)
	check.call("save and load keep a gunman's banked aim", g2.aimn[who] == 2)
	return [st[0], st[1], log]
