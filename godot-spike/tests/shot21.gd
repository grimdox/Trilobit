extends SceneTree
## Screens for 2026-10-18: the key list, the wait menu, the consume menu, looking, the Visuals options, the title.  godot ... -s tests/shot21.gd -- out_prefix
const MainScript = preload("res://src/main.gd")
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var m = MainScript.new()
	m.save_prefix = "user://shot_save_"
	m.settings_path = "user://shot_settings.json"
	root.add_child(m)
	for i in 4:
		await process_frame
	await _snap(out + "_title.png")
	m.begin_new(5)
	for i in 60:
		await process_frame
		if m.mode == "play":
			break
	await process_frame
	await _snap(out + "_play.png")
	var ev := InputEventKey.new()
	ev.pressed = true
	for k in [[KEY_QUESTION, "keys"], [KEY_ESCAPE, ""], [KEY_ENTER, "wait"], [KEY_ESCAPE, ""], [KEY_F8, "consume"], [KEY_ESCAPE, ""]]:
		ev = InputEventKey.new()
		ev.pressed = true
		ev.keycode = k[0]
		m._unhandled_key_input(ev)
		await process_frame
		await process_frame
		if k[1] != "":
			await _snap(out + "_" + k[1] + ".png")
	for k in [KEY_L, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_DOWN, KEY_DOWN]:
		ev = InputEventKey.new()
		ev.pressed = true
		ev.keycode = k
		m._unhandled_key_input(ev)
	await process_frame
	await process_frame
	await _snap(out + "_look.png")
	ev = InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_ESCAPE
	m._unhandled_key_input(ev)
	m.screen_back = "pause"
	m.open_screen("options")
	await process_frame
	await _snap(out + "_options.png")
	m.activate("visuals")
	await process_frame
	await process_frame
	await _snap(out + "_visuals.png")
	quit()

func _snap(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
