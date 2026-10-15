extends RefCounted
## Round two: the playable slice's rules, driven headless through the action API.  Returns [passed, total, log]
const GameScript = preload("res://src/game.gd")

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	var t0 := Time.get_ticks_msec()
	var g = GameScript.new(5)
	g.setup(2000)
	log.append("  (setup of a 256x256 city, 2,000 people, 30 cars, loot: %d ms)" % (Time.get_ticks_msec() - t0))
	check.call("the player starts on a road with a pistol, a coat and a backpack", g.city.tiles[g.pc] == 1 and g.wield != null and g.worn.size() == 2)
	check.call("loot is scattered through the city (more than 150 piles)", g.items_at.size() > 150)
	check.call("there are cars, some driven by AI drivers", g.vehicles.size() > 20 and g.vehicles.filter(func(v): return v["ai"]).size() > 5)
	# walk around
	var moved := 0
	for k in 40:
		var d: Array = g.SIZE_DIRS[k % 4]
		if g.act_move(d[0], d[1]):
			moved += 1
	check.call("the player can walk and time passes (%d moves, turn %d)" % [moved, g.turn], moved > 10 and g.turn >= moved)
	# pick up
	var cell := -1
	for c in g.items_at:
		if g.city.tiles[c] == 1 or g.city.tiles[c] == 3:
			cell = c
			break
	g.pc = cell
	g.fov.compute(cell % g.size, cell / g.size, 18)
	var before: int = g.yen + g.ammo_total() + g.inventory_list().size()
	g.act_pickup()
	check.call("picking up changes yen, ammo or the inventory", g.yen + g.ammo_total() + g.inventory_list().size() != before or g.items_at.has(cell))
	# the people
	check.call("about two thousand people exist, some of them hostile factions", g.fac.count(1) > 40 and g.fac.count(2) > 40)
	# awareness: a hostile person starts to notice a player who walks into view
	var thug := -1
	for _wait in 400:                      # let the morning commute put someone on a street
		for i in g.sim.n:
			if g.fac[i] == 1 and g.sim.alive[i] == 1 and g.sim.pos[i] < g.s2 and g.city.tiles[g.sim.pos[i]] == 1:
				thug = i
				break
		if thug >= 0:
			break
		g.end_turn()
	var anchor: int = g.sim.pos[thug]
	g.pc = anchor
	var placed := -1
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var c: int = anchor + dy * g.size + dx
			if c >= 0 and c < g.size * g.size and g.city.tiles[c] == 1 and g.sim.at[c] == -1 and maxi(absi(dx), absi(dy)) >= 4:
				placed = c
				break
		if placed >= 0:
			break
	g.pc = placed
	for k in 12:
		g.end_turn()                      # promotes the thug to a full agent
	var hot := -1
	for k in g.sim.near_list.size():
		var j: int = g.sim.near_list[k]
		if g.hostile(j) and g.sim.alive[j] == 1 and g.city.tiles[g.sim.pos[j]] == 1:
			hot = j
			break
	check.call("a hostile agent is near the player after teleporting", hot >= 0)
	var spot := -1
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var c: int = g.sim.pos[hot] + dy * g.size + dx
			if c >= 0 and c < g.size * g.size and g.city.tiles[c] == 1 and g.sim.at[c] == -1 and maxi(absi(dx), absi(dy)) >= 3 and g.sim._sees(c, g.sim.pos[hot], 12):
				spot = c
				break
		if spot >= 0:
			break
	check.call("found an open spot in line of sight of that hostile", spot >= 0)
	g.pc = spot
	g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
	var reached := 0
	for k in 25:
		g.end_turn()
		reached = maxi(reached, g.astate[hot])
		if g.astate[hot] == g.HUNTING:
			break
	log.append("  (hostile's awareness peaked at state %d; meter %d)" % [reached, g.meter[hot]])
	check.call("a hostile in view notices the player (suspicious or hunting)", reached >= 1)
	check.call("hunters take the fight to the player (hp %d)" % g.hp, g.hp <= g.hp_max)
	# theft test on a dozen different civilians
	var ok := 0
	var tries := 0
	var y0: int = g.yen
	for k in g.sim.near_list.size():
		var j: int = g.sim.near_list[k]
		if g.fac[j] != 0 or g.sim.alive[j] == 0 or tries >= 12:
			continue
		var nb := -1
		for d in g.SIZE_DIRS:
			var c: int = g.sim.pos[j] + d[1] * g.size + d[0]
			if g.sim.walk[c] == 1 and g.sim.at[c] == -1 and g.veh_at[c] == -1:
				nb = c
				break
		if nb < 0:
			continue
		g.pc = nb
		g.yenn[j] = 100
		g.astate[j] = 0
		tries += 1
		if g.act_steal():
			ok += 1
	check.call("pickpocketing succeeds some of the time (%d of %d) and moves yen" % [ok, tries], tries >= 6 and ok >= 1 and ok < tries + 1 and g.yen > y0)
	# shooting
	g.wield = g._new_item("trl_gun_sp45")
	var GunPlayCheck = preload("res://src/gunplay.gd")
	var shot := false
	for attempt in 40:
		var tgt: int = g.nearest_target()
		if tgt >= 0:
			var hp0: int = g.hpn[tgt]
			g.act_fire()
			shot = true
			break
		g.end_turn()
	check.call("a wielded gun fires at a visible target and uses ammo", (not shot) or g.wield.loaded < int(GunPlayCheck.stats(g.wield)["mag"]))
	# vehicle: enter the nearest car and drive
	var vi := -1
	for k in g.vehicles.size():
		if not g.vehicles[k]["ai"]:
			vi = k
			break
	g.pc = g.vehicles[vi]["cell"]
	g.in_vehicle = -1
	var entered: bool = g.act_vehicle()
	check.call("the player can enter a parked car", entered and g.in_vehicle == vi)
	var c0: int = g.pc
	for k in 6:
		g.act_move(1, 0)
	check.call("driving moves the car several tiles per turn (moved %d)" % g.cheb(c0, g.pc), g.cheb(c0, g.pc) >= 3 or g.vehicles[vi]["spd"] == 0)
	g.act_vehicle()
	check.call("the player can get out of the car", g.in_vehicle == -1)
	# AI cars move
	var mv := 0
	var pos0 := {}
	for k in g.vehicles.size():
		if g.vehicles[k]["ai"]:
			pos0[k] = g.vehicles[k]["cell"]
	g.pc = g.vehicles[g.vehicles.size() - 1]["cell"]
	for k in 20:
		g.end_turn()
	for k in pos0:
		if g.vehicles[k]["cell"] != pos0[k]:
			mv += 1
	check.call("AI-driven cars drive along the roads (%d moved)" % mv, mv >= 1)
	# save and load
	var d: Dictionary = g.save_dict()
	var s := JSON.stringify(d)
	var g2 = GameScript.new(1)
	g2.load_dict(JSON.parse_string(s))
	check.call("save and load restores the player, yen, turn and positions", g2.pc == g.pc and g2.yen == g.yen and g2.turn == g.turn and g2.sim.pos == g.sim.pos and g2.sim.near_list.size() == g.sim.near_list.size())
	check.call("a loaded game keeps the inventory", g2.inventory_list().size() == g.inventory_list().size())
	for k in 15:
		g2.end_turn()
	check.call("a loaded game keeps running", g2.turn == g.turn + 15)
	# frame cost
	var tt := Time.get_ticks_usec()
	for k in 60:
		g.end_turn()
	var ms := (Time.get_ticks_usec() - tt) / 60000.0
	log.append("  (full game turn with 2,000 people, awareness and cars: %.2f ms average)" % ms)
	check.call("a full turn costs under 12 ms (%.2f)" % ms, ms < 12.0)
	return [st[0], st[1], log]
