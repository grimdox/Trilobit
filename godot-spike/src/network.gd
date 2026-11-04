extends RefCounted
## Networking: Scan the Network (B), then scan, network to and hack what shows on it.
##   Scan the Network: needs a working Trilobit; 10 stamina minus 1 a Networking level, 60 s minus 6 s a level; shows every networked thing within
##     1 + 4 x Networking tiles as a ping (no difference between the kinds yet): people with implants, lights, cameras, control boards (androids wait).
##   Scan an object (within 1 + 2 x Networking): 30 s minus 6 s a level.  2d10 + Networking + Analysis against 10 + its Implementation
##     (a camera or a board: its level / 2; a light: 0).  Success names it for good (saved); failure only costs the time.
##   Network to a scanned object (same range): an Analysis check against 10 + its Implementation, 12 s minus 2 s a level.
##     Natural 2: (its Implementation - your Analysis) x 10 - Grit damage to the head, they are alerted, you are not linked.  3-6: alerted, not linked.
##     7-18 (the check failed): alerted, but linked.  A success links you and they do not notice.  A link is lost if the object leaves 1 + 2 x Networking.
##     Alerted people (implanted humans) look for you at a spot within 10 - their Implementation of you (exactly at you when that is 0 or less); no alarm.
##   Cameras and lights are linked by a device roll instead (2 min, the board's difficulty, lock-outs and damage: boards.gd), with no password.
##   A linked board opens its password screen.  A linked human can take an offensive nanohack: base x (1 + your Implementation / 10 - their Analysis / 10).
const BD = preload("res://src/boards.gd")
const CG = preload("res://src/citygen.gd")
const ENM = preload("res://src/enemies.gd")
const IMP = preload("res://src/implants.gd")
const NANO = preload("res://src/nanohacks.gd")

const SCAN_STAMINA := 10
const SCAN_SECONDS := 60.0
const OBJ_SCAN_SECONDS := 30.0
const NET_SECONDS := 12.0
const ALERT_RADIUS := 10
const FIXTURE_MOD := 7

## ---------------------------------------------------------------------------------------------------------------- numbers
static func lv(g) -> int:
	return g.lvl("networking")

static func scan_radius(g) -> int:
	return 1 + 4 * lv(g)

static func link_radius(g) -> int:
	return 1 + 2 * lv(g)

static func scan_stamina(g) -> int:
	return maxi(0, SCAN_STAMINA - lv(g))

static func scan_seconds(g) -> float:
	return maxf(0.0, SCAN_SECONDS - 6.0 * float(lv(g)))

static func obj_scan_seconds(g) -> float:
	return maxf(0.0, OBJ_SCAN_SECONDS - 6.0 * float(lv(g)))

static func net_seconds(g) -> float:
	return maxf(0.0, NET_SECONDS - 2.0 * float(lv(g)))

static func secs_text(s: float) -> String:
	return "instant" if s <= 0.0 else ("%d s" % int(round(s)))

## the multiplier of a hack: 1 + your Implementation / 10 - their Analysis / 10 (never below nothing)
static func power_mult(g, target_analysis: int) -> float:
	return maxf(0.0, 1.0 + float(g.lvl("implementation")) / 10.0 - float(target_analysis) / 10.0)

static func power_damage(g, base: int, target_analysis: int) -> int:
	return int(round(float(base) * power_mult(g, target_analysis)))

## ---------------------------------------------------------------------------------------------------------------- state
static func scanned(g) -> Dictionary:
	if not g.boards.has("nw_scanned"):
		g.boards["nw_scanned"] = {}
	return g.boards["nw_scanned"]

static func is_scanned(g, key: String) -> bool:
	return scanned(g).has(key)

## a link: {"ctl": true once a camera or light has been taken in hand}; lost when the thing leaves the link range
static func is_linked(g, p: Dictionary) -> bool:
	if not g.net_links.has(p["key"]):
		return false
	if not in_link_range(g, p):
		g.net_links.erase(p["key"])
		return false
	return true

## the people the player is networked to right now, nearest first (for the offensive nanohacks)
static func linked_humans(g) -> Array:
	var out: Array = []
	for p in g.net_snap.get("pings", []):
		if String(p["kind"]) == "human" and is_linked(g, p) and g.sim.alive[int(p["npc"])] == 1:
			out.append(int(p["npc"]))
	out.sort_custom(func(a, b): return g.cheb(g.sim.pos[a], g.pc) < g.cheb(g.sim.pos[b], g.pc))
	return out

