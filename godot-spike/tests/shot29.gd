extends SceneTree
## Parking lots and charging stations at 27 px tiles with the 10-line log, and the interact picker.  godot ... -s tests/shot29.gd -- out_prefix
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
	var lot: Dictionary = {}
	for l in g.city.lots:
		if l["kind"] == "station":
			lot = l
			break
	var post: int = lot["posts"][0]
	g.pc = post + g.size
	g.last_pc = g.pc
	g.facing = Vector2i(1, 0)
	g.yen = 300
	for k in 9:
		g.say("Test message line %d: the city hums and a car alarm somewhere complains." % k)
	g._compute_fov()
	m.refresh()
	for i in 3:
		await process_frame
	await _snap(out + "_station.png")
	# the picker: a table beside the post
	var t: int = g.pc + 1
	g.city.tiles[t] = preload("res://src/citygen.gd").TID["gunsmith_table"]
	g.sim.walk[t] = 0
	m.pick_list = g.interactables()
	m.mode = "pick"
	m.refresh()
	for i in 3:
		await process_frame
	await _snap(out + "_pick.png")
	quit()

func _snap(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
