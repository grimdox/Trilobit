extends SceneTree
const MainScript = preload("res://src/main.gd")
const WorldScript = preload("res://src/world.gd")
const BD = preload("res://src/boards.gd")
func _snap(path: String) -> void:
	for k in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
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
	var cell: int = int(g.city.cb_defs.keys()[0])
	var near := -1
	for d in [1, -1, g.size, -g.size]:
		if g.sim.walk[cell + d] == 1 and g.sim.at[cell + d] == -1:
			near = cell + d
			break
	g.pc = near
	g.last_pc = near
	g.sim.retier(near)
	g._compute_fov()
	m.refresh()
	await _snap(out + "_board.png")
	g.skills["analysis"] = 9
	BD.rec(g, cell)["conn"] = true
	BD.rec(g, cell)["acc"] = true
	m.menu = BD.open_menu(g, cell)
	m.mode = "talk"
	m.refresh()
	await _snap(out + "_menu.png")
	BD._unlocked(g, cell)["cameras"] = true
	var cams: Array = g.city.cb_defs[cell]["cams"]
	g.cam_view = {"board": cell, "i": 0}
	g._compute_fov()
	m.menu = {}
	m.mode = "camview"
	m.panel.visible = false
	m.refresh()
	await _snap(out + "_cam0.png")
	g.cam_view = {"board": cell, "i": 5}
	g._compute_fov()
	m.refresh()
	await _snap(out + "_cam5.png")
	quit()
