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
	var lays := {"open": 0, "closed": 2, "mix": 1}
	for lay in lays:
		g = w.game
		g.yen = 1000
		m.mode = "play"
		g.portal_close()
		m.open_terminal(term)
		var b: Dictionary = g.boards[str(term)]
		b["sw"] = [lays[lay], 1, 1, 1]
		m.screen_key(KEY_R)
		m.tm["sel"] = 0
		m.screen_key(KEY_ENTER)
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
		s.say("Site: %s, %d rooms, %d hostiles." % [s.mission["offer"]["layout"], s.mission["offer"]["rooms"], s.mission["offer"]["hostiles"]])
		await _snap("%s_%s.png" % [out, lay])
		# leave again
		var ex: int = int(s.city.get_meta("site")["exit"])
		for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var nc2: int = ex + d.y * s.size + d.x
			if s.sim.walk[nc2] == 1 and s.sim.at[nc2] == -1:
				s.pc = nc2
				s.act_move(-d.x, -d.y)
				break
		m.refresh()
		for k in 4:
			await process_frame
	quit()
