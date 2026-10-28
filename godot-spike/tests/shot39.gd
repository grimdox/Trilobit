extends SceneTree
## Look at any kind of cell in the game's own view at 64 px, everything around it revealed (a test camera, not play):
## godot ... -s tests/shot39.gd -- out_prefix name:tile:z [name:tile:z ...] [@skip]
## tile is a city tile number (citygen.gd), z the level (0 the street, -1 the tunnels, -2 the sewers, 1.. floors up);
## the camera goes to the first such cell (after skipping @skip of them) that has a walkable neighbour.
const MainScript = preload("res://src/main.gd")
const WorldScript = preload("res://src/world.gd")

func _variant(tile: int, dolls: String) -> GDScript:
	var src := FileAccess.get_file_as_string("res://src/view.gd")
	src = src.replace("const TILE := 27", "const TILE := %d" % tile)
	src = src.replace("const S := 27.0 / 32.0", "const S := %d.0 / 32.0" % tile)
	src = src.replace('const DOLLS_WORLD := "res://gfx/dolls32"', 'const DOLLS_WORLD := "%s"' % dolls)
	src = src.replace("\t_draw_hud()", "\tpass")
	var s := GDScript.new()
	s.source_code = src
	s.reload()
	return s

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var m = MainScript.new()
	m.save_prefix = "user://shot_save_"
	m.settings_path = "user://shot_settings.json"
	root.add_child(m)
	await process_frame
	var w = WorldScript.new()
	w.start(21, 300)
	m.world = w
	m.start_play(w.game)
	await process_frame
	var g = w.game
	var view_s = _variant(64, "res://gfx/dolls")
	for a in range(1, args.size()):
		var spec: PackedStringArray = String(args[a]).split(":")
		var tile: int = int(spec[1])
		var z: int = int(spec[2]) if spec.size() > 2 else 0
		var skip: int = int(spec[3]) if spec.size() > 3 else 0
		var lvl: int = z if z >= 0 else g.city.zmax - z
		var base: int = lvl * g.s2
		var at := -1
		for i in range(0, g.s2, 3):
			var c: int = base + i
			if g.city.tiles[c] != tile:
				continue
			var ok := false
			for d in [1, -1, g.size, -g.size]:
				var n2: int = c + d
				if n2 >= base and n2 < base + g.s2 and g.sim.walk[n2] == 1:
					ok = true
			if ok:
				if skip > 0:
					skip -= 1
					continue
				at = c
				break
		print(spec[0], " -> ", at)
		if at < 0:
			continue
		g.pc = at
		g.last_pc = at
		g.sim.tick = 12 * 600 + 10
		g.sim.player = g.pc
		g._compute_fov()
		g.fov.visible.fill(1)
		g.fov.explored.fill(1)
		var vp := SubViewport.new()
		vp.size = Vector2i(1280, 768)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var view = view_s.new()
		view.game = g
		view.tileset = m.tileset
		view.cols = 1280 / 64 + 1
		view.rows = 768 / 64 + 1
		view.focus_cell = g.pc
		vp.add_child(view)
		for k in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s_%s.png" % [out, spec[0]])
		vp.queue_free()
	quit()
