extends RefCounted
## Control Boards and Cameras: the electrical side of a building.  A board (a wall unit on a floor tile) runs everything electronic in its building:
## cameras and lights today; androids, terminals and static defences are listed but wait for the nanohack system.
##   1. Connect (Networking, once per board, no roll): 60 s minus 6 s a level; trains Networking.
##   2. Entry: the administration password.  2d10 + Analysis against 10 + board level (+1 for each failure that made it harder).
##   3. Control: choose a device group (another roll, the same way), then use it.  Every step takes time (Networking cuts it 10% a level).
## Implementation is never in a roll; it only softens what a failed hack does to you.
## State: g.boards["cb<cell>"] per board {conn, hard, acc, lock{cat: tick}, dh{cat: n}, sw{cam cell: waits}}; g.boards["cb_dark"] the switched-off lights.
## Placement (what exists in a building) is in city.cb_defs, built from the seed: {board cell: {lvl, kind, tower, cams[], lights[]}}.
const CG = preload("res://src/citygen.gd")
const CLK = preload("res://src/clock.gd")

const DIRS := [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]
const SWEEP := [-1, -2, -1, 0, 1, 2, 1, 0]            # a mobile camera's turn (in 45 degree steps) after each wait: left twice, right four times, back to the middle
const CAM_RANGE := 12
const CAM_ARC := 90.0
const CATS := ["cameras", "lights", "androids", "terminals", "defenses"]
const CAT_NAME := {"cameras": "Cameras", "lights": "Lights", "androids": "Androids", "terminals": "Mission Terminals & Job Boards", "defenses": "Static Defenses"}
const CAT_LIVE := ["cameras", "lights"]
const T_PASSWORD := 5.0                                # minutes at Networking 0
const T_DEVICE := 2.0
const T_ACTION := 1.0
const CONNECT_SEC := 60.0
const CONNECT_SEC_PER := 6.0
const LOCK_TURNS := 100                                # ten minutes
const PAGE := 6

## ---------------------------------------------------------------------------------------------------------------- state
static func defs(g) -> Dictionary:
	return g.city.cb_defs

static func def_at(g, cell: int) -> Dictionary:
	return g.city.cb_defs.get(cell, {})

static func rec(g, cell: int) -> Dictionary:
	var k := "cb" + str(cell)
	if not g.boards.has(k):
		g.boards[k] = {"conn": false, "hard": 0, "acc": false, "lock": {}, "dh": {}, "sw": {}}
	return g.boards[k]

static func dark(g) -> Dictionary:
	if not g.boards.has("cb_dark"):
		g.boards["cb_dark"] = {}
	return g.boards["cb_dark"]

## a switched-off light: a site light by its cell, a tower floor by tower_no * 64 + floor
static func light_key_site(cell: int) -> String:
	return "s" + str(cell)

static func light_key_floor(tower_no: int, z: int) -> String:
	return "f%d_%d" % [tower_no, z]

static func site_light_off(g, cell: int) -> bool:
	var d = g.boards.get("cb_dark")
	return d != null and not d.is_empty() and d.has(light_key_site(cell))

## the tower floor the cell is on is switched off at its board
static func floor_off(g, cell: int) -> bool:
	var d = g.boards.get("cb_dark")
	if d == null or d.is_empty():
		return false
	var z: int = cell / g.s2
	var x: int = (cell % g.s2) % g.size
	var y: int = (cell % g.s2) / g.size
	for t in g.city.tower_info:
		if x >= int(t["x0"]) and x <= int(t["x1"]) and y >= int(t["y0"]) and y <= int(t["y1"]):
			return d.has(light_key_floor(int(t["no"]), z))
	return false

## ---------------------------------------------------------------------------------------------------------------- time and rolls
static func time_mult(g) -> float:
	return maxf(0.0, 1.0 - 0.1 * float(g.lvl("networking")))

## let minutes (at Networking 0) go by, world and all
static func spend(g, minutes: float) -> void:
	var left: int = int(round(minutes * float(CLK.MIN) * time_mult(g)))
	while left > 0 and not g.game_over:
		g._tick()
		left -= 1
		if bool(g.mission.get("timeup", false)):
			break

static func connect_seconds(g) -> float:
	return maxf(0.0, CONNECT_SEC - CONNECT_SEC_PER * float(g.lvl("networking")))

