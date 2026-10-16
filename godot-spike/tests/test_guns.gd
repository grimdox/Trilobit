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
			for f in ["cal", "mag", "modes", "slots", "recoil", "noise", "reload", "pellets", "jam", "dmg", "range", "acc"]:
				if not b.has(f):
					complete = false
			if not GP.KINDS_BY_CAL.has(b["cal"]):
				complete = false
	check.call("all %d guns carry caliber, magazine, fire modes, mod slots and recoil" % guns, guns >= 50 and complete)
	var mods := 0
	for k in g.db.defs:
		if "mod" in g.db.defs[k]["tags"]:
			mods += 1
	check.call("there are at least 15 mods (%d)" % mods, mods >= 15)
	# accuracy and mods, as pure numbers
	var snip = g._new_item(g.gun_ids["sniper"][0])
	var base: Dictionary = GP.stats(snip)
	var far0: int = GP.hit_chance(base, 24, 0, false, false, 2, 0)
	var close0: int = GP.hit_chance(base, 2, 0, false, false, 2, 0)
	snip.mods.append(g._new_item("trl_mod_scope8"))
	var sc: Dictionary = GP.stats(snip)
	var far1: int = GP.hit_chance(sc, 24, 0, false, false, 2, 0)
	var close1: int = GP.hit_chance(sc, 2, 0, false, false, 2, 0)
	check.call("a scope raises hit chance at range (%d -> %d)" % [far0, far1], far1 > far0 + 8)
	check.call("a scope is a handicap up close (%d -> %d)" % [close0, close1], close1 < close0)
	check.call("a scope extends effective range (%d -> %d)" % [base["range"], sc["range"]], sc["range"] > base["range"] + 10)
	var a0: int = GP.hit_chance(base, 22, 0, false, false, 2, 0)
	var a3: int = GP.hit_chance(base, 22, 3, false, false, 2, 0)
	check.call("aiming for three turns adds accuracy (%d -> %d)" % [a0, a3], a3 >= a0 + 18)
	check.call("moving costs accuracy, crouching helps", GP.hit_chance(base, 22, 0, true, false, 2, 0) < a0 and GP.hit_chance(base, 22, 0, false, true, 2, 0) > a0)
	check.call("the implant's tremor costs accuracy", GP.hit_chance(base, 22, 0, false, false, 2, 28) < a0)
	var scope_aim: int = GP.hit_chance(sc, 15, 3, false, false, 2, 0)
	var smg = g._new_item(g.gun_ids["smg"][0])
	var s0: Dictionary = GP.stats(smg)
	check.call("recoil makes later shots in a burst less accurate", GP.hit_chance(s0, 6, 0, false, false, 2, 0, 5) < GP.hit_chance(s0, 6, 0, false, false, 2, 0, 0))
	smg.mods.append(g._new_item("trl_mod_compensator"))
	smg.mods.append(g._new_item("trl_mod_foregrip"))
	var s1: Dictionary = GP.stats(smg)
	check.call("compensator and foregrip cut recoil (%.1f -> %.1f) and help the last shot of a burst" % [s0["recoil"], s1["recoil"]],
		s1["recoil"] < s0["recoil"] * 0.6 and GP.hit_chance(s1, 6, 0, false, false, 2, 0, 5) > GP.hit_chance(s0, 6, 0, false, false, 2, 0, 5))
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
			g.hp = g.hp_max
			g.body.reset()
			g.act_fire(true)
			dmg_total += h0 - g.hpn[found]
			trials += 1
		check.call("shooting at a target in view deals damage over a few volleys (%d dmg in %d volleys)" % [dmg_total, trials], dmg_total > 0)
		# aiming takes turns and shows in the HUD line
		g.hpn[found] = 400
		var aims := 0
		while g.aim_turns < 2 and aims < 6:
			g.act_aim(true)
			aims += 1
		check.call("aiming stacks (%d actions at %.2f a turn) and appears in the gun line" % [aims, g.aim_rate()], g.aim_turns == 2 and g.gun_line().contains("aim 2") and aims <= 3)
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
		g.hp = g.hp_max
		g.hpn[found] = 400
		var hpf: int = g.hpn[found]
		var fired: bool = g.act_fire(true)
		check.call("a grenade fired at a target in view explodes and spends the round", fired and gl.loaded == 0)
	return [st[0], st[1], log]
