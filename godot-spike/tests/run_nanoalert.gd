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
	g.body.reset()
	g.skills["analysis"] = 5
	g.skills["implementation"] = 5
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
	# a clear row of floor, a wall between you and them: they are three tiles away and out of sight
	var base: int = (g.pc / g.s2) * g.s2
	var px: int = g.lx(g.pc)
	var py: int = g.ly(g.pc)
	for dx in range(-1, 6):
		for dy in [-1, 0, 1]:
			var cell: int = base + (py + dy) * g.size + px + dx
			g.city.tiles[cell] = CG.GROUND
			g.sim.walk[cell] = 1
	var wall: int = base + py * g.size + px + 2
	g.city.tiles[wall] = CG.WALL
	g.sim.walk[wall] = 0
	g.fov.opaque[wall] = 1
	var spot: int = base + py * g.size + px + 3
	g.sim.player = g.pc
	g.sim.place(target, spot)
	g.hpn[target] = 1000
	g.hpmax[target] = 1000
	g._npc_limbs_init(target)
	g.astate[target] = g.UNAWARE
	g.noticed_you[target] = 0
	g.face[target] = 0                                  # looking east, away from the player
	g._compute_fov()
	var unseen: bool = g.fov.visible[spot] == 0
	check("%s: the target starts unaware, three tiles off behind a wall" % hid, g.astate[target] == g.UNAWARE and g.cheb(g.sim.pos[target], g.pc) == 3 and unseen)
	g.net_links["h" + str(target)] = {}
	var used: bool = g.act_nano_use(hid, target, true)
	if not used:
		print("    log: ", g.log.slice(maxi(0, g.log.size() - 2)))
	check("%s: the hack runs through the link" % hid, used)
	var hp_pl: int = g.body.total()
	var st: int = g.astate[target]
	var lp: int = g.lastpos[target]
	print("    -> state %d (HUNTING = %d), told where you are: %s, noticed_you %d" % [st, g.HUNTING, str(lp == g.pc), g.noticed_you[target]])
	check("%s: the hacked enemy is now hunting" % hid, st == g.HUNTING)
	check("%s: and knows exactly where you stand" % hid, lp == g.pc)
	var d0: int = g.cheb(g.sim.pos[target], g.pc)
	for _t in 12:
		g._tick()
	var d1: int = g.cheb(g.sim.pos[target], g.pc)
	print("    -> distance %d after 12 turns (was %d); state %d; player hp lost %d; log %s" % [d1, d0, g.astate[target], hp_pl - g.body.total(), str(g.log.slice(maxi(0, g.log.size() - 3)))])
	check("%s: and goes after you: it closes in or opens fire (distance %d -> %d, you lost %d)" % [hid, d0, d1, hp_pl - g.body.total()], d1 < d0 or d1 <= 1 or g.body.total() < hp_pl)