static func ping_cell(g, p: Dictionary) -> int:
	if String(p["kind"]) == "human":
		var i: int = int(p["npc"])
		return g.sim.pos[i] if g.sim.alive[i] == 1 else -1
	return int(p["cell"])

static func dist_to(g, p: Dictionary) -> int:
	var c: int = ping_cell(g, p)
	if c < 0 or c / g.s2 != g.pc / g.s2:
		return 9999
	return g.cheb(c, g.pc)

static func in_link_range(g, p: Dictionary) -> bool:
	return dist_to(g, p) <= link_radius(g)

## ---------------------------------------------------------------------------------------------------------------- the scan
## "" if the network can be scanned now, else why not
static func why_not(g) -> String:
	if g.in_vehicle >= 0 or g.flying:
		return "You cannot scan the network from a vehicle or in flight."
	if g.nano_slots() <= 0:
		return "Scanning the network needs a Trilobit fitted."
	if not g.nano_ok():
		return "Your Trilobit is off."
	if g.stamina < scan_stamina(g):
		return "You are too tired to scan the network (it takes %d stamina)." % scan_stamina(g)
	return ""

static func scan(g) -> bool:
	var why: String = why_not(g)
	if why != "":
		g.say(why)
		return false
	g.say("You open a channel and sweep the network...")
	BD.spend_seconds(g, scan_seconds(g))
	if g.game_over:
		return false
	g.stamina = maxi(0, g.stamina - scan_stamina(g))
	build_snapshot(g)
	g.sfx("blip")
	return true

static func implant_names(g, i: int) -> Array:
	var out: Array = []
	for id in g.npc_implants(i):
		out.append(String(IMP.get_def(String(id)).get("name", id)))
	return out

static func build_snapshot(g) -> void:
	var R: int = scan_radius(g)
	var base: int = (g.pc / g.s2) * g.s2
	var px: int = g.lx(g.pc)
	var py: int = g.ly(g.pc)
	var pings: Array = []
	# people with implants
	for i in g.sim.n:
		if g.sim.alive[i] != 1 or g.fac[i] == g.CIV:
			continue
		var c: int = g.sim.pos[i]
		if c / g.s2 != g.pc / g.s2 or g.cheb(c, g.pc) > R:
			continue
		var rig: Array = implant_names(g, i)
		if rig.is_empty():
			continue
		pings.append({"key": "h" + str(i), "kind": "human", "cell": c, "npc": i, "name": "Implanted Human", "detail": rig,
			"impl": g.npc_lvl(i, "implementation"), "ana": g.npc_lvl(i, "analysis")})
	# cameras and boards
	for b in g.city.cb_defs:
		var d: Dictionary = g.city.cb_defs[b]
		var half: int = int(d["lvl"]) / 2
		if int(b) / g.s2 == g.pc / g.s2 and g.cheb(int(b), g.pc) <= R:
			pings.append({"key": "b" + str(b), "kind": "board", "cell": int(b), "name": "Control Board", "detail": [], "impl": half, "ana": 0})
		for cm in d["cams"]:
			var cc: int = int(cm["cell"])
			if cc / g.s2 == g.pc / g.s2 and g.cheb(cc, g.pc) <= R:
				pings.append({"key": "c" + str(cc), "kind": "camera", "cell": cc, "name": String(cm["name"]), "detail": [], "impl": half, "ana": 0})
	# lights: a site's lights, and the ceiling lights of a tower that has a board
	if g.city.has_meta("site"):
		g.light._site_build()
		for L in g.light._site_lights:
			var lc: int = int(L[0])
			if lc / g.s2 == g.pc / g.s2 and g.cheb(lc, g.pc) <= R and not g.dead_lights.has(lc):
				pings.append({"key": "l" + str(lc), "kind": "light", "cell": lc, "name": "Light", "detail": [], "impl": 0, "ana": 0})
	else:
		for t in g.city.tower_info:
			if BD.board_for(g, (int(t["y0"]) * g.size + int(t["x0"])) + base) < 0:
				continue
			for y in range(maxi(int(t["y0"]), py - R), mini(int(t["y1"]), py + R) + 1):
				for x in range(maxi(int(t["x0"]), px - R), mini(int(t["x1"]), px + R) + 1):
					if ((x + 3 * y) % FIXTURE_MOD + FIXTURE_MOD) % FIXTURE_MOD != 0:
						continue
					var fc: int = base + y * g.size + x
					if g.light.indoor(fc):
						pings.append({"key": "l" + str(fc), "kind": "light", "cell": fc, "name": "Light", "detail": [], "impl": 0, "ana": 0})
	g.net_snap = {"center": g.pc, "radius": R, "pings": pings}

