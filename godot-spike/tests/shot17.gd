extends SceneTree
const MainScript = preload("res://src/main.gd")
func _initialize() -> void:
	var m = MainScript.new()
	m.save_prefix = "user://shot_save_"
	m.settings_path = "user://shot_settings.json"
	root.add_child(m)
	await process_frame
	m.begin_new(5)
	for i in 5:
		await process_frame
	var args := OS.get_cmdline_user_args()
	var w = m.world
	w.enter(Vector2i(0, 1))
	var g = w.game
	var t = g.transit
	var si: int = t.stop_names.find("Harbor Terminal")
	var guard := 0
	while t.turns_to(si) > 0 and guard < 3000:
		t.clock += 1
		guard += 1
	var mid: int = t.stop_cell(si)
	g.pc = mid + g.size * 2 - 3
	g.facing = Vector2i(0, -1)
	g.sim.retier(g.pc)
	g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
	m.game = g
	m.view.game = g
	m.screen.game = g
	for i in 1:
		g.end_turn()
		await process_frame
	g._compute_fov()
	m.view.queue_redraw()
	for i in 10:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(args[1] if args.size() > 1 else "/tmp/claude-0/shot_port.png")
	print("fac counts ", g.fac.count(0), g.fac.count(1), g.fac.count(4), " veh ", g.vehicles.size(), " ai ", g.vehicles.filter(func(v): return v["ai"]).size())
	print("cars ", g.transit.all_cars().size(), " mid ", mid, " pc ", g.pc, " dw ", g.transit.dwell_of(0), g.transit.dwell_of(1), g.transit.dwell_of(2), " vis ", g.transit.all_cars().map(func(c): return g.fov.visible[c[2]]))
	quit(0)
