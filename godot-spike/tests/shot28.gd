extends SceneTree
## Charging post: the post on the street with the POWER bar, and the post's menu.  godot ... -s tests/shot28.gd -- out_prefix
const MainScript = preload("res://src/main.gd")
const WorldScript = preload("res://src/world.gd")
const CG = preload("res://src/citygen.gd")
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
	var post := -1
	for i in g.s2:
		if g.city.tiles[i] == CG.TID["charger"]:
			post = i
			break
	for id in ["smartlink", "optics", "legs", "dermal", "cortex", "mantis"]:
		g.implants[id] = true
	g.power_install("cortex")
	g.power = 140.0
	g.yen = 3000
	var dv := Vector2i.ZERO
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var c: int = post + d.y * g.size + d.x
		if g.sim.walk[c] == 1 and g.sim.at[c] == -1:
			g.pc = c
			dv = -d
			break
	g.last_pc = g.pc
	g.facing = dv
	g._compute_fov()
	m.refresh()
	for i in 3:
		await process_frame
	await _snap(out + "_street.png")
	g.act_move(dv.x, dv.y)
	m.menu = g.eco.charger_menu(g.charger_hit)
	g.charger_hit = -1
	m.mode = "talk"
	m.refresh()
	for i in 3:
		await process_frame
	await _snap(out + "_menu.png")
	quit()

func _snap(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
