extends SceneTree
## screenshots: the creation screen and the equipment tab in drop mode
func _init() -> void:
	var m = load("res://src/main.gd").new()
	root.add_child(m)
	await process_frame
	m.open_screen("title")
	m.open_creation()
	m.cc["app"]["sprite"] = 1
	m.cc["app"]["build"] = 2
	m.cc_sel = 2
	m._cc_sync()
	for i in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/n_create.png")
	quit()
