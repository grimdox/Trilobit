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
	var dy := int(args[0]) if args.size() > 0 else 0
	var w = m.world
	w.enter(Vector2i(0, 1))
	var g = w.game
	var o: Vector2i = g.island.zone_origin(0, 1)
	var rx: int = int(g.island.west_x(g.island.PORT.y)) + 6 - o.x + 5
	var xo := int(args[2]) if args.size() > 2 else 0
	g.pc = (g.island.PORT.y + dy - o.y) * g.size + rx + xo
	g.sim.retier(g.pc)
	g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
	m.game = g
	m.view.game = g
	m.screen.game = g
	for i in 12:
		g.end_turn()
		await process_frame
	g._compute_fov()
	m.view.queue_redraw()
	for i in 10:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(args[1] if args.size() > 1 else "/tmp/claude-0/shot_port.png")
	print("fac counts ", g.fac.count(0), g.fac.count(1), g.fac.count(4), " veh ", g.vehicles.size(), " ai ", g.vehicles.filter(func(v): return v["ai"]).size())
	quit(0)
