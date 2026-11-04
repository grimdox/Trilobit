extends SceneTree
## The network screen goes down by itself when a job on it is done, and the view comes back to you.  Run: godot --headless -s tests/run_netscreen.gd
const MainScript = preload("res://src/main.gd")
const NW = preload("res://src/network.gd")
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
	var g = m.game
	g.implants["x303"] = true
	g._sync_pools()
	NW.build_snapshot(g)
	m.mode = "netscan"
	m.net_looking = true
	m.look_off = Vector2i(3, 2)
	m.refresh()
	check("on the network screen the view follows the cursor (it scrolls)", m.view.look_on and m.view.look_off == Vector2i(3, 2))
	NW.close(g)                                          # what a finished job does
	m.mode = "play"
	m.refresh()
	check("when the screen goes down the view returns to you: no look cursor, no offset", not m.view.look_on and m.view.look_off == Vector2i.ZERO and m.look_off == Vector2i.ZERO and not m.net_looking and m.mode == "play")
	# a hack on a linked person closes the screen
	var t := -1
	for i in g.sim.n:
		if g.sim.alive[i] == 1 and g.fac[i] != g.CIV:
			t = i
			break
	g.sim.place(t, g.pc + 2)
	g.net_links["h" + str(t)] = {}
	NW.build_snapshot(g)
	var p: Dictionary = NW.ping_at(g, g.pc + 2)
	check("the person is on the screen", not p.is_empty())
	if not p.is_empty():
		var chip = g._new_item("trl_nano_shock")
		g.inv.stow(chip)
		g.act_nano_install(chip, -1)
		g.power = g.power_cap()
		var res: Dictionary = NW._do_hack(g, p, "shock")
		check("a hack through the network closes the screen", res.is_empty() and g.net_snap.is_empty())
	print("NETSCREEN %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
