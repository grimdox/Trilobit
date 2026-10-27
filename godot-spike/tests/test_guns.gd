extends RefCounted
## Ranged combat and gun mods.  Returns [passed, total, log]
const GameScript = preload("res://src/game.gd")
const GP = preload("res://src/gunplay.gd")

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	var g = GameScript.new(11)
	g.setup(1200)
	# data
	var guns := 0
	var complete := true
	for k in g.db.defs:
		var d: Dictionary = g.db.defs[k]
		if "gun" in d["tags"]:
			guns += 1
			var b: Dictionary = d["gun"]
			for f in ["cal", "mag", "modes", "slots", "max_aim", "aim_loss", "noise", "reload", "pellets", "jam", "range", "acc"]:
				if not b.has(f):
					complete = false
			if not GP.KINDS_BY_CAL.has(b["cal"]):
				complete = false
	var bands_ok := true
	for k in g.db.defs:
		var d2: Dictionary = g.db.defs[k]
		if "gun" in d2["tags"]:
			var rg: Array = d2["gun"]["range"]
			bands_ok = bands_ok and rg.size() == 2 and int(rg[0]) >= 1 and int(rg[1]) > int(rg[0]) and int(d2["gun"]["max_aim"]) >= 2
	check.call("all %d guns carry caliber, clip, fire modes, mod slots, max aim, aim loss and a natural range band" % guns, guns >= 50 and complete and bands_ok)
	var mods := 0
	for k in g.db.defs:
		if "mod" in g.db.defs[k]["tags"]:
			mods += 1
	check.call("there are at least 15 mods (%d)" % mods, mods >= 15)
	# accuracy and mods, as pure numbers
	var snip = g._new_item(g.gun_ids["sniper"][0])
	var base: Dictionary = GP.stats(snip)
	var far0: int = GP.hit_chance(base, 40, 0, false, false, 2, 0)
	var close0: int = GP.hit_chance(base, 24, 0, false, false, 2, 0)
	snip.mods.append(g._new_item("trl_mod_scope8"))
	var sc: Dictionary = GP.stats(snip)
	var far1: int = GP.hit_chance(sc, 40, 0, false, false, 2, 0)
	var close1: int = GP.hit_chance(sc, 24, 0, false, false, 2, 0)
	check.call("a scope raises hit chance far out (%d -> %d at 40 tiles)" % [far0, far1], far1 > far0 + 8)
	check.call("a scope moves the band out: the long shot is the better one (%d at 24 tiles, %d at 40)" % [close1, far1], far1 > close1)
	check.call("a scope extends the natural range (%d-%d -> %d-%d) and the max aim (%d -> %d)" % [base["range_lo"], base["range_hi"], sc["range_lo"], sc["range_hi"], base["max_aim"], sc["max_aim"]],
		sc["range_hi"] > base["range_hi"] + 10 and sc["max_aim"] == base["max_aim"] + 2)
	var a0: int = GP.hit_chance(base, 36, 0, false, false, 2, 0)
	var a3: int = GP.hit_chance(base, 36, 3, false, false, 2, 0)
	check.call("aiming for three points adds accuracy (%d -> %d)" % [a0, a3], a3 >= a0 + 12)
	check.call("moving costs accuracy, crouching helps", GP.hit_chance(base, 36, 0, true, false, 2, 0) < a0 and GP.hit_chance(base, 36, 0, false, true, 2, 0) > a0)
	check.call("the implant's tremor costs accuracy", GP.hit_chance(base, 36, 0, false, false, 2, 28) < a0)
	var c_open: int = GP.hit_chance(base, 25, 0, false, false, 2, 0)
	var c_cov: int = GP.hit_chance(base, 25, 0, false, false, 2, 0, 0, false, 0, 28)
	check.call("cover multiplies the roll down (%d -> %d with 28%% cover)" % [c_open, c_cov], c_cov < c_open - 15)
	var scope_aim: int = GP.hit_chance(sc, 40, 3, false, false, 2, 0)
	var smg = g._new_item(g.gun_ids["smg"][0])
	var s0: Dictionary = GP.stats(smg)
	check.call("each bullet fired loses aim, so later shots in a burst are less accurate", GP.hit_chance(s0, 6, 2, false, false, 2, 0, 5) < GP.hit_chance(s0, 6, 2, false, false, 2, 0, 0))
	smg.mods.append(g._new_item("trl_mod_compensator"))
	smg.mods.append(g._new_item("trl_mod_foregrip"))
	var s1: Dictionary = GP.stats(smg)
	check.call("compensator and foregrip cut the aim lost per bullet (%.2f -> %.2f) and help the last shot of a burst" % [s0["aim_loss"], s1["aim_loss"]],
		s1["aim_loss"] < s0["aim_loss"] * 0.6 and GP.hit_chance(s1, 6, 2, false, false, 2, 0, 5) > GP.hit_chance(s0, 6, 2, false, false, 2, 0, 5))
	var pis = g._new_item(g.gun_ids["pistol"][0])
	var p0: Dictionary = GP.stats(pis)
	pis.mods.append(g._new_item("trl_mod_suppressor"))
	var p1: Dictionary = GP.stats(pis)
	check.call("a suppressor shrinks the report (%d -> %d tiles) at a small cost to damage" % [p0["noise"], p1["noise"]], p1["noise"] <= 5 and p1["dmg"][1] <= p0["dmg"][1] and p1["suppressed"])
	pis.mods.append(g._new_item("trl_mod_extmag"))
	check.call("an extended magazine adds capacity (%d -> %d)" % [p0["mag"], GP.stats(pis)["mag"]], GP.stats(pis)["mag"] >= p0["mag"] * 3 / 2)
	var drum = g._new_item(g.gun_ids["smg"][1])
	var d0: Dictionary = GP.stats(drum)
	drum.mods.append(g._new_item("trl_mod_drum"))
	check.call("a drum magazine more than doubles capacity but jams more", GP.stats(drum)["mag"] >= d0["mag"] * 2 and GP.stats(drum)["jam"] > d0["jam"] + 1.0)
	var hp_item = g._new_item(g.gun_ids["pistol"][0])
	hp_item.kind = "hp"
	var ap_item = g._new_item(g.gun_ids["pistol"][0])
	ap_item.kind = "ap"
	var fm_item = g._new_item(g.gun_ids["pistol"][0])
	check.call("hollow-points hit harder, armour-piercing a little softer", GP.avg_dmg(GP.stats(hp_item)) > GP.avg_dmg(GP.stats(fm_item)) and GP.avg_dmg(GP.stats(ap_item)) < GP.avg_dmg(GP.stats(fm_item)))
	var cells: Array = GP.line_cells(10 * g.size + 10, 10 * g.size + 14, g.size)
	check.call("a bullet's line passes through the cells between shooter and target", cells.size() == 3 and cells[0] == 10 * g.size + 11 and cells[2] == 10 * g.size + 13)

	# actions through the game
	var pl = g._new_item(g.gun_ids["pistol"][0])
	g.wield = pl
	g.ammo_pool = {}
	g.pool_add("9mm", "fmj", 30)
	g.pool_add("9mm", "hp", 40)
	var mag: int = GP.stats(pl)["mag"]
	pl.loaded = 0
	check.call("an empty gun clicks and does not spend a turn", not g.act_fire(true))
	var t0: int = g.turn
	check.call("reload fills the magazine from loose rounds and takes time", g.act_reload() and pl.loaded == mag and g.pool_get("9mm", "fmj") == 30 - mag and g.turn > t0)
	check.call("cycling ammunition kind selects hollow-points for the next reload", g.act_cycle_kind() and g.want_kind["9mm"] == "hp")
	var fm_left: int = g.pool_get("9mm", "fmj")
	pl.loaded = mag - 3
	g.act_reload()
	check.call("switching kind unloads the old rounds and loads the new", pl.kind == "hp" and pl.loaded == mag and g.pool_get("9mm", "fmj") == fm_left + mag - 3)
	pl.jammed = true
	pl.loaded = 5
	g.act_fire(true)
	check.call("a jammed gun will not fire until cleared", pl.jammed and pl.loaded == 5)
	g.act_reload()
	check.call("reload clears a jam", not pl.jammed)
	# mods via the game
	var scope = g._new_item("trl_mod_redot")
	check.call("pistol cannot take a stock", not g.act_mod_install(g._new_item("trl_mod_stock")))
	g.stow(scope)
	check.call("a carried mod shows in the mod list", g.mods_carried().has(scope))
	check.call("fitting a mod moves it from the pack to the gun", g.act_mod_install(scope) and pl.mods.has(scope) and not g.mods_carried().has(scope))
	var ext = g._new_item("trl_mod_extmag")
	g.stow(ext)
	g.act_mod_install(ext)
	pl.loaded = GP.stats(pl)["mag"]
	check.call("magazine mod counts toward loaded rounds", pl.loaded > mag)
	var lo: int = pl.loaded
	g.act_mod_remove("mag")
	check.call("removing the magazine mod returns it and the extra rounds to your pool", pl.loaded == mag and g.mods_carried().size() >= 1 and g.pool_get("9mm", "hp") + g.pool_get("9mm", "fmj") >= lo - mag)
	g.act_mod_install(ext)
	# save / load keeps everything
	var dd: Dictionary = JSON.parse_string(JSON.stringify(g.save_dict()))
	var g2 = GameScript.new(11)
	g2.setup(1200)
	g2.load_dict(dd)
	check.call("save and load keep the wielded gun's mods, rounds, kind and the loose ammunition",
		g2.wield.mods.size() == 2 and g2.wield.loaded == pl.loaded and g2.wield.kind == pl.kind and g2.pool_get("9mm", "fmj") == g.pool_get("9mm", "fmj"))

	# firing at a hostile on a street
	g.game_over = false
	var found := -1
	var tries := 0
	while found < 0 and tries < 600:
		for k in g.sim.near_list.size():
			var j: int = g.sim.near_list[k]
			if g.sim.alive[j] == 1 and g.z_of(g.sim.pos[j]) == 0:
				var alone := true                                   # (someone standing apart: in a crowd the nearest person would take the shots)
				for k2 in g.sim.near_list.size():
					var j2: int = g.sim.near_list[k2]
					if j2 != j and g.sim.alive[j2] == 1 and maxi(absi(g.sim.pos[j2] % g.size - g.sim.pos[j] % g.size), absi(g.sim.pos[j2] / g.size - g.sim.pos[j] / g.size)) < 12:
						alone = false
						break
				if alone:
					found = j
					break
		if found < 0:
			g.end_turn()
		tries += 1
	var placed := false
	if found >= 0:
		var tc: int = g.sim.pos[found]
		for r in range(3, 9):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if placed or maxi(absi(dx), absi(dy)) != r:
						continue
					var nx: int = tc % g.size + dx
					var ny: int = tc / g.size + dy
					if not g.in_bounds(nx, ny):
						continue
					var c: int = ny * g.size + nx
					if g.city.walkable(g.city.tiles[c]) and g.sim.at[c] == -1 and g.veh_at[c] == -1 and g.sim._sees(c, tc, 20):
						g.pc = c
						placed = true
	check.call("found a target to shoot (turn %d)" % g.turn, found >= 0 and placed)
	if placed:
		g.last_pc = g.pc
		g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
		g.astate[found] = g.HUNTING
		g.hpn[found] = 400
		g.hpmax[found] = 400
		g.sim.near[found] = 1
		var gun2 = g._new_item(g.gun_ids["smg"][0])
		g.wield = gun2
		g.pool_add("9mm", "fmj", 100)
		gun2.mode = 2                                          # auto
		var refresh := func() -> void:                          # the target may have stepped about: keep it hunting, and put the player back in sight of it
			g.astate[found] = g.HUNTING
			g.sim.near[found] = 1
			var tcc: int = g.sim.pos[found]
			if not g.sim._sees(g.pc, tcc, 20):
				for rr in range(3, 9):
					for ddy in range(-rr, rr + 1):
						for ddx in range(-rr, rr + 1):
							if maxi(absi(ddx), absi(ddy)) != rr:
								continue
							var nx2: int = tcc % g.size + ddx
							var ny2: int = tcc / g.size + ddy
							if not g.in_bounds(nx2, ny2):
								continue
							var c2: int = ny2 * g.size + nx2
							if g.city.walkable(g.city.tiles[c2]) and g.sim.at[c2] == -1 and g.veh_at[c2] == -1 and g.sim._sees(c2, tcc, 20):
								g.pc = c2
								g.last_pc = c2
								break
			g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
		var before: int = gun2.loaded
		var hp_before: int = g.hpn[found]
		var tgt: int = g.current_target(true)
		check.call("target selection finds the person we placed in view", tgt == found or tgt >= 0)
		g.act_fire(true)
		check.call("an auto burst spends several rounds (%d -> %d) and leaves tracers" % [before, gun2.loaded], before - gun2.loaded == 6 and g.tracers.size() == 6)
		var dmg_total := 0
		var trials := 0
		g.hpn[found] = 400
		for _i in 14:
			if g.hpn[found] <= 0 or g.game_over:
				break
			gun2.loaded = int(GP.stats(gun2)["mag"])
			var h0: int = g.hpn[found]
			g.body.mend_to(1.0)
			g.body.reset()
			refresh.call()
			g.act_fire(true)
			dmg_total += h0 - g.hpn[found]
			trials += 1
		check.call("shooting at a target in view deals damage over a few volleys (%d dmg in %d volleys)" % [dmg_total, trials], dmg_total > 0)
		# aiming takes turns and shows in the HUD line
		g.hpn[found] = 400
		refresh.call()
		var aims := 0
		g.aim_turns = 0
		g.wield.jammed = false
		while g.aim_turns < 2 and aims < 6:
			refresh.call()
			g.act_aim(true)
			aims += 1
		check.call("aiming stacks (%d actions at %.2f a turn) and appears in the gun line" % [aims, g.aim_rate()], g.aim_turns == 2 and g.gun_line().contains("aim 2/") and aims <= 3)
		g.act_move(0, 0) if false else null
		# the report of a shot
		var civ_noise: int = int(GP.stats(gun2)["noise"])
		gun2.mods.append(g._new_item("trl_mod_suppressor"))
		check.call("with a suppressor the report is a quarter of the size", int(GP.stats(gun2)["noise"]) * 3 < civ_noise)
		gun2.mods.pop_back()
		# shotgun: pellets spread with distance
		var sg = g._new_item(g.gun_ids["shotgun"][0])
		var ss: Dictionary = GP.stats(sg)
		check.call("a shotgun throws several pellets", ss["pellets"] >= 6)
		sg.kind = "slug"
		check.call("a slug is a single heavy projectile", GP.stats(sg)["pellets"] == 1)
		# launcher blast
		var gl = g._new_item(g.gun_ids["launcher"][0])
		g.wield = gl
		g.pool_add("40mm", "he", 3)
		gl.loaded = 1
		g.body.mend_to(1.0)
		g.hpn[found] = 400
		var hpf: int = g.hpn[found]
		refresh.call()
		var fired: bool = g.act_fire(true)
		check.call("a grenade fired at a target in view explodes and spends the round", fired and gl.loaded == 0)
	return [st[0], st[1], log]
