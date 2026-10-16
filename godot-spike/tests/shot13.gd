extends SceneTree
const MainScript = preload("res://src/main.gd")
func _initialize() -> void:
	var m = MainScript.new()
	m.save_prefix = "user://shot_save_"
	m.settings_path = "user://shot_settings.json"
	root.add_child(m)
	await process_frame
	m.begin_new(5)
	for i in 100:
		await process_frame
	m.open_screen("map")
	for i in 40:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shot_map.png")
	quit(0)
