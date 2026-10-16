extends SceneTree
## usage: -- kind index  : stands the player outside the Nth venue of that kind (or just by index) and screenshots
const MainScript = preload("res://src/main.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var kind: String = args[0] if args.size() > 0 else "restaurant"
	var idx: int = int(args[1]) if args.size() > 1 else 0
	var out: String = args[2] if args.size() > 2 else "/tmp/claude-0/shot_v.png"
	var m = MainScript.new()
	m.save_prefix = "user://shot_save_"
	m.settings_path = "user://shot_settings.json"
	root.add_child(m)
	await process_frame
	m.begin_new(5)
	for i in 60:
		await process_frame
	var g = m.game
	print("STEP venues ", g.city.venues.size())
	var n := 0
	for v in g.city.venues:
		if v["kind"] == kind:
			if n == idx:
				print("STEP door ", v["door"])
				var dv: Vector2i = v["door"]
				var d: int = dv.y * g.size + dv.x
				g.pc = d
				g.sim.retier(g.pc)
				g._compute_fov()
				g.fov.visible.fill(1)
				g.fov.explored.fill(1)
				break
			n += 1
	if g.fov.visible.size() > 0:
		g.fov.visible.fill(1)
		g.fov.explored.fill(1)
	m.refresh()
	for i in 8:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit(0)
