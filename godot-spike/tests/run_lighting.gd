extends SceneTree
## day and night, three light levels, the rules of sight, weather:  godot --headless -s tests/run_lighting.gd
const GameScript = preload("res://src/game.gd")
const CLK = preload("res://src/clock.gd")
const LT = preload("res://src/lighting.gd")
const WX = preload("res://src/weather.gd")
const CG = preload("res://src/citygen.gd")
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
	# ---- the sun
	check("night until 07:30, then 30 minutes of sunrise (dim), full day from 08:00",
		CLK.ambient_level(tk(7, 29)) == CLK.DARK and CLK.ambient_level(tk(7, 30)) == CLK.DIM and CLK.ambient_level(tk(7, 59)) == CLK.DIM and CLK.ambient_level(tk(8, 0)) == CLK.LIT)
	check("day until 18:00, then 30 minutes of sunset (dim), night from 18:30",
		CLK.ambient_level(tk(17, 59)) == CLK.LIT and CLK.ambient_level(tk(18, 0)) == CLK.DIM and CLK.ambient_level(tk(18, 29)) == CLK.DIM and CLK.ambient_level(tk(18, 30)) == CLK.DARK)
	check("the phase names agree (%s %s %s %s)" % [CLK.phase(tk(7, 40)), CLK.phase(tk(12, 0)), CLK.phase(tk(18, 10)), CLK.phase(tk(23, 0))],
		CLK.phase(tk(7, 40)) == "Sunrise" and CLK.phase(tk(12, 0)) == "Day" and CLK.phase(tk(18, 10)) == "Sunset" and CLK.phase(tk(23, 0)) == "Night")
	check("it is the same every day", CLK.ambient_level(tk(12, 0) + 5 * CLK.DAY) == CLK.LIT and CLK.ambient_level(tk(3, 0) + 9 * CLK.DAY) == CLK.DARK)
	# ---- weather: rain 60% of the time, nothing else
	var wet := 0
	var kinds := {}
	var hours := 3000
	for h in hours:
		var w: Dictionary = WX.at(77, h * CLK.HOUR + 5)
		kinds[w["kind"]] = true
		if float(w["rain"]) > 0.0:
			wet += 1
	var share: float = 100.0 * float(wet) / float(hours)
	check("it rains about 60%% of the time (%.1f%% of %d hours), and the weather is only Rain or Clear (%s)" % [share, hours, str(kinds.keys())], share > 56.0 and share < 64.0 and kinds.size() == 2 and kinds.has("Rain") and kinds.has("Clear"))
	check("it is the same weather within an hour and from one call to the next", WX.at(77, 700)["kind"] == WX.at(77, 1100)["kind"] and WX.at(77, 1000) == WX.at(77, 1000))
	check("rain does not change the sunlight (an overlay for now)", WX.sun_factor(WX.at(77, 0)) == 1.0 and not WX.flash(77, 0, WX.at(77, 0)))
	# ---- the map
	var g = GameScript.new(7)
	g.setup(300)
	var lm = g.light
	check("the game has a light map with the rules on", lm != null and lm.enabled)
	var size: int = g.size
	# find an open ground tile far from any street lamp or sign, and a floor tile inside a building
	var open_far := -1
	var inside := -1
	g.sim.tick = tk(23, 0)
	lm.invalidate()
	var tally := [0, 0, 0]
	for c in range(size * 100, size * (size - 100), 37):
		if c % size < 60 or c % size > size - 60:
			continue
		var t: int = g.city.tiles[c]
		if (t == CG.GROUND or t == CG.ROAD or t == CG.PARK):
			var lv: int = lm.level(c)
			tally[lv] += 1
			if open_far < 0 and lv == LT.DARK and t == CG.GROUND:
				open_far = c
		if t == CG.FLOOR and inside < 0 and lm.indoor(c):
			inside = c
	var tot: float = float(tally[0] + tally[1] + tally[2])
	check("at night the open ground is a mix of dark, dim and lit (%.0f%% dark, %.0f%% dim, %.0f%% lit)" % [100.0 * tally[0] / tot, 100.0 * tally[1] / tot, 100.0 * tally[2] / tot], tally[0] / tot > 0.25 and tally[1] > 0 and tally[2] > 0)
	g.sim.tick = tk(12, 0)
	lm.invalidate()
	var day_lvl: int = lm.level(open_far)
	g.sim.tick = tk(7, 45)
	var dawn_lvl: int = lm.level(open_far)
	g.sim.tick = tk(23, 0)
	var night_lvl: int = lm.level(open_far)
	check("open ground away from lamps: lit at noon (%d), dim at sunrise (%d), dark at night (%d)" % [day_lvl, dawn_lvl, night_lvl], open_far >= 0 and day_lvl == LT.LIT and dawn_lvl == LT.DIM and night_lvl == LT.DARK)
	var in_day: int
	var in_night: int
	g.sim.tick = tk(12, 0)
	lm.invalidate()
	in_day = lm.level(inside)
	g.sim.tick = tk(23, 0)
	lm.invalidate()
	in_night = lm.level(inside)
	check("a building's ceiling lights keep its floor lit day and night (%d, %d)" % [in_day, in_night], inside >= 0 and in_day == LT.LIT and in_night == LT.LIT)
	# every floor tile of the first buildings has a light on it
	var floors := 0
	var lit_floors := 0
	for b in g.city.bldgs.slice(0, 40):
		for y in range(int(b["y0"]) + 1, int(b["y1"])):
			for x in range(int(b["x0"]) + 1, int(b["x1"])):
				var c2: int = y * size + x
				if g.city.tiles[c2] == CG.FLOOR:
					floors += 1
					if lm.level(c2) == LT.LIT:
						lit_floors += 1
	check("nearly every floor tile of 40 buildings is lit at night (%d of %d)" % [lit_floors, floors], floors > 100 and float(lit_floors) / float(floors) > 0.9)
	# street lamps and neon at night: lit near, dim further, dark far; and in their colour
	var lamp: Array = []
	var neon: Dictionary = {}
	for sg in g.city.signs:
		if String(sg["shape"]) == "neon" and int(sg["cell"]) < g.s2:
			neon = sg
			break
	for by in range(8, 16):
		for bx in range(8, 16):
			for L in lm._block(bx, by):
				if lamp.is_empty() and float(L[2]) == lm.STREET_LIT:
					lamp = L
	check("the city has street lamps and a neon sign", not lamp.is_empty() and not neon.is_empty())
	if not lamp.is_empty():
		var lc: int = int(lamp[1]) * size + int(lamp[0])
		g.sim.tick = tk(23, 0)
		lm.invalidate()
		var near_l: int = lm.level(lc)
		check("a street lamp lights the ground at its foot at night (%d)" % near_l, near_l == LT.LIT)
		check("and in the lamp's colour (%s)" % str(lm.colour(lc)), lm.colour(lc) == LT.STREET)
	if not neon.is_empty():
		var nc: int = int(neon["cell"])
		var pal: Array = (preload("res://src/signage.gd").PALS[String(neon["cat"])] as Array)[int(neon["pal"])]
		g.sim.tick = tk(23, 0)
		lm.invalidate()
		var best := Color(0, 0, 0, 0)
		var lit_here := false
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var c4: int = nc + dy * size + dx
				if g.city.tiles[c4] == CG.ROAD or g.city.tiles[c4] == CG.GROUND:
					if lm.level(c4) >= LT.DIM and lm.colour(c4) == pal[2]:
						lit_here = true
		check("neon lights the street around it in the neon's colour %s" % str(pal[2]), lit_here)
	# ---- the rules of sight, on a stage: 25 x 25 open ground, everything dim except where set
	var stage_c := -1
	for c in range(size * 100, size * (size - 100), 53):
		var open_all := c % size > 40 and c % size < size - 40
		for dy in range(-13, 14):
			for dx in range(-13, 14):
				if open_all and g.fov.opaque[c + dy * size + dx] == 1:
					open_all = false
		if open_all:
			stage_c = c
			break
	check("found open ground to stage the sight rules on", stage_c >= 0)
	if stage_c >= 0:
		lm.forced.clear()
		var me: int = stage_c
		# DARK: only within two tiles
		for dy in range(-12, 13):
			for dx in range(-12, 13):
				lm.forced[me + dy * size + dx] = LT.DARK
		var d_ok := true
		for d in range(1, 8):
			var seen: bool = lm.sees(me, me + d)
			d_ok = d_ok and (seen == (d <= 2))
		check("a dark tile can be seen from two tiles or less, no further", d_ok)
		lm.forced[me + 8] = LT.LIT
		check("a lit tile can be seen from far off, even from the dark", lm.sees(me, me + 8) and lm.level(me) == LT.DARK)
		# DIM region of 9 x 9 centred 6 tiles east
		var cen: int = me + 8 * size + 0
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				lm.forced[cen + dy * size + dx] = LT.DIM
		var edge: int = cen - 4 * size
		var inner: int = cen
		check("from outside, a dim area can be seen two tiles deep: its rim shows, its middle does not", lm.sees(me, edge) and lm.sees(me, cen - 3 * size) and not lm.sees(me, inner))
		check("from inside the dim area all of it shows", lm.sees(cen + 4 * size, cen - 4 * size + 1) and lm.sees(cen + 4 * size, inner))
		# NPC spotting uses the same rule
		g.pc = me
		g.fov.compute(me % size, me / size, 20)
		var npc_far: int = me + 7
		var npc_near: int = me + 2
		check("an NPC does not spot a player standing in the dark unless close (7 tiles: %s, 2 tiles: %s)" % [str(g.light_sees_player(npc_far)), str(g.light_sees_player(npc_near))], not g.light_sees_player(npc_far) and g.light_sees_player(npc_near))
		lm.forced[me] = LT.LIT
		check("a player standing in the light is seen from afar", g.light_sees_player(npc_far))
		# the field of view
		lm.forced[me] = LT.DARK
		g.facing = Vector2i(1, 0)
		g.fov.compute(me % size, me / size, 20)
		var max_dark := 0
		var lit_seen := 0
		for dy in range(-12, 13):
			for dx in range(-12, 13):
				var cc: int = me + dy * size + dx
				if g.fov.visible[cc] == 1:
					if lm.forced.get(cc, 0) == LT.DARK:
						max_dark = maxi(max_dark, maxi(absi(dx), absi(dy)))
					elif lm.forced.get(cc, 0) == LT.LIT:
						lit_seen += 1
		check("in the dark the field of view shows dark tiles to two tiles only, and the lit tile beyond (%d, %d lit)" % [max_dark, lit_seen], max_dark <= 2 and lit_seen >= 1)
		lm.forced.clear()
	# ---- the rules can be turned off (the other tests)
	lm.enabled = false
	check("with the rules off everything is lit and seen", lm.level(open_far) == LT.LIT and lm.sees(open_far, open_far + 20))
	print("LIGHTING %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
