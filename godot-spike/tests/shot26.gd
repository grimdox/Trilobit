extends SceneTree
## The character creation screen, fresh and after some choices.  godot ... -s tests/shot26.gd -- out_prefix
const MainScript = preload("res://src/main.gd")
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var m = MainScript.new()
	m.save_prefix = "user://shot_save_"
	m.settings_path = "user://shot_settings.json"
	root.add_child(m)
	for i in 4:
		await process_frame
	m.activate("new")
	for i in 3:
		await process_frame
	await _snap(out + "_fresh.png")
	# a few choices: a darker skin, a bob, green eyes, Strength up and Cognition and Endurance down
	for step in [[1, 3], [3, 4], [4, 2], [8, -1], [9, -2], [5, 3]]:
		m.cc_sel = step[0]
		for i in absi(step[1]):
			m.cc_step(1 if step[1] > 0 else -1)
	m.cc_sel = 5
	m._cc_sync()
	for i in 3:
		await process_frame
	await _snap(out + "_chosen.png")
	m.cc_sel = 7
	m.cc_step(-1)
	m.cc_sel = 10
	m.cc_begin()
	m._cc_sync()
	for i in 3:
		await process_frame
	await _snap(out + "_pool.png")
	quit()

func _snap(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
