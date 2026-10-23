extends RefCounted
## People falling: shoves, knockback, and the per-unit flying hook.  Returns [passed, total, log]
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
	var g = GameScript.new(51)
	g.setup(1200)
	g.specials_on = true
	for l_ in g.BODY.LIMBS:
		g.body.hp[l_] = 100000
		g.body.mx[l_] = 100000
	var tall: Dictionary = {}
	for t in g.city.tower_info:
		if tall.is_empty() or int(t["h"]) > int(tall["h"]):
			tall = t
	var H: int = tall["h"]
	var lv := func(z: int) -> int: return g.city.lvl_of_z(z) * g.s2
	# a roof edge: ROOF at x1-1, RAILING at x1, AIR beyond
	var edge := -1
	for y in range(int(tall["y0"]) + 2, int(tall["y1"]) - 2):
		var rc: int = lv.call(H) + y * g.size + int(tall["x1"]) - 1
		if g.city.tiles[rc] == CG.ROOF and g.city.tiles[rc - 1] == CG.ROOF and g.city.tiles[rc + 1] == CG.RAILING and g.city.tiles[rc + 2] == CG.AIR:
			edge = rc
			break
	check.call("found a roof edge with room to stand behind the victim", edge >= 0)
	g.pc = edge - 1
	g.last_pc = g.pc
	g.sim.retier(g.pc)
	# a victim: any near agent on this level, else pull one up
	var who := -1
	for i in g.sim.n:
		if g.sim.alive[i] == 1 and who < 0:
			who = i
	var put = func(cell: int, hp: int) -> void:
		if g.sim.near[who] == 1:
			g.sim.at[g.sim.pos[who]] = -1
		g.sim.place(who, cell)
		g.sim.sticky[who] = 1
		g.sim.idle[who] = 1
		g.fac[who] = g.BRATVA
		g.hpn[who] = hp
		g.hpmax[who] = hp
		g.astate[who] = g.UNAWARE
		g.stun[who] = 0
		g.sim.alive[who] = 1
	put.call(edge, 5000)
	check.call("the victim stands at the roof edge, thirty floors up", g.sim.pos[who] == edge and g.z_of(edge) == H and g.sim.near[who] == 1)
	var landing_hp: int = g.hpn[who]
	# shove over the railing
	var went := false
	for _t in 12:
		put.call(edge, 40)
		g.pc = edge - 1
		g.act_shove(1, 0)
		if g.z_of(g.sim.pos[who]) < H:
			went = true
			break
	check.call("a shove over the railing sends them off the roof", went)
	check.call("thirty floors is fatal (hp %d)" % g.hpn[who], g.sim.alive[who] == 0)
	var dropped := false
	var gc: int = edge % g.s2
	for dy in range(-8, 9):
		for dx in range(-8, 9):
			if g.items_at.has(gc + dy * g.size + dx):
				dropped = true
	check.call("and they land, and drop what they carried, on the street below", dropped)

	# a short fall that can be survived: three floors
	var air := -1
	for dx in range(2, 14):
		var x: int = int(tall["x1"]) + dx
		var y: int = (int(tall["y0"]) + int(tall["y1"])) / 2
		var gc2: int = y * g.size + x
		if g.sim.walk[gc2] == 1 and g.sim.at[gc2] == -1 and g.city.tiles[lv.call(3) + gc2] == CG.AIR and g.city.tiles[lv.call(1) + gc2] == CG.AIR and g.city.tiles[lv.call(2) + gc2] == CG.AIR:
			air = lv.call(3) + gc2
			break
	check.call("open air three floors up beside the tower", air >= 0)
	# put the player on the ground at that spot, so the victim lands on the player's level
	var below: int = air % g.s2
	g.pc = below - 6
	g.sim.retier(g.pc)
	# a victim standing on a street cell near the player, fall 3 floors from the air column above their cell
	var street: int = below
	g.pc = below - 5
	g.sim.retier(g.pc)
	if street >= 0:
		put.call(street + 3 * g.s2 - 3 * g.s2, 5000)
		g.astate[who] = g.HUNTING
		var h0: int = g.hpn[who]
		g.fall_agent(who, street + 3 * g.s2)
		var d: int = h0 - g.hpn[who]
		check.call("a three-floor fall costs 15-18 (%d) and the victim lives, stunned, where the player can see them" % d, d >= 15 and d <= 18 and g.sim.alive[who] == 1 and g.stun[who] > 0 and g.z_of(g.sim.pos[who]) == 0 and g.sim.near[who] == 1)
		check.call("a hunter who falls is still hunting", g.astate[who] == g.HUNTING)
	else:
		check.call("(no air column near the player)", false)
		check.call("(no air column near the player)", false)
	# landing on the player's cell is not allowed
	var lcell: Array = g.land_cell(g.pc + 2 * g.s2)
	check.call("a victim cannot land on the player", lcell[0] != g.pc)

	# abstract landing: the player is up on the roof, the victim falls to a floor the sim handles abstractly
	g.pc = edge - 1
	g.sim.retier(g.pc)
	put.call(edge, 5000)
	g.fall_agent(who, edge + 2)
	check.call("a victim who lands on another level is handed to the abstract simulation (alive %d, hp %d)" % [g.sim.alive[who], g.hpn[who]], g.sim.alive[who] == 0 or (g.sim.near[who] == 0 and g.z_of(g.sim.pos[who]) < H))

	# shove onto open floor and into a wall
	var open := -1
	for dy in range(-20, 21):
		for dx in range(-20, 21):
			var c: int = (g.size / 2 + dy) * g.size + g.size / 2 + dx
			if open < 0 and g.z_of(c) == 0 and g.sim.walk[c] == 1 and g.sim.walk[c + 1] == 1 and g.sim.walk[c + 2] == 1 and g.sim.walk[c - 1] == 1:
				open = c
	g.pc = open
	g.sim.retier(g.pc)
	g.last_pc = open
	put.call(open + 1, 5000)
	var moved := false
	for _t in 12:
		put.call(open + 1, 5000)
		g.act_shove(1, 0)
		if g.sim.pos[who] == open + 2:
			moved = true
			break
	check.call("shoving someone along open floor moves them one cell", moved)
	check.call("they are alerted by it", g.astate[who] != g.UNAWARE)
	g.city.tiles[open + 2] = CG.WALL
	g.sim.walk[open + 2] = 0
	var wall_hit := false
	for _t in 12:
		put.call(open + 1, 5000)
		g.act_shove(1, 0)
		if g.hpn[who] == 4997:
			wall_hit = true
			break
	check.call("shoved into a wall they take 3 and stay put", wall_hit and g.sim.pos[who] == open + 1)
	g.city.tiles[open + 2] = CG.GROUND
	g.sim.walk[open + 2] = 1

	# knockback from heavy weapons
	var knocked := 0
	g.wield = g._new_item("trl_mel_ono")
	for _t in 80:
		put.call(open + 1, 5000)
		g.fac[who] = g.BRATVA
		g.astate[who] = g.HUNTING
		g.melee(who)
		if g.sim.pos[who] == open + 2:
			knocked += 1
	check.call("an ono's blows sometimes throw people back (%d of 80)" % knocked, knocked >= 12 and knocked <= 60)
	# and off a roof
	g.pc = edge - 1
	g.sim.retier(g.pc)
	g.last_pc = g.pc
	var off := false
	for _t in 80:
		put.call(edge, 5000)
		g.astate[who] = g.HUNTING
		g.melee(who)
		if g.sim.alive[who] == 0 or g.z_of(g.sim.pos[who]) < H:
			off = true
			break
	check.call("a heavy blow at the railing can send them over", off)

	# the per-unit hook: a flyer hovers instead of falling
	g.wield = null
	g.fly_units[who] = {"fly": true}
	put.call(edge, 5000)
	g.fly_units[who] = {"fly": true}
	var hover := false
	for _t in 12:
		put.call(edge, 5000)
		g.fly_units[who] = {"fly": true}
		g.act_shove(1, 0)
		if g.sim.pos[who] == edge + 2:
			hover = true
			break
	check.call("a unit marked as a flyer hovers over the drop instead of falling", hover and g.sim.alive[who] == 1 and g.hpn[who] == 5000 and g.z_of(g.sim.pos[who]) == H)
	g.fly_units.clear()
	# mech slam throws people back
	return [st[0], st[1], log]
