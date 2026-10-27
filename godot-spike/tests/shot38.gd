extends SceneTree
## Business interiors with the new furniture, drawn by the game's own view at 64 px: the first cafe, bar, laundromat,
## office and gym the city generated (whatever district they fell in), the player stood inside.
## godot ... -s tests/shot38.gd -- out_prefix
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
	var CG = load("res://src/citygen.gd")
	var want := ["f_trl_coffee_bar", "f_trl_bar_counter", "f_trl_washing_machine", "f_trl_desk_workstation", "f_trl_treadmill", "f_trl_bed_double"]
	var found := {}
	var n: int = g.size * g.size
	for c in range(0, n, 1):
		var sp: String = String(CG.TILE_SPRITE.get(int(g.city.tiles[c]), ""))
		if sp in want and not found.has(sp):
			# a walkable cell two rows below it, in the room
			for k in range(1, 5):
				var cc: int = c + k * g.size
				if cc < n and g.sim.walk[cc] == 1:
					found[sp] = cc
					break
		if found.size() == want.size():
			break
	print("found ", found)
	var view_s = _variant(64, "res://gfx/dolls")
	for sp in found:
		g.pc = found[sp]
		g.last_pc = g.pc
		g.sim.tick = 12 * 600 + 10
		g.facing = Vector2i(0, -1)
		g.sim.player = g.pc
		g.act_wait()
		g._compute_fov()
		var vp := SubViewport.new()
		vp.size = Vector2i(1280, 704)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var view = view_s.new()
		view.game = g
		view.tileset = m.tileset
		view.cols = 1280 / 64 + 1
		view.rows = 704 / 64 + 1
		view.focus_cell = g.pc
		vp.add_child(view)
		for k in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s_%s.png" % [out, sp.substr(6)])
		vp.queue_free()
	quit()
