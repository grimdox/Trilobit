extends RefCounted
## Windows, doors and furniture: aiming through glass, flat cover for shots, and hunters that smash a window rather than stand at it.
const GameScript = preload("res://src/game.gd")
const CG = preload("res://src/citygen.gd")

func run() -> Array:
	var cnt: Array = [0, 0]
	var log: Array = []
	var check := func(label: String, ok: bool) -> void:
		cnt[1] += 1
		if ok:
			cnt[0] += 1
		else:
			log.append("  FAIL " + label)
	var g = GameScript.new(5)
	g.setup(600)
	var s: int = g.size
	var found := -1
	var step := 0
	for c in g.s2:
		if g.city.tiles[c] == CG.GLASS and g.z_of(c) == 0:
			for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
				var st: int = d.y * s + d.x
				if g._outside_t(g.city.tiles[c - st]) and g._inside_t(g.city.tiles[c + st]) and g._inside_t(g.city.tiles[c + 2 * st]) and g._inside_t(g.city.tiles[c + 3 * st]):
					found = c
					step = st
					break
		if found >= 0:
			break
	check.call("the city has a window with a floor behind it", found >= 0)
	check.call("windows 50%, doors 25%, furniture 25%", g.SHIELD_WINDOW == 50 and g.SHIELD_DOOR == 25 and g.SHIELD_FURNITURE == 25)
	var who := 0
	g.pc = found - step
	g.last_pc = g.pc
	var inside: int = found + step
	g.sim.place(who, inside)
	g.fac[who] = g.BRATVA
	g.astate[who] = g.HUNTING
	g.hpn[who] = 100000
	g.hpmax[who] = 100000
	g.wield = g._new_item("trl_gun_zp9")
	g.wield.loaded = 10
	g.fov.compute(g.pc % s, g.pc / s, 18)
	g.sim.retier(g.pc)
	g.fov.compute(g.pc % s, g.pc / s, 18)
	var sh: Dictionary = g.shield_vs(g.pc, inside)
	check.call("a target right behind a window is covered 50% (%s)" % str(sh), int(sh["pct"]) == 50 and sh["what"] == "window")
	check.call("and the aiming key finds a hostile behind the glass", g.target_list(false).has(who) and g.act_aim(false))
	var far: int = found + 3 * step
	g.sim.place(who, far)
	g.sim.retier(g.pc)
	check.call("a target three tiles back is not covered by the window", int(g.shield_vs(g.pc, far)["pct"]) == 0 and g.target_list(false).has(who))
	# the flat chance: with the target behind the glass, about half the volley is stopped
	g.sim.place(who, inside)
	g.sim.retier(g.pc)
	var stopped := 0
	var landed_n := 0
	var trials := 400
	g.crits = false
	for t in trials:
		g.city.tiles[found] = CG.GLASS                     # the volley and the hunter may have broken it
		g.sim.tiles[found] = CG.GLASS
		g.sim.place(who, inside)
		g.sim.near[who] = 1
		g.astate[who] = g.HUNTING
		g.wield.loaded = 10
		g.hpn[who] = 100000
		g.aim_turns = 2
		g.stamina = g.STAMINA_MAX
		g.ap = 199
		g.log.clear()
		g.act_fire(false)
		if g.hpn[who] < 100000:
			landed_n += 1
		if g.log.any(func(m): return String(m).contains("is stopped by the window")):
			stopped += 1
	var would_hit: int = stopped + landed_n
	check.call("half of the shots that would hit through a window are stopped (%d of %d)" % [stopped, would_hit], would_hit > 60 and stopped > would_hit * 0.38 and stopped < would_hit * 0.62)
	# door and furniture beside a target
	var door_cell := -1
	for c in g.s2:
		if g.city.tiles[c] == CG.DOOR and g.z_of(c) == 0 and c + 2 * s < g.s2 and c - 2 * s >= 0:
			door_cell = c
			break
	if door_cell >= 0:
		check.call("a person next to a door is covered 25% from the other side", int(g.shield_vs(door_cell - 2 * s, door_cell + s)["pct"]) in [0, 25] and int(g.shield_vs(door_cell + 3 * s, door_cell + 1)["pct"]) in [0, 25])
	var tbl := -1
	for c in g.s2:
		if g.city.tiles[c] >= CG.EXTRA0 and g.city.tiles[c] in CG.LOW_COVER and g.z_of(c) == 0 and c % s > 3 and c % s < s - 3:
			tbl = c
			break
	if tbl >= 0:
		check.call("furniture beside the target covers 25%", int(g.shield_vs(tbl - 3, tbl + 1)["pct"]) == 25)
	# a hunter without a gun smashes the window
	g.city.tiles[found] = CG.GLASS
	g.sim.tiles[found] = CG.GLASS
	g.sim.place(who, found + 2 * step)
	g.sim.retier(g.pc)
	g.gunc[who] = 0
	g.fac[who] = g.BRATVA
	g.astate[who] = g.HUNTING
	g.hpn[who] = 100
	g.hpmax[who] = 100
	g.crits = true
	var tile0: int = g.city.tiles[found]
	for t in 8:
		g.end_turn()
	check.call("a hunter with no gun smashes the window and comes through (state %d)" % g.astate[who], g.city.tiles[found] == CG.TID["window_broken"] and tile0 == CG.GLASS)
	return [cnt[0], cnt[1], log]