static func spend_seconds(g, secs: float) -> void:
	var left: int = int(round(secs / 6.0))
	while left > 0 and not g.game_over:
		g._tick()
		left -= 1

static func min_text(g, minutes: float) -> String:
	var s: float = minutes * 60.0 * time_mult(g)
	if s <= 0.5:
		return "instant"
	if s < 90.0:
		return "%d s" % int(round(s))
	return "%.1f min" % (s / 60.0)

## the DC for a step: 10 + the board's level + one for every failure that made it harder
static func dc(g, cell: int, cat: String = "") -> int:
	var d: Dictionary = def_at(g, cell)
	var r: Dictionary = rec(g, cell)
	var extra: int = int(r["hard"]) if cat == "" else int((r["dh"] as Dictionary).get(cat, 0))
	return 10 + int(d.get("lvl", 1)) + extra

## [ok, nat, total]: a natural 2 always fails, 19 and 20 always work
static func roll(g, dcv: int) -> Array:
	var nat: int = g._roll_2d10()
	var total: int = nat + g.lvl("analysis")
	var ok: bool = nat > 2 and (nat >= 19 or total >= dcv)
	return [ok, nat, total]

static func chance(g, dcv: int) -> int:
	var win := 0
	for a in range(1, 11):
		for b in range(1, 11):
			var nat: int = a + b
			if nat > 2 and (nat >= 19 or nat + g.lvl("analysis") >= dcv):
				win += 1
	return win

## damage to the head: Grit takes off, armour does not
static func hurt(g, amount: int) -> void:
	if amount <= 0:
		return
	g.say("[color=#ff6a6a]The board's counter-hack burns through your implants: %d damage to the head.[/color]" % amount)
	g._limb_hit("head", amount)

## "(base - Grit) x (level - Implementation)": the multiplier clamps at nothing, but the password's first two failures take a flat 10 when it would be negative
static func burn(g, base: int, lv: int, flat_if_negative: bool) -> int:
	var grit: int = g.lvl("grit")
	var impl: int = g.lvl("implementation")
	var m: int = lv - impl
	if m < 0:
		return 10 if flat_if_negative else 0
	return maxi(0, base - grit) * m

static func alarm(g, cell: int) -> void:
	g.say("[color=#ff6a6a]An alarm sounds![/color]")
	g.sfx("blip")
	var lvl_base: int = (cell / g.s2) * g.s2
	var site: bool = g.city.has_meta("site")
	var t: Dictionary = {} if site else g.tower_at(cell)
	var n := 0
	for i in g.sim.n:
		if g.sim.alive[i] != 1 or not g.hostile(i):
			continue
		var p: int = g.sim.pos[i]
		if site:
			pass
		elif not t.is_empty():
			var x: int = (p % g.s2) % g.size
			var y: int = (p % g.s2) / g.size
			if x < int(t["x0"]) or x > int(t["x1"]) or y < int(t["y0"]) or y > int(t["y1"]):
				continue
		elif g.cheb(p, cell) > 30 or (p / g.s2) != (cell / g.s2):
			continue
		g.astate[i] = g.SUSPICIOUS
		g.lastpos[i] = cell
		g.timer[i] = 25
		n += 1
	if n > 0:
		g.say("Somewhere in the building, people turn towards the board.")

## ---------------------------------------------------------------------------------------------------------------- the front end's entry points
static func board_name(g, cell: int) -> String:
	var d: Dictionary = def_at(g, cell)
	return "Control Board (level %d)" % int(d.get("lvl", 1))

## X beside a board: the first screen it needs
static func open_menu(g, cell: int) -> Dictionary:
	var r: Dictionary = rec(g, cell)
	if not bool(r["conn"]):
		return _connect_menu(g, cell)
	if not bool(r["acc"]):
		return _password_menu(g, cell)
	return _control_menu(g, cell)

static func _mk(g, cell: int, title: String, text: Array, options: Array) -> Dictionary:
	return {"title": title, "text": text, "options": options, "bd": cell, "who": "board"}

static func _connect_menu(g, cell: int) -> Dictionary:
	var txt := ["A wall unit with a screen and a dull green cursor.  It runs the electronics of this building.",
		"You have not linked to it yet (Networking, no roll, once for this board).  Takes %d s." % int(round(connect_seconds(g)))]
	return _mk(g, cell, board_name(g, cell), txt, [{"label": "Connect", "op": "bd_connect", "arg": cell}, {"label": "Walk away", "op": "close", "arg": 0}])

