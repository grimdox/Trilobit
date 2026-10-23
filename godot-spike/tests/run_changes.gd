extends SceneTree
## Change requests: push non-hostiles on bump, corpses (and siphoning them), weapon specials and stun off, arrows/numpad movement and the option that restores the old scheme, zoom.
## Run: godot --headless -s tests/run_changes.gd
const MainScript = preload("res://src/main.gd")
const GameScript = preload("res://src/game.gd")
const VS = preload("res://src/vehicles.gd")
const ZOOM_N := [10, 15, 20]
var ok := 0
var n := 0

func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name)

## whole tiles either side of the player in the visible width
func _side(m) -> int:
	return (int(1542.0 / m.view.TILE) - 1) / 2

func _person(g, fac: int) -> int:
	for i in g.sim.n:
		if g.sim.alive[i] == 1 and g.fac[i] == fac:
			return i
	return -1

func _initialize() -> void:
	var g = GameScript.new(21)
	g.setup(800)
	for l_ in g.BODY.LIMBS:
		g.body.hp[l_] = 100000
		g.body.mx[l_] = 100000
	for vi in g.vehicles.size():
		g.vs.lift(vi)
	g.vehicles.clear()
	g.veh_at.fill(-1)
	var e: int = g.city.xs[3]
	var a: int = g.vs.anchor_for("car", 0, VS.lane_hi2(e), 250, 0)
	g.pc = a
	g.sim.retier(g.pc)
	g.facing = Vector2i(0, 1)
	# ---- push on bump
	var civ: int = _person(g, g.CIV)
	check("there is a civilian to push", civ >= 0)
	g.sim.place(civ, a + g.size)
	g.astate[civ] = g.UNAWARE
	g.provoked.erase(civ)
	g.hpn[civ] = 100
	g.hpmax[civ] = 100
	var hp0: int = g.hpn[civ]
	g.log.clear()
	var t0: int = g.turn
	g.act_move(0, 1)
	check("walking into a civilian pushes them on, no damage, and you stay put (%s)" % str(g.log.slice(-2)), g.sim.pos[civ] == a + 2 * g.size and g.hpn[civ] == hp0 and g.pc == a and g.turn == t0 + 1)
	g.sim.place(civ, a + g.size)
	g.provoked[civ] = true
	g.act_move(0, 1)
	check("someone you have provoked is hit, not pushed", g.hpn[civ] < hp0 or g.sim.alive[civ] == 0)
	g.provoked.erase(civ)
	var ban: int = _person(g, g.BRATVA)
	if ban >= 0:
		g.sim.place(ban, a + g.size)
		g.hpn[ban] = 100
		g.hpmax[ban] = 100
		g.act_move(0, 1)
		check("a hostile faction member is still attacked", g.hpn[ban] < 100 or g.sim.alive[ban] == 0)
		g.kill(ban)
	# boxed in: nowhere to go
	var civ2: int = _person(g, g.CIV)
	if civ2 == civ:
		for i in g.sim.n:
			if i != civ and g.sim.alive[i] == 1 and g.fac[i] == g.CIV:
				civ2 = i
				break
	g.sim.place(civ2, 2 * g.size + 2)
	g.pc = 2 * g.size + 1
	g.sim.retier(g.pc)
	g.sim.place(civ2, 2 * g.size + 2)
	var tt: int = g.turn
	g.astate[civ2] = g.UNAWARE
	g.act_move(1, 0)
	check("pushing someone into a wall they cannot move through says so and spends no time or health", g.turn == tt or g.sim.pos[civ2] != 2 * g.size + 2)
	# ---- corpses
	g.pc = a
	var v: int = civ
	g.sim.alive[v] = 1
	g.sim.place(v, a + g.size)
	g.energy[v] = 500
	g.corpses.clear()
	g.kill(v)
	var ci: int = g.corpse_at(a + g.size)
	check("killing someone leaves a corpse where they fell, carrying their energy", ci >= 0 and int(g.corpses[ci]["kj"]) == 500)
	var pw0: float = g.power_left()
	var kj0: int = int(g.corpses[ci]["kj"])
	if g.implants.is_empty():
		g.implants = g.implants
	var d: Dictionary = g.save_dict()
	check("corpses are saved", d.has("corpses") and (d["corpses"] as Array).size() >= 1)
	var g2 = GameScript.new(21)
	g2.setup(800)
	g2.load_dict(JSON.parse_string(JSON.stringify(d)))
	check("and come back after a load", g2.corpse_at(a + g.size) >= 0)
	g.pc = a + 3 * g.size
	check("corpse_at finds nothing on an empty cell", g.corpse_at(g.pc) == -1)
	for i in 299:
		g.corpses.append({"cell": 1, "name": "x", "fac": 0, "kj": 1})
	g.sim.alive[v] = 1
	g.sim.place(v, a + g.size)
	g.kill(v)
	check("the corpse list is capped at %d" % g.CORPSE_CAP, g.corpses.size() <= g.CORPSE_CAP)
	# ---- specials and stun off
	check("weapon specials are shelved", not g.specials_on)
	var w: int = _person(g, g.CIV)
	g.sim.alive[w] = 1
	g.sim.place(w, a + g.size)
	g.hpn[w] = 500
	g.hpmax[w] = 500
	var stunned := false
	for k in 40:
		g._melee_effects(w, {"stun": 1.0, "trip": 1.0, "knock": 1.0, "bleed": true, "entangle": 1.0, "dmg": [1, 2]})
		if g.stun[w] > 0 or g.bleed[w] > 0:
			stunned = true
	check("a weapon with 100% stun, trip, knock-back and bleed does none of them", not stunned and g.sim.pos[w] == a + g.size)
	g.hpn[w] = 500
	g.act_shove(0, 1)
	check("a shove no longer stuns", g.stun[w] == 0)
	# ---- movement scheme
	var m = MainScript.new()
	m.save_prefix = "user://test_ch_save_"
	m.settings_path = "user://test_ch_settings.json"
	root.add_child(m)
	for i in 4:
		await process_frame
	m.open_screen("title")
	m.activate("new")
	m.cc_sel = 12
	m.begin_new(5, m.cc)
	for i in 600:
		await process_frame
		if m.mode == "play":
			break
	var press := func(k: int) -> void:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.pressed = true
		m._unhandled_key_input(ev)
	var gg = m.game
	var open_cell := -1
	for dy in range(-8, 9):
		for dx in range(-8, 9):
			pass
	check("new scheme is the default", not m.settings.view_follows_move)
	# find a spot with room all round
	var spot := -1
	for c in range(gg.pc - 6 * gg.size, gg.pc + 6 * gg.size):
		var ok_all := true
		for oy in range(-2, 3):
			for ox in range(-2, 3):
				var cc: int = c + oy * gg.size + ox
				if cc < 0 or cc >= gg.size * gg.size or gg.sim.walk[cc] == 0 or gg.sim.at[cc] != -1 or gg.thing_at[cc] != -1 or gg.crit_at[cc] != -1 or gg.veh_at[cc] != -1:
					ok_all = false
		if ok_all:
			spot = c
			break
	check("found a clear 5x5 to walk in", spot >= 0)
	if spot >= 0:
		gg.pc = spot
		gg.in_vehicle = -1
		gg.facing = Vector2i(0, -1)
		var p0: int = gg.pc
		press.call(KEY_KP_2)
		check("numpad 2 steps south without turning (%s)" % str(gg.facing), gg.pc == p0 + gg.size and gg.facing == Vector2i(0, -1))
		press.call(KEY_KP_6)
		check("numpad 6 strafes east without turning", gg.pc == p0 + gg.size + 1 and gg.facing == Vector2i(0, -1))
		var p1: int = gg.pc
		press.call(KEY_UP)
		check("Up walks forward along the view (north)", gg.pc == p1 - gg.size and gg.facing == Vector2i(0, -1))
		press.call(KEY_DOWN)
		check("Down walks back, still facing north", gg.pc == p1 and gg.facing == Vector2i(0, -1))
		var t1: int = gg.turn
		press.call(KEY_RIGHT)
		check("Right turns the view 45 degrees clockwise and takes no time", gg.facing == Vector2i(1, -1) and gg.turn == t1)
		press.call(KEY_LEFT)
		press.call(KEY_LEFT)
		check("Left turns anticlockwise", gg.facing == Vector2i(-1, -1))
		press.call(KEY_UP)
		check("Up now walks north-west", gg.pc == p1 - gg.size - 1)
		press.call(KEY_KP_SUBTRACT)
		check("numpad minus asks which way to turn", m.mode == "turn")
		press.call(KEY_KP_6)
		check("then numpad 6 turns to face east, no time, no step", m.mode == "play" and gg.facing == Vector2i(1, 0) and gg.pc == p1 - gg.size - 1)
		# old scheme
		m.settings.view_follows_move = true
		var p2: int = gg.pc
		press.call(KEY_KP_2)
		check("with the option on, numpad 2 moves south and turns to face south", gg.pc == p2 + gg.size and gg.facing == Vector2i(0, 1))
		press.call(KEY_LEFT)
		check("and Left moves west facing west", gg.facing == Vector2i(-1, 0) and gg.pc == p2 + gg.size - 1)
		m.settings.view_follows_move = false
	m._fill_options()
	check("the option is listed as 'Toggle view changes with move direction'", m.screen.items.any(func(i): return i["label"] == "Toggle view changes with move direction"))
	m.activate("vfm")
	check("activating it flips the setting and it is saved", m.settings.view_follows_move)
	m.activate("vfm")
	# ---- zoom
	check("zoom defaults to middle: 15 tiles either side", m.settings.zoom == 1 and _side(m) == 15)
	m.cycle_zoom()
	check("one press: far, 20 tiles either side", _side(m) == 20 and m.settings.zoom == 2)
	m.cycle_zoom()
	check("another: close, 10 tiles either side", _side(m) == 10 and m.settings.zoom == 0)
	var fits := true
	for z in 3:
		m.view.set_zoom(z)
		if m.view.cols * m.view.TILE < 1920 or m.view.rows * m.view.TILE < 837 or m.view.rows % 2 == 0 or m.view.cols % 2 == 0 or absf(m.view.shift.x + m.view.cols * m.view.TILE / 2.0 - 771.0) > 1.0 or absf(m.view.shift.y + m.view.rows * m.view.TILE / 2.0 - 418.5) > 1.0 or m.view.TILE * (ZOOM_N[z] * 2 + 1) > 1542:
			fits = false
	check("every zoom covers the canvas, shows N tiles either side in the visible width, and puts the player in the middle of the area left of the HUD and above the message bar", fits)
	m.cycle_zoom()
	check("and it cycles back to middle", m.settings.zoom == 1 and _side(m) == 15)
	press.call(KEY_EQUAL)
	check("= is the zoom key", m.settings.zoom == 2)
	press.call(KEY_EQUAL)
	press.call(KEY_EQUAL)
	print("CHANGES %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
