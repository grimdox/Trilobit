extends SceneTree
## screenshots of the creation screen (three body types), the key bindings and a street with props: godot -s tests/shot_screens.gd -- /tmp/shots/s
const MainScript = preload("res://src/main.gd")
const WorldScript = preload("res://src/world.gd")
func _snap(path: String) -> void:
	for k in 5:
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
	m.open_creation()
	for b in 3:
		m.cc["app"]["build"] = b
		m._cc_sync()
		await _snap("%s_create%d.png" % [out, b])
	m.screen_back = "title"; m.open_screen("keys")
	await _snap("%s_keys.png" % out)
	quit()