static func _password_menu(g, cell: int) -> Dictionary:
	var dcv: int = dc(g, cell)
	var r: Dictionary = rec(g, cell)
	var txt := ["Administration password required.",
		"Firewall DC %d%s.  Your Analysis %d: %d%% to get in.  Takes %s." % [dcv, ("  (+%d from failed tries)" % int(r["hard"])) if int(r["hard"]) > 0 else "", g.lvl("analysis"), chance(g, dcv), min_text(g, T_PASSWORD)],
		"A failed try can hurt: Grit and Implementation soften it, armour does not."]
	return _mk(g, cell, board_name(g, cell), txt, [{"label": "Enter the password", "op": "bd_password", "arg": cell}, {"label": "Walk away", "op": "close", "arg": 0}])

static func _unlocked(g, cell: int) -> Dictionary:
	if not g.has_meta("cb_open"):
		g.set_meta("cb_open", {})
	var m: Dictionary = g.get_meta("cb_open")
	if not m.has(cell):
		m[cell] = {}
	return m[cell]

static func _lock_left(g, cell: int, cat: String) -> int:
	var until: int = int((rec(g, cell)["lock"] as Dictionary).get(cat, 0))
	return maxi(0, until - g.sim.tick)

static func _control_menu(g, cell: int) -> Dictionary:
	var op := _unlocked(g, cell)
	var d: Dictionary = def_at(g, cell)
	var txt := ["Logged in.  Choose a device group (each one is another check against your Analysis, %s each)." % min_text(g, T_DEVICE)]
	var opts: Array = []
	for cat in CATS:
		var label: String = CAT_NAME[cat]
		if not CAT_LIVE.has(cat):
			label = "(offline)  " + label
		else:
			var n: int = (d.get("cams", []) as Array).size() if cat == "cameras" else (lights_of(g, cell) as Array).size()
			label += "  (%d)" % n
			var left: int = _lock_left(g, cell, cat)
			if left > 0:
				label += "  LOCKED OUT %d min" % int(ceil(float(left) / float(CLK.MIN)))
			elif op.has(cat):
				label += "  [open]"
		opts.append({"label": label, "op": "bd_cat", "arg": [cell, cat]})
	opts.append({"label": "Log off", "op": "close", "arg": 0})
	return _mk(g, cell, board_name(g, cell), txt, opts)

static func _page_nav(opts: Array, cell: int, cat: String, page: int, total: int) -> void:
	if page > 0:
		opts.append({"label": "Previous page", "op": "bd_page", "arg": [cell, cat, page - 1]})
	if (page + 1) * PAGE < total:
		opts.append({"label": "Next page", "op": "bd_page", "arg": [cell, cat, page + 1]})
	opts.append({"label": "Back to the control screen", "op": "bd_back", "arg": cell})

static func cameras_menu(g, cell: int, page: int = 0) -> Dictionary:
	var cams: Array = def_at(g, cell).get("cams", [])
	var opts: Array = []
	for k in range(page * PAGE, mini(cams.size(), (page + 1) * PAGE)):
		var cm: Dictionary = cams[k]
		opts.append({"label": "%s  [%s]" % [cm["name"], "mobile" if bool(cm["mobile"]) else "fixed"], "op": "bd_cam", "arg": [cell, k]})
	_page_nav(opts, cell, "cameras", page, cams.size())
	return _mk(g, cell, "Cameras", ["%d cameras on this board.  Switching to one takes %s." % [cams.size(), min_text(g, T_ACTION)],
		"In a camera: Left/Right (4/6) the next/previous camera, Down (5) wait a turn, Up/Esc (8) back out."], opts)

## the lights a board runs: [{key, name, cell}]  (a site's lights or a tower's floors)
static func lights_of(g, cell: int) -> Array:
	var d: Dictionary = def_at(g, cell)
	var out: Array = []
	if d.get("kind", "") == "site":
		g.light._site_build()
		var k := 1
		for L in g.light._site_lights:
			out.append({"key": light_key_site(int(L[0])), "name": "Light %d" % k, "cell": int(L[0])})
			k += 1
	else:
		var tn: int = int(d["tower"])
		for z in int(d["floors"]):
			out.append({"key": light_key_floor(tn, z), "name": "Lobby" if z == 0 else "Floor %d" % z, "cell": -1})
	return out

