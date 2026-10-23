extends SceneTree
## Three scenes drawn by the game's own view at a 32 px tile (32 px dolls) and at a 64 px tile (64 px dolls):
## a busy sidewalk at noon, a charging station, and a street at night with a patrol.  The view's source is loaded with
## its tile size changed; nothing else differs.  godot ... -s tests/shot32.gd -- out_prefix [sizes, default 32,64]
const MainScript = preload("res://src/main.gd")
const WorldScript = preload("res://src/world.gd")

func _variant(tile: int, dolls: String) -> GDScript:
	var src := FileAccess.get_file_as_string("res://src/view.gd")
	src = src.replace("const TILE := 27", "const TILE := %d" % tile)
	src = src.replace("const S := 27.0 / 32.0", "const S := %d.0 / 32.0" % tile)
	src = src.replace('const DOLLS_WORLD := "res://gfx/dolls32"', 'const DOLLS_WORLD := "%s"' % dolls)
	src = src.replace("\t_draw_hud()", "\tpass")          # the scene only, no side panel
	var s := GDScript.new()
	s.source_code = src
	s.reload()
	return s

func _crowd(g, around: int, facs: Array, n: int) -> void:
	# bring people of these factions onto free walkable cells around a cell (the sim's own place())
	var cells := []
	for dy in range(-5, 6):
		for dx in range(1, 16):
			var c: int = around + dy * g.size + dx
			if c != g.pc and g.sim.walk[c] == 1 and g.sim.at[c] == -1 and (abs(dx) + abs(dy)) % 3 == 1:
				cells.append(c)
	var placed := 0
	for i in g.sim.n:
		if placed >= n or placed >= cells.size():
			break
		if g.sim.alive[i] == 1 and int(g.fac[i]) in facs:
			g.sim.place(i, cells[(placed * 7) % cells.size()])
			cells.remove_at((placed * 7) % cells.size())
			placed += 1

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
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
	var scenes := []
	# 1 a sidewalk at noon: residents, a few criminals and a Nasim runner
	var side := -1
	for c in range(g.size * (g.size / 2) + g.size / 3, g.size * g.size, 11):
		var cx: int = c % g.size
		if cx < 60 or cx > g.size - 60 or g.city.tiles[c] != 0:
			continue
		var open := 0
		for dy in range(-4, 5):
			for dx in range(0, 18):
				var t: int = g.city.tiles[c + dy * g.size + dx]
				if t == 0 or t == 1:
					open += 1
		if open >= 140 and g.city.tiles[c - 3 * g.size] == 2:
			side = c
			break
	scenes.append(["sidewalk", side, 12 * 600 + 10, [0, 0, 0, 4, 3], 16])
	# 2 the charging station
	var lot: Dictionary = {}
	for l in g.city.lots:
		if l["kind"] == "station":
			lot = l
			break
	scenes.append(["station", int(lot["posts"][0]) + g.size, 17 * 600 + 30, [0, 0, 4], 8])
	# 3 late evening at a Bratva hideout
	var thug := -1
	for i in g.sim.n:
		if g.fac[i] == 1 and g.city.tiles[g.sim.pos[i]] == 1 and g.sim.alive[i] == 1:
			thug = i
			break
	scenes.append(["hideout", int(g.sim.pos[thug]) + 2, 23 * 600 + 40, [1, 2, 1, 2, 0], 12])
	var args := OS.get_cmdline_user_args()
	var sizes: Array = Array(String(args[1]).split(",")) if args.size() > 1 else ["32", "64"]
	var views := []
	for sz in sizes:
		views.append([_variant(int(sz), "res://gfx/dolls" if int(sz) >= 64 else "res://gfx/dolls32"), int(sz)])
	for sc in scenes:
		g.pc = sc[1]
		g.last_pc = g.pc
		g.sim.tick = sc[2]
		g.facing = Vector2i(1, 0)
		g.sim.player = g.pc
		_crowd(g, g.pc, sc[3], sc[4])
		g.act_wait()
		g._compute_fov()
		for v in views:
			var vp := SubViewport.new()
			vp.size = Vector2i(1280, 704)
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(vp)
			var view = v[0].new()
			view.game = g
			view.tileset = m.tileset
			view.cols = 1280 / int(v[1]) + 1
			view.rows = 704 / int(v[1]) + 1
			view.focus_cell = g.pc + view.cols / 2 - 2   # the camera ahead of the player, into the view cone (facing east)
			vp.add_child(view)
			for k in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png("%s_%s_%d.png" % [out, sc[0], v[1]])
			vp.queue_free()
	quit()