static func ping_at(g, cell: int) -> Dictionary:
	for p in g.net_snap.get("pings", []):
		if ping_cell(g, p) == cell:
			return p
	return {}

## the pings nearest first (Tab steps through them)
static func ping_cells(g) -> Array:
	var out: Array = []
	for p in g.net_snap.get("pings", []):
		var c: int = ping_cell(g, p)
		if c >= 0:
			out.append(c)
	out.sort_custom(func(a, b): return g.cheb(a, g.pc) < g.cheb(b, g.pc) or (g.cheb(a, g.pc) == g.cheb(b, g.pc) and a < b))
	return out

static func close(g) -> void:
	g.net_snap = {}

## ---------------------------------------------------------------------------------------------------------------- what a ping is called
static func label(g, p: Dictionary) -> String:
	if not is_scanned(g, String(p["key"])):
		return "Unknown signal"
	if String(p["kind"]) == "human":
		return "Implanted Human: " + ", ".join(p["detail"])
	return String(p["name"])

## ---------------------------------------------------------------------------------------------------------------- menus
static func _mk(title: String, text: Array, options: Array) -> Dictionary:
	return {"title": title, "text": text, "options": options, "nw": true, "who": "network"}

static func _back() -> Dictionary:
	return {"label": "Back to the network", "op": "nw_back", "arg": 0}

static func dc_of(p: Dictionary) -> int:
	return 10 + int(p["impl"])

## percent chance of 2d10 + bonus beating a DC (natural 2 always fails, 19-20 always work)
static func chance(bonus: int, dcv: int) -> int:
	var win := 0
	for a in range(1, 11):
		for b in range(1, 11):
			var nat: int = a + b
			if nat > 2 and (nat >= 19 or nat + bonus >= dcv):
				win += 1
	return win

static func ping_menu(g, p: Dictionary) -> Dictionary:
	var key: String = String(p["key"])
	var d: int = dist_to(g, p)
	var kind: String = String(p["kind"])
	if d > link_radius(g):
		return _mk(label(g, p), ["Too far to connect.  You must be within %d tiles of it (it is %d away)." % [link_radius(g), d]], [_back()])
	if not is_scanned(g, key):
		var bonus: int = lv(g) + g.lvl("analysis")
		var dcv: int = dc_of(p)
		return _mk("Unknown signal", ["Scan this object?", "Networking %d + Analysis %d: %d%% against DC %d.  Takes %s." % [lv(g), g.lvl("analysis"), chance(bonus, dcv), dcv, secs_text(obj_scan_seconds(g))]],
			[{"label": "Scan it", "op": "nw_scan", "arg": key}, _back()])
	if not is_linked(g, p):
		if kind == "camera" or kind == "light":
			var b: int = BD.board_for(g, int(p["cell"]))
			var cat := "cameras" if kind == "camera" else "lights"
			var dcv2: int = BD.dc(g, b, cat)
			return _mk(label(g, p), ["Take control of this %s?" % kind, "Analysis %d: %d%% against DC %d (its board's level %d).  Takes %s; a bad try can lock the %s group out or hurt." % [g.lvl("analysis"), BD.chance(g, dcv2), dcv2, int(BD.def_at(g, b).get("lvl", 1)), BD.min_text(g, BD.T_DEVICE), cat]],
				[{"label": "Network to it", "op": "nw_net", "arg": key}, _back()])
		var dcv3: int = dc_of(p)
		var txt := ["Network to %s?" % label(g, p), "Analysis %d: %d%% against DC %d.  Takes %s." % [g.lvl("analysis"), chance(g.lvl("analysis"), dcv3), dcv3, secs_text(net_seconds(g))]]
		if kind == "human":
			txt.append("A failure can alert them to you.")
		return _mk(label(g, p), txt, [{"label": "Network to it", "op": "nw_net", "arg": key}, _back()])
	return linked_menu(g, p)