static func lights_menu(g, cell: int, page: int = 0) -> Dictionary:
	var ls: Array = lights_of(g, cell)
	var dk: Dictionary = dark(g)
	var opts: Array = [{"label": "All on", "op": "bd_all", "arg": [cell, true]}, {"label": "All off", "op": "bd_all", "arg": [cell, false]}]
	var per := PAGE - 2
	for k in range(page * per, mini(ls.size(), (page + 1) * per)):
		var L: Dictionary = ls[k]
		var broken: bool = L["cell"] >= 0 and g.dead_lights.has(int(L["cell"]))
		opts.append({"label": "%s:  %s" % [L["name"], "BROKEN" if broken else ("off" if dk.has(L["key"]) else "on")], "op": "bd_light", "arg": [cell, k]})
	if page > 0:
		opts.append({"label": "Previous page", "op": "bd_page", "arg": [cell, "lights", page - 1]})
	if (page + 1) * per < ls.size():
		opts.append({"label": "Next page", "op": "bd_page", "arg": [cell, "lights", page + 1]})
	opts.append({"label": "Back to the control screen", "op": "bd_back", "arg": cell})
	return _mk(g, cell, "Lights", ["%d lights.  Each switch takes %s." % [ls.size(), min_text(g, T_ACTION)]], opts)

static func _relight(g) -> void:
	if g.light != null:
		g.light.invalidate()
	g._compute_fov()

## a menu choice; returns the next menu ({} closes it)
static func choose(g, m: Dictionary, k: int) -> Dictionary:
	if k < 0 or k >= m["options"].size():
		return m
	var o: Dictionary = m["options"][k]
	var cell: int = int(m["bd"])
	match String(o["op"]):
		"close":
			if g.has_meta("cb_open"):
				(g.get_meta("cb_open") as Dictionary).erase(cell)
			return {}
		"bd_connect":
			g.say("You link to the board...")
			spend_seconds(g, connect_seconds(g))
			rec(g, cell)["conn"] = true
			g.skill_up("networking", 2)
			g.say("Linked.  The board asks for its administration password.")
			return _password_menu(g, cell)
		"bd_password":
			return _try_password(g, cell)
		"bd_cat":
			return _try_category(g, cell, String(o["arg"][1]))
		"bd_back":
			return _control_menu(g, cell)
		"bd_page":
			var a: Array = o["arg"]
			return cameras_menu(g, cell, int(a[2])) if String(a[1]) == "cameras" else lights_menu(g, cell, int(a[2]))
		"bd_cam":
			return _use_camera(g, cell, int(o["arg"][1]))
		"bd_light":
			var ls: Array = lights_of(g, cell)
			var L: Dictionary = ls[int(o["arg"][1])]
			spend(g, T_ACTION)
			var dk: Dictionary = dark(g)
			if dk.has(L["key"]):
				dk.erase(L["key"])
				g.say("%s on." % L["name"])
			else:
				dk[L["key"]] = true
				g.say("%s off." % L["name"])
			_relight(g)
			return lights_menu(g, cell, int(int(o["arg"][1]) / (PAGE - 2)))
		"bd_all":
			spend(g, T_ACTION)
			var dk2: Dictionary = dark(g)
			for L2 in lights_of(g, cell):
				if bool(o["arg"][1]):
					dk2.erase(L2["key"])
				else:
					dk2[L2["key"]] = true
			g.say("All lights %s." % ("on" if bool(o["arg"][1]) else "off"))
			_relight(g)
			return lights_menu(g, cell, 0)
	return m

static func _try_password(g, cell: int) -> Dictionary:
	var r: Dictionary = rec(g, cell)
	var lv: int = int(def_at(g, cell).get("lvl", 1))
	spend(g, T_PASSWORD)
	if g.game_over:
		return {}
	var dcv: int = dc(g, cell)
	var res: Array = roll(g, dcv)
	g._math("Password: 2d10 %d + Analysis %d = %d vs DC %d" % [res[1], g.lvl("analysis"), res[2], dcv])
	g.skill_up("analysis", lv + int(r["hard"]))
	if bool(res[0]):
		r["acc"] = true
		g.say("[color=#7fe08a]The password gives way.  You are in.[/color]")
		return _control_menu(g, cell)
	var nat: int = int(res[1])
	g.say("The password fails.")
	var alarmed := false
	if nat == 2:
		hurt(g, burn(g, 30, lv, true))
	elif nat <= 5:
		hurt(g, burn(g, 10, lv, true))
		alarmed = true
	elif nat <= 7:
		hurt(g, maxi(0, lv - (g.lvl("grit") + g.lvl("implementation"))))
		alarmed = true
	elif nat == 8:
		r["hard"] = int(r["hard"]) + 1
		alarmed = true
		g.say("The board hardens against you (+1).")
	else:
		r["hard"] = int(r["hard"]) + 1
		g.say("The board hardens against you (+1).")
	if alarmed:
		alarm(g, cell)
	if g.game_over:
		return {}
	return _password_menu(g, cell)

