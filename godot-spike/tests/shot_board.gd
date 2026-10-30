extends SceneTree
## screenshots of the mission terminal's board (neutral, a changed setting with a done contract, no money) and a built site of each layout:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . -s tests/shot_board.gd -- /tmp/shots/b
const MainScript = preload("res://src/main.gd")
const WorldScript = preload("res://src/world.gd")
const CG = preload("res://src/citygen.gd")
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
	var w = WorldScript.new()
	w.start(21, 300)
	m.world = w
	m.start_play(w.game)
	await process_frame
	var g = w.game
	g.pc_level = 4
	var term := -1
	for i in g.s2:
		if g.city.tiles[i] == CG.TID["terminal"]:
			term = i
			break
	m.mode = "play"
	m.open_terminal(term)
	await _snap("%s_neutral.png" % out)
	m.screen_key(KEY_TAB)
	m.screen_key(KEY_LEFT)
	m.screen_key(KEY_DOWN)
	m.screen_key(KEY_RIGHT)
	m.screen_key(KEY_RIGHT)
	m.screen_key(KEY_DOWN)
	m.screen_key(KEY_LEFT)
	m.screen_key(KEY_UP)
	m.screen_key(KEY_UP)
	m.screen_key(KEY_UP)
	m.screen_key(KEY_RIGHT)
	m.tm["sel"] = 3
	g.done_contracts[String(m.tm["offers"][1]["id"])] = true
	await _snap("%s_changed.png" % out)
	g.yen = 50
	m.screen_key(KEY_R)
	m.tm["sel"] = 0
	await _snap("%s_poor.png" % out)
	g.yen = 900
	m.screen_key(KEY_R)
	await _snap("%s_regen.png" % out)
	quit()
