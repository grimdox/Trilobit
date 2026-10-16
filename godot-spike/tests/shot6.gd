extends SceneTree
const MainScript = preload("res://src/main.gd")
func _initialize() -> void:
	var m = MainScript.new()
	m.save_prefix = "user://shot_save_"
	m.settings_path = "user://shot_settings.json"
	root.add_child(m)
	await process_frame
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shot_title.png")
	m.open_screen("options")
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shot_options.png")
	m.open_screen("keys")
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shot_keys.png")
	m.begin_new(5)
	for i in 40:
		await process_frame
	m.game.implants["legs"] = true
	m.game.implants["smartlink"] = true
	m.screen_back = "pause"
	m.open_screen("implants")
	m.screen.part_sel = 5
	await process_frame; await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shot_implants.png")
	m.open_screen("pause")
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shot_pause.png")
	quit(0)
