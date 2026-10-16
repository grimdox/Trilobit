extends SceneTree
const MainScript = preload("res://src/main.gd")
func _initialize() -> void:
	var m = MainScript.new()
	m.save_prefix = "user://shot_save_"
	m.settings_path = "user://shot_settings.json"
	root.add_child(m)
	await process_frame
	m.begin_new(5)
	for i in 60:
		await process_frame
	print("TS ", m.tileset.index.size(), " ", m.tileset.tile_w, " ", m.ts_index, " ", m.tileset.sprite("t_wall"))
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shot_play.png")
	quit(0)
