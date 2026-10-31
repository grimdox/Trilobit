extends SceneTree
## Lamps, neon, window light, looking, mission-site lights, cover and moving rules, manual targeting, the holster belt.
## Run: TRL_STREET=1 godot --headless --path . -s tests/run_lightsb.gd   (the light rules must be on: do not set TRL_NOLIGHT)
const GameScript = preload("res://src/game.gd")
const CLK = preload("res://src/clock.gd")
const LT = preload("res://src/lighting.gd")
const LM = preload("res://src/lightmap.gd")
const CG = preload("res://src/citygen.gd")
const TJ = preload("res://src/temp_jobs.gd")
const MS = preload("res://src/missions.gd")
var ok := 0
var n := 0
func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name)
func tk(h: int, m: int) -> int:
	return h * CLK.HOUR + m * CLK.MIN

func _initialize() -> void:
	GameScript.light_rules = true
	GameScript.street_start = true
	var g = GameScript.new(7)
	g.setup(300)
	var lm = g.light
	var size: int = g.size
	# ---- street lamps on a ten-tile lattice, out from 08:00
	var lamp := -1
	var lamps_on_x := true
	var seen_lamps := 0
	g.sim.tick = tk(23, 0)
	lm.invalidate()
	for by in range(8, 14):
		for bx in range(8, 14):
			for L in lm._block(bx, by):
				if bool(L[5]) and L[4] == LT.STREET:
					seen_lamps += 1
					if int(L[0]) % 10 != 0 and int(L[1]) % 10 != 0:
						lamps_on_x = false
					if lamp < 0:
						lamp = int(L[1]) * size + int(L[0])
	check("street lamps stand on the ten-tile lattice (%d found)" % seen_lamps, seen_lamps > 5 and lamps_on_x)
	check("a lamp lights its own tile at night", lamp >= 0 and lm.level(lamp) == LT.LIT)
	g.sim.tick = tk(12, 0)
	lm.invalidate()
	check("and is off by day (no lamp colour on the ground)", lm.colour(lamp) == LT.DAYLIGHT)
	g.sim.tick = tk(7, 45)
	lm.invalidate()
	check("lamps are still on at sunrise (before 8am)", lm.colour(lamp) == LT.STREET or lm.colour(lamp) != LT.DAYLIGHT)
	g.sim.tick = tk(8, 1)
	lm.invalidate()
	check("and off by 8am", lm.colour(lamp) == LT.DAYLIGHT)
	# ---- neon radius
	check("neon lights two tiles and dimly four", LM.NEON_LIT == 2.0 and LM.NEON_DIM == 4.0)
	# ---- window light spills out
	var win_nb := -1
	g.sim.tick = tk(23, 0)
	lm.invalidate()
	for by in range(6, 16):
		for bx in range(6, 16):
			for L in lm._block(bx, by):
				if bool(L[5]) and L[4] == LT.WARM_WHITE and g.city.tiles[int(L[1]) * size + int(L[0])] == CG.GLASS:
					for d in [1, -1, size, -size]:
						var nb: int = int(L[1]) * size + int(L[0]) + d
						if win_nb < 0 and lm.open_air(nb):
							win_nb = nb
	check("light comes out of a window onto the street at night", win_nb >= 0 and lm.level(win_nb) >= LT.DIM)
	# ---- looking says dark, dim or lit
	var txt: String = g.describe_at(g.pc)
	check("looking names the light (%s)" % txt, txt.contains(", lit") or txt.contains(", dim") or txt.contains(", dark"))
	# ---- enemy look text
	var i := 0
	g.limbn[i * 6] = -1
	var t0: String = g.npc_look_text(i)
	check("an unhurt person shows no damage and 100%% (%s)" % t0, t0.contains("none") and t0.contains("head ~100%") and t0.contains("chest ~100%"))
	g.npc_limb_hit(i, "chest", 7)
	g.npc_limb_hit(i, "head", 1)
	var t1: String = g.npc_look_text(i)
	check("after wounds it lists the damage by part and estimates head and chest (%s)" % t1, t1.contains("chest -7") and t1.contains("head -1") and t1.contains("%"))
	# ---- cover / moving / jam
	var tgt: int = g.pc + 5
	var saved: int = g.city.tiles[tgt + 1]
	g.city.tiles[tgt + 1] = CG.WALL
	check("a wall beside the target gives cover from two tiles off", g.cover_vs(tgt + 2, tgt, false) > 0)
	check("but none from an adjacent shooter", g.cover_vs(tgt + 1, tgt, false) == 0)
	g.city.tiles[tgt + 1] = saved
	var pistol = null
	for k in g.db.defs:
		if "pistol" in g.db.defs[k].get("tags", []) and "gun" in g.db.defs[k].get("tags", []):
			pistol = g._new_item(k)
			break
	check("moving no longer costs accuracy", not FileAccess.get_file_as_string("res://src/game.gd").contains("aimed, moved, crouch") and not FileAccess.get_file_as_string("res://src/game.gd").contains("aim_turns, moved, crouch"))
	check("firing never jams the gun", not FileAccess.get_file_as_string("res://src/game.gd").contains('float(st["jam"]) * float(shots)'))
	# ---- holster belt
	var belt = g._new_item("trl_holster_belt")
	check("the holster belt exists and is a belt pocket", belt != null and belt.def.has("holster") and belt.def["pocket"]["slot"] == "belt")
	g.inv.stow(belt)
	g.act_wear(belt)
	var p1 = g._new_item(pistol.def["id"])
	var p2 = g._new_item(pistol.def["id"])
	var p3 = g._new_item(pistol.def["id"])
	g.inv.stow(p1)
	g.act_wield(p1)
	check("the belt is worn and has tiles", g.inv.equip.has("belt") and (g.inv.grid.has("belt")))
	(g.inv.grid["belt"] as Array)[0] = p2
	var turn0: int = g.turn
	g.act_wield(p2)
	check("a weapon drawn from the holster belt costs no time and the old one takes its place", g.turn == turn0 and g.wield == p2 and (g.inv.grid["belt"] as Array)[0] == p1)
	g.inv.stow(p3)
	var turn1: int = g.turn
	g.act_wield(p3)
	check("wielding from the pack takes a full turn", g.turn > turn1 and g.wield == p3)
	# ---- a mission site: lights, indoors, bulbs, manual targeting
	var o2: Dictionary = TJ.offers(5, 7, 1)[0]
	var ng = GameScript.new(int(o2["seed"]))
	ng.setup(0, null, Vector2i(-1, -1), MS.new_state(o2))
	var sl = ng.light
	var site: Dictionary = ng.city.get_meta("site")
	ng.sim.tick = tk(12, 0)
	sl.invalidate()
	var r0: Array = site["rooms"][0]
	var rc0: int = (int(r0[1]) + int(r0[3]) / 2) * ng.size + int(r0[0]) + int(r0[2]) / 2
	check("inside a mission room the rain does not fall and daylight does not reach", sl.indoor(rc0) and not sl.open_air(rc0))
	var lights: Array = sl.site_lights()
	var rooms_lit := {}
	check("the site has lights (%d)" % lights.size(), lights.size() >= 2)
	var dark_rooms := 0
	var all_rooms := 0
	for sd in [1, 2, 3, 4, 5, 6]:
		var og: Dictionary = TJ.offers(sd, 9, sd)[0]
		var gx = GameScript.new(int(og["seed"]))
		gx.setup(0, null, Vector2i(-1, -1), MS.new_state(og))
		var sx: Dictionary = gx.city.get_meta("site")
		gx.light.site_lights()
		var covered := {}
		for L in gx.light.site_lights():
			var lc: int = int(L[0])
			for ri in (sx["rooms"] as Array).size():
				var r: Array = sx["rooms"][ri]
				var lx: int = lc % gx.size
				var ly: int = lc / gx.size
				if lx >= int(r[0]) - 1 and lx <= int(r[0]) + int(r[2]) and ly >= int(r[1]) - 1 and ly <= int(r[1]) + int(r[3]):
					covered[ri] = true
		all_rooms += (sx["rooms"] as Array).size()
		dark_rooms += (sx["rooms"] as Array).size() - covered.size()
	check("some rooms have no light at all (%d of %d)" % [dark_rooms, all_rooms], dark_rooms > 0 and dark_rooms < all_rooms)
	var bulb := -1
	for L in lights:
		if String(L[1]) == "bulb":
			bulb = int(L[0])
			break
	if bulb < 0:
		for sd in range(10, 40):
			var og2: Dictionary = TJ.offers(sd, 9, sd)[0]
			ng = GameScript.new(int(og2["seed"]))
			ng.setup(0, null, Vector2i(-1, -1), MS.new_state(og2))
			sl = ng.light
			for L in sl.site_lights():
				if String(L[1]) == "bulb":
					bulb = int(L[0])
					break
			if bulb >= 0:
				break
	check("there are wall bulbs in a site", bulb >= 0)
	if bulb >= 0:
		var sz: int = ng.size
		var stand := -1
		for d in [1, -1, sz, -sz]:
			if ng.city.walkable(ng.city.tiles[bulb + d]):
				stand = bulb + d
		ng.pc = stand if stand >= 0 else ng.pc
		ng.fov.visible[bulb] = 1
		var gun = ng._new_item(pistol.def["id"])
		ng.inv.stow(gun)
		ng.act_wield(gun)
		gun.loaded = 12
		check("a bulb can be picked by hand", ng.act_manual_target(bulb) and ng.shoot_cell == bulb)
		var ap0: int = ng.aim_turns
		ng.shoot_cell = bulb
		var aimed_ok: bool = ng.act_aim()
		for _k in 4:
			ng.act_aim()
		check("aiming works on a hand-picked light (aim %d)" % ng.aim_turns, aimed_ok and ng.aim_turns > ap0 and ng.shoot_cell == bulb)
		var broke := false
		for k in 12:
			ng.shoot_cell = bulb
			ng.fov.visible[bulb] = 1
			ng.act_fire()
			if not ng.light.bulb_at(bulb):
				broke = true
				break
		check("a shot breaks the bulb and the light goes out", broke and ng.dead_lights.has(bulb))
	# ---- headlights: eight tiles ahead of a driven car, nothing behind
	g.sim.tick = tk(23, 30)
	lm.invalidate()
	var vk := -1
	var found_cell := -1
	for c in range(g.size * 200, g.size * (g.size - 200), 3):
		if g.city.tiles[c] == CG.ROAD and g.city.tiles[c + 12] == CG.ROAD and g.city.tiles[c - 12] == CG.ROAD:
			vk = g.vs.spawn("car", c, 2, Color.RED, true)
			if vk >= 0:
				found_cell = c
				break
	check("a car could be placed on a road", vk >= 0)
	if vk >= 0:
		var v: Dictionary = g.vehicles[vk]
		var cells: PackedInt32Array = g.vs.cells(v)
		var maxx := -1
		var ymid := 0
		for cc in cells:
			if cc % g.size > maxx:
				maxx = cc % g.size
		var rowy: int = (found_cell / g.size)
		var ahead3: int = rowy * g.size + maxx + 3
		var ahead7: int = rowy * g.size + maxx + 7
		var ahead10: int = rowy * g.size + maxx + 11
		var behind: int = rowy * g.size + (maxx - 6)
		lm.invalidate()
		g.sim.tick += 1
		g.pc = found_cell + 30
		var l3: int = lm.level(ahead3)
		var l7: int = lm.level(ahead7)
		var l11: int = lm.level(ahead10)
		var lb: int = lm.level(behind)
		check("a driven car lights the road ahead: lit at 3 (%d), dim at 7 (%d), nothing past 8 (%d)" % [l3, l7, l11], l3 == LT.LIT and l7 >= LT.DIM and l11 <= LT.DIM and l7 <= LT.LIT)
		g.vehicles[vk]["driver"] = -1
		g.sim.tick += 1
		check("a parked car has its lights off", lm.level(ahead3) < LT.LIT or lm.level(ahead3) == lm._info(ahead3)[0])
	print("LIGHTSB %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
