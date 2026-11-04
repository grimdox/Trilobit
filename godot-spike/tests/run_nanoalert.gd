extends SceneTree
## What an enemy does when it is nanohacked from outside its sight: it is alerted, goes HUNTING, and is told exactly where you are.
## Run: godot --headless -s tests/run_nanoalert.gd
const MainScript = preload("res://src/main.gd")
const WorldScript = preload("res://src/world.gd")
const NANO = preload("res://src/nanohacks.gd")
const BODY = preload("res://src/body.gd")
const NW = preload("res://src/network.gd")
const CG = preload("res://src/citygen.gd")
var ok := 0
var n := 0

func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name)

func _initialize() -> void:
	var m = MainScript.new()
	m.save_prefix = "user://test_save_"
	m.settings_path = "user://test_settings.json"
	root.add_child(m)
	await process_frame
	m.begin_new(5)
	for i in 30:
		await process_frame
	for hid in (OS.get_cmdline_user_args() if not OS.get_cmdline_user_args().is_empty() else ["shock", "impair"]):
		m.begin_new(5)
		for i in 30:
			await process_frame
		await _case(m.game, hid)
	print("NANOALERT %d/%d" % [ok, n])
	quit(0 if ok == n else 1)

func _put(g, base: int, px: int, py: int, dx: int, dy: int, kind: String) -> void:
	var c: int = base + (py + dy) * g.size + px + dx
	match kind:
		"wall":
			g.city.tiles[c] = CG.WALL
			g.sim.walk[c] = 0
			g.fov.opaque[c] = 1
		"floor":
			g.city.tiles[c] = CG.FLOOR
			g.sim.walk[c] = 1
			g.fov.opaque[c] = 0
		"door":
			g.city.tiles[c] = CG.DOOR
			g.sim.walk[c] = 1
			g.fov.opaque[c] = 0

func _rect(g, base: int, px: int, py: int, x0: int, y0: int, x1: int, y1: int, kind: String) -> void:
	for dy in range(y0, y1 + 1):
		for dx in range(x0, x1 + 1):
			_put(g, base, px, py, dx, dy, kind)

func _case(g, hid: String) -> void:
	g.implants = {"x303": true}
	g.nanos = []
	g.nano_fx = {}
	g.nano_cd = {}
	g.npc_fx = {}
	g.net_links = {}
	g._sync_pools()
	g.power = g.power_cap()
	g.skills["networking"] = 5
	g.skills["analysis"] = 5
	g.skills["implementation"] = 5
	g.body.reset()
	var c = g._new_item(NANO.chip_item(hid))
	g.inv.stow(c)
	g.act_nano_install(c, -1)
	var target := -1
	for i in g.sim.n:
		if g.sim.alive[i] == 1 and g.fac[i] != g.CIV and g.npc_implants(i).size() >= 2 and not g.npc_implants(i).filter(func(id): return BODY.PART_GROUP[g.IMP.get_def(id)["part"]] in ["arms", "legs"]).is_empty():
			target = i
			break
	if target < 0:
		check("%s: someone wired to test on" % hid, false)
		return
	# you are in room B (x -3..3, y 0..3).  The enemy is in room A above it (x -3..3, y -5..-2) with three doors:
	#   east (4,-4) to an empty closet, north (0,-6) to another empty closet, and south (-3,-1) down into your room.
	var base: int = (g.pc / g.s2) * g.s2
	var px: int = g.lx(g.pc)
	var py: int = g.ly(g.pc)
	_rect(g, base, px, py, -10, -11, 10, 6, "wall")
	_rect(g, base, px, py, -3, 0, 3, 3, "floor")
	_rect(g, base, px, py, -3, -5, 3, -2, "floor")
	_rect(g, base, px, py, 5, -5, 6, -3, "floor")
	_rect(g, base, px, py, -1, -8, 1, -7, "floor")
	_put(g, base, px, py, 4, -4, "door")
	_put(g, base, px, py, 0, -6, "door")
	_put(g, base, px, py, -3, -1, "door")
	var spot: int = base + (py - 3) * g.size + px + 3
	g.pc = base + (py + 3) * g.size + px - 2              # you stand at the back of room B, in line with the south door
	g.sim.player = g.pc
	g.sim.place(target, spot)
	g.hpn[target] = 1000
	g.hpmax[target] = 1000
	g._npc_limbs_init(target)
	g.gunc[target] = 0                                  # unarmed, so nothing is shot through the doorway
	g.astate[target] = g.UNAWARE
	g.noticed_you[target] = 0
	g._compute_fov()
	check("%s: the target starts unaware in the room next door, out of sight" % hid, g.astate[target] == g.UNAWARE and g.fov.visible[spot] == 0 and g.fov.around[spot] == 0)
	g.net_links["h" + str(target)] = {}
	var used: bool = g.act_nano_use(hid, target, true)
	check("%s: the hack runs through the link" % hid, used)
	check("%s: the hacked enemy goes searching, not hunting, and is not told where you are" % hid, g.astate[target] == g.SEARCHING and g.lastpos[target] != g.pc and g.dsearch.has(target))
	var doors: Array = []                                # the doors they stand in, in order
	var found_at := -1
	for t in 150:
		g._tick()
		var pos: int = g.sim.pos[target]
		if g._is_door_cell(pos) and (doors.is_empty() or doors[doors.size() - 1] != pos):
			doors.append(pos)
		if g.astate[target] == g.HUNTING:
			found_at = t
			break
	var rel: Array = doors.map(func(d): return Vector2i(g.lx(d) - px, g.ly(d) - py))
	print("    -> doors visited in order (relative to you): ", rel, "; found you after ", found_at, " turns")
	check("%s: they check the nearest door first (east closet), then the next off the same room (north closet)" % hid, rel.size() >= 2 and rel[0] == Vector2i(4, -4) and rel[1] == Vector2i(0, -6))
	check("%s: they look behind the empty doors before the one to your room, and then find you" % hid, rel.size() >= 3 and rel[2] == Vector2i(-3, -1) and found_at >= 0)
