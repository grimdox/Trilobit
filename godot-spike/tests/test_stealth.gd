extends RefCounted
## Stances, vision cones, hearing, cover and jumping.  Returns [passed, total, log]
const GameScript = preload("res://src/game.gd")
const CG = preload("res://src/citygen.gd")

func _open_cell(g, from: int) -> int:
	# a street/sidewalk cell with a 7x7 neighbourhood that is all walkable
	for r in range(0, 120):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var x: int = from % g.size + dx
				var y: int = from / g.size + dy
				if x < 5 or y < 5 or x >= g.size - 5 or y >= g.size - 5 or y >= g.size:
					continue
				var ok := true
				for oy in range(-3, 4):
					for ox in range(-3, 4):
						var c: int = (y + oy) * g.size + x + ox
						if g.sim.walk[c] == 0 or g.sim.at[c] != -1 or g.veh_at[c] != -1:
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
	var g = GameScript.new(21)
	g.setup(1200)
	var props := 0
	var by_kind := {23: 0, 24: 0, 25: 0}
	for i in g.s2:
		var t: int = g.city.tiles[i]
		if by_kind.has(t):
			by_kind[t] += 1
			props += 1
	check.call("ground level has crates, dumpsters and planters (%d)" % props, props > 60 and by_kind[23] > 5 and by_kind[24] > 5 and by_kind[25] > 5)
	var upstairs := 0
	for i in range(g.s2, g.city.tiles.size()):
		if g.city.tiles[i] >= 23 and g.city.tiles[i] <= 25:
			upstairs += 1
	check.call("tower floors have props too (%d)" % upstairs, upstairs > 20)

	var open := _open_cell(g, g.pc)
	check.call("found open ground to test on", open >= 0)
	g.pc = open
	g.last_pc = open
	g.sim.retier(g.pc)
	# stances
	var t0: int = g.turn
	g.act_move(1, 0)
	check.call("walking is one cell a turn", g.pc == open + 1 and g.turn == t0 + 1)
	g.pc = open
	t0 = g.turn
	var s0: int = g.stamina
	g.act_move(1, 0, true)
	check.call("running covers two cells in one turn and tires you (%d -> %d)" % [s0, g.stamina], g.pc == open + 2 and g.turn == t0 + 1 and g.stamina < s0 and g.stance == g.RUNNING)
	g.stamina = 1
	g.pc = open
	g.act_move(1, 0, true)
	check.call("a winded runner can only walk", g.pc == open + 1)
	for _i in 10:
		g.act_wait()
	check.call("stamina comes back while resting and the runner slows to a walk", g.stamina >= 10 and g.stance == g.WALKING)
	g.pc = open
	g.stamina = g.STAMINA_MAX
	g._set_stance(g.CRAWL)
	g.ap = g.AP_BASE
	t0 = g.turn
	g.act_move(1, 0)
	check.call("crawling is half speed", g.pc == open + 1 and g.turn == t0 + 2)
	var radii := []
	for s in 4:
		g._set_stance(s)
		radii.append(g.footstep_radius())
	check.call("footsteps carry further the faster you go %s" % str(radii), radii[0] < radii[1] and radii[1] < radii[2] and radii[2] < radii[3])
	g._set_stance(g.WALKING)

	# jumping
	g.pc = open
	g.stamina = g.STAMINA_MAX
	var cr: int = open + 1
	g.city.tiles[cr] = CG.CRATE
	g.sim.walk[cr] = 0
	var before: int = g.pc
	check.call("a crate can be jumped; you land two cells on", g.act_jump(1, 0) and g.pc == open + 2)
	g.pc = open
	g.city.tiles[open + 1] = CG.WALL
	g.sim.walk[open + 1] = 0
	check.call("a wall cannot be jumped", not g.act_jump(1, 0) and g.pc == open)
	g.city.tiles[open + 1] = CG.GROUND
	g.sim.walk[open + 1] = 1
	g.stamina = 3
	check.call("no jump when winded", not g.act_jump(1, 0))
	g.stamina = g.STAMINA_MAX
	g.pc = open - 3
	g.run_streak = 1
	g.run_dir = Vector2i(1, 0)
	g.city.tiles[open - 2] = CG.CRATE
	g.sim.walk[open - 2] = 0
	g.city.tiles[open - 1] = CG.CRATE
	g.sim.walk[open - 1] = 0
	check.call("a running start jumps three cells over two crates", g.act_jump(1, 0) and g.pc == open)
	g.city.tiles[open - 2] = CG.GROUND
	g.city.tiles[open - 1] = CG.GROUND
	g.sim.walk[open - 2] = 1
	g.sim.walk[open - 1] = 1
	g.city.tiles[cr] = CG.GROUND
	g.sim.walk[cr] = 1

	# cover
	var shooter: int = open - 4
	var tgt_cell: int = open
	check.call("no cover in the open", g.cover_vs(shooter, tgt_cell, false) == 0)
	g.city.tiles[open - 1] = CG.CRATE
	var low: int = g.cover_vs(shooter, tgt_cell, false)
	var crouched: int = g.cover_vs(shooter, tgt_cell, true)
	check.call("a crate on the shooter's side is cover (%d, %d crouched)" % [low, crouched], low >= 15 and crouched > low)
	check.call("cover on the far side does nothing", g.cover_vs(open + 4, tgt_cell, false) == 0)
	g.city.tiles[open - 1] = CG.GROUND

	# a watcher: find a near agent and put him in the open area
	var who := -1
	for k in g.sim.near_list.size():
		var j: int = g.sim.near_list[k]
		if g.sim.alive[j] == 1 and g.z_of(g.sim.pos[j]) == 0:
			who = j
			break
	check.call("there is someone near to be watched", who >= 0)
	if who >= 0:
		g.sim.at[g.sim.pos[who]] = -1
		g.sim.pos[who] = open + 5
		g.sim.at[open + 5] = who
		g.pc = open
		g.last_pc = open
		g.fac[who] = g.BRATVA
		g.astate[who] = g.UNAWARE
		g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
		g.face[who] = 6                                      # DIR8[6] = west: looking at the player
		check.call("looking straight at you: full cone", g.cone_factor(who, g.pc) == 1.0)
		g.face[who] = 0                                      # north: you are to his side
		var side: float = g.cone_factor(who, g.pc)
		g.face[who] = 2                                      # east: his back is to you
		var back: float = g.cone_factor(who, g.pc)
		check.call("side view is weak (%.1f) and behind is blind (%.1f)" % [side, back], side > 0.0 and side < 1.0 and back == 0.0)
		g.face[who] = 2
		g.meter[who] = 0
		g.step_noise = 0
		for _i in 6:
			g._notice(who, 5)
		check.call("standing behind an unaware guard goes unnoticed", g.meter[who] == 0 and g.astate[who] == g.UNAWARE)
		g.step_noise = 9
		for _i in 3:
			g._notice(who, 5)
		check.call("running footsteps behind him are heard and he turns (meter %d, face %d)" % [g.meter[who], g.face[who]], g.meter[who] >= 25 and g.face[who] == 6)
		g.astate[who] = g.UNAWARE
		g.meter[who] = 0
		g.step_noise = 0
		g.face[who] = 6
		for _i in 4:
			g._notice(who, 5)
		check.call("the same guard facing you notices quickly", g.astate[who] != g.UNAWARE or g.meter[who] >= 40)
		g.astate[who] = g.UNAWARE
		g.meter[who] = 0
		g.face[who] = 6
		g._set_stance(g.CRAWL)
		var crawl_meter := 0
		for _i in 4:
			g._notice(who, 5)
		crawl_meter = g.meter[who]
		g.meter[who] = 0
		g.astate[who] = g.UNAWARE
		g._set_stance(g.WALKING)
		for _i in 4:
			g._notice(who, 5)
		check.call("crawling gets noticed more slowly than walking (%d vs %d)" % [crawl_meter, g.meter[who]], crawl_meter < g.meter[who])
		# knife in the back
		g.hpmax[who] = 1000                            # limbs scale with it: a long run of blows must not kill him
		var tot_back := 0
		var tot_front := 0
		for trial in 40:
			g.limbn[who * 6] = -1
			g.sim.alive[who] = 1
			g.astate[who] = g.UNAWARE
			g.hpn[who] = 1000
			g.face[who] = 2
			g.melee(who)
			tot_back += 1000 - g.hpn[who]
			g.limbn[who * 6] = -1
			g.sim.alive[who] = 1
			g.astate[who] = g.UNAWARE
			g.hpn[who] = 1000
			g.face[who] = 6
			g.melee(who)
			tot_front += 1000 - g.hpn[who]
		check.call("a blow from behind does about twice what a frontal ambush does (%d vs %d)" % [tot_back, tot_front], tot_back > tot_front * 3 / 2 and tot_front > 0)
	# save/load puts you back on your feet
	g._set_stance(g.CRAWL)
	g.stamina = 77
	var dd: Dictionary = JSON.parse_string(JSON.stringify(g.save_dict()))
	var g2 = GameScript.new(21)
	g2.setup(1200)
	g2.load_dict(dd)
	check.call("a loaded game starts walking and keeps its stamina", g2.stance == g2.WALKING and g2.stamina == 77)
	return [st[0], st[1], log]
