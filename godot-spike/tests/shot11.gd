extends SceneTree
const MainScript = preload("res://src/main.gd")
func _initialize() -> void:
	var m = MainScript.new()
	m.save_prefix = "user://shot_save_"
	m.settings_path = "user://shot_settings.json"
	root.add_child(m)
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shot_title.png")
	m.open_screen("loading")
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shot_loading.png")
	m.begin_new(5)
	for i in 100:
		await process_frame
	var g = m.game
	g.turn_to(0, -1)
	m.refresh()
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shot_facing.png")
	quit(0)