static func linked_menu(g, p: Dictionary) -> Dictionary:
	var kind: String = String(p["kind"])
	var key: String = String(p["key"])
	match kind:
		"human":
			var opts: Array = []
			var txt := ["Networked.  Offensive nanohacks:"]
			for hid in g.nano_installed():
				var nd: Dictionary = NANO.get_def(String(hid))
				if NANO.is_offensive(nd):
					var lab: String
					if nd.has("damage"):
						lab = "%s: %d damage (base %d x %.2f)" % [nd["name"], power_damage(g, int(nd["damage"]), int(p["ana"])), int(nd["damage"]), power_mult(g, int(p["ana"]))]
					else:
						lab = "%s: %d kJ" % [nd["name"], int(ceil(g.nano_cost(String(hid))))]
					if int(g.nano_cd.get(String(hid), 0)) > 0:
						lab += "  (cooling down)"
					opts.append({"label": lab, "op": "nw_hack", "arg": [key, String(hid)]})
			if opts.is_empty():
				txt = ["Networked, but you have no offensive nanohack installed."]
			opts.append(_back())
			return _mk(label(g, p), txt, opts)
		"camera":
			return _mk(label(g, p), ["Linked to this camera."], [{"label": "View through it (%s)" % BD.min_text(g, BD.T_ACTION), "op": "nw_cam", "arg": key}, _back()])
		"light":
			var off: bool = BD.fixture_off(g, int(p["cell"])) if not g.city.has_meta("site") else BD.site_light_off(g, int(p["cell"]))
			return _mk(label(g, p), ["Linked to this light, which is %s." % ("off" if off else "on")],
				[{"label": "Switch it %s (%s)" % ["on" if off else "off", BD.min_text(g, BD.T_ACTION)], "op": "nw_light", "arg": key}, _back()])
		"board":
			var bc: int = int(p["cell"])
			BD.rec(g, bc)["conn"] = true
			return BD.open_menu(g, bc)
	return _back_menu()

static func _back_menu() -> Dictionary:
	return {}

static func _find(g, key: String) -> Dictionary:
	for p in g.net_snap.get("pings", []):
		if String(p["key"]) == key:
			return p
	return {}

## a menu choice; returns the next menu ({} closes it)
static func choose(g, m: Dictionary, k: int) -> Dictionary:
	if k < 0 or k >= m["options"].size():
		return m
	var o: Dictionary = m["options"][k]
	match String(o["op"]):
		"nw_back", "close":
			return {}
		"nw_scan":
			var p: Dictionary = _find(g, String(o["arg"]))
			return _do_scan(g, p)
		"nw_net":
			return _do_network(g, _find(g, String(o["arg"])))
		"nw_hack":
			return _do_hack(g, _find(g, String(o["arg"][0])), String(o["arg"][1]))
		"nw_cam":
			return _do_camera(g, _find(g, String(o["arg"])))
		"nw_light":
			return _do_light(g, _find(g, String(o["arg"])))
	return m

static func _do_scan(g, p: Dictionary) -> Dictionary:
	if p.is_empty() or not in_link_range(g, p):
		g.say("It is out of range.")
		return {}
	BD.spend_seconds(g, obj_scan_seconds(g))
	if g.game_over:
		return {}
	var dcv: int = dc_of(p)
	var nat: int = g._roll_2d10()
	var total: int = nat + lv(g) + g.lvl("analysis")
	g._math("Scan: 2d10 %d + Networking %d + Analysis %d = %d vs DC %d" % [nat, lv(g), g.lvl("analysis"), total, dcv])
	g.skill_up("networking", int(p["impl"]))
	if nat > 2 and (nat >= 19 or total >= dcv):
		scanned(g)[String(p["key"])] = true
		g.say("Scanned: %s." % label(g, p))
		return ping_menu(g, p)
	g.say("The scan slips off.  You can try again.")
	return ping_menu(g, p)

