extends RefCounted
## Movement between levels: falling, jump jets, leg actuators, stairs with pursuers, gyros and mechs.  Returns [passed, total, log]
const GameScript = preload("res://src/game.gd")
const CG = preload("res://src/citygen.gd")

func _open_cell(g, from: int, rad: int) -> int:
	for r in range(0, 140):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var x: int = from % g.size + dx
				var y: int = from / g.size + dy
				if x < rad + 2 or y < rad + 2 or x >= g.size - rad - 2 or y >= g.size - rad - 2:
					continue
				var c0: int = y * g.size + x
				if g.city.tiles[c0 + g.s2] != CG.AIR:
					continue
				var ok := true
				for oy in range(-rad, rad + 1):
					for ox in range(-rad, rad + 1):
						var c: int = (y + oy) * g.size + x + ox
						if g.sim.walk[c] == 0 or g.sim.at[c] != -1 or g.veh_at[c] != -1 or g.items_at.has(c):
							ok = false
				if ok:
					return c0
	return -1

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	var g = GameScript.new(31)
	g.setup(1200)
	g.hp = 5000
	g.hp_max = 5000
	var tall: Dictionary = {}
	for t in g.city.tower_info:
		if tall.is_empty() or int(t["h"]) > int(tall["h"]):
			tall = t
	var H: int = tall["h"]
	var lvl := func(z: int) -> int: return g.city.lvl_of_z(z) * g.s2

	# ---- falling
	check.call("a fall costs five a floor, halved by leg actuators, nothing with fuelled jets, a third into water",
		g.fall_damage(4) == 20 and (func(): g.implants["legs"] = true; var d = g.fall_damage(4); g.implants.erase("legs"); return d == 10).call()
		and (func(): g.implants["jets"] = true; g.fuel = 10; var d = g.fall_damage(4); g.implants.erase("jets"); return d == 0).call() and g.fall_damage(6, true) == 10)
	var aircell := -1
	for dx in range(2, 12):
		var x: int = int(tall["x1"]) + dx
		var y: int = (int(tall["y0"]) + int(tall["y1"])) / 2
		var gc: int = y * g.size + x
		if g.sim.walk[gc] == 1 and g.sim.at[gc] == -1 and g.city.tiles[lvl.call(5) + gc] == CG.AIR and g.city.tiles[lvl.call(1) + gc] == CG.AIR:
			aircell = lvl.call(5) + gc
			break
	check.call("found open air five floors up beside the tower", aircell >= 0)
	if aircell >= 0:
		g.pc = aircell
		var hp0: int = g.hp
		g._fall_player("Test.")
		check.call("a five-floor fall lands on the street for 25-28 damage (%d)" % (hp0 - g.hp), g.z_of(g.pc) == 0 and hp0 - g.hp >= 25 and hp0 - g.hp <= 28 and g.sim.walk[g.pc] == 1)

	# ---- leaping into the void from the roof
	var edge := -1
	for y in range(int(tall["y0"]) + 2, int(tall["y1"]) - 2):
		var x1: int = tall["x1"]
		var rc: int = lvl.call(H) + y * g.size + x1 - 1
		if g.city.tiles[rc] == CG.ROOF and g.city.tiles[rc + 1] == CG.RAILING and g.city.tiles[rc + 2] == CG.AIR and g.city.tiles[rc + 3] == CG.AIR:
			edge = rc
			break
	check.call("found a roof edge with a railing and open air beyond", edge >= 0)
	if edge >= 0:
		g.pc = edge
		g.stamina = 30
		g.stance = g.WALKING
		var hp1: int = g.hp
		check.call("leaping over the railing into the void drops you thirty floors", g.act_jump(1, 0) and g.z_of(g.pc) == 0 and hp1 - g.hp >= 100)
		g.pc = edge
		g.implants["jets"] = true
		g.fuel = 24
		g.stamina = 30
		g.sim.retier(g.pc)
		check.call("with jump jets the same leap ends in flight, still thirty floors up", g.act_jump(1, 0) and g.flying and g.z_of(g.pc) == H)
		var f0: int = g.fuel
		g.act_move(1, 0)
		check.call("flying costs fuel and moves you through open air (%d -> %d)" % [f0, g.fuel], g.flying and g.fuel < f0 and g.z_of(g.pc) == H)
		# fly back in over the railing and touch down on the roof
		g.act_move(-1, 0)
		g.act_move(-1, 0)
		var over_rail: bool = g.flying and g.city.tiles[g.pc] == CG.RAILING
		g.act_move(-1, 0)
		check.call("a flyer hovers over the railing and touches down on the roof", over_rail and not g.flying and g.city.tiles[g.pc] == CG.ROOF and g.z_of(g.pc) == H)
		g.implants.erase("jets")
		g.flying = false

	# ---- leg actuators
	var open: int = _open_cell(g, g.pc if g.z_of(g.pc) == 0 else (g.size / 2) * g.size + g.size / 2, 5)
	check.call("found open ground", open >= 0)
	g.pc = open
	g.sim.retier(g.pc)
	g.stamina = 30
	g.stance = g.WALKING
	g.last_pc = open
	g.act_jump(1, 0)
	check.call("an ordinary jump goes two cells", g.pc == open + 2)
	g.pc = open
	g.implants["legs"] = true
	g.stamina = 30
	g.act_jump(1, 0)
	check.call("leg actuators jump four", g.pc == open + 4)
	g.implants.erase("legs")

	# ---- jump jets from the ground
	g.pc = open
	g.last_pc = open
	g.implants["jets"] = true
	g.fuel = 24
	g.stamina = 30
	check.call("without leaving the ground first, jets lift you through open air", g.act_vertical(1) and g.flying and g.z_of(g.pc) == 1)
	g.act_vertical(1)
	g.act_vertical(1)
	check.call("you can climb three floors", g.z_of(g.pc) == 3 and g.fuel < 24 - 5)
	var xx: int = g.pc % g.size
	g.act_move(1, 0)
	check.call("and fly sideways at that height", g.pc % g.size == xx + 1 and g.z_of(g.pc) == 3)
	g.act_move(-1, 0)
	g.act_vertical(-1)
	g.act_vertical(-1)
	g.act_vertical(-1)
	check.call("descending lands you on the street, no longer flying", g.z_of(g.pc) == 0 and not g.flying and g.sim.walk[g.pc] == 1)
	for _i in 12:
		g.act_wait()
	check.call("jet fuel recharges on the ground", g.fuel >= 20)
	# out of fuel in the air
	g.pc = open + 3 * g.s2
	g.flying = true
	g.fuel = 1
	var hp2: int = g.hp
	g.sim.retier(g.pc)
	g.act_wait()
	check.call("running out of fuel in the air means a fall (hp -%d)" % (hp2 - g.hp), g.z_of(g.pc) == 0 and not g.flying and hp2 - g.hp > 0)
	# a ceiling stops jets
	var ceil_cell := -1
	for y in range(int(tall["y0"]) + 2, int(tall["y1"]) - 2):
		for x in range(int(tall["x0"]) + 2, int(tall["x1"]) - 2):
			var c: int = y * g.size + x
			if g.city.tiles[c] == CG.FLOOR and g.city.haslink[c] == 0 and g.city.tiles[c + g.s2] != CG.AIR and ceil_cell < 0:
				ceil_cell = c
	g.pc = ceil_cell
	g.sim.retier(g.pc)
	var z0: int = g.z_of(g.pc)
	check.call("indoors the ceiling stops the jets", ceil_cell >= 0 and not g.act_vertical(1) and not g.flying and g.z_of(g.pc) == z0)
	g.implants.erase("jets")

	# ---- stairs, with a pursuer
	var stairs: int = tall["stairs"]
	g.pc = stairs
	g.sim.retier(g.pc)
	g.last_pc = stairs
	var hunter := -1
	for k in g.sim.near_list.size():
		var j: int = g.sim.near_list[k]
		if g.sim.alive[j] == 1 and g.fac[j] != g.CIV or hunter < 0 and g.sim.alive[j] == 1:
			hunter = j
			break
	var adj := -1
	for d in g.SIZE_DIRS:
		var c: int = stairs + d[1] * g.size + d[0]
		if g.sim.walk[c] == 1 and g.sim.at[c] == -1 and adj < 0:
			adj = c
	check.call("a hunter and a free square beside the stairs", hunter >= 0 and adj >= 0)
	if hunter >= 0 and adj >= 0:
		g.sim.place(hunter, adj)
		g.fac[hunter] = g.BRATVA
		g.astate[hunter] = g.HUNTING
		g.sim.ctl[hunter] = 1
		var t_before: int = g.turn
		check.call("taking the stairs up works and costs two turns", g.act_vertical(1) and g.z_of(g.pc) == 1 and g.turn - t_before >= 2)
		for _i in 8:
			g.act_wait()
		check.call("the hunter follows you up (now on floor %d, %d tiles away)" % [g.z_of(g.sim.pos[hunter]), g.cheb(g.sim.pos[hunter], g.pc)], g.sim.alive[hunter] == 0 or (g.z_of(g.sim.pos[hunter]) == 1 and g.cheb(g.sim.pos[hunter], g.pc) < 12))
		check.call("and you can go back down the same way", g.act_vertical(-1) and g.z_of(g.pc) == 0)

	# ---- gyro
	var gy := -1
	var roof_gy := 0
	for k in g.vehicles.size():
		if g.veh_kind(k) == "gyro":
			if g.z_of(g.vehicles[k]["cell"]) > 0:
				roof_gy += 1
			elif gy < 0:
				gy = k
	check.call("there is a gyro on the street and gyros on the roofs (%d)" % roof_gy, gy >= 0 and roof_gy >= 1)
	if gy >= 0:
		var gcell: int = g.vehicles[gy]["cell"]
		var stand := -1
		for d in g.SIZE_DIRS:
			var c: int = gcell + d[1] * g.size + d[0]
			if g.sim.walk[c] == 1 and g.sim.at[c] == -1 and g.veh_at[c] == -1 and stand < 0:
				stand = c
		g.pc = stand
		g.sim.retier(g.pc)
		g.in_vehicle = -1
		check.call("you can strap into the gyro", g.act_vehicle() and g.in_gyro())
		check.call("it will not taxi along the ground", not g.act_move(1, 0))
		check.call("[<] lifts it into the air", g.act_vertical(1) and g.vehicles[gy].get("air", false) and g.z_of(g.pc) == 1)
		g.act_vertical(1)
		var gx: int = g.pc % g.size
		var moved := false
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			if g.act_move(d[0], d[1]):
				moved = true
				break
		check.call("it flies through open air at height (moved %s)" % str(moved), moved and g.z_of(g.pc) == 2 and g.vehicles[gy]["cell"] == g.pc)
		# fly back to the column and land
		g.pc = gcell + 2 * g.s2
		g._move_vehicle(gy, g.pc)
		g.act_vertical(-1)
		var landed: bool = g.act_vertical(-1)
		check.call("it can set down where it started", landed and not g.vehicles[gy]["air"] and g.z_of(g.pc) == 0)
		g.act_vertical(1)
		var hp3: int = g.hp
		g.act_vehicle()
		check.call("bailing out in mid-air means a fall (hp -%d)" % (hp3 - g.hp), g.in_vehicle == -1 and g.z_of(g.pc) == 0 and not g.vehicles[gy]["air"])

	# ---- mech
	var mi := -1
	for k in g.vehicles.size():
		if g.veh_kind(k) == "mech" and mi < 0 and g.z_of(g.vehicles[k]["cell"]) == 0:
			mi = k
	check.call("there are mechs on the street", mi >= 0)
	if mi >= 0:
		var mc: int = g.vehicles[mi]["cell"]
		var stand2 := -1
		for d in g.SIZE_DIRS:
			var c: int = mc + d[1] * g.size + d[0]
			if g.sim.walk[c] == 1 and g.sim.at[c] == -1 and g.veh_at[c] == -1 and stand2 < 0:
				stand2 = c
		g.pc = stand2
		g.sim.retier(g.pc)
		g.in_vehicle = -1
		check.call("you can climb into the mech", g.act_vehicle() and g.in_mech())
		var fr0: int = g.vehicles[mi]["hp"]
		var hp4: int = g.hp
		g.player_hurt(50, "Test")
		check.call("armour takes the blow: frame %d -> %d, you lose %d" % [fr0, g.vehicles[mi]["hp"], hp4 - g.hp], g.vehicles[mi]["hp"] == fr0 - 50 and hp4 - g.hp == 10)
		# step over a crate
		var op2: int = _open_cell(g, g.pc, 4)
		g.pc = op2
		g._move_vehicle(mi, op2)
		g.sim.retier(g.pc)
		g.city.tiles[op2 + 1] = CG.CRATE
		g.sim.tiles[op2 + 1] = CG.CRATE
		g.sim.walk[op2 + 1] = 0
		check.call("it walks straight over a crate, crushing it", g.act_move(1, 0) and g.pc == op2 + 1 and g.city.tiles[op2 + 1] == CG.GROUND and g.vehicles[mi]["cell"] == g.pc)
		g.pc = op2
		g._move_vehicle(mi, op2)
		g.stance = g.WALKING
		for q in range(1, 7):
			if g.thing_at[op2 + q] >= 0:
				g._remove_thing(g.thing_at[op2 + q])
			if q >= 2:
				g.city.tiles[op2 + q] = CG.GROUND
				g.sim.tiles[op2 + q] = CG.GROUND
				g.sim.walk[op2 + q] = 1
		check.call("it jumps five cells", g.act_jump(1, 0) and g.pc == op2 + 5 and g.veh_at[g.pc] == mi)
		g.player_hurt(500, "Test")
		check.call("a wrecked mech throws you clear", g.in_vehicle == -1 and g.vehicles[mi]["hp"] <= 0)

	# ---- save / load
	g.implants["jets"] = true
	g.implants["legs"] = true
	g.fuel = 17
	g.pc = open + 2 * g.s2
	g.flying = true
	g.in_vehicle = -1
	var dd: Dictionary = JSON.parse_string(JSON.stringify(g.save_dict()))
	var g2 = GameScript.new(31)
	g2.setup(1200)
	g2.load_dict(dd)
	check.call("save and load keep implants, fuel, flight and special vehicles", g2.has_implant("jets") and g2.has_implant("legs") and g2.fuel == 17 and g2.flying and g2.pc == g.pc
		and g2.vehicles.size() == g.vehicles.size() and g2.veh_kind(mi) == "mech" and g2.vehicles[mi]["hp"] == g.vehicles[mi]["hp"])
	return [st[0], st[1], log]
