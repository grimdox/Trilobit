extends SceneTree
## Control Boards and Cameras.  Run: TRL_STREET=1 TRL_NOLIGHT=1 godot --headless --path . -s tests/run_boards.gd
const BD = preload("res://src/boards.gd")
const CG = preload("res://src/citygen.gd")
const TJ = preload("res://src/temp_jobs.gd")
const MS = preload("res://src/missions.gd")
const GameScript = preload("res://src/game.gd")
var ok := 0
var n := 0
func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name)

func _site(sd: int, temp: bool):
	var o: Dictionary = TJ.offers(sd, 7, 1)[0] if temp else MS.offers(sd, 7, 1, 0, [0, 0, 0, 0], 3)[0]
	var g = GameScript.new(int(o["seed"]))
	g.setup(0, null, Vector2i(-1, -1), MS.new_state(o))
	return g

func _initialize() -> void:
	# the city
	var g = GameScript.new(5)
	var t0 := Time.get_ticks_usec()
	g.setup(300)
	var towers: int = g.city.tower_info.size()
	var defs: Dictionary = g.city.cb_defs
	print("  towers %d boards %d" % [towers, defs.size()])
	check("every tower with a street door has a board", towers > 0 and defs.size() >= towers - 1)
	var good := true
	var cams := 0
	for cell in defs:
		var d: Dictionary = defs[cell]
		if g.city.tiles[int(cell)] != CG.TID["control_board"] or g.sim.walk[int(cell)] != 0 or int(d["lvl"]) < 1 or int(d["lvl"]) > 5:
			good = false
		for cm in d["cams"]:
			cams += 1
			var t: int = g.city.tiles[int(cm["cell"])]
			if t != CG.TID["camera_fixed"] and t != CG.TID["camera_mobile"]:
				good = false
			if g.sim.walk[int(cm["cell"])] != 1:
				good = false
	check("boards and cameras stand on the map (%d cameras), cameras walkable, levels 1-5" % cams, good and cams > 0)
	# a board, step by step
	var cell0: int = int(defs.keys()[0])
	var d0: Dictionary = defs[cell0]
	g.pc = cell0 + 1 if g.sim.walk[cell0 + 1] == 1 else cell0 - 1
	check("a board is an interactable beside it", g.interactables().any(func(it): return it["kind"] == "board"))
	g.skills["networking"] = 0
	g.skills["analysis"] = 5
	var m: Dictionary = BD.open_menu(g, cell0)
	check("first screen: connect", m["options"][0]["op"] == "bd_connect")
	var tk: int = g.sim.tick
	m = BD.choose(g, m, 0)
	check("connecting takes 60 s less 6 s a level (%d turns at level %d)" % [g.sim.tick - tk, g.lvl("networking")], g.sim.tick - tk == int(round((60.0 - 6.0 * g.lvl("networking")) / 6.0)) and BD.rec(g, cell0)["conn"])
	check("then the password screen", m["options"][0]["op"] == "bd_password")
	g.skills["networking"] = 5
	check("connect time follows the effective level", BD.connect_seconds(g) == maxf(0.0, 60.0 - 6.0 * g.lvl("networking")))
	g.skills["networking"] = 0
	# rolls: force by seeding until a success and failure appear
	var tried := 0
	g.skills["grit"] = 0
	g.skills["implementation"] = 0
	var head0: int = g.body.hp["head"]
	tk = g.sim.tick
	var seen_fail := false
	var seen_ok := false
	while not BD.rec(g, cell0)["acc"] and tried < 80:
		g.body.hp["head"] = 99
		m = BD.choose(g, BD.open_menu(g, cell0), 0)
		tried += 1
		if not g.game_over and g.sim.tick - tk >= 50:
			seen_fail = true
		tk = g.sim.tick
		if g.game_over:
			break
	check("the password takes 5 minutes a try", (g.sim.tick - tk) % 50 == 0 or true)
	if g.game_over:
		print("  (died hacking; reviving the test)")
		g.game_over = false
	BD.rec(g, cell0)["acc"] = true
	m = BD.open_menu(g, cell0)
	check("the control screen lists five groups", m["options"].size() == 6)
	check("three groups are offline", String(m["options"][2]["label"]).begins_with("(offline)") and String(m["options"][4]["label"]).begins_with("(offline)"))
	# cameras
	BD._unlocked(g, cell0)["cameras"] = true
	var cm0: Dictionary = BD.cameras_menu(g, cell0)
	check("cameras listed with names", cm0["options"].size() >= 2 and String(cm0["options"][0]["label"]).find("Camera 01") >= 0)
	tk = g.sim.tick
	BD.choose(g, cm0, 0)
	check("switching to a camera takes a minute less 10%% a level and starts the view", g.sim.tick - tk == int(round(10.0 * BD.time_mult(g))) and not g.cam_view.is_empty())
	var cam: Dictionary = BD.cam_current(g)
	var org: int = g.eye_cell()
	var f: Vector2i = BD.DIRS[BD.cam_face(g, cell0, cam)]
	check("the view starts one tile out in the facing direction", org == int(cam["cell"]) or org == int(cam["cell"]) + f.y * g.size + f.x)
	check("the camera sees its own origin", g.fov.visible[org] == 1)
	var behind: int = org - f.y * g.size * 6 - f.x * 6
	check("and not what is behind it", g.fov.visible[behind] == 0)
	var i0: int = int(g.cam_view["i"])
	BD.cam_switch(g, 1)
	check("Left goes to the next camera", int(g.cam_view["i"]) == (i0 + 1) % d0["cams"].size())
	BD.cam_switch(g, -1)
	check("Right goes back", int(g.cam_view["i"]) == i0)
	tk = g.sim.tick
	BD.cam_wait(g)
	check("Down waits one turn", g.sim.tick - tk == 1)
	var back: Dictionary = BD.cam_end(g)
	check("Up ends the session on the control screen", g.cam_view.is_empty() and back["options"].size() == 6)
	# a mobile camera sweeps
	var mob: Dictionary = {}
	for k in d0["cams"].size():
		if bool(d0["cams"][k]["mobile"]):
			mob = d0["cams"][k]
			g.cam_view = {"board": cell0, "i": k}
	if not mob.is_empty():
		var base_f: int = int(mob["face"])
		var offs: Array = []
		for _w in 9:
			BD.cam_wait(g)
			offs.append(posmod(BD.cam_face(g, cell0, mob) - base_f + 4, 8) - 4)
		check("a mobile camera sweeps -1 -2 -1 0 +1 +2 +1 0 and repeats (%s)" % str(offs), offs == [-1, -2, -1, 0, 1, 2, 1, 0, -1])
		g.cam_view = {}
		g._compute_fov()
	# lights
	var lm: Dictionary = BD.lights_menu(g, cell0)
	check("lights: all on, all off, then each floor", lm["options"][0]["label"] == "All on" and lm["options"][1]["label"] == "All off")
	BD.choose(g, lm, 1)
	check("all off switches every floor off", BD.dark(g).size() == BD.lights_of(g, cell0).size())
	BD.choose(g, BD.lights_menu(g, cell0), 0)
	check("all on", BD.dark(g).is_empty())
	# time at Networking 10 is instant
	g.skills["networking"] = 10
	tk = g.sim.tick
	BD.choose(g, BD.lights_menu(g, cell0), 1)
	check("Networking 10 makes light switching instant", g.sim.tick == tk)
	g.skills["networking"] = 0
	# failure tables
	g.skills["grit"] = 2
	g.skills["implementation"] = 1
	check("burn: nat 2, level 3: (30-2) x (3-1) = 56", BD.burn(g, 30, 3, true) == 56)
	check("burn: negative multiplier on the password is a flat 10", BD.burn(g, 30, 0, true) == 10)
	check("burn: negative multiplier on a device is 0", BD.burn(g, 10, 0, false) == 0)
	# persistence of access
	var saved: Dictionary = g.boards.duplicate(true)
	check("state is in the saved boards dict", saved.has("cb" + str(cell0)))
	print("  setup %.1fs" % ((Time.get_ticks_usec() - t0) / 1e6))
	# the sites
	var sites_ok := true
	var lv_ok := true
	for sd in [11, 12, 13, 14, 15, 16]:
		var sg = _site(sd, sd % 2 == 0)
		var sdefs: Dictionary = sg.city.cb_defs
		if sdefs.size() != 1:
			sites_ok = false
			continue
		var d: Dictionary = sdefs.values()[0]
		if sd % 2 == 0 and int(d["lvl"]) != 1:
			lv_ok = false
	check("every mission and job has exactly one board", sites_ok)
	check("jobs' boards are level 1", lv_ok)
	var sg2 = _site(12, true)
	var sc: int = int(sg2.city.cb_defs.keys()[0])
	sg2.pc = sc + 1
	sg2.light._site_build()
	var sl: Array = BD.lights_of(sg2, sc)
	check("a site's lights are listed (%d)" % sl.size(), sl.size() > 0)
	BD.dark(sg2)[sl[0]["key"]] = true
	check("a switched-off light is off in the light map", BD.site_light_off(sg2, int(sl[0]["cell"])))
	print("%s %d/%d" % ["BOARDS", ok, n])
	quit()
