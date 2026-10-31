extends SceneTree
## screenshots inside generated sites, through the real flow (terminal, portal, step in): godot -s tests/shot_site.gd -- /tmp/shots/s
const MS = preload("res://src/missions.gd")
const MainScript = preload("res://src/main.gd")
const WorldScript = preload("res://src/world.gd")
const CG = preload("res://src/citygen.gd")
func _snap(path: String) -> void:
	for k in 6:
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
	var term := -1
	for i in g.s2:
		if g.city.tiles[i] == CG.TID["terminal"]:
			term = i
			break
	var TJ = preload("res://src/temp_jobs.gd")
	for ji in [0, 2]:
		g = w.game
		m.mode = "play"
		g.portal_close()
		var o: Dictionary = TJ.offers(9, term, 1)[ji]
		g.portal_open(o, term)
		var pcell: int = int(g.portal["cell"])
		for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var nc: int = pcell + d.y * g.size + d.x
			if g.sim.walk[nc] == 1 and g.sim.at[nc] == -1:
				g.pc = nc
				g.act_move(-d.x, -d.y)
				break
		m.refresh()
		for k in 4:
			await process_frame
		var s = w.game
		var site: Dictionary = s.city.get_meta("site")
		s.pc = int(site["stations"][0][0]) + s.size
		s.last_pc = s.pc
		s.sim.retier(s.pc)
		s._compute_fov()
		m.refresh()
		for k in 4:
			await process_frame
		await _snap("%s_%s.png" % [out, o["collar"]])
		var ex: int = int(site["exit"])
		s.pc = ex + s.size
		s.act_move(0, -1)
		m.refresh()
		for k in 4:
			await process_frame
	quit()
