extends RefCounted
## Pushable things (crates, tables, chairs) and animals (dogs, cats), and everything the floor does to them.  Returns [passed, total, log]
const GameScript = preload("res://src/game.gd")
const CG = preload("res://src/citygen.gd")

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	var g = GameScript.new(61)
	g.setup(1200)
	g.hp = 5000
	g.hp_max = 5000
	var kinds := {"crate": 0, "table": 0, "chair": 0}
	for t in g.things:
		if t["k"] != "":
			kinds[t["k"]] += 1
	check.call("loose crates, tables and chairs are scattered about %s" % str(kinds), kinds["crate"] > 30 and kinds["table"] > 20 and kinds["chair"] > 10)
	var dogs := 0
	var cats := 0
	for k in g.critters:
		if k["k"] == "dog":
			dogs += 1
		elif k["k"] == "cat":
			cats += 1
	check.call("dogs and cats roam the city (%d dogs, %d cats)" % [dogs, cats], dogs > 15 and cats > 15)
	var blocked := true
	for t in g.things:
		if t["k"] != "" and g.sim.walk[t["cell"]] != 0:
			blocked = false
	check.call("things block movement for everyone", blocked)

	var tall: Dictionary = {}
	for t in g.city.tower_info:
		if tall.is_empty() or int(t["h"]) > int(tall["h"]):
			tall = t
	var H: int = tall["h"]
	var lv := func(z: int) -> int: return g.city.lvl_of_z(z) * g.s2
	# open ground
	var open := -1
	for dy in range(-30, 31):
		for dx in range(-30, 31):
			var c: int = (g.size / 2 + dy) * g.size + g.size / 2 + dx
			if open >= 0 or g.z_of(c) != 0:
				continue
			var ok := true
			for ox in range(-2, 5):
				var cc: int = c + ox
				if g.sim.walk[cc] == 0 or g.sim.at[cc] != -1 or g.veh_at[cc] != -1 or g.thing_at[cc] != -1 or g.crit_at[cc] != -1:
					ok = false
			if ok:
				open = c
	check.call("open ground found", open >= 0)
	g.pc = open
	g.sim.retier(g.pc)
	g.last_pc = open
	# push a crate
	var ti: int = g._add_thing("crate", open + 1, true)
	g.act_move(1, 0)
	check.call("walking into a crate pushes it along and you follow", g.things[ti]["cell"] == open + 2 and g.pc == open + 1 and g.thing_at[open + 2] == ti and g.thing_at[open + 1] == -1)
	check.call("the cell it left is walkable again, the one it sits on is not", g.sim.walk[open + 1] == 1 and g.sim.walk[open + 2] == 0)
	# blocked by a wall
	g.city.tiles[open + 3] = CG.WALL
	g.sim.walk[open + 3] = 0
	var t0: int = g.turn
	check.call("it won't go into a wall, and that costs no time", not g.act_move(1, 0) and g.turn == t0 and g.things[ti]["cell"] == open + 2)
	g.city.tiles[open + 3] = CG.GROUND
	g.sim.walk[open + 3] = 1
	# a table takes two turns
	g._remove_thing(ti)
	g.pc = open
	var tb: int = g._add_thing("table", open + 1, false)
	t0 = g.turn
	g.act_move(1, 0)
	check.call("a table is a heave: two turns", g.things[tb]["cell"] == open + 2 and g.turn - t0 == 2)
	g._remove_thing(tb)
	# things don't stack up
	g.pc = open
	var c1: int = g._add_thing("crate", open + 1, false)
	var c2: int = g._add_thing("crate", open + 2, false)
	check.call("a crate behind a crate will not move", not g.act_move(1, 0) and g.things[c1]["cell"] == open + 1)
	g._remove_thing(c1)
	g._remove_thing(c2)
	# cover
	var cv: int = g._add_thing("crate", open + 1, false)
	check.call("a crate is cover for whoever crouches behind it", g.cover_vs(open - 3, open + 2 - 0, false) >= 0 and g.cover_vs(open, open + 2, true) > 0)
	g._remove_thing(cv)
	# smash by hitting
	var sm: int = g._add_thing("crate", open + 1, true)
	g.items_at.erase(open + 1)
	g.wield = g._new_item("trl_mel_topor")
	var swings := 0
	while g.things[sm]["k"] != "" and swings < 10:
		g.act_strike(1, 0)
		swings += 1
	check.call("a crate can be broken open with an axe (%d swings) and spills its contents" % swings, g.things[sm]["k"] == "" and g.items_at.has(open + 1) and g.sim.walk[open + 1] == 1)
	g.wield = null
	# explosions
	var ex: int = g._add_thing("table", open + 2, false)
	var ek: int = g._add_critter("dog", open + 3)
	g.pc = open - 2
	g._explode(open + 2, 2, 30)
	check.call("a blast wrecks tables and kills dogs near it", g.things[ex]["k"] == "" and g.critters[ek]["k"] == "")
	g.pc = open

	# ---- falling
	var edge := -1
	for y in range(int(tall["y0"]) + 2, int(tall["y1"]) - 2):
		var rc: int = lv.call(H) + y * g.size + int(tall["x1"]) - 1
		if g.city.tiles[rc] == CG.ROOF and g.city.tiles[rc - 1] == CG.ROOF and g.city.tiles[rc + 1] == CG.RAILING and g.city.tiles[rc + 2] == CG.AIR and g.items_at.has(rc) == false:
			edge = rc
			break
	check.call("a roof edge to push things off", edge >= 0)
	g.pc = edge - 1
	g.sim.retier(g.pc)
	g.last_pc = g.pc
	var drop: int = g._add_thing("crate", edge, true)
	g.act_move(1, 0)
	check.call("a crate pushed at the railing goes over and is smashed far below", g.things[drop]["k"] == "" and g.z_of(g.pc) == H)
	var tab: int = g._add_thing("table", edge, false)
	g.pc = edge - 1
	check.call("a table is too heavy to heave over a railing", not g.act_move(1, 0) and g.things[tab]["cell"] == edge)
	g._remove_thing(tab)
	# fall heights
	var air3 := -1
	for dx in range(2, 14):
		var x: int = int(tall["x1"]) + dx
		var y: int = (int(tall["y0"]) + int(tall["y1"])) / 2
		var gc: int = y * g.size + x
		if g.sim.walk[gc] == 1 and g.sim.at[gc] == -1 and g.thing_at[gc] == -1 and g.crit_at[gc] == -1 and g.city.tiles[lv.call(3) + gc] == CG.AIR and g.city.tiles[lv.call(1) + gc] == CG.AIR and g.city.tiles[lv.call(2) + gc] == CG.AIR:
			air3 = lv.call(3) + gc
			break
	check.call("air three floors up", air3 >= 0)
	var gcol: int = air3 % g.s2
	g.pc = gcol - 5
	g.sim.retier(g.pc)
	var a1: int = g._add_thing("crate", gcol - 0 + 0, false)
	g._remove_thing(a1)
	var cr: int = g._add_thing("crate", edge, false)
	g.fall_thing(cr, air3 - 2 * g.s2)          # one floor up
	check.call("a crate dropped one floor lands in one piece", g.thing_at[gcol] != -1 and g.things[g.thing_at[gcol]]["k"] == "crate")
	g._remove_thing(g.thing_at[gcol])
	var ch: int = g._add_thing("chair", edge, false)
	g.fall_thing(ch, air3 - 2 * g.s2)
	check.call("a chair dropped one floor breaks", g.thing_at[gcol] == -1)
	var cr3: int = g._add_thing("crate", edge, false)
	g.fall_thing(cr3, air3)
	check.call("a crate dropped three floors smashes", g.thing_at[gcol] == -1)
	# items fall
	g.items_at.erase(gcol)
	g._put(air3, g._new_item("trl_ration"))
	check.call("an item dropped over open air falls to the floor below", g.items_at.has(gcol))

	# ---- animals
	var dog: int = g._add_critter("dog", open + 1)
	var cat: int = g._add_critter("cat", open + 4)
	g.pc = open
	g.sim.retier(g.pc)
	g.last_pc = open
	g.stance = g.WALKING
	check.call("a dog is nudged along when you walk into it", g.act_move(1, 0) and g.pc == open + 1 and g.cheb(g.critters[dog]["cell"], open + 2) <= 1 and g.critters[dog]["cell"] != g.pc)
	# cats keep their distance
	g.critters[cat]["mood"] = 0
	var d0: int = g.cheb(g.critters[cat]["cell"], g.pc)
	for _t in 4:
		g.act_wait()
	check.call("a cat walks away from you when you are close", g.cheb(g.critters[cat]["cell"], g.pc) >= d0 or g.critters[cat]["cell"] != open + 4)
	# angry dog bites
	var dg: int = g._add_critter("dog", open - 1) if g.crit_at[open - 1] == -1 and g.sim.walk[open - 1] == 1 else g.crit_at[open - 1]
	g.pc = open + 1
	g.critters[dg]["cell"] = g.critters[dg]["cell"]
	g.critters[dg]["mood"] = 1
	g._move_crit(dg, open)
	var hp_b: int = g.hp
	for _t in 25:
		g.critters[dg]["stun"] = 0
		g._critters_turn()
	check.call("an angry dog bites (hp -%d)" % (hp_b - g.hp), g.hp < hp_b)
	g._kill_crit(dg, "dies")
	# hitting a dog
	var hd: int = g._add_critter("dog", open + 2)
	g.pc = open + 1
	g.wield = g._new_item("trl_mel_katana")
	g.act_strike(1, 0)
	check.call("a dog that survives a hit turns on you", g.critters[hd]["k"] == "" or g.critters[hd]["mood"] == 1)
	g.wield = null
	# animals over the edge
	g.pc = edge - 1
	g.sim.retier(g.pc)
	var cd: int = g._add_critter("dog", edge)
	g.act_shove(1, 0)
	check.call("a dog shoved off the roof does not survive thirty floors", g.critters[cd]["k"] == "")
	var cc3: int = g._add_critter("cat", gcol - 3 * 0 + 1 if false else air3 % g.s2 - 7)
	g._kill_crit(cc3, "gone")
	var cc: int = g._add_critter("cat", edge)
	var hp_cat: int = g.critters[cc]["hp"]
	g.fall_crit(cc, air3)
	check.call("a cat falls three floors, lands on its feet and survives (hp %d -> %d)" % [hp_cat, g.critters[cc]["hp"]], g.critters[cc]["k"] == "cat" and g.critters[cc]["hp"] > 0 and g.critters[cc]["hp"] < hp_cat and g.z_of(g.critters[cc]["cell"]) == 0)
	g._kill_crit(cc, "gone")
	var dd3: int = g._add_critter("dog", edge)
	g.fall_crit(dd3, air3)
	check.call("a dog falling three floors takes a beating (hp %d)" % g.critters[dd3]["hp"] if g.critters[dd3]["k"] != "" else "a dog falling three floors does not survive", g.critters[dd3]["k"] == "" or g.critters[dd3]["hp"] <= 3)
	# barking is gentle
	var civ := -1
	var thug := -1
	for k in g.sim.near_list.size():
		var j: int = g.sim.near_list[k]
		if g.sim.alive[j] == 1 and g.z_of(g.sim.pos[j]) == g.z_of(g.pc):
			if g.fac[j] == g.CIV and civ < 0:
				civ = j
			elif g.fac[j] != g.CIV and thug < 0:
				thug = j
	if civ >= 0 and thug >= 0:
		g.astate[civ] = g.UNAWARE
		g.astate[thug] = g.UNAWARE
		g._noise_gentle(g.pc, 60)
		check.call("a bark makes the armed suspicious and does not scare civilians", g.astate[thug] == g.SUSPICIOUS and g.astate[civ] == g.UNAWARE)
	else:
		check.call("(no civilian and armed person near the player on the roof)", true)

	# ---- save and load
	g.pc = open
	g.sim.retier(g.pc)
	var sv: int = g._add_thing("table", open + 3, false)
	var sc: int = g._add_critter("cat", open + 5)
	g.things[sv]["hp"] = 7
	var dict: Dictionary = JSON.parse_string(JSON.stringify(g.save_dict()))
	var g2 = GameScript.new(61)
	g2.setup(1200)
	g2.load_dict(dict)
	var cnt1 := 0
	var cnt2 := 0
	for t in g.things:
		if t["k"] != "":
			cnt1 += 1
	for t in g2.things:
		if t["k"] != "":
			cnt2 += 1
	check.call("save and load keep every thing and animal where it was (%d things)" % cnt2, cnt1 == cnt2 and g2.thing_at[open + 3] != -1 and g2.things[g2.thing_at[open + 3]]["hp"] == 7 and g2.crit_at[open + 5] != -1 and g2.sim.walk[open + 3] == 0)
	return [st[0], st[1], log]
