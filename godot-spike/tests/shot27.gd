extends SceneTree
## Mission terminals: a venue terminal, the mission screen, the open portal on the street, and a site.  godot ... -s tests/shot27.gd -- out_prefix
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
	var term := -1
	for i in g.s2:
		if g.city.tiles[i] == CG.TID["terminal"]:
			term = i
			break
	var dv := Vector2i.ZERO
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var c: int = term + d.y * g.size + d.x
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
	await _snap(out + "_terminal_world.png")
	m.open_terminal(term)
	m.screen_key(KEY_3)
	for i in 3:
		await process_frame
	await _snap(out + "_screen.png")
	m.screen_key(KEY_ENTER)
	m.refresh()
	var pcell: int = int(g.portal["cell"])
	var near := Vector2i.ZERO
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var c: int = pcell + d.y * g.size + d.x
		if g.sim.walk[c] == 1 and g.sim.at[c] == -1 and c != term:
			g.pc = c
			near = -d
			break
	g.facing = Vector2i(-near.x, -near.y)
	g._compute_fov()
	m.refresh()
	for i in 3:
		await process_frame
	await _snap(out + "_portal.png")
	g.act_move(near.x, near.y)
	m.refresh()
	for i in 3:
		await process_frame
	await _snap(out + "_site_start.png")
	var s = w.game
	var site: Dictionary = s.city.get_meta("site")
	s.pc = int(site["objective"]) + 64 * 2
	s.sim.retier(s.pc)
	s.facing = Vector2i(0, -1)
	s._compute_fov()
	m.refresh()
	for i in 3:
		await process_frame
	await _snap(out + "_site_objective.png")
	quit()

func _snap(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
