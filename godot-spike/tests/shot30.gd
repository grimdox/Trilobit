extends SceneTree
## People drawn with the layered dolls: a busy street at 27 px tiles.  godot ... -s tests/shot30.gd -- out_prefix
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
	g.sim.tick = 13 * 60
	# the street cell with the most people around it
	for k in 3:
		g.act_wait()
	var best: int = g.pc
	var bn := 0
	for c in range(0, g.size * g.size, 7):
		if g.city.tiles[c] != 1 or g.sim.at[c] != -1:
			continue
		var n := 0
		for j in g.sim.n:
			if g.sim.alive[j] == 1 and g.cheb(g.sim.pos[j], c) <= 8:
				n += 1
		if n > bn:
			bn = n
			best = c
	print("people near: %d" % bn)
	g.pc = best
	g.last_pc = g.pc
	for k in 6:
		g.act_wait()
	g._compute_fov()
	m.refresh()
	for i in 3:
		await process_frame
	var t0 := Time.get_ticks_msec()
	await _snap(out + "_street.png")
	print("first frame with new looks: %d ms" % (Time.get_ticks_msec() - t0))
	t0 = Time.get_ticks_msec()
	m.refresh()
	await _snap(out + "_street2.png")
	print("next frame: %d ms" % (Time.get_ticks_msec() - t0))
	quit()

func _snap(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