## the spot an alerted person goes to look: within 10 - their Implementation of you (exactly at you if that is 0 or less)
static func alert(g, p: Dictionary) -> void:
	if String(p["kind"]) != "human":
		return
	var i: int = int(p["npc"])
	if g.sim.alive[i] != 1:
		return
	var rad: int = ALERT_RADIUS - int(p["impl"])
	var spot: int = g.pc
	if rad > 0:
		var base: int = (g.pc / g.s2) * g.s2
		for _k in 40:
			var x: int = g.lx(g.pc) + g.rng.randi_range(-rad, rad)
			var y: int = g.ly(g.pc) + g.rng.randi_range(-rad, rad)
			if not g.in_bounds(x, y):
				continue
			var c: int = base + y * g.size + x
			if g.sim.walk[c] == 1:
				spot = c
				break
	g.astate[i] = g.SUSPICIOUS
	g.lastpos[i] = spot
	g.timer[i] = 25
	g.say("%s stirs: something is probing them, and they turn to look for you." % g.name_of(i))

static func _do_network(g, p: Dictionary) -> Dictionary:
	if p.is_empty() or not in_link_range(g, p):
		g.say("It is out of range.")
		return {}
	var kind: String = String(p["kind"])
	if kind == "camera" or kind == "light":
		var b: int = BD.board_for(g, int(p["cell"]))
		if b < 0:
			g.say("It is not on a board's network.")
			return ping_menu(g, p)
		var cat := "cameras" if kind == "camera" else "lights"
		if not BD.device_check(g, b, cat):
			return {} if g.game_over else ping_menu(g, p)
		g.net_links[String(p["key"])] = {"ctl": true}
		g.say("Linked.")
		return ping_menu(g, p)
	BD.spend_seconds(g, net_seconds(g))
	if g.game_over:
		return {}
	var dcv: int = dc_of(p)
	var nat: int = g._roll_2d10()
	var total: int = nat + g.lvl("analysis")
	g._math("Network: 2d10 %d + Analysis %d = %d vs DC %d" % [nat, g.lvl("analysis"), total, dcv])
	g.skill_up("analysis", int(p["impl"]))
	if nat > 2 and (nat >= 19 or total >= dcv):
		g.net_links[String(p["key"])] = {}
		g.say("[color=#7fe08a]Networked.[/color]")
		return ping_menu(g, p)
	if nat == 2:
		BD.hurt(g, maxi(0, (int(p["impl"]) - g.lvl("analysis")) * 10 - g.lvl("grit")))
		alert(g, p)
		g.say("The link recoils.")
		return {} if g.game_over else ping_menu(g, p)
	alert(g, p)
	if nat <= 6:
		g.say("The link fails.")
		return ping_menu(g, p)
	g.net_links[String(p["key"])] = {}
	g.say("You slip through, but it felt you.")
	return ping_menu(g, p)

static func _do_hack(g, p: Dictionary, hid: String) -> Dictionary:
	if p.is_empty() or not is_linked(g, p):
		g.say("The link is gone.")
		return {}
	g.act_nano_use(hid, int(p["npc"]), true)
	if g.sim.alive[int(p["npc"])] != 1 or g.game_over:
		g.net_links.erase(String(p["key"]))
	close(g)                                            # done: the screen goes down (the link stays; the N menu uses it)
	return {}

static func _do_camera(g, p: Dictionary) -> Dictionary:
	if p.is_empty() or not is_linked(g, p):
		g.say("The link is gone.")
		return {}
	var ca: Array = BD.camera_at(g, int(p["cell"]))
	if ca.is_empty():
		return {}
	BD.spend(g, BD.T_ACTION)
	if g.game_over:
		return {}
	close(g)
	g.cam_view = {"board": int(ca[0]), "i": int(ca[1]), "solo": true}
	g._compute_fov()
	return {}

static func _do_light(g, p: Dictionary) -> Dictionary:
	if p.is_empty() or not is_linked(g, p):
		g.say("The link is gone.")
		return {}
	BD.spend(g, BD.T_ACTION)
	if g.game_over:
		return {}
	if g.city.has_meta("site"):
		var dk: Dictionary = BD.dark(g)
		var k: String = BD.light_key_site(int(p["cell"]))
		if dk.has(k):
			dk.erase(k)
		else:
			dk[k] = true
	else:
		BD.fixture_toggle(g, int(p["cell"]))
	BD._relight(g)
	close(g)                                            # the job is done: the scan screen goes down with the menu so the game can be seen
	return {}
