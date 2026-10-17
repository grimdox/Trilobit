extends SceneTree
## The new city: the player stands at a chosen spot.  godot ... -s tests/shot20.gd -- out.png mode
## modes: bridge (a four-lane bridge over the river), highway (the six-lane bridge beside the rail bridge), rail (on the rail bridge), downtown
const MainScript = preload("res://src/main.gd")
const ISL = preload("res://src/island.gd")
func _initialize() -> void:
	var m = MainScript.new()
	m.save_prefix = "user://shot_save_"
	m.settings_path = "user://shot_settings.json"
	root.add_child(m)
	await process_frame
	m.begin_new(7)
	for i in 5:
		await process_frame
	var g = m.world.game
	var args := OS.get_cmdline_user_args()
	var mode: String = args[1] if args.size() > 1 else "bridge"
	var o: Vector2i = ISL.zone_origin(1, 1)
	var n: int = g.size
	var tx := 0
	var ty := 0
	match mode:
		"bridge":
			var e: int = ISL.BRIDGES_Y[1]
			var sp: Vector2i = g.island.river_span(o.y + e + 12)
			tx = (sp.x + sp.y) / 2 - o.x - 4
			ty = e + 20
		"highway":
			var tr: int = int(g.city.plan["trunk"])
			var sp2: Vector2i = g.island.river_span(o.y + tr + 18)
			tx = (sp2.x + sp2.y) / 2 - o.x
			ty = tr + 30
		"rail":
			var rb: Dictionary = g.city.plan["rail"]
			var sp3: Vector2i = g.island.river_span(o.y + int(rb["y_ret"]) + 2)
			tx = (sp3.x + sp3.y) / 2 - o.x
			ty = int(rb["y_ret"]) - 4
		_:
			tx = 440
			ty = 300
	g.pc = ty * n + tx
	g.sim.retier(g.pc)
	g.last_pc = g.pc
	g.fov.compute(tx, ty, 18)
	if mode == "rail":
		var t = g.transit
		var guard := 0
		while guard < t.period:
			t.clock += 1
			guard += 1
			var occ: Dictionary = t.occupancy()
			var hit := false
			for cc in occ:
				if int(cc) < g.s2 and g.city.tiles[int(cc)] == 14 and g.island.river_tile(o.x + int(cc) % n, o.y + int(cc) / n) == 1:
					hit = true
					break
			if hit:
				break
	m.game = g
	m.view.game = g
	m.screen.game = g
	for i in 3:
		g.end_turn()
		await process_frame
	g._compute_fov()
	m.view.queue_redraw()
	for i in 8:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(args[0] if args.size() > 0 else "/tmp/claude-0/shot_city.png")
	quit()