static func _try_category(g, cell: int, cat: String) -> Dictionary:
	var r: Dictionary = rec(g, cell)
	if not CAT_LIVE.has(cat):
		g.say("%s are not on the network yet." % CAT_NAME[cat])
		return _control_menu(g, cell)
	var left: int = _lock_left(g, cell, cat)
	if left > 0:
		g.say("%s are locked out for %d more minutes." % [CAT_NAME[cat], int(ceil(float(left) / float(CLK.MIN)))])
		return _control_menu(g, cell)
	var op := _unlocked(g, cell)
	if not op.has(cat):
		var lv: int = int(def_at(g, cell).get("lvl", 1))
		spend(g, T_DEVICE)
		if g.game_over:
			return {}
		var dcv: int = dc(g, cell, cat)
		var res: Array = roll(g, dcv)
		g._math("%s: 2d10 %d + Analysis %d = %d vs DC %d" % [CAT_NAME[cat], res[1], g.lvl("analysis"), res[2], dcv])
		g.skill_up("analysis", lv + int((r["dh"] as Dictionary).get(cat, 0)))
		if not bool(res[0]):
			var nat: int = int(res[1])
			if nat == 2:
				hurt(g, maxi(0, 10 - g.lvl("grit")) * maxi(0, lv - g.lvl("implementation")))
				g.say("The %s group throws you out." % CAT_NAME[cat].to_lower())
			elif nat <= 7:
				(r["lock"] as Dictionary)[cat] = g.sim.tick + LOCK_TURNS
				hurt(g, maxi(0, lv - g.lvl("grit") - g.lvl("implementation")))
				g.say("The %s group locks you out for 10 minutes." % CAT_NAME[cat].to_lower())
			else:
				(r["dh"] as Dictionary)[cat] = int((r["dh"] as Dictionary).get(cat, 0)) + 1
				g.say("The %s group hardens against you (+1 to try again)." % CAT_NAME[cat].to_lower())
			if g.game_over:
				return {}
			return _control_menu(g, cell)
		op[cat] = true
	return cameras_menu(g, cell) if cat == "cameras" else lights_menu(g, cell)

## ---------------------------------------------------------------------------------------------------------------- camera view
static func cam_face(g, cell: int, cam: Dictionary) -> int:
	var n: int = int((rec(g, cell)["sw"] as Dictionary).get(str(cam["cell"]), 0))
	var f: int = int(cam["face"])
	if bool(cam["mobile"]) and n > 0:
		f += int(SWEEP[(n - 1) % 8])
	return posmod(f, 8)

## the tile the camera looks out from: one step in the way it faces (its own tile if that is blocked)
static func cam_origin(g, cell: int, cam: Dictionary) -> int:
	var d: Vector2i = DIRS[cam_face(g, cell, cam)]
	var cc: int = int(cam["cell"])
	var x: int = (cc % g.s2) % g.size + d.x
	var y: int = (cc % g.s2) / g.size + d.y
	if not g.in_bounds(x, y):
		return cc
	var o: int = (cc / g.s2) * g.s2 + y * g.size + x
	if g.sim.walk[o] == 0 or g.sim.opaque[o] == 1:
		return cc
	return o

static func _use_camera(g, cell: int, k: int) -> Dictionary:
	var cams: Array = def_at(g, cell).get("cams", [])
	if k < 0 or k >= cams.size():
		return cameras_menu(g, cell)
	spend(g, T_ACTION)
	if g.game_over:
		return {}
	g.cam_view = {"board": cell, "i": k}
	g._compute_fov()
	return {}

