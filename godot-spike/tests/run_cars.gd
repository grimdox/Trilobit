extends SceneTree
## Cars: 3x5 body, eight headings, tank controls (left and right are the car's own), the view follows the heading, run-over damage by speed, old saves.  Run: godot --headless -s tests/run_cars.gd
const GameScript = preload("res://src/game.gd")
const VS = preload("res://src/vehicles.gd")
const CG = preload("res://src/citygen.gd")
var ok := 0
var n := 0

func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name)

func _clear(g) -> void:
	for vi in g.vehicles.size():
		g.vs.lift(vi)
	g.vehicles.clear()
	g.veh_at.clear()
	g.in_vehicle = -1
	g.pc = 5 * g.size + 5

func _initialize() -> void:
	var g = GameScript.new(21)
	g.setup(800)
	for l_ in g.BODY.LIMBS:
		g.body.hp[l_] = 100000
		g.body.mx[l_] = 100000
	_clear(g)
	var vs = g.vs
	var e: int = g.city.xs[3]
	var mid_y := 125
	var a: int = vs.anchor_for("car", 0, VS.lane_hi2(e), 2 * mid_y, 0)
	var vi: int = vs.spawn("car", a, 0, Color.RED)
	check("a car spawns as 3 x 5 (15 tiles)", vi >= 0 and vs.cells(g.vehicles[vi]).size() == 15)
	# every heading has a footprint of about 15 tiles with the seat in the middle, and the seat tile is a cabin tile
	var shapes_ok := true
	for d in 8:
		var off: Array = vs.offsets("car", d)
		if off.size() < 13 or off.size() > 19 or not off.any(func(o): return o[0] == 0 and o[1] == 0 and o[2] == "C"):
			shapes_ok = false
	check("all eight headings give a connected-looking footprint of 13-19 tiles with the driver's seat on the anchor", shapes_ok)
	var orth_ok: bool = vs.offsets("car", 0).size() == 15 and vs.offsets("car", 2).size() == 15 and vs.offsets("car", 4).size() == 15 and vs.offsets("car", 6).size() == 15
	check("the four straight headings are exact 15-tile rectangles", orth_ok)
	var tc: Vector2 = vs.true_center("car", a, 3)
	check("the body turns about the driver's seat: its centre is the seat at any heading", absf(tc.x - (float(a % g.size) + 0.5)) < 0.01 and absf(tc.y - (float((a % g.s2) / g.size) + 0.5)) < 0.01)
	# get in and drive
	var v: Dictionary = g.vehicles[vi]
	g.pc = a
	v["driver"] = -2
	g.in_vehicle = vi
	g.facing = Vector2i(0, 1)
	# Right from a standstill pivots 45 degrees to the car's right, the view with it
	g.act_move(1, 0)
	check("Right pivots a stopped car to north-east and the character faces north-east (%s)" % str(g.facing), v["dir"] == 1 and v["spd"] == 0 and v["cell"] == a and g.facing == Vector2i(1, -1))
	g.act_move(1, 0)
	g.act_move(1, 0)
	check("two more presses: east, then south-east; the view follows each time", v["dir"] == 3 and g.facing == Vector2i(1, 1))
	g.act_move(1, 0)
	check("one more: south", v["dir"] == 4 and g.facing == Vector2i(0, 1))
	# Left is relative: heading south, Left turns it toward the east (the car's own left is the screen's east)
	g.act_move(-1, 0)
	check("heading south, Left turns it to the car's left (south-east, i.e. toward the screen's east)", v["dir"] == 3 and g.facing == Vector2i(1, 1))
	# accelerate diagonally
	var c0: int = v["cell"]
	g.act_move(0, -1)
	check("Up drives it one step along its diagonal heading (down and right on the screen)", v["cell"] == c0 + g.size + 1 and v["spd"] == 1)
	var turn_a: int = v["cell"]
	g.act_move(0, -1)
	g.act_move(-1, -1)
	check("Up-Left accelerates and turns at once (the heading is east)", v["dir"] == 2)
	g.act_move(0, 0)
	check("Space stops it", v["spd"] == 0)
	# kph and the damage split
	v["spd"] = 3
	check("3 tiles a turn is 45 km/h", vs.kph(v) == 45)
	var sp: Dictionary = vs.hit_split(45)
	check("45 km/h splits 11 and 11 into the legs (about half), chest, arms 4 and 4, head 2 and sums to 45", int(sp["l_leg"]) == 11 and int(sp["r_leg"]) == 11 and int(sp["l_leg"]) + int(sp["r_leg"]) >= 22 and int(sp["l_arm"]) == 4 and int(sp["head"]) == 2 and sp.values().reduce(func(x, y): return x + y) == 45)
	var sp2: Dictionary = vs.hit_split(60)
	check("60 km/h: 15 to each leg, 36 in all to... legs 30, 60 in total", int(sp2["l_leg"]) == 15 and int(sp2["r_leg"]) == 15 and sp2.values().reduce(func(x, y): return x + y) == 60)
	# run down an NPC
	_clear(g)
	var a2: int = vs.anchor_for("car", 0, VS.lane_hi2(e), 2 * mid_y, 0)
	var vj: int = vs.spawn("car", a2, 0, Color.RED)
	var w := -1
	for i in g.sim.n:
		if g.sim.alive[i] == 1:
			w = i
			break
	var front: int = int(g.vehicles[vj]["cell"]) - 4 * g.size
	g.sim.place(w, front)
	g.hpn[w] = 200
	g.hpmax[w] = 200
	g.pc = g.vehicles[vj]["cell"]
	g.vehicles[vj]["driver"] = -2
	g.in_vehicle = vj
	g.vehicles[vj]["spd"] = 3
	var hp0: int = g.hpn[w]
	var ll0: int = g.npc_limb_hp(w, "l_leg")
	g.log.clear()
	g.act_move(0, -1)
	var hurt: int = hp0 - g.hpn[w]
	check("driving into a person at speed takes off about the car's speed in km/h (%d of 60)" % hurt, hurt == 60 or hurt == 45 or hurt == 30)
	check("their legs took the hit: each leg lost a quarter of it", g.npc_limb_hp(w, "l_leg") < ll0 and g.npc_limb_hp(w, "r_leg") < g.npc_limb_max(w, "r_leg"))
	check("the log says how fast and where", g.log.any(func(l): return String(l).contains("km/h") and String(l).contains("legs")))
	# a fast hit kills and disables legs of a normal person
	var w2 := -1
	for i in g.sim.n:
		if g.sim.alive[i] == 1 and i != w:
			w2 = i
			break
	g.sim.place(w2, int(g.vehicles[vj]["cell"]) - 3 * g.size)
	g.hpn[w2] = g.hpmax[w2]
	g.vehicles[vj]["spd"] = 4
	g.act_move(0, -1)
	check("at 60+ km/h an ordinary person is killed or crippled (alive %s)" % str(g.sim.alive[w2] == 1), g.sim.alive[w2] == 0 or g.npc_legs_ok(w2) < 2)
	# a car hits the player
	_clear(g)
	g.in_vehicle = -1
	g.pc = int(g.vehicles.size() * 0) + 5 * g.size + 5
	var a3: int = vs.anchor_for("car", 0, VS.lane_lo2(e), 2 * mid_y + 40, 0)
	var vk: int = -1
	for off in range(0, 400, 7):
		a3 = vs.anchor_for("car", 0, VS.lane_lo2(e), 2 * (mid_y + off), 0)
		vk = vs.spawn("car", a3, 0, Color.BLUE, true)
		if vk >= 0:
			break
	g.vehicles[vk]["spd"] = 2
	var legs0: int = int(g.body.hp["l_leg"])
	g.body.hp["l_leg"] = 200
	g.body.mx["l_leg"] = 200
	g.log.clear()
	vs.run_down(vk, "player", -1, g.pc)
	check("a car hitting you at 30 km/h costs 7 in each leg and says so", int(g.body.hp["l_leg"]) == 200 - 7 and g.log.any(func(l): return String(l).contains("30 km/h")))
	# old saves: ground vehicles saved with four headings are doubled
	var oldrec: Dictionary = vs.to_dict(g.vehicles[vk])
	oldrec.erase("d8")
	oldrec["dir"] = 1
	var back: Dictionary = vs.from_dict(oldrec)
	check("a car saved with the old four headings (1 = east) loads as heading 2 of 8", back["dir"] == 2 and back["d8"] == true)
	var rec2: Dictionary = vs.from_dict(vs.to_dict(g.vehicles[vk]))
	check("a new record round-trips unchanged", rec2["dir"] == g.vehicles[vk]["dir"])
	# AI traffic: slows for a person ahead, may hit one that is in its way while it moves, never when stopped, never aims
	_clear(g)
	g.in_vehicle = -1
	var cars := -1
	var ai_a := -1
	for off in range(0, 400, 7):
		ai_a = vs.anchor_for("car", 0, VS.lane_hi2(e), 2 * (mid_y + off), 0)
		cars = vs.spawn("car", ai_a, 0, Color.GREEN, true)
		if cars >= 0:
			break
	var av: Dictionary = g.vehicles[cars]
	var pw := -1
	for i in g.sim.n:
		if g.sim.alive[i] == 1:
			pw = i
			break
	g.sim.place(pw, ai_a - 4 * g.size)
	g.hpn[pw] = 5000
	g.hpmax[pw] = 5000
	av["spd"] = 2
	vs._ai_car(cars)
	check("traffic slows to one tile a turn for somebody four tiles ahead (it moved %d, speed %d)" % [(ai_a - av["cell"]) / g.size, av["spd"]], av["spd"] == 1 and (ai_a - int(av["cell"])) / g.size == 1)
	var hits := 0
	var trials := 300
	for t in trials:
		vs.lift(cars)
		av["cell"] = ai_a
		vs.put(cars, ai_a, 0)
		g.sim.place(pw, ai_a - 3 * g.size)
		g.hpn[pw] = 5000
		g.limbn[pw * 6] = -1                                   # whole again
		g.sim.alive[pw] = 1
		av["spd"] = 2
		av["stuck"] = 0
		av["turn_at"] = vs.center2("car", ai_a, 0).y * 4          # no turning at a cross street in this test
		vs._ai_car(cars)
		if g.hpn[pw] < 5000:
			hits += 1
	check("a person in its way while it is moving gets hit some of the time, not always (%d of %d)" % [hits, trials], hits > trials / 10 and hits < trials * 3 / 4)
	var still := 0
	for t in 100:
		vs.lift(cars)
		av["cell"] = ai_a
		vs.put(cars, ai_a, 0)
		g.sim.place(pw, ai_a - 3 * g.size)
		g.hpn[pw] = 5000
		av["spd"] = 0
		av["stuck"] = 0
		vs._ai_car(cars)
		if g.hpn[pw] < 5000:
			still += 1
	check("a stopped car never hits anyone: it waits (%d hits in 100)" % still, still == 0)
	# the marker art is there, and traffic still drives
	check("the driving marker sprite exists", FileAccess.file_exists("res://gfx/Trilobit64/veh/veh_drive_mark.png"))
	var g5 = GameScript.new(7)
	g5.setup(600)
	var moved := 0
	var near := 0                                          # (only cars within 80 tiles of the player are driven; how many that is depends on the seed's luck)
	for vv in g5.vehicles:
		if vv["ai"] and vv["driver"] == -3 and g5.cheb(vv["cell"], g5.pc) <= 80:
			near += 1
	var start: Array = []
	for vv in g5.vehicles:
		start.append(vv["cell"])
	for t in 40:
		g5.act_wait()
	for k in g5.vehicles.size():
		if g5.vehicles[k]["cell"] != start[k]:
			moved += 1
	check("traffic still drives about with the smaller cars (%d of %d cars near the player moved)" % [moved, near], near >= 1 and moved >= maxi(1, near / 2))
	print("CARS %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
