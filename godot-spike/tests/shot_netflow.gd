extends SceneTree
const MainScript = preload("res://src/main.gd")
const NW = preload("res://src/network.gd")
func key(m, k: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	m._unhandled_key_input(ev)
func _initialize() -> void:
	var m = MainScript.new()
	m.save_prefix = "user://test_save_"
	m.settings_path = "user://test_settings.json"
	root.add_child(m)
	await process_frame
	m.begin_scenario("nano_test")
	for i in 120:
		await process_frame
	var g = m.game
	print("mode ", m.mode, " site ", g.city.has_meta("site"))
	var t := -1
	for i in g.sim.n:
		if g.sim.alive[i] == 1 and g.fac[i] != g.CIV and g.npc_implants(i).size() >= 2:
			t = i
			break
	g.sim.place(t, g.pc + 2)
	g.hpn[t] = 1000
	g.hpmax[t] = 1000
	g._npc_limbs_init(t)
	g.net_links["h" + str(t)] = {}
	for h in range(1):
		g.power = g.power_cap()
		g.nano_cd = {}
		NW.build_snapshot(g)
		NW.scanned(g)["h" + str(t)] = true
		m.mode = "netscan"
		m.net_looking = true
		m.look_off = Vector2i(2, 0)
		m.view.look_on = true
		m.view.look_off = Vector2i(2, 0)
		m.refresh()
		key(m, KEY_ENTER)
		for i in 20:
			await process_frame
		var opts: Array = (m.menu.get("options", []) as Array).map(func(o): return o["label"])
		key(m, KEY_1 + h)
		await process_frame
		await process_frame
		print("hack ", h, " opts ", opts, " -> mode ", m.mode, " menu empty ", m.menu.is_empty(), " panel ", m.panel.visible, " term '", m.term.style, "' snap ", g.net_snap.size(), " look_on ", m.view.look_on, " alive ", g.sim.alive[t], " fx ", g.npc_fx.get(t, {}).keys())
		g.net_links["h" + str(t)] = {}
		for i in 30:
			await process_frame
		root.get_texture().get_image().save_png("/tmp/claude-0/shot_afterhack.png")
		print("final: mode ", m.mode, " term '", m.term.style, "' snap ", g.net_snap.size(), " panel ", m.panel.visible)
	quit()