## in a camera: next (+1) or previous (-1)
static func cam_switch(g, step: int) -> void:
	var cell: int = int(g.cam_view["board"])
	var cams: Array = def_at(g, cell).get("cams", [])
	if cams.size() < 2:
		g.say("This is the only camera on the board.")
		return
	spend(g, T_ACTION)
	if g.cam_view.is_empty() or g.game_over:
		return
	g.cam_view["i"] = posmod(int(g.cam_view["i"]) + step, cams.size())
	g._compute_fov()

## in a camera: wait a turn (a mobile camera sweeps)
static func cam_wait(g) -> void:
	var cell: int = int(g.cam_view["board"])
	var cam: Dictionary = def_at(g, cell)["cams"][int(g.cam_view["i"])]
	if bool(cam["mobile"]):
		var sw: Dictionary = rec(g, cell)["sw"]
		sw[str(cam["cell"])] = int(sw.get(str(cam["cell"]), 0)) + 1
	g._tick()
	g._compute_fov()

static func cam_end(g) -> Dictionary:
	var cell: int = int(g.cam_view["board"])
	g.cam_view = {}
	g._compute_fov()
	return _control_menu(g, cell)

static func cam_current(g) -> Dictionary:
	if g.cam_view.is_empty():
		return {}
	var cams: Array = def_at(g, int(g.cam_view["board"])).get("cams", [])
	return cams[int(g.cam_view["i"])]

## ---------------------------------------------------------------------------------------------------------------- placement
## a floor cell with a wall at its side and clear of doors, stairs and lifts, so a unit stands there without blocking anything
static func wall_spot(c, cell: int, size: int, s2: int) -> bool:
	var t: int = c.tiles[cell]
	if not CG.is_floor(t):
		return false
	var x: int = (cell % s2) % size
	var y: int = (cell % s2) / size
	if x < 2 or y < 2 or x >= size - 2 or y >= size - 2:
		return false
	var walls := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var n: int = c.tiles[cell + dy * size + dx]
			if n == CG.DOOR or n == CG.LOCKED or n == CG.STAIRS or n == CG.ELEVATOR or n == CG.TID["door_closed"] or n >= CG.EXTRA0 and not CG.is_floor(n):
				return false
			if (dx == 0 or dy == 0) and n == CG.WALL:
				walls += 1
	return walls >= 1

static func _face_for(c, cell: int, size: int, s2: int, rng: RandomNumberGenerator) -> int:
	var best := -1
	var best_run := -1
	for k in [0, 2, 4, 6]:
		var d: Vector2i = DIRS[k]
		var run := 0
		var x: int = (cell % s2) % size
		var y: int = (cell % s2) / size
		for _s in 12:
			x += d.x
			y += d.y
			if x < 0 or y < 0 or x >= size or y >= size:
				break
			var t: int = c.tiles[(cell / s2) * s2 + y * size + x]
			if not (CG.is_floor(t) or t == CG.DOOR or t == CG.TID["camera_fixed"] or t == CG.TID["camera_mobile"]):
				break
			run += 1
		var score: int = run * 4 + rng.randi_range(0, 3)
		if score > best_run:
			best_run = score
			best = k
	return best

static func _put(c, cell: int, tile_name: String, size: int, s2: int, extra_tiles = null) -> void:
	if cell < s2:
		c.under[cell] = c.tiles[cell]
	c.tiles[cell] = CG.TID[tile_name]

static func _cam_entry(c, cell: int, size: int, s2: int, rng: RandomNumberGenerator, num: int, label: String) -> Dictionary:
	var mobile: bool = rng.randi() % 2 == 0
	var face: int = _face_for(c, cell, size, s2, rng)
	_put(c, cell, "camera_mobile" if mobile else "camera_fixed", size, s2)
	return {"cell": cell, "mobile": mobile, "face": face, "name": "Camera %02d - %s" % [num, label]}

## the board level a district rates: poor 1-2, middle 2-3, rich 4-5
static func level_for_wealth(w: int, rng: RandomNumberGenerator) -> int:
	match clampi(w, 0, 2):
		0: return rng.randi_range(1, 2)
		1: return rng.randi_range(2, 3)
	return rng.randi_range(4, 5)

