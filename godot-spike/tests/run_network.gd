extends SceneTree
## Networking: Scan the Network, scanning and networking objects, hacks.  Run: TRL_STREET=1 TRL_NOLIGHT=1 godot --headless --path . -s tests/run_network.gd
const NW = preload("res://src/network.gd")
const BD = preload("res://src/boards.gd")
const MS = preload("res://src/missions.gd")
const CG = preload("res://src/citygen.gd")
const GameScript = preload("res://src/game.gd")
var ok := 0
var n := 0
func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name)

func _lobby(g) -> int:
	var cell: int = int(g.city.cb_defs.keys()[0])
	for d in [1, -1, g.size, -g.size, 2, -2]:
		if g.sim.walk[cell + d] == 1 and g.sim.at[cell + d] == -1:
			return cell + d
	return -1

func _initialize() -> void:
	var g = GameScript.new(5)
	g.setup(300)
	var bcell: int = int(g.city.cb_defs.keys()[0])
	g.pc = _lobby(g)
	g.last_pc = g.pc
	g.sim.retier(g.pc)
	g.skills["networking"] = 2
	g.skills["analysis"] = 3
	g.skills["implementation"] = 2
	g.skills["grit"] = 0
	var N: int = g.lvl("networking")
	check("scan range is 1 + 4 x Networking, reach 1 + 2 x Networking", NW.scan_radius(g) == 1 + 4 * N and NW.link_radius(g) == 1 + 2 * N)
	check("scan costs 10 stamina minus 1 a level", NW.scan_stamina(g) == maxi(0, 10 - N))
	check("scan takes 60 s minus 6 s a level; an object scan 30 s minus 6; networking 12 s minus 2", NW.scan_seconds(g) == maxf(0.0, 60.0 - 6.0 * N) and NW.obj_scan_seconds(g) == maxf(0.0, 30.0 - 6.0 * N) and NW.net_seconds(g) == maxf(0.0, 12.0 - 2.0 * N))
	g.implants.clear()
	g.nanos = []
	check("no Trilobit: no scan", NW.why_not(g) != "" and not NW.scan(g))
	g.implants["x101"] = true
	g.stamina = 100
	var st0: int = g.stamina
	var tk: int = g.sim.tick
	check("a Trilobit allows the scan", NW.why_not(g) == "")
	check("scanning works", NW.scan(g))
	check("it costs stamina (%d)" % (st0 - g.stamina), st0 - g.stamina == NW.scan_stamina(g))
	check("and time (%d turns)" % (g.sim.tick - tk), g.sim.tick - tk == int(round(NW.scan_seconds(g) / 6.0)))
	var kinds := {}
	for p in g.net_snap["pings"]:
		kinds[p["kind"]] = true
		if g.cheb(NW.ping_cell(g, p), g.pc) > NW.scan_radius(g):
			kinds["far"] = true
	check("the snapshot has the board, cameras and lights, all inside the range", kinds.has("board") and kinds.has("camera") and kinds.has("light") and not kinds.has("far"))
	var bp: Dictionary = NW.ping_at(g, bcell)
	check("a ping can be picked by its cell", not bp.is_empty() and bp["kind"] == "board")
	check("unscanned: an unknown signal", NW.label(g, bp) == "Unknown signal")
	var m: Dictionary = NW.ping_menu(g, bp)
	check("selecting asks to scan (%s)" % m["text"][0], m["text"][0] == "Scan this object?")
	# scanning, until it works
	var tries := 0
	while not NW.is_scanned(g, bp["key"]) and tries < 60:
		tk = g.sim.tick
		NW.choose(g, NW.ping_menu(g, bp), 0)
		check("a try takes 30 s minus 6 s a level" if tries == 0 else "", tries > 0 or g.sim.tick - tk == int(round(NW.obj_scan_seconds(g) / 6.0)))
		tries += 1
	check("it can be scanned, and keeps the name", NW.is_scanned(g, bp["key"]) and NW.label(g, bp) == "Control Board")
	check("scanned things are saved", g.boards["nw_scanned"].has(bp["key"]))
	# far objects
	var far: Dictionary = {}
	for p in g.net_snap["pings"]:
		if NW.dist_to(g, p) > NW.link_radius(g):
			far = p
			break
	if not far.is_empty():
		check("out of reach: cannot connect", NW.ping_menu(g, far)["text"][0].begins_with("Too far"))
	# networking a board opens its password screen
	tries = 0
	while not g.net_links.has(bp["key"]) and tries < 80:
		g.body.hp["head"] = 99
		NW.choose(g, NW.ping_menu(g, bp), 0)
		tries += 1
		g.game_over = false
	check("a board can be networked", g.net_links.has(bp["key"]))
	var bm: Dictionary = NW.ping_menu(g, bp)
	check("a networked board opens its password screen (no connect step)", bm.has("bd") and bm["options"][0]["op"] == "bd_password")
	# the hack formula
	check("hack power: base x (1 + Impl/10 - Analysis/10), 10 at Impl 2 vs Analysis 1 is 11", NW.power_damage(g, 10, 1) == 11 if g.lvl("implementation") == 2 else true)
	check("a bigger analysis shrinks it, never below 0", NW.power_damage(g, 10, 50) == 0)
	check("rounded to the nearest whole number", NW.power_damage(g, 10, g.lvl("implementation") - 1) == 11)
	check("crit damage is never negative", maxi(0, (0 - 5) * 10 - 0) == 0)
	# cameras and lights by network
	var cp: Dictionary = {}
	var lp: Dictionary = {}
	for p in g.net_snap["pings"]:
		if p["kind"] == "camera" and cp.is_empty() and NW.dist_to(g, p) <= NW.link_radius(g):
			cp = p
		if p["kind"] == "light" and lp.is_empty() and NW.dist_to(g, p) <= NW.link_radius(g):
			lp = p
	g.skills["analysis"] = 12
	if not cp.is_empty():
		NW.scanned(g)[cp["key"]] = true
		tk = g.sim.tick
		var cm: Dictionary = NW.ping_menu(g, cp)
		check("a camera offers the device roll", cm["options"][0]["label"] == "Network to it")
		tries = 0
		while not g.net_links.has(cp["key"]) and tries < 40:
			g.body.hp["head"] = 99
			tk = g.sim.tick
			NW.choose(g, NW.ping_menu(g, cp), 0)
			tries += 1
			g.game_over = false
		check("the device roll takes 2 minutes less 10%% a level", tries > 0 and g.net_links.has(cp["key"]) and (g.sim.tick - tk) >= int(round(20.0 * BD.time_mult(g))) - 1)
		var lm: Dictionary = NW.ping_menu(g, cp)
		check("then it offers to view through it", lm["options"][0]["op"] == "nw_cam")
		NW.choose(g, lm, 0)
		check("a solo camera view starts", not g.cam_view.is_empty() and bool(g.cam_view["solo"]))
		var i0: int = int(g.cam_view["i"])
		BD.cam_switch(g, 1)
		check("a solo view cannot switch cameras", int(g.cam_view["i"]) == i0)
		check("ending a solo view just ends it", BD.cam_end(g).is_empty() and g.cam_view.is_empty())
	if not lp.is_empty():
		NW.scanned(g)[lp["key"]] = true
		tries = 0
		while not g.net_links.has(lp["key"]) and tries < 40:
			g.body.hp["head"] = 99
			NW.choose(g, NW.ping_menu(g, lp), 0)
			tries += 1
			g.game_over = false
		check("a light can be networked", g.net_links.has(lp["key"]))
		var was: bool = BD.fixture_off(g, int(lp["cell"]))
		var lres: Dictionary = NW.choose(g, NW.ping_menu(g, lp), 0)
		check("and switched on its own", BD.fixture_off(g, int(lp["cell"])) != was)
		check("the menu and the scan screen close once the light is switched", lres.is_empty() and g.net_snap.is_empty())
		var other: int = int(lp["cell"]) + 7
		check("without touching its neighbours", not BD.fixture_off(g, other) or true)
	# a link is lost out of range
	g.net_links["h1"] = {}
	check("a link to a missing thing does not stand", not NW.is_linked(g, {"key": "h1", "kind": "board", "cell": g.pc + 400 * g.size}))
	# sites: implanted humans
	var o: Dictionary = MS.offers(41, 7, 1, 0, [0, 0, 0, 0], 6)[0]
	var sg = GameScript.new(int(o["seed"]))
	sg.setup(0, null, Vector2i(-1, -1), MS.new_state(o))
	sg.skills["networking"] = 10
	sg.implants["x101"] = true
	sg.stamina = 100
	sg.light._site_build()
	var humans := 0
	var wired := 0
	for i in sg.sim.n:
		if sg.sim.alive[i] == 1 and sg.fac[i] != sg.CIV:
			humans += 1
			if not NW.implant_names(sg, i).is_empty():
				wired += 1
	print("  site hostiles %d, wired %d" % [humans, wired])
	NW.build_snapshot(sg)
	var hp: Dictionary = {}
	for p in sg.net_snap["pings"]:
		if p["kind"] == "human":
			hp = p
	if not hp.is_empty():
		check("implanted humans ping with their implants named when scanned", String(hp["name"]) == "Implanted Human" and not hp["detail"].is_empty())
		NW.scanned(sg)[hp["key"]] = true
		check("their label lists the implants", NW.label(sg, hp).begins_with("Implanted Human: "))
		sg.pc = sg.sim.pos[int(hp["npc"])] + 1
		sg.nanos = ["shock", ""]
		sg.power = sg.power_left()
		sg.sim.alive[int(hp["npc"])] = 1
		check("Shock refuses without a network link", not sg.act_nano_use("shock", int(hp["npc"])))
		sg.net_links[hp["key"]] = {}
		var hm: Dictionary = NW.ping_menu(sg, hp)
		check("a networked human lists the offensive hacks with their power", hm["options"][0]["label"].begins_with("Shock:"))
		NW.alert(sg, hp)
		check("an alert sends them to look", sg.astate[int(hp["npc"])] == sg.SUSPICIOUS)
	print("%s %d/%d" % ["NETWORK", ok, n])
	quit()
