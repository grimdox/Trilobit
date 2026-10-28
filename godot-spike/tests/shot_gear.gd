extends SceneTree
const MainScript = preload("res://src/main.gd")
const WorldScript = preload("res://src/world.gd")
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
	g.stow(g._new_item("trl_imp_x111"))
	for tab in ["implants", "equipment"]:
		m.open_tab(tab)
		for k in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [out, tab])
	quit()