## every downtown tower gets a board in its lobby, a pair of cameras there and one on every floor beside the stairs
static func place_city(g) -> void:
	var c = g.city
	c.cb_defs = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = (g.seed_value ^ 0xb0a4d) + g.zone.x * 977 + g.zone.y * 131
	var size: int = c.size
	var s2: int = size * size
	for t in c.tower_info:
		var h: int = int(t["h"])
		var door: Vector2i = t["door"] if t["door"] is Vector2i else Vector2i(int(t["x0"]), int(t["y0"]))
		var cands: Array = []
		for y in range(int(t["y0"]) + 1, int(t["y1"])):
			for x in range(int(t["x0"]) + 1, int(t["x1"])):
				var cell: int = y * size + x
				if wall_spot(c, cell, size, s2):
					cands.append([maxi(absi(x - door.x), absi(y - door.y)), cell])
		if cands.is_empty():
			continue
		cands.sort_custom(func(a, b): return a[0] < b[0])
		var pick := -1
		for e in cands:
			if int(e[0]) >= 3:
				pick = int(e[1])
				break
		if pick < 0:
			pick = int(cands[0][1])
		var wealth: int = c.wealth_at(((int(t["y0"]) + int(t["y1"])) / 2) * size + (int(t["x0"]) + int(t["x1"])) / 2)
		var d := {"kind": "tower", "tower": int(t["no"]), "lvl": level_for_wealth(wealth, rng), "floors": h, "cams": []}
		_put(c, pick, "control_board", size, s2)
		# the lobby's cameras
		var num := 1
		var used: Array = [pick]
		for e in cands:
			var cc: int = int(e[1])
			if cc == pick or used.size() >= 3:
				continue
			var far := true
			for u in used:
				if g.cheb(cc, int(u)) < 5:
					far = false
			if not far:
				continue
			(d["cams"] as Array).append(_cam_entry(c, cc, size, s2, rng, num, "Lobby"))
			used.append(cc)
			num += 1
		# a camera on each floor, close to the stairs
		var st: int = int(t["stairs"])
		for z in range(1, h):
			var base: int = z * s2
			var sx: int = (st % s2) % size
			var sy: int = (st % s2) / size
			var found := -1
			var best := 99
			for dy in range(-4, 5):
				for dx in range(-4, 5):
					var dd: int = maxi(absi(dx), absi(dy))
					if dd < 2 or dd >= best:
						continue
					var x2: int = sx + dx
					var y2: int = sy + dy
					if x2 < int(t["x0"]) + 1 or x2 >= int(t["x1"]) or y2 < int(t["y0"]) + 1 or y2 >= int(t["y1"]):
						continue
					var cell2: int = base + y2 * size + x2
					if wall_spot(c, cell2, size, s2):
						found = cell2
						best = dd
			if found >= 0:
				(d["cams"] as Array).append(_cam_entry(c, found, size, s2, rng, num, "Floor %d" % z))
				num += 1
		c.cb_defs[pick] = d
	# the simulation reads its own copies of the map
	for cell in c.cb_defs:
		g.sim.tiles[int(cell)] = c.tiles[int(cell)]
		g.sim.walk[int(cell)] = 0
		for cm in c.cb_defs[cell]["cams"]:
			g.sim.tiles[int(cm["cell"])] = c.tiles[int(cm["cell"])]

## a mission or a job: one board in a room (the level of the opposition for a mission, 1 for a temp job) and a camera in up to three other rooms
static func place_site(c, rng: RandomNumberGenerator, inner: Array, used: Dictionary, S: int, o: Dictionary, temp: bool) -> void:
	c.cb_defs = {}
	if inner.is_empty():
		return
	var lo: int = int((o["lv"] as Array)[0])
	var hi: int = int((o["lv"] as Array)[1])
	var lvl: int = 1 if temp else maxi(1, rng.randi_range(mini(lo, hi), maxi(lo, hi)))
	var order: Array = range(inner.size())
	for i in range(order.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	var board := -1
	var cams: Array = []
	var num := 1
	for ri in order:
		var r: Rect2i = inner[ri]
		var spot := -1
		for _k in 60:
			var x: int = rng.randi_range(r.position.x, r.end.x - 1)
			var y: int = rng.randi_range(r.position.y, r.end.y - 1)
			var cell: int = y * S + x
			if not used.has(cell) and wall_spot(c, cell, S, S * S):
				spot = cell
				break
		if spot < 0:
			continue
		used[spot] = true
		if board < 0:
			board = spot
			_put(c, spot, "control_board", S, S * S)
		elif cams.size() < 3:
			cams.append(_cam_entry(c, spot, S, S * S, rng, num, "Room %d" % (num)))
			num += 1
	if board >= 0:
		c.cb_defs[board] = {"kind": "site", "lvl": lvl, "cams": cams}
