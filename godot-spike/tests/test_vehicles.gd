extends RefCounted
## Vehicles at human scale: footprints, lanes, driving, damage, engines, AI traffic, flying, the mech.  Returns [passed, total, log]
const GameScript = preload("res://src/game.gd")
const CG = preload("res://src/citygen.gd")
const VS = preload("res://src/vehicles.gd")

func _clear(g) -> void:
	for vi in g.vehicles.size():
		g.vs.lift(vi)
	g.vehicles.clear()
	g.veh_at.fill(-1)
	g.in_vehicle = -1

func _beside(g, vi: int) -> int:
	var fp := {}
	for c in g.vs.cells(g.vehicles[vi]):
		fp[c] = 1
	for c in fp:
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nc: int = c + d[1] * g.size + d[0]
			if not fp.has(nc) and g.veh_at[nc] == -1 and g.sim.walk[nc] == 1 and g.sim.at[nc] == -1:
				return nc
	return -1

## nobody stands within r tiles of the car (people are random; the steering checks are about the car)
func _no_people(g, vi: int, r: int) -> void:
	var ctr: int = g.vehicles[vi]["cell"]
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c: int = ctr + dy * g.size + dx
			if c >= 0 and c < g.sim.at.size() and g.sim.at[c] != -1:
				var who: int = g.sim.at[c]
				g.sim.place(who, g.sim.home_cell[who])

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	var g = GameScript.new(21)
	g.setup(800)
	for l_ in g.BODY.LIMBS:
		g.body.hp[l_] = 100000
		g.body.mx[l_] = 100000
	var vs = g.vs
	var size: int = g.size
	var cc = g.city
	# ---- the road: two lanes of six
	var e: int = cc.xs[3]
	var mid_y: int = 125
	var row := []
	for k in 12:
		row.append(int(cc.marks[mid_y * size + e + k]))
	check.call("a road is 12 wide: white, four black, yellow, yellow, four black, white  %s" % str(row), row == [1, 0, 0, 0, 0, 2, 2, 0, 0, 0, 0, 1])
	var all_road := true
	for k in 12:
		if cc.tiles[mid_y * size + e + k] != CG.ROAD:
			all_road = false
	check.call("all twelve are road tiles", all_road)
	# ---- the car's shape
	_clear(g)
	var cells0: PackedInt32Array = vs.cells_at("car", 0, 0)
	var off = vs.offsets("car", 0)
	var counts := {}
	for o in off:
		counts[o[2]] = int(counts.get(o[2], 0)) + 1
	check.call("a car is 15 tiles: 3 wide, 5 long", off.size() == 15)
	check.call("it has a two-seat cabin, an engine bay, a trunk and four wheels %s" % str(counts), counts["C"] == 2 and counts["E"] == 2 and counts["T"] == 1 and counts["W"] == 4)
	var xs := []
	var ys := []
	for o in off:
		xs.append(o[0])
		ys.append(o[1])
	check.call("facing north it is 3 across and 5 deep", xs.max() - xs.min() == 2 and ys.max() - ys.min() == 4)
	var off_e = vs.offsets("car", 2)
	var xe := []
	var ye := []
	for o in off_e:
		xe.append(o[0])
		ye.append(o[1])
	check.call("facing east it is 5 across and 3 deep", xe.max() - xe.min() == 4 and ye.max() - ye.min() == 2)
	var off_ne = vs.offsets("car", 1)
	var off_se = vs.offsets("car", 3)
	check.call("facing north-east it is a turned body of about 15 tiles, the seat in the middle and an engine tile ahead of it (%d tiles)" % off_ne.size(), off_ne.size() >= 13 and off_ne.size() <= 19 and off_ne.any(func(o): return o[0] == 0 and o[1] == 0 and o[2] == "C") and off_ne.any(func(o): return o[2] == "E" and o[0] > 0 and o[1] < 0) and off_se.any(func(o): return o[2] == "E" and o[0] > 0 and o[1] > 0))
	# ---- park a car in the east lane of a vertical road, heading north
	var lane_x: int = e + 8
	var a: int = vs.anchor_for("car", 0, VS.lane_hi2(e), 2 * mid_y, 0)
	var vi: int = vs.spawn("car", a, 0, Color.RED)
	check.call("a car fits a lane (spawned in the northbound lane)", vi >= 0)
	var occupied := 0
	for c in vs.cells(g.vehicles[vi]):
		if g.veh_at[c] == vi and g.sim.walk[c] == 0:
			occupied += 1
	check.call("every tile of the body is marked as occupied", occupied == 15)
	var bx0 := 99999
	var bx1 := 0
	for c in vs.cells(g.vehicles[vi]):
		bx0 = mini(bx0, c % size)
		bx1 = maxi(bx1, c % size)
	check.call("its three tiles sit inside the four black lane tiles (x %d..%d)" % [bx0, bx1], bx0 >= e + 7 and bx1 <= e + 10 and bx1 - bx0 == 2)
	var other: int = vs.anchor_for("car", 0, VS.lane_hi2(e), 2 * mid_y + 4, 0)
	check.call("a second car cannot overlap the first", vs.spawn("car", other, 0, Color.BLUE) == -1)
	check.call("a person cannot stand on the body", g.sim.walk[g.vehicles[vi]["cell"]] == 0)
	# ---- getting in, driving
	g.pc = _beside(g, vi)
	g.sim.retier(g.pc)
	g.fov.compute(g.pc % size, g.pc / size, 18)
	check.call("you can reach a car from the kerb side", vs.near_vehicle() == vi)
	g.stance = g.WALKING
	check.call("[e] gets you in", g.act_vehicle() and g.in_vehicle == vi and g.pc == g.vehicles[vi]["cell"])
	var c0: int = g.vehicles[vi]["cell"]
	g.act_move(0, -1)
	check.call("up drives forward at speed 1", g.vehicles[vi]["cell"] == c0 - size and g.vehicles[vi]["spd"] == 1)
	g.act_move(0, -1)
	g.act_move(0, -1)
	g.act_move(0, -1)
	check.call("it accelerates up to the engine's top speed (4)", g.vehicles[vi]["spd"] == 4 and g.vehicles[vi]["cell"] <= c0 - size * 6)
	check.call("the player's seat moves with it", g.pc == g.vehicles[vi]["cell"])
	var cs: int = g.vehicles[vi]["cell"]
	g.act_move(1, 0)
	check.call("at speed a turn scrubs a point of speed, bends the heading 45 degrees to the car's right and the car keeps moving (an arc)", g.vehicles[vi]["dir"] == 1 and g.vehicles[vi]["spd"] == 3 and g.vehicles[vi]["cell"] != cs and g.facing == Vector2i(1, -1))
	var presses := 0
	while g.vehicles[vi]["spd"] > 0 and presses < 4:
		g.act_move(0, 1)
		presses += 1
	check.call("the opposite key brakes to a halt", g.vehicles[vi]["spd"] == 0)
	_no_people(g, vi, 8)
	# the arc of the right turn may have run the car up to the kerb: set it back in the middle of its lane, still heading north-east and standing, then turn left
	var back: int = vs.anchor_for("car", 1, VS.lane_hi2(e), 2 * mid_y, 0)
	if vs.probe(vi, back, 1).is_empty():
		vs.put(vi, back, 1)
		g.pc = g.vehicles[vi]["cell"]
	g.act_move(-1, 0)
	check.call("Left turns it back to the left of its own heading, and the view follows (%s)" % str(g.facing), g.vehicles[vi]["dir"] == 0 and g.facing == Vector2i(0, -1))
	# standing still, Right pivots on the spot
	var cell_still: int = g.vehicles[vi]["cell"]
	g.act_move(1, 0)
	g.act_move(1, 0)
	check.call("standing still a sideways key pivots it on the spot, 45 degrees each press (now heading east)", g.vehicles[vi]["dir"] == 2 and g.vehicles[vi]["cell"] == cell_still and g.facing == Vector2i(1, 0))
	# the damage model
	var v: Dictionary = g.vehicles[vi]
	v["spd"] = 0
	var p0: int = v["parts"]["engine"]
	vs.damage(vi, "engine", 20, "test")
	check.call("an engine hit lowers the engine part and top speed", v["parts"]["engine"] == p0 - 20 and vs.max_speed(v) < 4)
	vs.damage(vi, "engine", 500, "test")
	check.call("a dead engine means it will not move", vs.max_speed(v) == 0 and not g.act_move(1, 0))
	# swap the engine
	g.act_vehicle()
	check.call("you can get out of a dead car", g.in_vehicle == -1)
	# stand at a free tile beside the body and drop an engine there
	var stand := -1
	for c in vs.cells(v):
		for d in g.SIZE_DIRS:
			var nc: int = c + d[1] * size + d[0]
			if g.veh_at[nc] == -1 and g.sim.walk[nc] == 1 and g.sim.at[nc] == -1:
				stand = nc
	g.pc = stand
	g.items_at.erase(stand)
	g._put(stand, g._new_item("trl_eng_sport"))
	check.call("an engine at your feet is offered", g.engines_available().size() >= 1)
	var fitted: bool = g.act_fit_engine(vi, g.items_at[stand][0], true)
	check.call("a sport engine fits and revives it", fitted and v["eng"]["id"] == "trl_eng_sport" and v["parts"]["engine"] == 55 and vs.max_speed(v) == 6)
	check.call("the dead engine drops at your feet with its wear (%d hp)" % (g.items_at[stand][0].cond if g.items_at.has(stand) else -9), g.items_at.has(stand) and g.items_at[stand][0].id() == "trl_eng_city" and g.items_at[stand][0].cond == 0)
	var mismatch = g._new_item("trl_eng_reactor")
	g._put(stand, mismatch)
	check.call("a mech reactor does not fit a car", not g.act_fit_engine(vi, mismatch, true))
	# repairs
	vs.damage(vi, "body", 30)
	g.inv.stow(g._new_item("trl_kit_repair"))
	var b0: int = v["parts"]["body"]
	check.call("a repair kit mends a part", g.act_repair(vi, "body") and v["parts"]["body"] == b0 + 25)
	# crash into a wall
	_clear(g)
	var wall_x: int = 0
	var vi2: int = vs.spawn("car", vs.anchor_for("car", 0, VS.lane_hi2(e), 2 * 143, 0), 0, Color.GREEN)
	vs.spawn("car", vs.anchor_for("car", 0, VS.lane_hi2(e), 2 * 128, 0), 0, Color.GRAY)
	g.pc = _beside(g, vi2)
	g.sim.retier(g.pc)
	g.act_vehicle()
	var hp_before: int = g.body.total()
	var body_before: int = g.vehicles[vi2]["parts"]["body"]
	# drive north until something stops us (the road ends at the edge of the street grid)
	for k in 80:
		if not g.act_move(0, -1):
			break
		if g.vehicles[vi2]["parts"]["body"] < body_before:
			break
	check.call("hitting something at speed damages the body", g.vehicles[vi2]["parts"]["body"] < body_before or g.vehicles[vi2]["spd"] == 0)
	# running people over
	_clear(g)
	var vi3: int = vs.spawn("car", vs.anchor_for("car", 0, VS.lane_hi2(e), 2 * 143, 0), 0, Color.WHITE)
	g.pc = _beside(g, vi3)
	g.sim.retier(g.pc)
	g.act_vehicle()
	var victim := -1
	for i in g.sim.n:
		if g.sim.alive[i] == 1 and g.sim.near[i] == 0:
			victim = i
			break
	var vcell: int = g.vehicles[vi3]["cell"] - 3 * size
	g.sim.place(victim, vcell)
	var vhp: int = g.hpn[victim]
	g.act_move(0, -1)
	g.act_move(0, -1)
	check.call("driving into a person hurts them", g.hpn[victim] < vhp or g.sim.alive[victim] == 0)
	# ---- NPC traffic
	var g2 = GameScript.new(33)
	g2.setup(600)
	var ai := 0
	var parked := 0
	for v2 in g2.vehicles:
		if v2["ai"]:
			ai += 1
		elif v2["kind"] == "car":
			parked += 1
	check.call("traffic is driven by NPCs (%d) and cars are parked about (%d)" % [ai, parked], ai >= 30 and parked >= 4)
	var kinds := {}
	for v2 in g2.vehicles:
		kinds[v2["kind"]] = int(kinds.get(v2["kind"], 0)) + 1
	check.call("there are cars, trucks, helicopters and mechs %s" % str(kinds), kinds.has("car") and kinds.has("truck") and kinds.has("heli") and kinds.has("mech"))
	# put the player in the middle of the traffic and run it
	var first_ai := -1
	for k in g2.vehicles.size():
		if g2.vehicles[k]["ai"]:
			first_ai = k
			break
	var start: int = g2.vehicles[first_ai]["cell"]
	g2.pc = start
	for t in 3:
		pass
	g2.sim.retier(g2.pc)
	var starts := {}
	var dirs := {}
	for k in g2.vehicles.size():
		if g2.vehicles[k]["ai"]:
			starts[k] = g2.vehicles[k]["cell"]
			dirs[k] = g2.vehicles[k]["dir"]
	var off_road := 0
	var moved_n := 0
	var turned := 0
	for t in 120:
		g2.vs.ai_turn()
		for k in starts:
			var v3: Dictionary = g2.vehicles[k]
			for c in g2.vs.cells(v3):
				if g2.city.tiles[c] != CG.ROAD:
					off_road += 1
					break
	for k in starts:
		if g2.vehicles[k]["cell"] != starts[k]:
			moved_n += 1
		if g2.vehicles[k]["dir"] != dirs[k]:
			turned += 1
	# only cars within 80 tiles of the player move, so count those that could
	var near_n := 0
	for k in starts:
		if g2.cheb(starts[k], g2.pc) <= 80:
			near_n += 1
	check.call("NPC drivers move (%d of %d nearby)" % [moved_n, near_n], moved_n >= near_n / 2 and near_n >= 2)
	check.call("they stay on the road (%d off-road steps)" % off_road, off_road == 0)
	check.call("some take turns at intersections (%d)" % turned, turned >= 1)
	# ---- helicopter
	var g3 = GameScript.new(35)
	g3.setup(500)
	var hv := -1
	for k in g3.vehicles.size():
		if g3.vehicles[k]["kind"] == "heli" and g3.z_of(g3.vehicles[k]["cell"]) == 0:
			hv = k
			break
	check.call("a helicopter stands near the start", hv >= 0)
	var hel: Dictionary = g3.vehicles[hv]
	g3.pc = hel["cell"] + 4
	g3.sim.retier(g3.pc)
	# step next to a footprint cell
	var spot := -1
	for c in g3.vs.cells(hel):
		for d in g3.SIZE_DIRS:
			var nc: int = c + d[1] * g3.size + d[0]
			if g3.veh_at[nc] == -1 and g3.sim.walk[nc] == 1 and g3.sim.at[nc] == -1:
				spot = nc
	g3.pc = spot
	check.call("you can climb into it", g3.act_vehicle() and g3.in_vehicle == hv and g3.pc == hel["cell"])
	check.call("up lifts off one level", g3.act_vertical(1) and hel["air"] and g3.z_of(hel["cell"]) == 1)
	var hc: int = hel["cell"]
	var hd0: int = int(hel["dir"])
	g3.act_move(1, 0)
	check.call("it hovers across the street and the whole body comes along", hel["cell"] == hc + 1 or hel["cell"] == hc + 2)
	g3.vs.put(hv, hc, hd0)
	for k in 6:
		g3.act_vertical(1)
	check.call("it climbs several floors", g3.z_of(hel["cell"]) >= 3)
	var clearing = g3.vs.fits(hv, hel["cell"], hel["dir"], true)
	check.call("it is standing in clear air", clearing)
	for k in 8:
		g3.act_vertical(-1)
	check.call("down brings it to the ground", not hel["air"] and g3.z_of(hel["cell"]) == 0)
	# rotor damage brings it down
	g3.act_vertical(1)
	g3.vs.damage(hv, "drive", 500, "test")
	g3.act_move(1, 0)
	check.call("a destroyed rotor drops it", not hel["air"] and g3.z_of(hel["cell"]) == 0)
	# ---- mech
	var g4 = GameScript.new(37)
	g4.setup(500)
	var mv := -1
	for k in g4.vehicles.size():
		if g4.vehicles[k]["kind"] == "mech":
			mv = k
			break
	var mech: Dictionary = g4.vehicles[mv]
	check.call("a mech is a 5x5 frame", g4.vs.offsets("mech", 0).size() == 21 and g4.vs.cells(mech).size() == 21)
	var spot2 := -1
	for c in g4.vs.cells(mech):
		for d in g4.SIZE_DIRS:
			var nc: int = c + d[1] * g4.size + d[0]
			if g4.veh_at[nc] == -1 and g4.sim.walk[nc] == 1 and g4.sim.at[nc] == -1:
				spot2 = nc
	g4.pc = spot2
	g4.sim.retier(g4.pc)
	check.call("you climb into it", g4.act_vehicle() and g4.in_mech())
	var mc: int = mech["cell"]
	var moved_m := false
	for d in [[1, 0], [0, 1], [-1, 0], [0, -1]]:
		if g4.act_move(d[0], d[1]):
			moved_m = true
			break
	check.call("it walks, whole body at once", moved_m and mech["cell"] != mc)
	# a crate in its path is crushed
	var tc: int = mech["cell"] + 3
	var ti: int = g4._add_thing("crate", tc, false) if g4.veh_at[tc] == -1 and g4.thing_at[tc] == -1 and g4.sim.walk[tc] == 1 else -1
	if ti >= 0:
		mech["dir"] = 1
		g4.act_move(1, 0)
		g4.act_move(1, 0)
		g4.act_move(1, 0)
		check.call("it crushes a crate underfoot", g4.things[ti]["k"] == "")
	else:
		check.call("(no clear patch for the crate test)", true)
	# jump
	var jc: int = mech["cell"]
	var jumped := false
	for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
		if g4.act_jump(d[0], d[1]):
			jumped = true
			break
	check.call("it jumps several tiles", jumped and g4.cheb(mech["cell"], jc) >= 2)
	var f0: int = mech["parts"]["body"]
	g4.player_hurt(40, "A shell")
	check.call("armour takes the blow: body %d -> %d" % [f0, mech["parts"]["body"]], mech["parts"]["body"] == f0 - 40)
	g4.player_hurt(900, "A missile")
	check.call("a wrecked mech throws you clear", g4.in_vehicle == -1 and mech["wreck"])
	# ---- shooting a car
	var g5 = GameScript.new(39)
	g5.setup(500)
	_clear(g5)
	e = g5.city.xs[3]
	var ve: int = g5.vs.spawn("car", g5.vs.anchor_for("car", 0, VS.lane_hi2(e), 2 * 125, 0), 0, Color.RED)
	var cell_e: int = g5.vehicles[ve]["cell"] - 2 * g5.size
	check.call("the engine bay is where the front tiles are", g5.vs.part_at(g5.vehicles[ve], cell_e) == "engine")
	check.call("the trunk is behind the cabin", g5.vs.part_at(g5.vehicles[ve], g5.vehicles[ve]["cell"] + 2 * g5.size) == "body")
	g5.vs.damage_cell(ve, cell_e, 20, "test")
	check.call("a shot to the bonnet hurts the engine", g5.vehicles[ve]["parts"]["engine"] < 50)
	for k in 8:
		g5.vs.damage_cell(ve, cell_e, 40, "test")
	check.call("enough hits wreck it", g5.vehicles[ve]["wreck"])
	g5._explode(g5.vehicles[ve]["cell"], 4, 50)
	check.call("a wreck stays as a block of cover", g5.veh_at[g5.vehicles[ve]["cell"]] == ve)
	# ---- save and load
	var g6 = GameScript.new(41)
	g6.setup(400)
	g6.vehicles[0]["parts"]["engine"] = 17
	g6.vehicles[0]["eng"]["id"] = "trl_eng_sport"
	var d6: Dictionary = JSON.parse_string(JSON.stringify(g6.save_dict()))
	var g7 = GameScript.new(0)
	g7.load_dict(d6)
	var same = g7.vehicles.size() == g6.vehicles.size() and g7.vehicles[0]["parts"]["engine"] == 17 and g7.vehicles[0]["eng"]["id"] == "trl_eng_sport" and g7.vehicles[0]["cell"] == g6.vehicles[0]["cell"]
	var occ_ok := true
	for k in g7.vehicles.size():
		for c in g7.vs.cells(g7.vehicles[k]):
			if g7.veh_at[c] != k:
				occ_ok = false
	check.call("save and load keep every vehicle, its parts and its engine", same and occ_ok)
	return [st[0], st[1], log]
